#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

BUILD_MODE="${1:-debug}"
PACKAGE_NAME="com.messenger.frontend"
MAIN_ACTIVITY=".MainActivity"

PRIMARY_AVD="${PRIMARY_AVD:-Medium_Phone_API_36}"
SECONDARY_AVD="${SECONDARY_AVD:-emulator2}"
TERTIARY_AVD="${TERTIARY_AVD:-Medium_Phone_API_36}"

declare -a SERIALS=("emulator-5554" "emulator-5556" "emulator-5558")
declare -a PORTS=("5554" "5556" "5558")
declare -a AVDS=("$PRIMARY_AVD" "$SECONDARY_AVD" "$TERTIARY_AVD")
declare -a EXTRA_ARGS=("" "" "-read-only")

log() {
  printf '[run-android-three] %s\n' "$1"
}

device_state() {
  adb devices | awk -v serial="$1" '$1 == serial { print $2 }'
}

is_device_ready() {
  [[ "$(device_state "$1")" == "device" ]]
}

start_emulator() {
  local avd="$1"
  local port="$2"
  local serial="emulator-$port"
  local extra_args="$3"

  if is_device_ready "$serial"; then
    log "$serial already running"
    return
  fi

  log "Launching $avd on $serial"
  nohup emulator "@$avd" -port "$port" -no-boot-anim -no-snapshot-save -gpu auto $extra_args \
    >"./flutter_${port}.log" 2>&1 &
}

wait_for_boot() {
  local serial="$1"

  log "Waiting for $serial"
  adb -s "$serial" wait-for-device >/dev/null 2>&1

  for _ in $(seq 1 120); do
    local boot_state
    boot_state="$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "$boot_state" == "1" ]]; then
      adb -s "$serial" shell input keyevent 82 >/dev/null 2>&1 || true
      log "$serial is ready"
      return
    fi
    sleep 2
  done

  log "Timed out waiting for $serial to finish booting"
  exit 1
}

launch_app() {
  local serial="$1"
  local apk_path="$2"

  log "Installing on $serial"
  adb -s "$serial" install -r "$apk_path" >/dev/null

  log "Starting app on $serial"
  adb -s "$serial" shell am start -n "$PACKAGE_NAME/$MAIN_ACTIVITY" >/dev/null
}

log "Refreshing dependencies"
flutter pub get >/dev/null

for index in 0 1 2; do
  start_emulator "${AVDS[$index]}" "${PORTS[$index]}" "${EXTRA_ARGS[$index]}"
done

for serial in "${SERIALS[@]}"; do
  wait_for_boot "$serial"
done

log "Building APK in $BUILD_MODE mode"
./android/gradlew -p android "app:assemble${BUILD_MODE^}" >/dev/null

APK_PATH="./build/app/outputs/apk/$BUILD_MODE/app-$BUILD_MODE.apk"
if [[ ! -f "$APK_PATH" ]]; then
  log "APK not found at $APK_PATH"
  exit 1
fi

for serial in "${SERIALS[@]}"; do
  launch_app "$serial" "$APK_PATH"
done

log "Opened app on ${SERIALS[*]}"
log "Emulator logs: ./flutter_5554.log ./flutter_5556.log ./flutter_5558.log"