# GPGApp

A simple macOS application for GPG encryption, decryption, and signature verification.

## System Requirements

- **macOS**: 10.15 (Catalina) or newer
- **GPG**: GnuPG 2.x (GPG Suite)
  - Install via [GPG Tools](https://gpgtools.org/) or Homebrew: `brew install gnupg`
- **GPG Path**: The app expects GPG at `/usr/local/bin/gpg`

## Installation

### Method 1: Direct Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/GPGApp.git
cd GPGApp

# Make the install script executable
chmod +x install.sh

# Run the installation script
./install.sh
```

The app will be installed to your Applications folder.

### Method 2: Run Without Installing

```bash
# Clone the repository
git clone https://github.com/yourusername/GPGApp.git
cd GPGApp

# Run the development script
./start.sh
```

## Usage

### Send Messages

1. Select your private key for signing
2. Select recipient's public key for encryption
3. Enter your message in the left panel
4. Click "Encrypt & Sign"
5. Copy the encrypted output from the right panel

### Receive Messages

1. Select your private key for decryption
2. Optionally select expected sender for verification
3. Paste the encrypted message in the left panel
4. Click "Decrypt & Verify"
5. View the decrypted message in the right panel

If a passphrase is required, you'll be prompted to enter it.

## Building from Source

If you want to build manually:

```bash
# Build the app
swift build -c release

# Create an app bundle
mkdir -p build/GPGApp.app/Contents/MacOS
cp $(swift build --show-bin-path -c release)/GPGApp build/GPGApp.app/Contents/MacOS/
cp Info.plist build/GPGApp.app/Contents/
```

## GPG Key Management

GPGApp uses the keys from your GPG keyring. To manage your keys:

- Use GPG Keychain (if installed with GPG Suite)
- Or use GPG command-line tools:

  ```bash
  # List keys
  gpg --list-keys
  gpg --list-secret-keys

  # Generate a new key
  gpg --full-generate-key
  ```
