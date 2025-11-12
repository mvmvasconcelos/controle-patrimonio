#!/bin/bash
# Usage: ./create_htpasswd.sh username
# It will prompt for password or read from STDIN

if [ -z "$1" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi
USER=$1
read -s -p "Enter password for $USER: " PASS
echo
# Create htpasswd compatible entry using openssl
# Format: username:encrypted
HASH=$(printf "%s" "$PASS" | openssl passwd -apr1 -stdin)
mkdir -p $(dirname "$0")
HTFILE="$(dirname "$0")/.htpasswd"
# Replace or add
if grep -q "^$USER:" "$HTFILE" 2>/dev/null; then
  sed -i "/^$USER:/d" "$HTFILE"
fi
printf "%s:%s\n" "$USER" "$HASH" >> "$HTFILE"
chmod 600 "$HTFILE"
echo "Created/updated $HTFILE for user $USER"
