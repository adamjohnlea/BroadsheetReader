#!/bin/bash
# ci_post_clone.sh — Xcode Cloud post-clone script
#
# Strips restricted entitlements (CloudKit, push notifications) that prevent
# the test runner from launching the app on Xcode Cloud.
# See: https://developer.apple.com/forums/thread/748570

set -euo pipefail

ENTITLEMENTS_FILE="$CI_PRIMARY_REPOSITORY_PATH/Broadsheet/Broadsheet.entitlements"

if [ -f "$ENTITLEMENTS_FILE" ]; then
    echo "Stripping restricted entitlements for CI..."

    # Remove CloudKit entitlements
    /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.icloud-container-identifiers" "$ENTITLEMENTS_FILE" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.icloud-services" "$ENTITLEMENTS_FILE" 2>/dev/null || true

    # Remove push notification entitlement
    /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.aps-environment" "$ENTITLEMENTS_FILE" 2>/dev/null || true

    echo "Entitlements after stripping:"
    cat "$ENTITLEMENTS_FILE"
else
    echo "Warning: Entitlements file not found at $ENTITLEMENTS_FILE"
fi
