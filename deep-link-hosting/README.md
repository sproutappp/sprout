# Deep link hosting — sproutapp.in

Two files need to be hosted at your real domain for Android App Links to
work (tap an invite link -> app opens directly instead of a browser).

## 1. Get your REAL signing fingerprint (this is the part most likely to
   go wrong if guessed)

Since Sprout is already live on Play Console, the fingerprint that
actually matters is the one Google Play uses to sign your app for
distribution -- not necessarily your local upload key, if Play App
Signing is enabled (it usually is by default for new apps).

Go to: Play Console -> Sprout -> Test and release -> Setup ->
App integrity -> App signing. Copy the SHA-256 certificate
fingerprint shown there (a long colon-separated hex string).

## 2. Fill in assetlinks.json

Open deep-link-hosting/.well-known/assetlinks.json in this repo and
replace REPLACE_WITH_YOUR_REAL_SHA256_FINGERPRINT with the value from
step 1 (keep the colons, keep it as one string in the array).

## 3. Host both files at the right paths

Whatever static host you use for sproutapp.in, these need to end up
reachable at exactly:

- https://sproutapp.in/.well-known/assetlinks.json
- https://sproutapp.in/join/ (the fallback page, for when the app
  isn't installed yet)

If you don't already have hosting for sproutapp.in, Firebase
Hosting is a reasonable choice since the project already exists for
this app (Console -> Build -> Hosting -> connect your custom domain,
then deploy these two files at their respective paths). Any static
host works equally well, though -- GitHub Pages, Netlify, whatever you
already use for anything else, as long as it serves assetlinks.json
with Content-Type: application/json (most hosts do this correctly
automatically based on the .json extension).

## 4. Verify it worked

Once hosted, you can check Android's own verification status from a
terminal with an Android device/emulator connected:

    adb shell pm get-app-links com.sprout.app

It should show "sproutapp.in: verified" -- if it says something else,
double check the JSON is reachable at the exact URL above, is valid
JSON, and the fingerprint matches exactly.

## What's already done in the app code (no action needed)

- AndroidManifest.xml has the App Links intent-filter, pointed at
  sproutapp.in/join/*
- The invite link generator now points at sproutapp.in (previously a
  placeholder domain made up before the real one was known)
- A new route (/join/:token) handles the incoming link and attempts
  to join automatically -- no manual paste needed when the app is
  already installed and the link is tapped directly
