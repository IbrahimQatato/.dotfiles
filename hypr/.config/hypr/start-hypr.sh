#!/bin/bash
DIR=/home/ibra/.config/hypr/
FILE=HYPR_IS_LAPTOP.env

if hyprctl monitors | grep -q "eDP-1"; then
    echo "env = HYPR_IS_LAPTOP,true" > "${DIR}${FILE}"
else
    echo "env = HYPR_IS_LAPTOP,false" > "${DIR}${FILE}"

fi

# exec Hyprland
