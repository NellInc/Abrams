# macOS signing and notarization

Abrams uses a Developer ID Application certificate for distribution outside the Mac App Store. Signing identifies the developer. Notarization submits the signed app to Apple's automated checks. An accepted submission produces a ticket; attaching that ticket to the app lets Gatekeeper verify it offline.

Alpha 4 (signed build 1a61287931510c16adc4) was notarized on 3 October 2026: submission 871599ab-b8f4-45c7-a920-e303cf985360, Accepted with no issues, ticket stapled, Gatekeeper `accepted, source=Notarized Developer ID` from the released ZIP. Earlier alphas were not notarized. Do not describe any future signed app as notarized until Apple has accepted it and its ticket has been verified.

## One-time account setup

1. Sign into [Apple Account](https://account.apple.com/) with the Apple ID belonging to the developer team.
2. Under **Sign-In and Security**, create an **App-Specific Password** for Abrams notarization. See [Apple's instructions](https://support.apple.com/102654).
3. In your own Terminal, run the command below, replacing `YOUR_APPLE_ID`. The password is entered at a secure prompt, then stored in Keychain. Keep it out of chat, scripts and environment files.

```sh
xcrun notarytool store-credentials Abrams \
  --apple-id YOUR_APPLE_ID --team-id BBYYCBH7EW
```

The command validates the credentials with Apple. An existing `notarytool` Keychain profile can be used instead; only its profile name is needed by the release tools.

## Sign a new build

Build into a new path, retaining the previous alpha for rollback. The signing helper verifies the payload, signs native libraries and executables before their enclosing frameworks/apps, enables hardened runtime and obtains secure timestamps. It never submits an app for notarization.

```sh
python3 -m tools.standalone.sign_macos \
  --app "/absolute/release/M1 Abrams Battle Tank Fan Remaster.app" \
  --identity 'Developer ID Application: Nell Watson Ltd (BBYYCBH7EW)' \
  --team BBYYCBH7EW \
  --report /absolute/release/signing.json
```

Test the signed launcher, importer, bundled Python bridge and Godot renderer before proceeding. The original game uses the normal interpreted CPU core; no JIT exception or disabled library validation is added by default. Any exception must be justified by a reproduced failure.

## Submit, inspect and staple

These steps upload the original-free app to Apple and require release-owner approval.

```sh
ditto -c -k --sequesterRsrc --keepParent \
  "/absolute/release/M1 Abrams Battle Tank Fan Remaster.app" /absolute/release/Abrams-notary.zip
xcrun notarytool submit /absolute/release/Abrams-notary.zip \
  --keychain-profile Abrams --wait --output-format json
```

Retain the returned submission ID. Download and review its log even when the status is **Accepted**:

```sh
xcrun notarytool log SUBMISSION_ID --keychain-profile Abrams \
  /absolute/release/notary-log.json
```

Only after acceptance:

```sh
xcrun stapler staple "/absolute/release/M1 Abrams Battle Tank Fan Remaster.app"
xcrun stapler validate "/absolute/release/M1 Abrams Battle Tank Fan Remaster.app"
codesign --verify --deep --strict "/absolute/release/M1 Abrams Battle Tank Fan Remaster.app"
spctl --assess --type execute --verbose=4 "/absolute/release/M1 Abrams Battle Tank Fan Remaster.app"
```

Create the final release ZIP **after stapling**, calculate its SHA-256, then check the downloaded release copy. A ZIP itself cannot carry a stapled ticket. Do not alter the app after signing, or reuse a pre-stapling archive for distribution.

## References

[Apple's notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [custom command-line workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow), and [notarytool migration guidance](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool).
