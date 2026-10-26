# frida-ksu installer. Sourced by KernelSU update-binary (BusyBox ash).
# Installs frida-server for this device's ARCH, auto-detecting the latest
# upstream release. Falls back to FRIDA_FALLBACK_VERSION when offline.
#
# Provided by installer env: MODPATH TMPDIR ZIPFILE ARCH IS64BIT API
# Provided funcs: ui_print abort set_perm set_perm_recursive

# --- load shared helpers (already extracted to $MODPATH by update-binary) ---
if [ -f "$MODPATH/lib.sh" ]; then
  # shellcheck disable=SC1091
  . "$MODPATH/lib.sh"
else
  abort "! lib.sh missing in module package"
fi

# --- reverser.id banner ---
if [ -f "$MODPATH/banner.txt" ]; then
  while IFS= read -r _line || [ -n "$_line" ]; do
    ui_print "$_line"
  done < "$MODPATH/banner.txt"
fi

ui_print "- frida-ksu installer"
ui_print "- ARCH=$ARCH API=$API"

FARCH="$(frida_arch "$ARCH")"
[ -n "$FARCH" ] || abort "! unsupported ARCH: $ARCH"

LATEST="$(frida_latest_tag)"
if [ -n "$LATEST" ]; then
  ui_print "- latest upstream: $LATEST"
  FRIDA_VER="$LATEST"
else
  ui_print "! network unreachable, using fallback $FRIDA_FALLBACK_VERSION"
  FRIDA_VER="$FRIDA_FALLBACK_VERSION"
fi

URL="$(frida_asset_url "$FRIDA_VER" "$FARCH")"
ui_print "- downloading: $(basename "$URL")"

rm -f "$TMPDIR/frida.xz"
if ! frida_download "$URL" "$TMPDIR/frida.xz"; then
  abort "! download failed: $URL"
fi

mkdir -p "$MODPATH/system/bin"
if ! frida_extract "$TMPDIR/frida.xz" "$MODPATH/system/bin/frida-server"; then
  abort "! extract failed (xz missing or corrupt archive)"
fi
rm -f "$TMPDIR/frida.xz"

# Record installed version for service.sh / action.sh update checks
echo -n "$FRIDA_VER" > "$MODPATH/version"
chmod 644 "$MODPATH/version"

# Keep module.prop description in sync (single-line, LF)
if [ -f "$MODPATH/module.prop" ]; then
  sed -i "s/^version=.*/version=v${FRIDA_VER}/" "$MODPATH/module.prop"
fi

# --- permissions: THE critical part for this module ---
# Binary must be executable or service.sh fails silently at boot.
# Scripts must be executable. Everything else 644.
# Context: system_file so init/su transitions accept the binary path.
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/bin/frida-server" 0 0 0755 "u:object_r:system_file:s0"
set_perm "$MODPATH/service.sh" 0 0 0755 "u:object_r:system_file:s0"
set_perm "$MODPATH/action.sh" 0 0 0755 "u:object_r:system_file:s0"
set_perm "$MODPATH/customize.sh" 0 0 0755 "u:object_r:system_file:s0"
set_perm "$MODPATH/uninstall.sh" 0 0 0755 "u:object_r:system_file:s0"
[ -f "$MODPATH/sepolicy.rule" ] && set_perm "$MODPATH/sepolicy.rule" 0 0 0644 "u:object_r:system_file:s0"

# Hot-install support: no system/ overlay here (binary lives under
# system/bin but is executed by path, not overlaid), sepolicy loads at
# install, service.sh effect is achieved by starting the daemon now.
export MODULE_HOT_INSTALL_REQUEST=true
export MODULE_HOT_RUN_SCRIPT=service.sh

ui_print "- frida-server $FRIDA_VER ($FARCH) installed"
ui_print "- by reverser.id"
