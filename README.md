import SwiftUI

# GPG Studio

A native macOS app for easy GPG operations including encryption, decryption, signing, and verification.

## Requirements

- macOS 12.0 or later
- Swift 5.5 or later
- GPG Tools installed (can be installed via Homebrew: `brew install gnupg`)
- fswatch for auto-rebuild (can be installed via Homebrew: `brew install fswatch`)

## Running the App

There are two ways to run the app:

### 1. Build Once (Simple)

```bash
cd GPGApp
./build.sh
```

This builds the app once and launches it. Use this if you just want to run the app.

### 2. Auto-rebuild on Changes (Recommended for Development)

```bash
cd GPGApp
./start.sh
```

This builds the app, launches it, and then watches for changes in the source files. When you edit a file, the app is automatically rebuilt and relaunched.

## Features

- Clean, native macOS interface
- Text input and output panes
- Automatic key detection from GPG keyring
- Support for:
  - Encryption
  - Decryption
  - Signing
  - Verification
- Error handling with user-friendly alerts

## Usage

1. Select your private key from the dropdown (for decryption and signing)
2. Select the recipient's public key (for encryption)
3. Enter your text in the input pane
4. Click the desired operation button
5. View the result in the output pane

## Security

- Uses system GPG installation
- Passphrase prompts use native macOS UI
- No key material is stored in the app
- All operations are performed locally

## License

MIT License
