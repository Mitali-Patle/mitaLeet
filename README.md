# mitaLeet

Realtime competitive coding OS for private coding squads.

```
apps/
  server/      NestJS + PostgreSQL + Prisma + Socket.IO  (port 3000)
  mobile/      Flutter + Dart + Riverpod  (Android + iOS)
  extension/   Plasmo browser extension  (Chrome)
packages/
  shared/      Shared TypeScript types
```

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Clone the repo](#2-clone-the-repo)
3. [Secrets and out-of-band config files](#3-secrets-and-out-of-band-config-files)
4. [Server setup](#4-server-setup)
5. [Chrome extension setup](#5-chrome-extension-setup)
6. [Mobile (Flutter) setup](#6-mobile-flutter-setup)
7. [Running all three concurrently](#7-running-all-three-concurrently)
8. [Dev auth bypass](#8-dev-auth-bypass)

---

## 1. Prerequisites

Install the following before continuing. Versions listed are the tested floor.

| Tool | Minimum version | Notes |
|---|---|---|
| Node.js | 20 | `node --version` |
| npm | ships with Node 20 | used per-app, no workspace root |
| Flutter SDK | 3.4.0 | `flutter --version` |
| Dart SDK | ships with Flutter | |
| Docker + Docker Compose | any recent | for PostgreSQL 16 + Redis 7 |
| Android Studio | Flamingo or later | for Android emulator / SDK tools |
| Xcode | 15+ | macOS only, for iOS build |

### External services you must provision yourself

- **Google Cloud project** — create an OAuth 2.0 Web Client and an Android OAuth client (registered with package name `com.mitaleet.app` and the SHA-1 fingerprint from your debug keystore).
- **Firebase project** — used only for FCM push notifications, not for Firebase Auth. Register the Android app (`com.mitaleet.app`) and download `google-services.json`. Create a Firebase Admin SDK service account and download the JSON key file.

> ⚠️ The Firebase project and the Google Cloud OAuth project are intentionally separate. The Web Client ID from Google Cloud is what the server uses to verify ID tokens; Firebase is used only for push.

---

## 2. Clone the repo

```bash
git clone <repo-url> mitaLeet
cd mitaLeet
```

There is no workspace root install step. Each app manages its own `node_modules`.

---

## 3. Secrets and out-of-band config files

These files are gitignored and must be obtained and placed manually before any app will start.

### 3a. Server environment file

```bash
cp apps/server/.env.example apps/server/.env
```

Then open `apps/server/.env` and fill in every placeholder:

```dotenv
DATABASE_URL="postgresql://mitaleet:mitaleet_dev@localhost:5432/mitaleet?schema=public"

JWT_SECRET="<run: openssl rand -base64 48>"
JWT_EXPIRES_IN="7d"
JWT_ACCESS_EXPIRATION="7d"
JWT_REFRESH_EXPIRES_IN="30d"

PORT=3000

# Google Cloud OAuth — Web Client ID and secret
GOOGLE_CLIENT_ID="<web-oauth-client-id>.apps.googleusercontent.com"
GOOGLE_CLIENT_SECRET="GOCSPX-..."
GOOGLE_CALLBACK_URL="http://localhost:3000/auth/google/callback"

# Firebase Admin SDK — copy values from the downloaded service account JSON
FIREBASE_PROJECT_ID="mitaleet-fb8ce"
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxx@mitaleet-fb8ce.iam.gserviceaccount.com"

# Redis
REDIS_URL="redis://localhost:6379"

# LeetCode scraping
LEETCODE_GRAPHQL_URL="https://leetcode.com/graphql"
LEETCODE_RATE_LIMIT_MS=2000

# CORS
CORS_ORIGINS="http://localhost:*,capacitor://localhost,ionic://localhost"

# Environment
NODE_ENV="development"
LOG_LEVEL="debug"
```

> ⚠️ `FIREBASE_PRIVATE_KEY` must preserve the literal `\n` sequences from the JSON file. When pasting into `.env`, keep them as `\n` (two characters), not real newlines. The server replaces them at runtime.

> ⚠️ If the Firebase vars are left as placeholders (values starting with `your-`), the server starts fine but FCM push notifications are silently disabled. This is intentional for local dev.

### 3b. Firebase Admin SDK service account JSON

The `secrets/` directory is gitignored. Place the downloaded service account JSON here:

```
secrets/mitaleet-fb8ce-firebase-adminsdk-fbsvc-<hash>.json
```

The server does **not** read this file directly — it reads the three Firebase env vars above. Keep the JSON in `secrets/` as the source of truth for those values and to avoid losing the key.

### 3c. Android Firebase config

```
apps/mobile/android/app/google-services.json
```

Download from the Firebase console (Project settings → Your apps → Android app → `google-services.json`) and place it at that exact path. This file is gitignored.

### 3d. iOS Firebase config (macOS / iOS builds only)

```
apps/mobile/ios/Runner/GoogleService-Info.plist
```

Download from the Firebase console (same page, iOS app tab) and place it at that exact path. This file is gitignored.

---

## 4. Server setup

### 4a. Start backing services (PostgreSQL + Redis)

Use Docker to start only the database and cache. Do not use `docker compose up` without flags during development — that also starts the server container, which conflicts with the hot-reload process below.

```bash
# From the repo root
docker compose up postgres redis -d
```

Verify they are running:

```bash
docker compose ps
```

### 4b. Install dependencies

```bash
cd apps/server
npm install
```

### 4c. Run database migrations

```bash
npx prisma generate
npx prisma migrate dev
```

> ⚠️ `migrate dev` must succeed before the server will start. If `DATABASE_URL` is wrong or PostgreSQL is not running, this will fail with a connection error.

### 4d. Start the server

```bash
npm run start:dev
```

The server starts on `http://localhost:3000` with hot-reload. Confirm it is up:

```bash
curl http://localhost:3000/health
```

### Full Docker path (no hot-reload)

If you want to run the server inside Docker instead:

```bash
# From the repo root
docker compose up
```

This builds the server image from `apps/server/Dockerfile` and starts all three services (postgres, redis, server). The server will not hot-reload on file changes in this mode.

---

## 5. Chrome extension setup

### 5a. Install dependencies

```bash
cd apps/extension
npm install
```

### 5b. Set the API URL (non-localhost only)

For local development the extension defaults to `http://localhost:3000`. No `.env` file is needed.

If connecting to a remote server, create `apps/extension/.env`:

```dotenv
PLASMO_PUBLIC_API_URL=https://your-server.example.com
```

### 5c. Start the dev build

```bash
npm run dev
```

Plasmo watches for changes and rebuilds into `build/chrome-mv3-dev/`.

### 5d. Load in Chrome

1. Open `chrome://extensions`
2. Enable **Developer mode** (toggle, top-right)
3. Click **Load unpacked**
4. Select the directory: `apps/extension/build/chrome-mv3-dev/`

The extension appears in your toolbar. Reload it from `chrome://extensions` after any rebuild.

---

## 6. Mobile (Flutter) setup

### 6a. Install Dart dependencies

```bash
cd apps/mobile
flutter pub get
```

### 6b. Set the server URL

Open `apps/mobile/lib/core/constants/app_constants.dart`.

**Emulator:** The default `localhost:3000` works on Android emulators. Leave it as-is.

**Physical Android device:** The phone cannot reach your PC's `localhost`. Update the file with your PC's local IP address:

```bash
# Find your PC's IP on the current network
ip route get 1.1.1.1 | grep -oP 'src \K[\d.]+'
```

Then edit the file:

```dart
static const String baseUrl = 'http://192.168.x.x:3000/api/v1';  // replace with your IP
static const String wsUrl  = 'http://192.168.x.x:3000';
```

> ⚠️ Your PC's local IP changes when you switch networks. Re-run the `ip route` command whenever the connection stops working and update the file.

> ⚠️ The phone and PC must be on the same Wi-Fi network. USB tethering also works.

### 6c. Android-specific setup

#### Google Sign-In OAuth client

The `serverClientId` is hardcoded in `apps/mobile/lib/features/auth/providers/auth_provider.dart`. This is the OAuth 2.0 Web Client ID and is intentionally embedded in source (it is not a secret). If you are running your own Google Cloud project, replace the value with your Web Client ID.

#### Get your debug SHA-1 fingerprint

Your debug keystore is machine-local (`~/.android/debug.keystore`). Every developer needs their own SHA-1 registered in the Google Cloud Console under the Android OAuth client (package name `com.mitaleet.app`).

```bash
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey \
  -storepass android \
  -keypass android \
  | grep SHA1
```

Register the printed SHA1 value in: Google Cloud Console → Credentials → your Android OAuth 2.0 client.

> ⚠️ If the SHA-1 registered in Google Cloud does not match your local debug keystore, Google Sign-In will fail on device with "Authentication failed" and no further indication of the cause. Use the [dev auth bypass](#8-dev-auth-bypass) to avoid this requirement entirely during early development.

#### Verify `google-services.json` is in place

```
apps/mobile/android/app/google-services.json   ← must exist (step 3c)
```

#### Physical device on Linux — USB permissions

If `flutter devices` shows "no permissions":

```bash
sudo bash -c 'echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", MODE=\"0666\", GROUP=\"plugdev\"" > /etc/udev/rules.d/51-android.rules'
sudo usermod -aG plugdev $USER
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Then unplug and replug the phone, and tap **Allow USB debugging** on the device screen.

If Flutter cannot find the Android SDK:

```bash
flutter config --android-sdk ~/android-sdk
```

#### Run on Android

```bash
flutter devices            # confirm device is listed
flutter run                # auto-targets the connected device
flutter run -d <device-id> # target a specific device
```

After changing any native Android config (build.gradle, AndroidManifest, google-services.json):

```bash
flutter clean && flutter pub get && flutter run
```

### 6d. iOS-specific setup (macOS only)

```bash
cd apps/mobile/ios
pod install
cd ..
flutter run -d <ios-device-or-simulator>
```

> ⚠️ The bundle ID registered in Firebase and in your Apple Developer account must match the one in `ios/Runner.xcodeproj`. The package name is `com.mitaleet.app`.

### 6e. Google Sign-In on Linux desktop

Google Sign-In is intentionally blocked on the Linux platform in the app code. Use the [dev auth bypass](#8-dev-auth-bypass) instead, or run on an Android device or emulator.

---

## 7. Running all three concurrently

Open three terminal windows.

**Terminal 1 — Server**

```bash
cd apps/server
npm run start:dev
```

**Terminal 2 — Mobile**

```bash
cd apps/mobile
flutter run
```

**Terminal 3 — Extension**

```bash
cd apps/extension
npm run dev
```

Then load the extension in Chrome as described in [step 5d](#5d-load-in-chrome).

---

## 8. Dev auth bypass

The server exposes a `/auth/dev-login` endpoint that is disabled in production (`NODE_ENV=production`). It creates or reuses a dev user without requiring a real Google account.

From the mobile app, tap the **Dev Login** button (visible only in debug builds). This calls `devBypass()` in `auth_provider.dart`, which posts `{ username: "mitali" }` to `/auth/dev-login` and persists the returned JWT tokens.

This is the recommended path for:
- Testing on Linux desktop (where Google Sign-In is blocked)
- UI development without a real Google account
- CI / integration tests

---

## Useful commands

### Prisma

```bash
cd apps/server
npx prisma migrate dev    # apply pending migrations
npx prisma generate       # regenerate Prisma client after schema changes
npx prisma studio         # open DB browser GUI
npx prisma db seed        # run seed script
```

### Flutter

```bash
flutter doctor            # diagnose missing tools
flutter devices           # list connected devices
flutter emulators         # list available emulators
flutter clean             # clear build cache
flutter pub get           # install/update packages
```

### Docker

```bash
docker compose up postgres redis -d    # start backing services only
docker compose down                    # stop all services
docker compose down -v                 # stop and delete DB volume (destructive)
```
