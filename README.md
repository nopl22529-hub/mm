# FluxTube: YouTube Client App

![FluxTube](doc/banner.jpg)

<p align="center">
<a href="https://github.com/mu-fazil-vk/FluxTube/releases" alt="GitHub release"><img src="https://img.shields.io/github/release/mu-fazil-vk/FluxTube.svg" ></a>
<a href="https://www.gnu.org/licenses/gpl-3.0.en.html" alt="GitHub release"><img src="https://shields.io/badge/License-GPL%20v3-blue.svg" ></a>
  <a href="https://github.com/mu-fazil-vk/FluxTube/releases" alt="GitHub release"><img src="https://shields.io/badge/Flutter-v3.47.1-blue.svg" ></a>
  <a href="https://github.com/mu-fazil-vk/FluxTube/releases" alt="GitHub release"><img src="https://img.shields.io/github/downloads/mu-fazil-vk/FluxTube/total.svg?label=FluxTube+Downloads" ></a>
  <a title="Crowdin" target="_blank" href="https://crowdin.com/project/fluxtube"><img src="https://badges.crowdin.net/fluxtube/localized.svg"></a>
</p>

An ad-free YouTube client built with Flutter. Watch YouTube videos without ads, subscribe to channels, retrieve video dislikes, read comments, save videos, and more.

> **Note:** This app was originally created for personal use. If it's not for you, that's fine - just don't use it. I've seen comments calling this a "NewPipe clone." Sure, if that's how you see it. But FluxTube is built with Flutter, supports multiple YouTube services (NewPipe Extractor, Invidious), and the whole point of having multiple backends is to keep the app working - if one service goes down, switch to another. If you actually care about improving it, open an issue. No offense.

## Features

- **No Login Needed**: Use the app without any login requirements.
- **Google Account Sign-In**: Optionally connect a Google account from Settings.
- **Ad-Free Experience**: Enjoy YouTube videos without interruptions.
- **Multiple YouTube Services**: Switch between NewPipe Extractor and Invidious backends (Piped and Explode were retired — see [Retired providers](#retired-providers)).
- **Download Videos**: Download videos and audio in multiple qualities with FFmpeg merging support.
- **Background Playback**: Continue listening with notification controls (play/pause/seek).
- **Picture-in-Picture**: System PiP mode - auto-enters when pressing home while playing.
- **SponsorBlock**: Auto-skip sponsored segments, intros, outros, and more.
- **Multiple Profiles**: Separate subscriptions, history, and saved videos per profile.
- **Channel Subscriptions**: Subscribe to your favorite channels.
- **Dislike Retrieval**: See the number of dislikes on videos.
- **Comment Section**: Read video comments and replies.
- **Save Videos**: Save videos to watch later with search and sorting.
- **Deep Linking**: Open YouTube links directly in FluxTube.
- **NewPipe-Compatible Backup**: Import/export data as NewPipe-compatible ZIP files.
- **Select Your Region**: Customize the content based on your region.
- **Multi-Language Support**: 12+ languages supported.
- **Watch live streams**: Enjoy live content.
- **Video Fit Modes**: Contain, cover, fill, fit-width, fit-height.
- **Customizable Skip Interval**: Double-tap to skip 5-60 seconds.
- **Watch Videos up to 4K Quality**: Enjoy videos in high quality up to 4K resolution.
- **Distraction-Free Mode**: Hide comments and related videos.

###### Note:

Some features are only available when using the NewPipe Extractor service.

## Screenshots

<div align="center">
  <img src="doc/screenshots/home.jpg" alt="Home: hero card, Continue Watching and category chips" width="30%">
  <img src="doc/screenshots/watch.jpg" alt="Watch: player controls, actions and related videos" width="30%">
  <img src="doc/screenshots/shorts.jpg" alt="Shorts feed from your subscriptions" width="30%">
</div>
<div align="center">
  <img src="doc/screenshots/subscriptions.jpg" alt="Subscriptions videos feed with filters" width="30%">
  <img src="doc/screenshots/library.jpg" alt="Library: watch stats, saved, history, downloads and playlists" width="30%">
  <img src="doc/screenshots/settings.jpg" alt="Settings with profiles" width="30%">
</div>

## Download

<p>
  <a href="https://github.com/mu-fazil-vk/FluxTube/releases">
    <img alt="Get it on GitHub" src="doc/get-it-on-gb.png" width="200">
  </a>
</p>

<p>
  <a href="https://apt.izzysoft.de/packages/com.fazilvk.fluxtube">
    <img alt="Get it on IzzyOnDroid" src="https://gitlab.com/IzzyOnDroid/repo/-/raw/master/assets/IzzyOnDroid.png" width="200">
  </a>
</p>

You can download the latest version of the app from the [releases page](https://github.com/mu-fazil-vk/FluxTube/releases).

## Google Sign-In Setup

Google sign-in is optional. To enable it in your own build:

1. In Google Cloud Console, configure the OAuth consent screen and create an **Android** OAuth client for package `com.fazilvk.fluxtube`.
2. Get your debug certificate's SHA-1 by running `cd android; .\gradlew signingReport` from PowerShell. Add that SHA-1 to the Android OAuth client. If you publish a release, add the release key's SHA-1 too.
3. Create a **Web application** OAuth client ID. Pass that ID to the build as shown below.

```sh
flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

For iOS, also create an iOS OAuth client for your bundle identifier and pass it with `--dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID`. Google sign-in currently connects the Google identity and shows the account in Settings; FluxTube's video, subscription, and like features continue to use its existing providers.

## YouTube Account Sign-In (Innertube, Phase 1)

Separate from the Google identity card above, Settings → **YouTube Account** signs FluxTube in as your real YouTube channel using the OAuth TV device flow: the app shows a code, you enter it at youtube.com/activate, and the app stores the refresh token in platform secure storage (Android Keystore / iOS Keychain) so you stay signed in across restarts. No Google Cloud project is needed for this flow.

Phase 1 only signs in and shows your channel in Settings. Like, subscribe, comment, and watch-history sync build on this session in later phases; until then, playback and subscriptions still use the existing anonymous providers and local profiles.

> Unofficial API notice: this uses YouTube's internal Innertube API, which is not a public Google API. It can break when YouTube changes its clients, and using it may violate YouTube's Terms of Service. Use it with an account you can afford to lose access to, and do not distribute builds with it on app stores.

## Build an Android APK (Windows)

Install Flutter `3.47.1`, Android Studio with the Android SDK, and Java 17. From the project folder, run:

```powershell
.\scripts\build-apk.ps1
```

This creates a debug APK at `build\app\outputs\flutter-apk\app-debug.apk`. To enable Google sign-in in that build, set your Web OAuth client ID first:

```powershell
$env:GOOGLE_SERVER_CLIENT_ID = "YOUR_WEB_CLIENT_ID"
.\scripts\build-apk.ps1
```

If Google sign-in is not configured, the APK still builds, but the Google button stays disabled and shows setup instructions. For a release APK, pass `-Mode release`; Android release signing must also be configured in `android/key.properties` as described in `android/app/build.gradle`.

## Build without installing Flutter or Android SDK

The `google-signin-apk` branch builds a signed release APK on GitHub Actions, so Flutter and Android SDK do not need to be installed on your PC. The workflow uses the repository's `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, and `ANDROID_KEY_ALIAS` Actions secrets. It also reads `GOOGLE_SERVER_CLIENT_ID` from Actions variables to enable Google sign-in.

After the Google OAuth clients are configured for this app's Android package and signing certificate, set `GOOGLE_SERVER_CLIENT_ID` under **Settings → Secrets and variables → Actions → Variables**. Push to `google-signin-apk` or run **Build Signed Release APK** from the **Actions** tab. Download `fluxtube-apk` from the completed run. Keep the signing key and its passwords private; future APK updates must use the same key.

## FluxTube vs NewPipe App

If you select "NewPipe Extractor" as your YouTube service in FluxTube, it uses the same [NewPipe Extractor](https://github.com/TeamNewPipe/NewPipeExtractor) library under the hood. So what's the difference?

|                             | FluxTube                                | NewPipe App                   |
| --------------------------- | --------------------------------------- | ----------------------------- |
| **Framework**         | Flutter (cross-platform)                | Native Android (Kotlin/Java)  |
| **Multiple Backends** | Yes (NewPipe Extractor, Invidious)      | No (NewPipe Extractor only)   |
| **Fallback Options**  | Switch service if one breaks            | Wait for app update           |
| **SponsorBlock**      | Built-in                                | Requires fork (e.g., Tubular) |
| **Multiple Profiles** | Yes                                     | No                            |
| **Download**          | Yes (all services, with FFmpeg merging) | Yes                           |
| **Background Play**   | Yes (with notification controls)        | Yes                           |
| **System PiP**        | Yes (auto-enter on home press)          | Yes                           |

**TL;DR:** FluxTube gives you options. If NewPipe Extractor stops working tomorrow, you can switch to Invidious and keep watching. NewPipe app is more feature-complete for downloading, but you're stuck with one backend. The UIs are different too.

## Recommended Settings

For the best experience:

| Use Case                                | YouTube Service     | Notes                                                 |
| --------------------------------------- | ------------------- | ----------------------------------------------------- |
| **Recommended**                   | NewPipe Extractor   | Direct extraction, most reliable, no instances needed |
| **When NewPipe Extractor breaks** | Invidious (Limited) | Instance-based; few public instances still allow apps |

> **Tip:** Click on  "Auto-Check Instances" in settings for automatic failover when an instance becomes unavailable.

### Retired providers

Checked live on 2026-10-02. Both are hidden from the service picker; anyone still set to one is moved to NewPipe Extractor automatically.

| Provider                  | Status                          | Why                                                                                                                                                                                                                                     |
| ------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Piped**           | Unusable (project still active) | YouTube blocks the datacenter IPs public instances run on. 14 of 15 public API instances were dead, and the last one served only 401 mirror media. The Piped team is rebuilding on [rustypipe](https://github.com/TeamPiped/rustypipe). |
| **YouTube Explode** | Unmaintained                    | `youtube_explode_dart` has had no release or merged fix since May 2026; adaptive streams return 403 and only 360p still plays.                                                                                                        |

NewPipe Extractor already covers Explode's role (on-device extraction from your own IP, up to 4K) and is actively maintained. For a server-side, privacy-proxy option, Invidious (with [invidious-companion](https://github.com/iv-org/invidious-companion)) is the maintained alternative.

## Todo

- [X] Playlist Support
- [X] Picture in Picture Mode
- [X] Channel Profile Support
- [X] Subtitle Support
- [X] Unlimited Scroll Support
- [X] User Profiles
- [X] SponsorBlock
- [X] NewPipe-Compatible Backup/Restore
- [X] Deep Linking / Share Intent
- [X] Search History
- [X] Download Videos (all services)
- [X] Background Playback with Notification Controls
- [X] Android System Picture-in-Picture
- [X] Save Downloads to Public Storage
- [X] Database Migration (Isar → Drift)

## Translations

- Go to [Crowdin](https://crowdin.com/project/fluxtube/invite?h=4d7d9f6ba7c350dc176d6f75a5f569362170999) and help with the translations.

## Contribution

Contributions are welcome! Whether you have ideas, translations, design changes, code cleaning, or even major code changes, help is always welcome. The app gets better and better with each contribution, no matter how big or small!

If you have any ideas, suggestions, or issues, please open a [new issue](https://github.com/mu-fazil-vk/FluxTube/issues) or submit a pull request.

1. Fork the repository.
2. Create a new branch: `git checkout -b my-feature-branch`
3. Commit your changes: `git commit -m 'Add some feature'`
4. Push to the branch: `git push origin my-feature-branch`
5. Submit a pull request.

   #### Note:


   - Flutter version: `3.47.1`
   - Build runner command (Drift, Freezed, Injectable, JSON serialization): `flutter pub run build_runner build --delete-conflicting-outputs`
   - Translation command: `dart run intl_utils:generate`

## License

FluxTube is a free software licensed under GPL v3.0

## Support:

<p><a href="https://www.buymeacoffee.com/fazilvk"> <img align="left" src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" height="50" width="210" alt="fazilvk" /></a></p><br><br>
<br>

## Message Me

If you have any questions or need further assistance, feel free to contact me.

<p align="left">
<a href="https://t.me/fazilvk" target="blank"><img align="center" src="https://www.freepnglogos.com/uploads/telegram-png/telegram-software-wikipedia-2.png" alt="mu_fazil_vk" height="40" width="40" /></a>   
<a href="https://instagram.com/fazil.v.k" target="blank"><img align="center" src="https://www.freepnglogos.com/uploads/instagram-logo-png-transparent-0.png" alt="fazil.v.k" height="54" width="54" /></a>
<a href="mailto:fazilvk6@gmail.com" target="blank"><img align="center" src="https://www.freepnglogos.com/uploads/logo-gmail-png/logo-gmail-png-for-gmail-email-client-mac-app-store-16.png" alt="Fazil vk" height="40" width="40" /></a>

## Privacy Policy

The FluxTube project is designed to offer a private, anonymous YouTube experience. The app ensures no data is collected without your explicit consent. Your privacy is a top priority. Enjoy watching YouTube securely with FluxTube.

## Warning

```
This project was created for learning purposes and is not affiliated with any content provider. 
All videos, content, and trademarks are the property of their respective owners. 
FluxTube is not responsible for any copyright infringements. This software is provided "as-is" without 
any warranty, and the author is not liable for any damages arising from its use.

This project is not officially associated with YouTube. 
```
