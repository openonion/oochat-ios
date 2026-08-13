# OpenOnion for iOS

[![Build & Test](https://github.com/openonion/oochat-ios/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/openonion/oochat-ios/actions/workflows/ios-ci.yml)
[![Pre-publication audit](https://github.com/openonion/oochat-ios/actions/workflows/audit.yml/badge.svg)](https://github.com/openonion/oochat-ios/actions/workflows/audit.yml)

Native SwiftUI client for [ConnectOnion](https://docs.connectonion.com/) agents.
Add an agent by its `0x…` address and talk to it from your phone — the same
protocol the [web client](https://github.com/openonion/oo-chat) speaks.

Ships as **OpenOnion** on the App Store. The repository and bundle identifier
keep the `oochat` name they share with the other native clients; that name is
for developers, not for the home screen.

## Who this is for

This is a starting point, not a finished product you are meant to use as-is.

If you are running ConnectOnion agents and your users want a native iOS app
rather than a browser tab, fork this, change the four things under
[Make it yours](#make-it-yours), and ship it under your own Apple Developer
account. The web client is the default answer; this exists for when the default
is not enough.

## What it does

- Manage multiple agents by Ed25519 address; add one manually or by **scanning a
  QR code**, and share a saved agent back out as a QR code
- Discover an agent on the local network first, falling back to the ConnectOnion
  relay
- Stream replies, thinking updates, tool calls and tool results as they arrive
- **Four trust modes** — Safe, Plan, Accept Edits, and Ultra Work
- Handle tool approvals, plan reviews, agent questions and Ultra Work
  checkpoints inline in the transcript
- Attach up to 10 images and 10 files per message (10 MB each)
- **Dictate a prompt** using on-device speech recognition
- Render Markdown and syntax-highlighted code
- Persist agents, conversations, messages, attachments and session state with
  **SwiftData**
- Search conversation titles and message bodies
- Queue, retry or cancel a message when connectivity changes
- Reuse WebSocket sessions through a bounded connection pool
- Follow the system appearance, or pick light or dark explicitly

### What it does not do

- 🔴 **Do not ship this to iOS 17 yet.** The project deploys to iOS 17.0, but on
  an iOS 17.5 simulator 22 of the SwiftData persistence tests fail: messages,
  delivery state and attachments write and read back empty, and the store does
  not survive a relaunch. The same tests pass on iOS 26. The models use
  `@Relationship(deleteRule: .cascade, inverse:)` to-many relationships, which
  iOS 17's SwiftData does not honour reliably — so a user on iOS 17 would lose
  every conversation. `.github/workflows/ios-floor.yml` runs the persistence
  tests across runtimes to find the real floor; raise
  `IPHONEOS_DEPLOYMENT_TARGET` to it before release.
- **No iPad-specific layout.** It runs on iPad, but the layout is the phone one
- **Not on the App Store.** This is source you build and ship yourself; see
  [Shipping it](#shipping-it)
- Speech recognition and the camera need the user's permission at first use; if
  either is refused, dictation and QR scanning are unavailable rather than
  degraded

## Requirements

| | |
|---|---|
| iOS | 17.0 is the declared target, but see the warning under [What it does not do](#what-it-does-not-do) — persistence is broken there |
| Xcode | 15.4 or later builds it. Xcode 26 additionally compiles the iOS 26 glass styling — see [Toolchains](#toolchains) |
| An agent | See [connectonion](https://github.com/openonion/connectonion) — `pip install connectonion`, then `co init` |

## Build and run

```bash
git clone https://github.com/openonion/oochat-ios.git
cd oochat-ios
open OOChatIOS.xcodeproj
```

Build and run the `OOChatIOS` scheme. Or, from the command line:

```bash
xcodebuild build \
  -project OOChatIOS.xcodeproj -scheme OOChatIOS \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

There is also `./scripts/setup.sh`, which picks a simulator, builds, installs
and launches in one step.

### Toolchains

The app deploys to iOS 17, but a few visual touches use iOS 26 APIs — Liquid
Glass surfaces and one toolbar refinement. Those are guarded twice:
`#available` for the run time, and `#if compiler(>=6.2)` for the compile.

The compile-time guard matters because `#available` does not help there: a
symbol has to exist in the SDK you are building against. Without it, Xcode 15
fails outright on `Glass`, `glassEffect` and `sharedBackgroundVisibility`.

So: **Xcode 15.4 builds a working app** with the same non-glass surfaces that
iOS 17 users and anyone with Reduce Transparency enabled see anyway.
**Xcode 26 additionally compiles the glass path.** Neither is a stub.

## Make it yours

| # | What | Where |
|---|---|---|
| 1 | Bundle identifier | `OOChatIOS.xcodeproj/project.pbxproj` — currently `ai.openonion.oochat` |
| 2 | Display name | `OOChatIOS/Resources/Info.plist` |
| 3 | Icon and accent | `OOChatIOS/Resources/Assets.xcassets` |
| 4 | Brand colour | `OOChatIOS/Shared/AppTheme.swift` |

### Colour

One accent, on a neutral canvas. `AppTheme.primary` is the ConnectOnion green —
`#16A34A` in light mode, `#4ADE80` in dark — the same ramp as the web client, so
a user moving between the two sees one product. Red is reserved for destructive
actions; everything else is neutral.

Two other files carry surface colours derived from that ramp
(`EmptyChatTheme.swift`, `ChatScreenBackdrop.swift`). Change the accent in all
three, or the palette drifts apart.

## Shipping it

`.github/workflows/release.yml` archives the app when you push a tag, and
publishes the archive on a GitHub Release.

**That archive is unsigned.** Signing and distribution are your Apple Developer
account's job, not this repository's: add your certificate, provisioning profile
and App Store Connect key to your fork's secrets and extend the release workflow
with `xcodebuild -exportArchive`.

Having a developer account is not the same as being through review. Apple
reviews every submission, and an app that connects to arbitrary agent endpoints
will be asked how it handles what those agents return. Budget for that
conversation.

## Architecture

`App/` boots and routes. `Features/` holds Chat, Agents and Settings — each a
SwiftUI view over a view model. `Core/` is the part worth reading first:
`Protocol/` owns the wire format, discovery, the WebSocket transport and the
connection pool; `Identity/` owns the Ed25519 keypair; `Persistence/` is the
SwiftData layer behind a repository protocol.

`HostedAgentClient` is the seam. Everything above it works against a protocol,
which is why the tests can drive a mock agent without a network.

## Tests

19 test files covering the protocol codec, discovery, connection lifecycle,
persistence and message delivery.

```bash
xcodebuild test \
  -project OOChatIOS.xcodeproj -scheme OOChatIOS \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Contributing

Issues and pull requests are welcome at
<https://github.com/openonion/oochat-ios>.

## License

MIT — see [LICENSE](LICENSE).

Copyright (c) 2026 ConnectOnion PTY LTD.
