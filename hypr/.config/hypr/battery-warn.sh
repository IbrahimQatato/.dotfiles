#!/bin/sh
while true; do
  battery=$(upower --dump | grep -E percentage | awk '{print $2}' | tr -d '%' | head -n 1)

  if [ "$battery" -le "20" ]; then
    # hyprctl notify 0 5000 0 "  Low battery: ${battery}%" 
    # Send a styled notification to SwayNC
    # -u critical: Highlights it in red (usually) and keeps it on screen
    # -h int:value: Tells SwayNC to render a progress bar
    paplay ./toink.mp3
    notify-send -u critical \
        -h string:x-canonical-private-synchronous:battery_low \
        -h int:value:"$battery" \
        "󰂃 Low Battery Warning" \
        "Your system is at <b>${battery}%</b>. Please connect a charger."
    sleep 240
  else
    sleep 120
  fi

done
