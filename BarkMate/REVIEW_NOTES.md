# BarkAgent — App Store Review Notes

> 用于 App Store Connect 的 "App Review Information → Notes" 字段。
> 内容尽量简洁，仅包含审核员需要的事实信息。

## What the app does

BarkAgent is a personal inbox for push notifications from your own scripts,
CI pipelines, and AI coding agents. It receives Bark-protocol pushes,
aggregates them into per-agent task cards with a status machine
(running / waiting / blocked / done / failed / stale), and lets you browse
step history, search, pin, mute, and archive. All data is stored on device
(SwiftData in an App Group container). The app does not collect any
analytics, advertising IDs, or behavioral telemetry.

## Default push server

On first launch the app seeds a single default Bark-protocol server entry:

- URL: `https://barkagent.we2.xyz`
- Operator: developer-hosted, no account required
- Purpose: receive the device's APNs token so that user-issued HTTP POST
  requests can be relayed to this device as encrypted pushes
- Health check: `GET https://barkagent.we2.xyz/ping` should return
  `{"code":200,"message":"pong"}`

Users can add, edit, or remove servers from Settings → Manage servers at any
time. The default server can be removed entirely after the user adds their
own.

## Demo: how to send a test push to the review device

After install, open the Setup tab → Copy install (or Copy curl). The
pre-filled snippet shows exactly the request the user is expected to make.
Reviewers can paste the curl directly into a terminal; the push will appear
on the test device within seconds and create an agent task card on the
Dashboard.

```
curl -X POST "https://barkagent.we2.xyz/<key>" \
  -d "title=Hello from review" \
  -d "body=BarkAgent push demo" \
  -d "agent_id=review-agent" \
  -d "agent_status=running" \
  -d "progress=1/3"
```

(`<key>` is shown inside the app on the Setup tab after the first launch.)

## Demo account

None required. The app has no login.

## Privacy

- No tracking, no analytics, no third-party analytics SDKs.
- APNs token is sent only to the user-configured Bark server(s).
- Push contents are end-to-end encrypted client-side (AES) when a crypto key
  is configured by the user; otherwise sent over HTTPS.
- See `PrivacyInfo.xcprivacy` bundled in the app for Required Reason API
  declarations (UserDefaults / FileTimestamp / DiskSpace / SystemBootTime —
  all category 1 / first-party-only).

## Encryption export compliance

`ITSAppUsesNonExemptEncryption = false`. The app uses only standard Apple
cryptographic APIs (CryptoKit / CommonCrypto via CryptoSwift) for local
storage and notification payload decryption. No proprietary encryption,
no key exchange beyond standard TLS.

## Extensions

- `NotificationServiceExtension` — decrypts incoming Bark pushes and saves
  them to the shared SwiftData store. Required for push functionality.
- `BarkAgentWidgets` — Home Screen widget bundle showing active agent counts.

## Permissions requested

- Notifications (`UNUserNotificationCenter.requestAuthorization`) — required
  to receive Bark pushes. Requested on first launch.

## Contact

Build: 1.0.0 — TestFlight / App Store submission.
