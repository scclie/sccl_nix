#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-root@192.168.0.239}"
FLAKE="${2:-.#laeradr}"

echo "Deploying to $TARGET with flake $FLAKE"

# Generate hardware config on target
echo "Generating hardware configuration..."
nixos-anywhere \
  --flake "$FLAKE" \
  --generate-hardware-config nixos-generate-config \
  --target-host "$TARGET" \
  --extra-files /etc/nixos/secrets

echo "Deploy complete!"
