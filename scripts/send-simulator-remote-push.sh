#!/usr/bin/env bash

set -euo pipefail

readonly simulator_device="${1:-booted}"
readonly push_identifier="${2:-simulator-e2e-running-001}"
readonly task_identifier="${3:-remote-push-001}"
readonly agent_status="${4-running}"
readonly task_progress="${5:-1/3}"
readonly push_title="${6:-Simulator Push Probe}"
readonly push_body="${7:-Notification Service Extension archived this APNs Sandbox push.}"
readonly push_group="${8:-simulator-e2e}"
readonly ciphertext="${9-}"
readonly ciphertext_initialization_vector="${10-}"
readonly application_bundle_identifier="com.barkagent.ios"
readonly application_group_identifier="group.com.barkagent.shared"
readonly shared_store_filename="BarkAgent.sqlite"
readonly shared_preferences_relative_path="Library/Preferences/group.com.barkagent.shared.plist"

shared_container_path="$(
  xcrun simctl get_app_container \
    "${simulator_device}" \
    "${application_bundle_identifier}" \
    "${application_group_identifier}"
)"
readonly shared_container_path

readonly shared_store_path="${shared_container_path}/${shared_store_filename}"
readonly shared_preferences_path="${shared_container_path}/${shared_preferences_relative_path}"
server_address="$(
  sqlite3 -readonly "${shared_store_path}" \
    "SELECT ZADDRESS FROM ZSERVER WHERE LENGTH(ZKEY) > 0 ORDER BY ZCREATEDAT DESC LIMIT 1;"
)"
readonly server_address
device_key="$(
  sqlite3 -readonly "${shared_store_path}" \
    "SELECT ZKEY FROM ZSERVER WHERE LENGTH(ZKEY) > 0 ORDER BY ZCREATEDAT DESC LIMIT 1;"
)"
readonly device_key
device_token="$(
  /usr/libexec/PlistBuddy -c 'Print :apns.deviceToken' "${shared_preferences_path}"
)"
readonly device_token

if [[ -z "${server_address}" || -z "${device_key}" || -z "${device_token}" ]]; then
  echo "No complete simulator push registration was found." >&2
  exit 1
fi

curl --fail-with-body --silent --show-error \
  --output /dev/null \
  --request POST \
  "${server_address%/}/register" \
  --data-urlencode "device_key=${device_key}" \
  --data-urlencode "device_token=${device_token}"

push_arguments=(
  --data-urlencode "device_key=${device_key}"
  --data-urlencode "title=${push_title}"
  --data-urlencode "body=${push_body}"
  --data-urlencode "id=${push_identifier}"
  --data-urlencode "group=${push_group}"
)

if [[ -n "${agent_status}" ]]; then
  push_arguments+=(
    --data-urlencode "task_id=${task_identifier}"
    --data-urlencode "agent_status=${agent_status}"
    --data-urlencode "progress=${task_progress}"
  )
fi

if [[ -n "${ciphertext}" ]]; then
  push_arguments+=(--data-urlencode "ciphertext=${ciphertext}")
  if [[ -n "${ciphertext_initialization_vector}" ]]; then
    push_arguments+=(--data-urlencode "iv=${ciphertext_initialization_vector}")
  fi
fi

curl --fail-with-body --silent --show-error \
  --output /dev/null \
  --write-out 'Remote push request returned HTTP %{http_code}.\n' \
  --request POST \
  "${server_address%/}/push" \
  "${push_arguments[@]}"
