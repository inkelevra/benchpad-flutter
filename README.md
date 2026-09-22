# BenchPad — Flutter app (native rebuild of the PWA)

Native Android/iOS rebuild of the BenchPad PWA. Backend (Cloudflare Workers/D1,
`benchpad.pages.dev`) is unchanged — this is a new client only.

## Status

First scaffold. Ported so far:
- App shell + navigation (`lib/main.dart`)
- Theme matching the PWA's dark/amber look (`lib/theme/app_theme.dart`)
- API client for `/api/publish-stats`, `/api/publish-queue-status`,
  `/api/publish-status`, `/api/benchpad-ai/publish` (`lib/services/benchpad_api.dart`)
- Home screen (placeholder, shows live publish stats)
- Advertise screen: photo pick, position/zoom sliders, message, publish +
  queued-job status polling (`lib/screens/advertise_screen.dart`)

Not yet ported: Weather/Culture/Social/Quote templates, Studio canvas editor,
Capsules, Vault/Memory Sphere, Control Room, Roadmap screen.

## Setup on Chromebook (Acer 314 / Crostini Linux)

```bash
# 1. Install Flutter SDK (one time)
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
flutter doctor

# 2. Get dependencies
cd benchpad_flutter
flutter pub get

# 3. Run on a real phone over USB (NOT the emulator — too heavy for this hardware)
#    - Enable Developer Options + USB debugging on the phone
#    - Plug in via USB, accept the debugging prompt on the phone
flutter devices        # confirm the phone shows up
flutter run             # builds + installs + hot-reload session
```

`flutter doctor` will flag missing Android SDK/licenses on first run — follow
its instructions (`flutter doctor --android-licenses` to accept licenses).

## iOS

Needs a Mac (Xcode) — not possible on this Chromebook. Use a rented/cloud Mac
(Codemagic, MacinCloud) or borrow one when the Android build is stable. No code
changes needed to switch — same Dart source, `flutter build ios` on a Mac.

## Config

Backend URL and default device id live in `lib/config.dart` — change there,
not scattered across screens.
