# Getting the signing credentials in place

Everything here needs the Apple account, so it is yours to do. Once the secrets
are in the repository, `release.yml` handles the rest: tag, archive, sign,
upload.

## What already exists

Found on the machine that builds this, on 2026-08-14:

| | |
|---|---|
| Team | `APPLE_TEAM_ID` (Apple Developer) |
| App Store record | `ai.openonion.app` — this project now uses that identifier |
| Last approved version | **1.1.3**. The next upload must be higher; this project is set to `2.0.0` build `20` |
| Private keys | **Present in the login keychain** — two `Apple Distribution` and three `Apple Development` identities |
| Certificates | **Expired 2025-07-26**, both distribution ones |
| Provisioning profile | `Onion`, for `ai.openonion.app` — **expired the same day** |
| App Store Connect API key | **Not on this machine** |

The private keys mattering is the good news: certificates are re-issued against
a key you already hold, so nothing has to be rebuilt from scratch.

The version number is not a guess. An archive from 2024-11-28 carries App
Store's own rejection text:

> The value for key CFBundleShortVersionString [1.1.3] in the Info.plist file
> must contain a higher version than that of the previously approved version
> [1.1.3]

## 1. Re-issue the distribution certificate

Certificates → Identifiers & Profiles at <https://developer.apple.com/account/resources/certificates>

1. **+** → **Apple Distribution** → Continue
2. It asks for a Certificate Signing Request. Keychain Access → menu **Keychain
   Access → Certificate Assistant → Request a Certificate From a Certificate
   Authority**. Enter your email, leave CA Email blank, choose **Saved to disk**.
   Save the `.certSigningRequest`.
3. Upload it, download the resulting `.cer`, double-click to add it to the
   keychain.
4. In Keychain Access, find **Apple Distribution: Apple Developer (APPLE_TEAM_ID)** with
   today's date, expand it to confirm a private key is nested underneath, then
   right-click → **Export** → `.p12`. Set a password and remember it.

If the expansion arrow shows no key underneath, the certificate was issued
against a different key — start again from step 2 on this machine.

## 2. New provisioning profile

Profiles → **+** → **App Store Connect** (under Distribution)

- App ID: `ai.openonion.app`
- Certificate: the one from step 1
- Download the `.mobileprovision`

## 3. App Store Connect API key

Users and Access → **Integrations** → App Store Connect API → **+**

- Access: **App Manager** is enough to upload builds
- Download the `.p8` — **Apple lets you download it once**
- Note the **Key ID** and the **Issuer ID** from the same page

## 4. Put them in the repository

Settings → Secrets and variables → Actions, on `openonion/oochat-ios`.

Base64-encode the binary ones so they survive being stored as text:

```sh
base64 -i dist.p12 | pbcopy            # APPLE_DISTRIBUTION_P12
base64 -i profile.mobileprovision | pbcopy   # APPLE_PROVISIONING_PROFILE
base64 -i AuthKey_XXXXXX.p8 | pbcopy    # APP_STORE_CONNECT_API_KEY
```

| Secret | Value |
|---|---|
| `APPLE_DISTRIBUTION_P12` | base64 of the `.p12` |
| `APPLE_DISTRIBUTION_P12_PASSWORD` | the password from step 1 |
| `APPLE_PROVISIONING_PROFILE` | base64 of the `.mobileprovision` |
| `APP_STORE_CONNECT_API_KEY` | base64 of the `.p8` |
| `APP_STORE_CONNECT_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |

## 5. Ship

```sh
git tag v2.0.0
git push origin v2.0.0
```

`release.yml` archives, signs, exports and uploads to TestFlight. With the
secrets missing it still runs, publishing an unsigned archive and saying so in
the release notes — so a tag never fails for the sole reason that credentials
have not been added yet.

## Before submitting for review

- Screenshots, 6.7" and 6.5", at least three each
- A privacy policy URL — required
- The privacy questionnaire. The key is generated on device, conversations stay
  in local SwiftData, and speech is transcribed on device; that reads as "no data
  collected", but confirm what the relay logs before answering for it
- In the review notes, say what the app is up front. The App Store's own search
  index treats "onion" as Tor — searching "open onion" returns a screen of Tor
  browsers — and this app connects to `0x…` addresses over a relay. It connects
  to agents the user deployed and is not an anonymity tool; saying so first is
  cheaper than answering it in a second review round
