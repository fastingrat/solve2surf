#!/bin/sh

# Load openwrt's uci functions
. /lib/functions.sh

# Fetch the storage URL from our config
config_load solve2surf
config_get storage_url "main" "storage_url" ""

if [ -z "$storage_url" ]; then
    logger -t solve2surf-sync "Error: storage_url not configured in /etc/config/solve2surf"
    exit 1
fi

DEST="/tmp/solve2surf_problems.json"
TMP_DEST="/tmp/solve2surf_problems.json.tmp"

# Download the file using curl
curl --silent --fail --location --output "$TMP_DEST" "$storage_url"

RETURN_CODE=$?

if [ $RETURN_CODE -eq 0 ]; then
    # 3. JSON Validation Logic
    # We use jsonfilter to verify the file is valid JSON and has at least one entry
    if jsonfilter -i "$TMP_DEST" -e "@" > /dev/null 2>&1; then
        mv "$TMP_DEST" "$DEST"
        logger -t solve2surf-sync "Successfully updated and validated problems from $storage_url"
    else
        logger -t solve2surf-sync "Error: Downloaded file from $storage_url is not valid JSON. Keeping old file."
        rm -f "$TMP_DEST"
        exit 2
    fi
else
    logger -t solve2surf-sync "Failed to download problems from $storage_url (Exit code: $RETURN_CODE)"
    exit $RETURN_CODE
fi