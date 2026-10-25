#!/usr/bin/env bash

CURRENT_WORKSPACE=$(hyprctl activeworkspace -j | jq '.id')
TARGET_WORKSPACE="1$CURRENT_WORKSPACE"

# جلب عناوين النوافذ (استخدام -r لإزالة علامات التنصيص المزدوجة)
WINDOWS=$(hyprctl clients -j | jq -r --argjson TARGET_WS "$TARGET_WORKSPACE" '.[] | select(.workspace.id == $TARGET_WS) | .address')

for WINDOW_ADDRESS in $WINDOWS; do
    if [ -n "$WINDOW_ADDRESS" ]; then
        # نقل كل نافذة عبر عنوانها باستخدام دالة Lua
        hyprctl dispatch "hl.dsp.window.move({ workspace = $CURRENT_WORKSPACE, follow = false, window = 'address:$WINDOW_ADDRESS' })"
    fi
done
