#!/usr/bin/env sh

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.1; done

# Launch bar1 and bar2
# polybar top;
# polybar bottom
# polybar bar &

if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    WIFI=$(ip a | grep -E "^[0-9]+:\s+wlp" | sed "s/^[0-9]\+:\s\+\(.*\):\s.*/\1/") MONITOR=$m polybar --reload bar &
  done
else
  WIFI=$(ip a | grep -E "^[0-9]+:\s+wlp" | sed "s/^[0-9]\+:\s\+\(.*\):\s.*/\1/") polybar --reload bar &
fi

echo "Bars launched..."
