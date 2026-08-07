#!/usr/bin/env bash
set -euo pipefail
for inhibited in /sys/class/input/input*/inhibited; do
    dev="$(dirname "$inhibited")"
    name="$(cat "$dev/name" 2>/dev/null || true)"
    if [ "$name" != "HOLTEK USB-HID Keyboard" ]; then
        continue
    fi
    current="$(cat "$inhibited")"
    if [ "$current" = "0" ]; then
        echo 1 > "$inhibited"
        notify-send -t 1500 "Keyboard" "Built-in keyboard DISABLED"
    else
        echo 0 > "$inhibited"
        notify-send -t 1500 "Keyboard" "Built-in keyboard ENABLED"
    fi
done
