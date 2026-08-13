# Getting OpenOnion onto the App Store

State of play and what is left. Written 2026-08-13, updated the same evening.

## Done

| | |
|---|---|
| Product name | **OpenOnion**. Checked the US, GB and AU stores for an exact match — none. `openonion` is also unclaimed on PyPI and npm. |
| Bundle identifier | `ai.openonion.app`, matching the sibling clients |
| Version | `1.0.0`, build `1` |
| Accent colour | ConnectOnion green (`#16A34A` light / `#4ADE80` dark), one ramp shared with the web client |
| Builds | Xcode 15.4 and Xcode 26 both build it. Five sites compiled only against the newest toolchain and are now guarded — see [Toolchains](../README.md#toolchains) |
| Runs | Installed and launched on an iPhone 15 simulator, iOS 17.5 |
| Backend | A local ConnectOnion agent answers `GET /docs` and rejects unsigned `POST /input` with `401 unauthorized: signed request required` — the signing protocol is doing its job |
| Privacy strings | Camera, microphone and speech recognition all present and specific |
| Licence | MIT, ConnectOnion PTY LTD |
| Audit | `scripts/audit_repo.sh` exits 0; no student IDs, course codes or inherited URLs |
| Tests | 323 pass, 0 fail, on an iOS 17.5 simulator. It was 298/25: every message written to a conversation was lost on iOS 17, silently — the write succeeded and the relationship read back empty. Fixed by setting the `conversation` inverse explicitly. `ios-persistence-matrix.yml` guards against it returning |

## Blocked on credentials

Nobody but the account holder should touch these, and nothing here can proceed
without them.

1. Create the app record in App Store Connect
2. Generate an **App Store Connect API key** — Issuer ID, Key ID, and the `.p8`
3. Export the **distribution certificate** (`.p12`) and the **App Store
   provisioning profile**
4. Add all of it to this repository's Actions secrets

Then `release.yml` can be extended: it already archives on a tag push, so what
it needs is `xcodebuild -exportArchive` with an `ExportOptions.plist`, and an
upload step. Until the secrets exist, adding that workflow would only produce a
job that fails on every tag.

## Needed for the listing, not for the build

- **Screenshots** — 6.7" and 6.5", at least three each
- **Privacy policy URL** — required. A page under `docs.connectonion.com` is enough
- **Privacy questionnaire** — the app generates its Ed25519 key on device, keeps
  conversations in local SwiftData, and transcribes speech on device. That reads
  as "no data collected", but confirm what the relay logs before answering
- **Subtitle** — suggestion: `Chat with your AI agents`

## One thing to pre-empt in review

Searching the App Store for "open onion" returns a screen of Tor browsers and
VPNs: Apple's own index treats "onion" as Tor. This app connects to agents the
user deployed, over a relay, using addresses that look like `0x…` — a reviewer
skimming it could file it next to anonymity tooling.

Not a reason to rename: the company, the domain and the icon are all already the
onion. But say so first in the review notes rather than answering it in a second
round.

Apple also asks how an app handles content it does not control. This one renders
whatever an agent returns, so expect the question about user-generated content
even though every agent is one the user chose to add.

## Known gaps

- **No URL scheme.** An agent is added by typing a 64-character hex address or by
  scanning a QR code. There is no `openonion://agent/0x…` link, so an agent
  cannot be handed over in an email or from a web page — which is how a customer
  would most naturally receive one.
- **No iPad layout.** It runs, using the phone layout.
- **End-to-end connect is unverified from a clean install.** The app builds, runs
  and reaches the agent's discovery path; a live conversation has not been driven
  from the simulator, because adding an agent needs typing that cannot be
  automated through `simctl`. A local agent was verified separately: it answers
  `GET /docs` and rejects an unsigned `POST /input` with
  `401 unauthorized: signed request required`.
