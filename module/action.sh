#!/system/bin/sh
# frida-ksu Action button: update checker + updater + status.
# Output is shown in the KernelSU manager dialog, so plain echo only.
MODDIR=${0%/*}

# shellcheck disable=SC1091
[ -f "$MODDIR/lib.sh" ] && . "$MODDIR/lib.sh"

# reverser.id banner (manager Action dialog)
[ -f "$MODDIR/banner.txt" ] && cat "$MODDIR/banner.txt"

CUR="$(cat "$MODDIR/version" 2>/dev/null)"
[ -n "$CUR" ] || CUR="unknown"
echo "frida-ksu: installed $CUR"

LATEST="$(frida_latest_tag)"
if [ -z "$LATEST" ]; then
  echo "frida-ksu: network unreachable, cannot check for updates"
  if [ -x "$MODDIR/system/bin/frida-server" ]; then
    if ps -o args 2>/dev/null | grep -q "[f]rida-server"; then
      echo "frida-ksu: daemon is RUNNING"
    else
      echo "frida-ksu: daemon is STOPPED, restarting..."
      sh "$MODDIR/service.sh"
    fi
  else
    echo "frida-ksu: binary missing, reinstall the module"
  fi
  exit 0
fi

echo "frida-ksu: latest upstream $LATEST"
CMP="$(frida_vercmp "$LATEST" "$CUR")"
if [ "$CMP" != "1" ]; then
  echo "frida-ksu: up to date"
  exit 0
fi

echo "frida-ksu: updating $CUR -> $LATEST ..."
# Detect device arch from running binary (getprop fallback chain)
ARCH_PROP="$(getprop ro.product.cpu.abi 2>/dev/null)"
case "$ARCH_PROP" in
  arm64*) KARCH="arm64" ;;
  armeabi*) KARCH="arm" ;;
  x86_64*) KARCH="x86_64" ;;
  x86*) KARCH="x86" ;;
  *) KARCH="arm64" ;;
esac

URL="$(frida_asset_url "$LATEST" "$KARCH")"
TMP="/data/local/tmp/frida-ksu-update.xz"
rm -f "$TMP"
if ! frida_download "$URL" "$TMP"; then
  echo "frida-ksu: download failed"
  exit 1
fi
if ! frida_extract "$TMP" "$MODDIR/system/bin/frida-server"; then
  echo "frida-ksu: extract failed"
  rm -f "$TMP"
  exit 1
fi
rm -f "$TMP"
chmod 755 "$MODDIR/system/bin/frida-server"
chcon "u:object_r:system_file:s0" "$MODDIR/system/bin/frida-server" 2>/dev/null
echo -n "$LATEST" >"$MODDIR/version"
chmod 644 "$MODDIR/version"
if [ -f "$MODDIR/module.prop" ]; then
  sed -i "s/^version=.*/version=v${LATEST}/" "$MODDIR/module.prop"
fi
sh "$MODDIR/service.sh"
echo "frida-ksu: updated to $LATEST and restarted"
