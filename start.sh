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

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Store the script's PID
SCRIPT_PID=$$

# Debug print function
debug_print() {
    if [ $DEBUG -eq 1 ]; then
        echo -e "${CYAN}[DEBUG]${RESET} $1"
    fi
}

# Log formatting function
format_log() {
    local timestamp
    while IFS= read -r line; do
        timestamp=$(date +"%H:%M:%S")
        echo -e "${BOLD}${PURPLE}[APP ${timestamp}]${RESET} $line"
    done
}

# Script log functions
log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# Function to print status message
print_status() {
    echo -e "\n${BOLD}${GREEN}> $1${RESET}"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Kill all child processes of this script
    pkill -P "$SCRIPT_PID" || true
    
    # Kill the app if running
    pkill -f "$APP_NAME" || true
    
    # Kill fswatch if running
    if [ -n "$FSWATCH_PID" ]; then
        kill "$FSWATCH_PID" 2>/dev/null || true
    fi
    
    # Kill polling process if running
    if [ -n "$POLLING_PID" ]; then
        kill "$POLLING_PID" 2>/dev/null || true
    fi
    
    # Remove temporary files
    rm -f "$FLAG_FILE"
    rm -f "/tmp/gpgapp_last_check"
    rm -f "/tmp/gpgapp_changed_file_$$"
    
    # Restore terminal settings
    exec 3>&-
    stty sane 2>/dev/null || true
    
    # Exit explicitly
    exit 0
}

# Set up trap for various signals
trap cleanup EXIT INT TERM HUP

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
    local current_time
    current_time=$(date +%s)
    local time_since_last_build
    time_since_last_build=$((current_time - LAST_BUILD_TIME))
    
    if [ $time_since_last_build -lt $MIN_BUILD_INTERVAL ]; then
        log_warning "Skipping rebuild: Too soon after last build (${time_since_last_build}s < ${MIN_BUILD_INTERVAL}s)"
        rm -f "$FLAG_FILE"  # Clear the flag
        return 0
    fi
    
    REBUILDING=1
    log_info "Building ${BOLD}$APP_NAME${RESET}..."
    
    # Create build directory and app bundle structure if needed
    mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
    
    # Copy Info.plist and resources if they've changed
    if [ ! -f "$APP_BUNDLE/Contents/Info.plist" ] || [ Info.plist -nt "$APP_BUNDLE/Contents/Info.plist" ]; then
        cp Info.plist "$APP_BUNDLE/Contents/"
    fi
    
    # Always copy resources to ensure they're up to date
    if [ -d "Resources" ]; then
        log_info "Copying resources..."
        for icns in Resources/*.icns; do
            if [ -f "$icns" ]; then
                dest="$APP_BUNDLE/Contents/Resources/$(basename "$icns")"
                cp "$icns" "$dest"
                log_info "Updated $(basename "$icns")"
            fi
        done
    fi

    echo -e "${YELLOW}${BOLD}Building for production...${RESET}"
    # Build the app
    if ! swift build -c release; then
        log_error "Build failed!"
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
    log_info "Closing existing app instance (if any)..."
    pkill -f "$APP_NAME" || true
    sleep 0.5 # Give it a moment to close
    
    # Touch the app bundle to ensure Finder refreshes
    touch "$APP_BUNDLE"
    
    # Open the app
    if [ "$DEBUG" -eq 1 ]; then
        log_info "Launching app in debug mode (stdout visible)..."
        echo -e "${BOLD}${PURPLE}───── APP OUTPUT START ─────${RESET}"
        "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>&1 | format_log &
    else
        log_info "Launching app in GUI mode..."
        open "$APP_BUNDLE"
    fi
    
    # Update timestamp and reset flag
    LAST_BUILD_TIME=$(date +%s)
    rm -f "$FLAG_FILE"  # Clear the flag file after building
    sleep 1.5
    REBUILDING=0
    log_success "Build and restart complete."
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
    log_info "Rebuild triggered by: ${YELLOW}$trigger${RESET}"
    
    # If it's a Package.swift change, do a clean build
    if [[ "$trigger" =~ Package\.swift$ ]] || [[ "$trigger" =~ Package\.resolved$ ]] || [[ "$trigger" =~ \.icns$ ]]; then
        log_warning "Dependencies or resources changed, performing clean build..."
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
    debug_print "Manually triggering rebuild"
    rm -f "$FLAG_FILE"  # Ensure flag is clear before rebuild
    handle_change "manual trigger"
}

# Initial build
build_and_run
LAST_BUILD_TIME=$(date +%s)  # Set initial build time

# Watch for changes and app quit
echo -e "\n${BOLD}${BLUE}Watching for changes in Sources directory.${RESET}"
echo -e "${BOLD}${GREEN}Press Enter to rebuild. Press Ctrl+C to stop.${RESET}"

# Create terminal control to make it non-blocking
exec 3<>/dev/tty
stty -icanon min 0 time 0 <&3

# Set up fswatch to monitor file changes
if command -v fswatch >/dev/null 2>&1; then
    debug_print "Starting fswatch for file monitoring..."
    (
        fswatch -0 -r -l 0.5 Sources Resources Package.swift Info.plist | while read -r -d "" file; do
            debug_print "fswatch detected change: $file"
            touch "$FLAG_FILE"
            echo "$file" > "/tmp/gpgapp_changed_file_$$"
        done
    ) &
    FSWATCH_PID=$!
    debug_print "fswatch started with PID: $FSWATCH_PID"
else
    # Fallback to polling if fswatch is not available
    debug_print "fswatch not available, falling back to polling"
    (
        while true; do
            for file in Sources/*.swift Resources/* Package.swift Info.plist; do
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
fi

# Main loop
while true; do
    # Check if a file change was detected via the flag file
    if [ -f "$FLAG_FILE" ]; then
        debug_print "FLAG_FILE detected"
        if [ -f "/tmp/gpgapp_changed_file_$$" ]; then
            CHANGED_FILE=$(cat "/tmp/gpgapp_changed_file_$$")
            handle_file_change "$CHANGED_FILE"
            rm -f "/tmp/gpgapp_changed_file_$$"
        else
            # Direct rebuild if flag is set but no file info
            debug_print "No changed file info, triggering direct rebuild"
            trigger_rebuild
        fi
    fi

    # Check for Enter key press - simplified approach
    if read -r -t 1 input <&3; then
        debug_print "Key press detected: '$input'"
        print_status "Manual rebuild triggered by Enter key"
        trigger_rebuild
    fi

    # Check if app quit (only if not rebuilding)
    if ! is_app_running; then
        print_status "App was quit by user. Stopping watch."
        cleanup  # This will exit the script
    fi
    
    # Short sleep to prevent busy waiting
    sleep 0.5
done

# Restore terminal on exit (should be caught by trap, but good practice)
exec 3>&-
stty sane
