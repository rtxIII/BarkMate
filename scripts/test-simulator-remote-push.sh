#!/usr/bin/env bash

set -euo pipefail

readonly script_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly repository_root="$(cd -- "${script_directory}/.." && pwd)"
readonly project_path="${repository_root}/BarkMate/BarkMate.xcodeproj"
readonly scheme_name="BarkMate"
readonly simulator_device="${BARKAGENT_SIMULATOR_DEVICE:-booted}"
readonly simulator_destination="${BARKAGENT_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 17,OS=26.5}"
readonly application_bundle_identifier="com.barkagent.ios"
readonly application_process_marker="UIKitApplication:${application_bundle_identifier}["
readonly application_group_identifier="group.com.barkagent.shared"
readonly shared_store_filename="BarkAgent.sqlite"
readonly archive_wait_attempt_count=20
readonly archive_wait_interval_seconds=1
readonly application_launch_wait_attempt_count=60
readonly application_launch_wait_interval_seconds=0.5
readonly application_state_settle_interval_seconds=2
readonly remote_agent_identifier="simulator-e2e"
readonly legacy_group_identifier="legacy-e2e"
readonly crypto_failure_group_identifier="crypto-failure-e2e"
readonly remote_task_identifier="remote-push-lifecycle-$(date +%s)"
readonly foreground_task_identifier="remote-push-foreground-$(date +%s)"
readonly background_task_identifier="remote-push-background-$(date +%s)"
readonly terminated_task_identifier="remote-push-terminated-$(date +%s)"
readonly encrypted_task_identifier="remote-push-encrypted-$(date +%s)"
readonly encryption_key_hex="3031323334353637383961626364656630313233343536373839616263646566"
readonly encryption_iv_text="abcdef0123456789"
readonly encryption_iv_hex="61626364656630313233343536373839"
readonly remote_push_compilation_conditions='$(inherited) BARKAGENT_REMOTE_PUSH_E2E'
readonly permission_test="BarkMateUITests/BarkMateRemoteNotificationTests/testNotificationPermissionCanBeGranted"
readonly running_test="BarkMateUITests/BarkMateRemoteNotificationTests/testRemoteNotificationRunningStageAppearsOnceOnDashboard"
readonly waiting_test="BarkMateUITests/BarkMateRemoteNotificationTests/testRemoteNotificationWaitingStageMovesSameTaskToNeedsYou"
readonly done_test="BarkMateUITests/BarkMateRemoteNotificationTests/testRemoteNotificationDoneStageMovesSameTaskToSettledWithAllSteps"
readonly foreground_test="BarkMateUITests/BarkMateRemoteNotificationTests/testRemoteNotificationRefreshesDashboardWhileAppIsForeground"
readonly background_test="BarkMateUITests/BarkMateRemoteNotificationTests/testRemoteNotificationArchivesWhileBackgroundedAndRefreshesOnReturn"
readonly terminated_test="BarkMateUITests/BarkMateRemoteNotificationTests/testRemoteNotificationArchivesWhileTerminatedAndAppearsAfterLaunch"
readonly legacy_test="BarkMateUITests/BarkMateRemoteNotificationTests/testLegacyRemoteNotificationAppearsInIncomingHistory"
readonly crypto_fixture_test="BarkMateTests/RemotePushCryptoFixtureTests/testInstallSharedCryptoFixture"
readonly crypto_key_removal_fixture_test="BarkMateTests/RemotePushCryptoFixtureTests/testRemoveSharedCryptoKeyFixture"
readonly crypto_cleanup_fixture_test="BarkMateTests/RemotePushCryptoFixtureTests/testRemoveSharedCryptoFixture"
readonly encrypted_test="BarkMateUITests/BarkMateRemoteNotificationTests/testEncryptedRemoteNotificationDecryptsIntoDashboardTask"
readonly crypto_failure_test="BarkMateUITests/BarkMateRemoteNotificationTests/testEncryptedRemoteNotificationWithoutKeyFallsBackToIncomingHistory"

interactive_test_process_id=""

terminate_interactive_test() {
  if [[ -n "${interactive_test_process_id}" ]] && kill -0 "${interactive_test_process_id}" 2>/dev/null; then
    kill "${interactive_test_process_id}"
    wait "${interactive_test_process_id}" 2>/dev/null || true
  fi
}

trap terminate_interactive_test EXIT

run_ui_test() {
  local test_identifier="$1"
  xcodebuild \
    -quiet \
    -project "${project_path}" \
    -scheme "${scheme_name}" \
    -destination "${simulator_destination}" \
    -only-testing:"${test_identifier}" \
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS=${remote_push_compilation_conditions}" \
    test
}

run_ui_test "${permission_test}"

shared_container_path="$(
  xcrun simctl get_app_container \
    "${simulator_device}" \
    "${application_bundle_identifier}" \
    "${application_group_identifier}"
)"
readonly shared_container_path
readonly shared_store_path="${shared_container_path}/${shared_store_filename}"

cleanup_remote_probe_data() {
  sqlite3 "${shared_store_path}" \
    "BEGIN IMMEDIATE;
     DELETE FROM ZAGENTSTEP WHERE ZTASK IN (
       SELECT Z_PK FROM ZAGENTTASK WHERE ZAGENTID = '${remote_agent_identifier}'
     );
     DELETE FROM ZAGENTTASK WHERE ZAGENTID = '${remote_agent_identifier}';
     COMMIT;"
}

cleanup_legacy_probe_data() {
  sqlite3 "${shared_store_path}" \
    "DELETE FROM ZAGENTINBOXITEM WHERE ZGROUP = '${legacy_group_identifier}';"
}

cleanup_crypto_failure_probe_data() {
  sqlite3 "${shared_store_path}" \
    "DELETE FROM ZAGENTINBOXITEM WHERE ZGROUP = '${crypto_failure_group_identifier}';"
}

task_updated_at() {
  local task_identifier="$1"
  sqlite3 -readonly "${shared_store_path}" \
    "SELECT COALESCE(MAX(ZUPDATEDAT), 0) FROM ZAGENTTASK WHERE ZAGENTID = '${remote_agent_identifier}' AND ZTASKID = '${task_identifier}';"
}

wait_for_archive_update() {
  local previous_updated_at="$1"
  local task_identifier="$2"
  local current_updated_at
  local attempt
  for ((attempt = 1; attempt <= archive_wait_attempt_count; attempt += 1)); do
    current_updated_at="$(task_updated_at "${task_identifier}")"
    if [[ "${current_updated_at}" != "0" && "${current_updated_at}" != "${previous_updated_at}" ]]; then
      return 0
    fi
    sleep "${archive_wait_interval_seconds}"
  done

  echo "Timed out waiting for Notification Service Extension archival." >&2
  return 1
}

wait_for_legacy_archive() {
  local archived_item_count
  local attempt
  for ((attempt = 1; attempt <= archive_wait_attempt_count; attempt += 1)); do
    archived_item_count="$(
      sqlite3 -readonly "${shared_store_path}" \
        "SELECT COUNT(*) FROM ZAGENTINBOXITEM WHERE ZGROUP = '${legacy_group_identifier}';"
    )"
    if [[ "${archived_item_count}" == "1" ]]; then
      return 0
    fi
    sleep "${archive_wait_interval_seconds}"
  done

  echo "Timed out waiting for the legacy push to enter Incoming History." >&2
  return 1
}

wait_for_crypto_failure_archive() {
  local archived_item_count
  local attempt
  for ((attempt = 1; attempt <= archive_wait_attempt_count; attempt += 1)); do
    archived_item_count="$(
      sqlite3 -readonly "${shared_store_path}" \
        "SELECT COUNT(*) FROM ZAGENTINBOXITEM
         WHERE ZGROUP = '${crypto_failure_group_identifier}'
           AND ZBODY = 'Decryption Failed'
           AND CAST(ZMETADATA AS TEXT) LIKE '%\"ciphertext\":%'
           AND CAST(ZMETADATA AS TEXT) LIKE '%\"reason\":\"decryptionFailed\"%'
           AND CAST(ZMETADATA AS TEXT) LIKE '%\"iv\":\"${encryption_iv_text}\"%';"
    )"
    if [[ "${archived_item_count}" == "1" ]]; then
      return 0
    fi
    sleep "${archive_wait_interval_seconds}"
  done

  echo "Timed out waiting for encrypted push failure degradation." >&2
  return 1
}

wait_for_application_process() {
  local launch_services
  local attempt
  for ((attempt = 1; attempt <= application_launch_wait_attempt_count; attempt += 1)); do
    launch_services="$(xcrun simctl spawn "${simulator_device}" launchctl list)"
    if [[ "${launch_services}" == *"${application_process_marker}"* ]]; then
      return 0
    fi
    sleep "${application_launch_wait_interval_seconds}"
  done

  echo "Timed out waiting for BarkAgent to enter the foreground test." >&2
  return 1
}

wait_for_application_process_to_stop() {
  local launch_services
  local attempt
  for ((attempt = 1; attempt <= application_launch_wait_attempt_count; attempt += 1)); do
    launch_services="$(xcrun simctl spawn "${simulator_device}" launchctl list)"
    if [[ "${launch_services}" != *"${application_process_marker}"* ]]; then
      return 0
    fi
    sleep "${application_launch_wait_interval_seconds}"
  done

  echo "Timed out waiting for BarkAgent to terminate before the remote push." >&2
  return 1
}

send_stage_and_verify() {
  local stage_name="$1"
  local task_progress="$2"
  local push_title="$3"
  local push_body="$4"
  local test_identifier="$5"
  local previous_updated_at
  previous_updated_at="$(task_updated_at "${remote_task_identifier}")"

  "${script_directory}/send-simulator-remote-push.sh" \
    "${simulator_device}" \
    "${remote_task_identifier}-${stage_name}" \
    "${remote_task_identifier}" \
    "${stage_name}" \
    "${task_progress}" \
    "${push_title}" \
    "${push_body}"

  wait_for_archive_update "${previous_updated_at}" "${remote_task_identifier}"
  run_ui_test "${test_identifier}"
}

cleanup_remote_probe_data

send_stage_and_verify \
  "running" \
  "1/3" \
  "Simulator Push Running" \
  "Remote lifecycle stage 1 of 3 is running." \
  "${running_test}"

send_stage_and_verify \
  "waiting_input" \
  "2/3" \
  "Simulator Push Waiting" \
  "Remote lifecycle stage 2 of 3 needs user input." \
  "${waiting_test}"

send_stage_and_verify \
  "done" \
  "3/3" \
  "Simulator Push Done" \
  "Remote lifecycle stage 3 of 3 completed." \
  "${done_test}"

cleanup_remote_probe_data

xcrun simctl terminate "${simulator_device}" "${application_bundle_identifier}" 2>/dev/null || true
run_ui_test "${foreground_test}" &
interactive_test_process_id=$!
wait_for_application_process

"${script_directory}/send-simulator-remote-push.sh" \
  "${simulator_device}" \
  "${foreground_task_identifier}-running" \
  "${foreground_task_identifier}" \
  "running" \
  "1/3" \
  "Simulator Push Foreground" \
  "The Dashboard refreshed while BarkAgent remained in the foreground."

wait "${interactive_test_process_id}"
interactive_test_process_id=""

cleanup_remote_probe_data

xcrun simctl terminate "${simulator_device}" "${application_bundle_identifier}" 2>/dev/null || true
run_ui_test "${background_test}" &
interactive_test_process_id=$!
wait_for_application_process
sleep "${application_state_settle_interval_seconds}"

"${script_directory}/send-simulator-remote-push.sh" \
  "${simulator_device}" \
  "${background_task_identifier}-running" \
  "${background_task_identifier}" \
  "running" \
  "1/3" \
  "Simulator Push Background" \
  "BarkAgent received this notification while it was backgrounded."

wait_for_archive_update "0" "${background_task_identifier}"
wait "${interactive_test_process_id}"
interactive_test_process_id=""

cleanup_remote_probe_data

xcrun simctl terminate "${simulator_device}" "${application_bundle_identifier}" 2>/dev/null || true
run_ui_test "${terminated_test}" &
interactive_test_process_id=$!
wait_for_application_process
wait_for_application_process_to_stop

"${script_directory}/send-simulator-remote-push.sh" \
  "${simulator_device}" \
  "${terminated_task_identifier}-running" \
  "${terminated_task_identifier}" \
  "running" \
  "1/3" \
  "Simulator Push Terminated" \
  "BarkAgent received this notification after its process was terminated."

wait_for_archive_update "0" "${terminated_task_identifier}"
wait "${interactive_test_process_id}"
interactive_test_process_id=""

cleanup_legacy_probe_data

"${script_directory}/send-simulator-remote-push.sh" \
  "${simulator_device}" \
  "legacy-e2e-$(date +%s)" \
  "" \
  "" \
  "" \
  "Simulator Push Legacy" \
  "Legacy Bark notification archived through real APNs." \
  "${legacy_group_identifier}"

wait_for_legacy_archive
run_ui_test "${legacy_test}"

cleanup_remote_probe_data
run_ui_test "${crypto_fixture_test}"

encrypted_plaintext="{
  \"title\": \"Simulator Push Encrypted\",
  \"body\": \"Encrypted payload decrypted by Notification Service Extension.\",
  \"group\": \"${remote_agent_identifier}\",
  \"task_id\": \"${encrypted_task_identifier}\",
  \"agent_status\": \"running\",
  \"progress\": \"1/2\",
  \"id\": \"${encrypted_task_identifier}-running\"
}"
readonly encrypted_plaintext
encrypted_ciphertext="$(
  printf '%s' "${encrypted_plaintext}" | openssl enc \
    -aes-256-cbc \
    -K "${encryption_key_hex}" \
    -iv "${encryption_iv_hex}" \
    -base64 \
    -A
)"
readonly encrypted_ciphertext

"${script_directory}/send-simulator-remote-push.sh" \
  "${simulator_device}" \
  "${encrypted_task_identifier}-envelope" \
  "" \
  "" \
  "" \
  "Encrypted Bark Payload" \
  "Decrypting on device." \
  "${remote_agent_identifier}" \
  "${encrypted_ciphertext}" \
  "${encryption_iv_text}"

wait_for_archive_update "0" "${encrypted_task_identifier}"
run_ui_test "${encrypted_test}"

cleanup_crypto_failure_probe_data
run_ui_test "${crypto_key_removal_fixture_test}"

"${script_directory}/send-simulator-remote-push.sh" \
  "${simulator_device}" \
  "${encrypted_task_identifier}-missing-key" \
  "" \
  "" \
  "" \
  "Simulator Push Missing Key" \
  "Decrypting without a local key." \
  "${crypto_failure_group_identifier}" \
  "${encrypted_ciphertext}" \
  "${encryption_iv_text}"

wait_for_crypto_failure_archive
run_ui_test "${crypto_failure_test}"
run_ui_test "${crypto_cleanup_fixture_test}"
cleanup_remote_probe_data
cleanup_crypto_failure_probe_data
