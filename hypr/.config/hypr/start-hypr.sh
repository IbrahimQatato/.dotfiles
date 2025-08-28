#!/bin/bash

if hyprctl monitors | grep -q "eDP-1"; then
    export HYPR_IS_LAPTOP=true
else
    export HYPR_IS_LAPTOP=false
fi

# exec Hyprland
