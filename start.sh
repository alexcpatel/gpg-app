#!/bin/bash

set -e  # Exit on error

# Set build directory
BUILD_DIR="build"
APP_NAME="GPGApp"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
REBUILDING=0
FLAG_FILE="/tmp/gpgapp_rebuild_flag_$$"
LAST_BUILD_TIME=0
MIN_BUILD_INTERVAL=2  # Minimum seconds between builds
DEBUG=1  # Set to 1 to enable debug output

# Debug print function
debug_print() {
    if [ $DEBUG -eq 1 ]; then
        echo "[DEBUG] $1"
    fi
}

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    # Kill the app if running
    pkill -f "$APP_NAME" || true
    # Kill fswatch if running
    [ -n "$FSWATCH_PID" ] && kill $FSWATCH_PID 2>/dev/null || true
    # Remove flag file
    rm -f "$FLAG_FILE"
    # Restore terminal settings
    exec 3>&-
    stty icanon echo
    exit 0
}

# Set up trap for script termination
trap cleanup EXIT INT TERM

# Function to check if we need a clean build
need_clean_build() {
    # Check if Package.swift or Package.resolved has changed
    if [ -f ".last_clean" ]; then
        if [ "$(stat -f %m Package.swift)" -gt "$(cat .last_clean)" ] || \
           [ -f "Package.resolved" ] && [ "$(stat -f %m Package.resolved)" -gt "$(cat .last_clean)" ] || \
           [ -f "Resources/GPGAppIcon.icns" ] && [ "$(stat -f %m Resources/GPGAppIcon.icns)" -gt "$(cat .last_clean)" ]; then
            return 0
        fi
    else
        return 0
    fi
    return 1
}

# Function to clear icon cache
clear_icon_cache() {
    # Remove the app from the system icon cache
    touch "$APP_BUNDLE"
    if [ -f "$HOME/Library/Preferences/com.apple.finder.plist" ]; then
        defaults read com.apple.finder > /dev/null 2>&1 || true
    fi
    killall Finder > /dev/null 2>&1 || true
    killall Dock > /dev/null 2>&1 || true
}

# Function to build and run the app
build_and_run() {
    # Check if we need to respect the build interval
    local current_time=$(date +%s)
    local time_since_last_build=$((current_time - LAST_BUILD_TIME))
    
    if [ $time_since_last_build -lt $MIN_BUILD_INTERVAL ]; then
        echo "Skipping rebuild: Too soon after last build (${time_since_last_build}s < ${MIN_BUILD_INTERVAL}s)"
        rm -f "$FLAG_FILE"  # Clear the flag
        return 0
    fi
    
    REBUILDING=1
    echo "Building $APP_NAME..."
    
    # Create build directory and app bundle structure if needed
    mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
    
    # Copy Info.plist and resources if they've changed
    if [ ! -f "$APP_BUNDLE/Contents/Info.plist" ] || [ Info.plist -nt "$APP_BUNDLE/Contents/Info.plist" ]; then
        cp Info.plist "$APP_BUNDLE/Contents/"
    fi
    
    # Always copy resources to ensure they're up to date
    if [ -d "Resources" ]; then
        echo "Copying resources..."
        for icns in Resources/*.icns; do
            if [ -f "$icns" ]; then
                dest="$APP_BUNDLE/Contents/Resources/$(basename "$icns")"
                cp "$icns" "$dest"
                echo "Updated $(basename "$icns")"
            fi
        done
    fi

    echo "Building for production..."
    # Build the app
    if ! swift build -c release; then
        echo "Build failed!"
        REBUILDING=0 # Reset flag on failure
        return 1
    fi
    
    # Get and copy executable
    EXECUTABLE_PATH="$(swift build --show-bin-path -c release)/$APP_NAME"
    cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    
    # Create PkgInfo if it doesn't exist
    if [ ! -f "$APP_BUNDLE/Contents/PkgInfo" ]; then
        echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"
    fi
    
    # Kill existing app instance if running
    echo "Closing existing app instance (if any)..."
    pkill -f "$APP_NAME" || true
    sleep 0.5 # Give it a moment to close
    
    # Touch the app bundle to ensure Finder refreshes
    touch "$APP_BUNDLE"
    
    # Open the app
    echo "Launching updated app..."
    open "$APP_BUNDLE"
    
    # Update timestamp and reset flag
    LAST_BUILD_TIME=$(date +%s)
    sleep 1.5
    REBUILDING=0
    echo "Build and restart complete."
}

# Function to check if app is running
is_app_running() {
    # If we are in the middle of rebuilding, assume it *should* be running or starting
    if [ $REBUILDING -eq 1 ]; then
        return 0 # Treat as running
    fi
    # Otherwise, check if the process actually exists
    pgrep -f "$APP_NAME" > /dev/null
}

# Function to handle file change
handle_file_change() {
    local file="$1"
    debug_print "File change detected: $file"
    
    # Always rebuild on any Swift file change
    if [[ "$file" == *.swift ]] || [[ "$file" == *"Package.swift" ]] || [[ "$file" == *"Info.plist" ]]; then
        debug_print "Triggering rebuild for Swift file: $file"
        handle_change "file change: $file"
    elif [[ "$file" == *".icns" ]]; then
        debug_print "Triggering rebuild for resource file: $file"
        handle_change "file change: $file"
    else
        debug_print "Ignoring non-Swift change to: $file"
        rm -f "$FLAG_FILE"  # Clear the flag for ignored files
    fi
}

# Function to handle changes
handle_change() {
    local trigger="$1"
    echo "Rebuild triggered by: $trigger"
    
    # Clear the flag file if it exists (relevant for file changes)
    rm -f "$FLAG_FILE"
    
    # If it's a Package.swift change, do a clean build
    if [[ "$trigger" =~ Package\.swift$ ]] || [[ "$trigger" =~ Package\.resolved$ ]] || [[ "$trigger" =~ \.icns$ ]]; then
        echo "Dependencies or resources changed, performing clean build..."
        rm -rf .build
        rm -rf "$BUILD_DIR"
        date +%s > .last_clean
        clear_icon_cache
    fi
    
    build_and_run
}

# Function to manually trigger a rebuild
trigger_rebuild() {
    # Directly trigger a rebuild
    handle_change "manual trigger"
}

# Initial build
build_and_run
LAST_BUILD_TIME=$(date +%s)  # Set initial build time

# Watch for changes and app quit
echo "Watching for changes in Sources directory. Press Enter to rebuild. Press Ctrl+C to stop."

# Create terminal control to make it non-blocking
exec 3<>/dev/tty
# Put terminal into non-canonical mode (char-by-char input)
stty -icanon -echo <&3

# Set up a polling mechanism to check for Swift file changes
(
    while true; do
        for file in Sources/*.swift; do
            if [ -f "$file" ] && [ "$file" -nt "/tmp/gpgapp_last_check" ]; then
                debug_print "Change detected in $file"
                touch "$FLAG_FILE"
                echo "$file" > "/tmp/gpgapp_changed_file_$$"
                break
            fi
        done
        touch "/tmp/gpgapp_last_check"
        sleep 1
    done
) &
POLLING_PID=$!

# Main loop
while true; do
    # Check if a file change was detected via the flag file
    if [ -f "$FLAG_FILE" ]; then
        if [ -f "/tmp/gpgapp_changed_file_$$" ]; then
            CHANGED_FILE=$(cat "/tmp/gpgapp_changed_file_$$")
            handle_file_change "$CHANGED_FILE"
            rm -f "/tmp/gpgapp_changed_file_$$"
        else
            # Direct rebuild if flag is set but no file info
            trigger_rebuild
        fi
    fi

    # Check if Enter was pressed
    if read -t 1 -n 1 char <&3; then
        if [ "$char" = $'\n' ]; then
            handle_change "terminal input"
        fi
    fi

    # Check if app quit (only if not rebuilding)
    if ! is_app_running; then
        echo "App was quit by user. Stopping watch."
        # Kill polling process
        [ -n "$POLLING_PID" ] && kill $POLLING_PID 2>/dev/null || true
        cleanup
        break
    fi
    
    # Short sleep to prevent busy waiting
    sleep 1
done

# Restore terminal on exit (should be caught by trap, but good practice)
exec 3>&-
stty icanon echo
