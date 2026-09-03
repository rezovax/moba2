#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
android_sdk="${ANDROID_SDK_ROOT:-/home/re7ov/Android/Sdk}"
adb="$android_sdk/platform-tools/adb"
scrcpy="$repo_root/.tools/scrcpy-linux-x86_64-v4.1/scrcpy"

if [[ ! -x "$adb" ]]; then
	echo "ADB не найден: $adb" >&2
	exit 1
fi

if [[ ! -x "$scrcpy" ]]; then
	echo "scrcpy не найден: $scrcpy" >&2
	exit 1
fi

device_serial="$("$adb" devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1; exit }')"
if [[ -z "$device_serial" ]]; then
	echo "Android-эмулятор не подключён." >&2
	exit 1
fi

"$adb" -s "$device_serial" shell am start \
	-n org.moba2.concept/com.godot.game.GodotAppLauncher

if [[ -z "${DISPLAY:-}" ]]; then
	export DISPLAY="$(systemctl --user show-environment | sed -n 's/^DISPLAY=//p')"
fi
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
	export WAYLAND_DISPLAY="$(systemctl --user show-environment | sed -n 's/^WAYLAND_DISPLAY=//p')"
fi
if [[ -z "${XAUTHORITY:-}" ]]; then
	export XAUTHORITY="$(systemctl --user show-environment | sed -n 's/^XAUTHORITY=//p')"
fi

exec "$scrcpy" \
	--serial "$device_serial" \
	--window-title "MOBA2 Android Emulator"
