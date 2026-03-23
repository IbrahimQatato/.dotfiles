#!/bin/sh
while true; do
  battery=$(upower --dump | grep -E percentage | awk '{print $2}' | tr -d '%' | head -n 1)
  charging=$(upower -i $(upower -e | grep BAT) | grep "state" | awk '{print $2}')

  if [[ "$battery" -le 25 && "$charging" != "charging" ]] ; then
    # hyprctl notify 0 5000 0 "  Low battery: ${battery}%" 
    # Send a styled notification to SwayNC
    # -u critical: Highlights it in red (usually) and keeps it on screen
    # -h int:value: Tells SwayNC to render a progress bar
    ~/.dotfiles/hypr/.config/hypr/playsound.sh ~/.dotfiles/hypr/.config/hypr/toink.mp3 
    notify-send -u critical \
        -h string:x-canonical-private-synchronous:battery_low \
        -h int:value:"$battery" \
        "󰂃 Low Battery Warning" \
        "<b>${battery}%</b>. CHARGE ME!"
    sleep 240
  else
    sleep 120
  fi

done
