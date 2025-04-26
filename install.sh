#!/bin/bash

# Exit on any error
set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# App variables
APP_NAME="GPGApp"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DEST_PATH="/Applications/$APP_NAME.app"

# Print colored message
print_message() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# Clean up any existing build
if [ -d "$BUILD_DIR" ]; then
    print_message "Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS" "$BUILD_DIR/$APP_NAME.app/Contents/Resources"

# Build the app
print_message "Building $APP_NAME in release mode..."
swift build -c release

# Copy executable
print_message "Copying executable to app bundle..."
EXECUTABLE_PATH="$(swift build --show-bin-path -c release)/$APP_NAME"
cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist and resources
print_message "Copying app resources..."
cp Info.plist "$APP_BUNDLE/Contents/"

# Copy icon if it exists
if [ -f "Resources/GPGAppIcon.icns" ]; then
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    cp Resources/GPGAppIcon.icns "$APP_BUNDLE/Contents/Resources/"
fi

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Check if app already exists in Applications
if [ -d "$DEST_PATH" ]; then
    print_warning "App already exists in Applications. It will be replaced."
    # Try to remove without sudo first
    if ! rm -rf "$DEST_PATH" 2>/dev/null; then
        print_message "Elevated permissions required to replace existing app..."
        sudo rm -rf "$DEST_PATH"
    fi
fi

# Try to copy to Applications without sudo first
print_message "Installing app to $DEST_PATH..."
if ! cp -R "$APP_BUNDLE" "/Applications/" 2>/dev/null; then
    print_message "Elevated permissions required to install to Applications..."
    sudo cp -R "$APP_BUNDLE" "/Applications/"
fi

# Set proper permissions
print_message "Setting permissions..."
if ! chmod -R 755 "$DEST_PATH" 2>/dev/null; then
    sudo chmod -R 755 "$DEST_PATH"
fi

# Update ownership if installed with sudo
if [ -n "$SUDO_USER" ]; then
    print_message "Updating ownership..."
    sudo chown -R "$SUDO_USER:staff" "$DEST_PATH"
fi

print_success "$APP_NAME has been installed to $DEST_PATH"
print_message "You can now launch it from Launchpad or by clicking the app icon"

# Open the Applications folder
open /Applications/ 
