#!/usr/bin/env bash

# جلب مساحة العمل الحالية وتحديد مساحة الهدف
CURRENT_WORKSPACE=$(hyprctl activeworkspace -j | jq '.id')
TARGET_WORKSPACE="1$CURRENT_WORKSPACE"

# تنفيذ أمر النقل عبر صيغة Lua Dispatcher الجديدة بصمت (follow = false)
hyprctl dispatch "hl.dsp.window.move({ workspace = $TARGET_WORKSPACE, follow = false })"
