#!/bin/bash
# usage: shot.sh <build-dir> <data-dir> <out.png> [Page] [theme]
B=$1; D=$2; OUT=$3; PAGE=${4:-Library}
rm -f "$OUT"
QT_QPA_PLATFORM=offscreen PRISM_MODERN_PAGE=$PAGE PRISM_MODERN_SCREENSHOT=$OUT "$B/prismlauncher.app/Contents/MacOS/prismlauncher" -d "$D" > "$OUT.log" 2>&1 &
PID=$!
for i in $(seq 1 60); do [ -f "$OUT" ] && break; sleep 0.5; done
sleep 0.5; kill -9 $PID 2>/dev/null
grep -E "qrc:|\.qml:|ReferenceError|TypeError|Critical" "$OUT.log" | head -30
[ -f "$OUT" ] && echo "saved $OUT" || { echo "no screenshot"; tail -20 "$OUT.log"; }
