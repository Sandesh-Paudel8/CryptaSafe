# CryptaSafe 
### An Encrypted Mobile Data Vault Using Cryptographic Techniques

> Final Year Project — Sandesh Paudel (LC00021000842)  
> National College of Management and Technical Science, Lincoln University College  
> Department of Computer Science and Multimedia — 2025

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Firebase Setup](#firebase-setup)
- [Running the App](#running-the-app)
- [How to Use](#how-to-use)
- [Secret Code](#secret-code)
- [Running Tests](#running-tests)
- [Building APK](#building-apk)
- [Project Structure](#project-structure)
- [Security Architecture](#security-architecture)
- [Known Limitations](#known-limitations)

---

## About

CryptaSafe is a Flutter-based Android application that provides military-grade AES-256 encryption for personal files and notes. The app is disguised as a calculator — only users who know the secret code can access the real vault. It supports biometric authentication, cloud backup, SMS remote wipe, and trusted peer recovery using RSA-2048 asymmetric cryptography.

---

## Features

| Feature | Description |
|---|---|
| 🧮 Calculator disguise | App appears as a fully working calculator |
| 🔐 AES-256 encryption | Files and notes encrypted with AES-256-CBC |
| 🔑 PBKDF2 key derivation | 100,000 iterations — brute force resistant |
| 🧬 Biometric auth | Fingerprint / face unlock via Android Keystore |
| 🎭 Decoy vault | Secondary password shows fake files |
| ☁️ Cloud backup | Zero-knowledge encrypted backup to Firebase |
| 🔑 RSA-2048 peer recovery | Trusted contact can restore your vault |
| 📱 SMS remote wipe | Send secret SMS to wipe vault remotely |
| 🔒 Auto-lock | Locks after 2 min inactivity or app background |
| 📝 Encrypted notes | Multiple named encrypted notes |
| 🔍 File search | Search vault files by name |
| 📦 Export backup | Export all encrypted files as zip |
| 🚫 Screenshot block | FLAG_SECURE prevents screen capture |
| 🔄 Change password | Update master password from settings |

---

## Tech Stack

```
Frontend      Flutter (Dart)
Native        Kotlin (Android BroadcastReceiver, MethodChannel)
Encryption    AES-256-CBC, PBKDF2, RSA-2048, SHA-256
Cloud         Firebase Auth, Firebase Storage, Cloud Firestore
Storage       Android Keystore (flutter_secure_storage)
```

**Key packages:**
```yaml
encrypt: ^5.0.3          # AES-256 encryption
pointycastle: ^3.9.1     # PBKDF2 key derivation
asn1lib: ^1.5.4          # RSA key serialization
crypto: ^3.0.3           # SHA-256 hashing
flutter_secure_storage: ^9.2.2   # Android Keystore
local_auth: ^2.3.0       # Biometric authentication
firebase_core: ^3.13.0   # Firebase
firebase_auth: ^5.5.2    # Firebase Auth
firebase_storage: ^12.4.5 # Cloud backup
cloud_firestore: ^5.6.5  # Metadata & peer recovery
file_picker: ^8.0.0      # File selection
archive: ^3.6.1          # Zip export
share_plus: ^10.0.0      # Share backup
```

---

## Prerequisites

Before you begin make sure you have the following installed:

- **Flutter SDK** 3.x stable — [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
- **Android Studio** or **VS Code** with Flutter and Dart extensions
- **Android SDK** API 23 or higher
- **Node.js** (for Firebase CLI) — [nodejs.org](https://nodejs.org)
- **Firebase CLI** — install with `npm install -g firebase-tools`
- **FlutterFire CLI** — install with `dart pub global activate flutterfire_cli`
- A physical Android device or emulator running **Android 6.0+**

---

## Installation

**Step 1 — Clone the repository:**
```bash
git clone https://github.com/yourusername/cryptasafe.git
cd cryptasafe
```

Or download and extract the zip, then open the folder in VS Code.

**Step 2 — Install dependencies:**
```bash
flutter pub get
```

**Step 3 — Check Flutter setup:**
```bash
flutter doctor
```
Make sure there are no errors. Fix any issues shown before proceeding.

---

## Firebase Setup

CryptaSafe requires Firebase for cloud backup, authentication, and peer recovery.

**Step 1 — Create Firebase project:**
1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **Add project** → name it `CryptaSafe`
3. Enable Google Analytics (optional)

**Step 2 — Enable services:**
- **Authentication** → Sign-in method → Enable **Email/Password**
- **Firestore Database** → Create database → Start in **test mode**
- **Storage** → Get started → Upgrade to **Blaze plan** (required for Storage)

**Step 3 — Configure Firebase rules:**

Firestore rules (`Firestore → Rules`):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /vaults/{userId}/files/{fileId} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
    match /peer_recovery/{email}/recoveries/{uid} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Storage rules (`Storage → Rules`):
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /vaults/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId;
    }
  }
}
```

**Step 4 — Connect your app:**
```bash
firebase login
flutterfire configure
```
Select your CryptaSafe project and Android platform. This generates `lib/firebase_options.dart` automatically.

**Step 5 — Add `google-services.json`:**
The above command generates it automatically. If not, download from Firebase Console → Project Settings → Your app → download `google-services.json` → place in `android/app/`

---

## Running the App

**Connect your Android device** via USB and enable USB Debugging:
- Settings → About Phone → tap Build Number 7 times
- Settings → Developer Options → USB Debugging → ON

**Check device is detected:**
```bash
flutter devices
```

**Run the app:**
```bash
flutter run
```

For a release build experience:
```bash
flutter run --release
```

---

## How to Use

### First Launch

```
1. App opens → Splash screen with animated lock icon
2. Onboarding walkthrough → swipe through 4 screens → tap Get Started
3. Sign up screen → create Firebase account (or tap Skip for offline)
4. Setup screen → create your master password (8+ characters)
5. Optional → enable decoy vault with a secondary password
6. App opens as Calculator ✓
```

### Unlocking the Vault

```
Calculator screen → type  1 3 3 7 #  on the keypad
→ Login screen appears
→ Enter master password  OR  use fingerprint
→ Vault opens ✓
```

### Encrypting a File

```
Vault screen → tap Add file (upload icon)
→ File picker opens → select any file
→ Loading overlay: "Encrypting filename..."
→ File appears in vault list as filename.ext.enc ✓
```

To decrypt: **tap the file** in the vault list → file is decrypted and saved to app storage.

### Encrypted Notes

```
Vault screen → tap Notes button
→ Notes list screen → tap + (FAB)
→ Enter title and content → tap ✓ to save
→ Note is AES-256 encrypted automatically ✓
```

### Cloud Backup

```
Vault screen → tap cloud sync icon (top right)
→ Cloud panel appears showing backed up files
→ On any file → tap cloud upload icon to backup
→ To restore → tap download icon in cloud panel ✓
```

> Requires Firebase sign-in and Blaze plan

### Trusted Peer Recovery

**Adding a peer (do this before you lose access):**
```
Settings → Trusted Peer Recovery → My Key tab
→ Copy your public key → share with your trusted contact

Settings → Trusted Peer Recovery → Add Peer tab
→ Enter peer's email and their public key
→ Tap Add Trusted Peer ✓
```

**Recovering your vault:**
```
Login screen → tap Recover via trusted peer
→ Sign in to Firebase first if prompted
→ Tap Recover now
→ App decrypts recovery data using your RSA private key
→ Tap Enter vault now ✓
```

### SMS Remote Wipe

**Setup:**
```
Settings → SMS Remote Wipe → tap Enable SMS wipe
→ Grant permission → green checkmark shown ✓
```

**Triggering wipe (from another phone):**
```
Send this exact SMS to your phone number:

    CRYPTASAFE_WIPE_NOW

→ Vault wipes automatically when received
→ App returns to setup screen
```

> ⚠️ Must send from another **Android** phone or with iMessage **disabled** on iPhone
> ⚠️ Message must be exactly as shown — no spaces, no punctuation

### Decoy Vault

If you set a decoy password during setup:
```
Login screen → enter decoy password (not master password)
→ Fake vault opens showing dummy files
→ Real vault is completely hidden ✓
```

### Export Vault Backup

```
Vault screen → tap Export button
→ Loading: "Creating encrypted backup zip..."
→ System share sheet opens
→ Share or save the zip file ✓
```

> All files in the zip are still AES-256 encrypted — the zip is safe to store anywhere

### Change Password

```
Settings → Change master password
→ Enter current password
→ Enter new password (8+ characters)
→ Confirm new password → tap Change Password
→ App logs you out → log in with new password ✓
```

---

## Secret Code

The default secret code to open the vault from the calculator is:

```
1337#
```

To change it, open `lib/screens/calculator_screen.dart` and edit:
```dart
static const String _secretCode = '1337#';
```

Change it to any sequence of numbers and symbols available on the calculator keypad.

---

## Running Tests

**Run all unit tests:**
```bash
flutter test test/encryption_test.dart --reporter expanded
```

**Expected output:**
```
+15: All tests passed!
```

**What is tested:**
- Text encryption and decryption (5 tests)
- File encryption and decryption (4 tests)
- Password hashing with SHA-256 (4 tests)
- Salt generation and PBKDF2 key derivation (5 tests — do not wait for this, it takes ~2 min)

---

## Building APK

**Debug APK** (for testing):
```bash
flutter build apk --debug
```

**Release APK** (for submission/distribution):
```bash
flutter build apk --release
```

Output location:
```
build/app/outputs/flutter-apk/app-release.apk
```

Install directly on device:
```bash
flutter install
```

---

## Project Structure

```
cryptasafe/
├── android/
│   └── app/
│       ├── src/main/
│       │   ├── kotlin/com/example/cryptasafe/
│       │   │   ├── MainActivity.kt          # MethodChannel + FLAG_SECURE
│       │   │   └── SmsWipeReceiver.kt       # BroadcastReceiver for SMS wipe
│       │   ├── AndroidManifest.xml          # Permissions and receiver registration
│       │   └── res/values/styles.xml        # App theme
│       ├── build.gradle.kts                 # App build config + Firebase
│       └── google-services.json            # Firebase config (auto-generated)
├── lib/
│   ├── main.dart                           # Entry point + routing
│   ├── firebase_options.dart               # Firebase config (auto-generated)
│   ├── screens/
│   │   ├── splash_screen.dart              # Animated launch screen
│   │   ├── onboarding_screen.dart          # First-launch walkthrough
│   │   ├── calculator_screen.dart          # Disguise home screen
│   │   ├── setup_screen.dart               # First vault setup
│   │   ├── login_screen.dart               # Password + biometric login
│   │   ├── auth_screen.dart                # Firebase sign in / sign up
│   │   ├── vault_screen.dart               # Main vault UI
│   │   ├── decoy_vault_screen.dart         # Fake vault for decoy password
│   │   ├── notes_screen.dart               # Encrypted notes list
│   │   ├── peer_recovery_screen.dart       # Add / manage trusted peers
│   │   ├── peer_recovery_request_screen.dart # Recover vault from peer
│   │   ├── settings_screen.dart            # All settings
│   │   ├── change_password_screen.dart     # Change master password
│   │   └── auto_lock_wrapper.dart          # Inactivity auto-lock
│   └── services/
│       ├── encryption_service.dart         # AES-256, PBKDF2, SHA-256
│       ├── auth_service.dart               # Local vault auth (Keystore)
│       ├── firebase_auth_service.dart      # Firebase email/password auth
│       ├── storage_service.dart            # Local file storage
│       ├── cloud_backup_service.dart       # Firebase Storage backup
│       ├── biometric_service.dart          # Fingerprint / face auth
│       ├── rsa_service.dart                # RSA-2048 key pair management
│       ├── peer_recovery_service.dart      # Trusted peer logic
│       ├── notes_service.dart              # Encrypted notes storage
│       ├── export_service.dart             # Vault zip export
│       ├── sms_wipe_service.dart           # SMS wipe Flutter side
│       └── wipe_service.dart               # Complete vault wipe
├── test/
│   └── encryption_test.dart               # 15 unit tests
├── pubspec.yaml                            # Dependencies
└── README.md                              # This file
```

---

## Security Architecture

```
User Password
      │
      ▼
PBKDF2 (100,000 iterations + random 32-byte salt)
      │
      ▼
AES-256 Key (256-bit, never stored)
      │
      ├──────────────────────┐
      ▼                      ▼
Random 16-byte IV       File/Note bytes
      │                      │
      └─────► AES-256-CBC ◄──┘
                   │
                   ▼
          [16B IV][Ciphertext]
                   │
         ┌─────────┴──────────┐
         ▼                    ▼
    .enc file            Firebase Storage
  (Private App Dir)     (Zero-knowledge)
```

**Key storage:**
| Data | Storage Location |
|---|---|
| Master password hash | Android Keystore |
| PBKDF2 salt | Android Keystore |
| RSA private key | Android Keystore |
| Encrypted files | App private directory |
| Cloud metadata | Firestore |
| Peer recovery secret | Firestore (RSA-encrypted) |

---

## Known Limitations

1. **Android only** — iOS not supported in this version
2. **Firebase Storage requires Blaze plan** — cloud backup unavailable on free Spark tier
3. **SMS wipe requires Android sender** — iPhone iMessage does not trigger the BroadcastReceiver; disable iMessage on iPhone before sending
4. **SMS wipe requires RECEIVE_SMS permission** — must be granted from Settings
5. **RSA key tied to device** — factory reset before adding a peer loses the private key permanently
6. **PBKDF2 derivation adds ~1.2 seconds** to unlock time — intentional for security
7. **Multi-user vault** not supported — single user per installation

---

## Troubleshooting

**App won't build:**
```bash
flutter clean
flutter pub get
flutter run
```

**Firebase not connecting:**
- Ensure `google-services.json` is in `android/app/`
- Run `flutterfire configure` again if needed
- Check Firebase project has Email/Password auth enabled

**Biometrics not working:**
- Check `AndroidManifest.xml` has `USE_BIOMETRIC` permission
- Ensure fingerprint is enrolled in phone settings

**SMS wipe not triggering:**
- Check SMS permission is granted in app Settings
- Send from Android phone (not iPhone with iMessage on)
- Message must be exactly `CRYPTASAFE_WIPE_NOW`
- Check battery saver settings on MIUI — set CryptaSafe to No Restrictions

**File picker locks vault:**
- This is fixed with `autoLockPaused = true` in `vault_screen.dart`
- Make sure you have the latest `auto_lock_wrapper.dart`

**Wrong password error after update:**
- Go to Android Settings → Apps → CryptaSafe → Clear Data
- Set up vault again from scratch

---

## License

This project was developed as a final year academic project at National College of Management and Technical Science, Lincoln University College. All rights reserved © 2025 Sandesh Paudel.

---

## Acknowledgements

Supervisor: Shashank Ghimire  
Institution: National College of Management and Technical Science  
Affiliated University: Lincoln University College, Malaysia
