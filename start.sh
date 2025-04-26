#!/bin/bash

set -e  # Exit on error

# Set build directory
BUILD_DIR="build"
APP_NAME="GPGApp"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    # Kill the app if running
    pkill -f "$APP_NAME" || true
    # Kill fswatch if running
    [ -n "$FSWATCH_PID" ] && kill $FSWATCH_PID 2>/dev/null || true
    exit 0
}

# Set up trap for script termination
trap cleanup EXIT INT TERM

# Function to check if we need a clean build
need_clean_build() {
    # Check if Package.swift or Package.resolved has changed
    if [ -f ".last_clean" ]; then
        if [ "$(stat -f %m Package.swift)" -gt "$(cat .last_clean)" ] || \
           [ -f "Package.resolved" ] && [ "$(stat -f %m Package.resolved)" -gt "$(cat .last_clean)" ]; then
            return 0
        fi
    else
        return 0
    fi
    return 1
}

# Function to build and run the app
build_and_run() {
    echo "Building $APP_NAME..."
    
    # Check if we need a clean build
    if need_clean_build; then
        echo "Dependencies changed, performing clean build..."
        rm -rf .build
        rm -rf "$BUILD_DIR"
        date +%s > .last_clean
    fi
    
    # Create build directory and app bundle structure if needed
    mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
    
    # Copy Info.plist and resources if they've changed
    if [ ! -f "$APP_BUNDLE/Contents/Info.plist" ] || [ Info.plist -nt "$APP_BUNDLE/Contents/Info.plist" ]; then
        cp Info.plist "$APP_BUNDLE/Contents/"
    fi
    
    if [ -d "Resources" ]; then
        for icns in Resources/*.icns; do
            if [ -f "$icns" ]; then
                dest="$APP_BUNDLE/Contents/Resources/$(basename "$icns")"
                if [ ! -f "$dest" ] || [ "$icns" -nt "$dest" ]; then
                    cp "$icns" "$dest"
                fi
            fi
        done
    fi

    # Build the app
    swift build -c release
    
    # Get and copy executable if it's changed
    EXECUTABLE_PATH="$(swift build --show-bin-path -c release)/$APP_NAME"
    if [ ! -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ] || [ "$EXECUTABLE_PATH" -nt "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
        cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
        chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    fi
    
    # Create PkgInfo if it doesn't exist
    if [ ! -f "$APP_BUNDLE/Contents/PkgInfo" ]; then
        echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"
    fi
    
    # Kill existing app instance if running
    pkill -f "$APP_NAME" || true
    sleep 1
    
    # Open the app
    open "$APP_BUNDLE"
}

# Function to check if app is running
is_app_running() {
    launchctl list | grep -q "$APP_NAME"
}

# Initial build
build_and_run

# Watch for changes and app quit
echo "Watching for changes. Press Ctrl+C to stop."

# Start watching file changes in background
fswatch -o Sources/ | while read f; do
    echo "Change detected, rebuilding..."
    build_and_run
done &
FSWATCH_PID=$!

# Wait for app quit
while true; do
    if ! is_app_running; then
        echo "App was quit. Stopping watch."
        cleanup
    fi
    sleep 1
done 
