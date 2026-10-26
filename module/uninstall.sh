#!/system/bin/sh
# frida-ksu cleanup on module removal.
MODDIR=${0%/*}
[ -f "/data/adb/frida-ksu/frida.pid" ] && kill "$(cat /data/adb/frida-ksu/frida.pid)" 2>/dev/null
# shellcheck disable=SC2009
ps -o pid,args 2>/dev/null | grep "[f]rida-server" | awk '{print $1}' | while read -r p; do kill "$p" 2>/dev/null; done
rm -rf /data/adb/frida-ksu
exit 0
