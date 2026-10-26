#!/system/bin/sh
# frida-ksu boot + hot-install entry point.
# Runs in late_start service mode (non-blocking) and once right after a
# hot install. Must be idempotent: kills the old daemon before starting.
MODDIR=${0%/*}

BIN="$MODDIR/system/bin/frida-server"
LOG="/data/adb/frida-ksu/frida.log"
PIDFILE="/data/adb/frida-ksu/frida.pid"
LISTEN_FILE="$MODDIR/listen_addr"

# Default: localhost only. Write e.g. "0.0.0.0:27042" into $MODDIR/listen_addr
# to expose ADB/Wi-Fi clients (understand the risk before doing so).
LISTEN="127.0.0.1:27042"
[ -f "$LISTEN_FILE" ] && LISTEN="$(cat "$LISTEN_FILE" 2>/dev/null)"

mkdir -p "$(dirname "$LOG")"

# Stop previous instance (tolerate stale pidfile + multiple matches)
if [ -f "$PIDFILE" ]; then
  OLDPID="$(cat "$PIDFILE" 2>/dev/null)"
  [ -n "$OLDPID" ] && kill "$OLDPID" 2>/dev/null
  rm -f "$PIDFILE"
fi
# shellcheck disable=SC2009
ps -o pid,args 2>/dev/null | grep "[f]rida-server" | awk '{print $1}' | while read -r p; do kill "$p" 2>/dev/null; done

[ -x "$BIN" ] || {
  echo "frida-ksu: $BIN missing or not executable" >>"$LOG" 2>&1
  exit 1
}

# -D daemonizes; stdout/err go to log for post-mortem
"$BIN" -D -l "$LISTEN" >>"$LOG" 2>&1 &
sleep 1
# shellcheck disable=SC2009
NEWPID="$(ps -o pid,args 2>/dev/null | grep "[f]rida-server" | awk '{print $1}' | head -n 1)"
[ -n "$NEWPID" ] && echo -n "$NEWPID" >"$PIDFILE"
echo "frida-ksu: started $(cat "$MODDIR/version" 2>/dev/null) pid=${NEWPID:-unknown} listen=$LISTEN" >>"$LOG" 2>&1
exit 0
