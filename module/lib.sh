# Common helpers for frida-ksu. Sourced by customize.sh and action.sh.
# Must stay POSIX ash-compatible (KernelSU runs BusyBox ash standalone mode).
# No bashisms: no arrays, no [[ ]], no local -r chains.

FRIDA_REPO="frida/frida"
FRIDA_FALLBACK_VERSION="17.24.3"
FRIDA_BIN_NAME="frida-server"
FRIDA_PORT="27042"

# $1 = KSU ARCH value (arm/arm64/x86/x64). Echoes frida arch or empty.
frida_arch() {
  case "$1" in
    arm) echo "arm" ;;
    arm64) echo "arm64" ;;
    x86) echo "x86" ;;
    x64|x86_64|amd64) echo "x86_64" ;;
    *) echo "" ;;
  esac
}

# Echoes latest tag (e.g. 17.24.3) or empty on failure. Never aborts.
frida_latest_tag() {
  _tag=""
  if command -v curl >/dev/null 2>&1; then
    _tag="$(curl -fsSL --connect-timeout 10 "https://api.github.com/repos/${FRIDA_REPO}/releases/latest" 2>/dev/null | grep '"tag_name"' | head -n 1 | cut -d'"' -f4)"
  elif command -v wget >/dev/null 2>&1; then
    _tag="$(wget -qO- --timeout=10 "https://api.github.com/repos/${FRIDA_REPO}/releases/latest" 2>/dev/null | grep '"tag_name"' | head -n 1 | cut -d'"' -f4)"
  fi
  # tags has no 'v' prefix upstream (e.g. 17.24.3); strip one if present
  _tag="${_tag#v}"
  echo "$_tag"
}

frida_asset_url() {
  # $1 = version (no v prefix), $2 = frida arch
  echo "https://github.com/${FRIDA_REPO}/releases/download/$1/${FRIDA_BIN_NAME}-$1-android-$2.xz"
}

# Numeric compare of dotted versions. Echoes: 1 if $1 > $2, -1 if $1 < $2, 0 if equal.
frida_vercmp() {
  _a="$1"
  _b="$2"
  _i=1
  while [ $_i -le 4 ]; do
    _pa="$(echo "$_a" | cut -d. -f$_i)"
    _pb="$(echo "$_b" | cut -d. -f$_i)"
    _pa="${_pa:-0}"
    _pb="${_pb:-0}"
    # strip non-digits (e.g. "3-beta")
    _pa="$(echo "$_pa" | tr -cd '0-9')"
    _pb="$(echo "$_pb" | tr -cd '0-9')"
    _pa="${_pa:-0}"
    _pb="${_pb:-0}"
    if [ "$_pa" -gt "$_pb" ] 2>/dev/null; then echo 1; return; fi
    if [ "$_pa" -lt "$_pb" ] 2>/dev/null; then echo "-1"; return; fi
    _i=$((_i + 1))
  done
  echo 0
}

# $1 = url, $2 = dest file. Returns 0 on success.
frida_download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fSL --connect-timeout 15 --retry 2 -o "$2" "$1" && return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -O "$2" "$1" && return 0
  fi
  return 1
}

# $1 = .xz file, $2 = dest binary. Returns 0 on success.
frida_extract() {
  if command -v xz >/dev/null 2>&1; then
    xz -dc "$1" > "$2" && return 0
  fi
  if command -v unxz >/dev/null 2>&1; then
    unxz -c "$1" > "$2" && return 0
  fi
  if command -v 7z >/dev/null 2>&1; then
    7z x -so "$1" > "$2" && return 0
  fi
  return 1
}
