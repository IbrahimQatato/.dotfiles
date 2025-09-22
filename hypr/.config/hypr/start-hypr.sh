#!/bin/bash

if hyprctl monitors | grep -q "eDP-1"; then
    echo "env = HYPR_IS_LAPTOP,true" > display_env.conf
else
    echo "env = HYPR_IS_LAPTOP,false" > display_env.conf

fi

# exec Hyprland
