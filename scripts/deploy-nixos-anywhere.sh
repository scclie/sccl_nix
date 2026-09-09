# !!!!!!!!!!!!!!!!!!!!
# FOR NEW SERVERS ONLY
# FOR NEW SERVERS ONLY
# FOR NEW SERVERS ONLY
# !!!!!!!!!!!!!!!!!!!!
# EDIT BEFORE USE (am lazy to make universal script)

#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-root@192.168.0.10}"
FLAKE="${2:-.#laeradr}"
AGE_KEY="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys-server.txt}"

echo "Deploying to $TARGET with flake $FLAKE"

# Stage the age key so it lands at /var/lib/sops-nix/key.txt on the target.
# nixos-anywhere --extra-files copies the *contents* of a local dir to target root (/),
# so we build var/lib/sops-nix/key.txt inside a staging dir.
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

if [ -f "$AGE_KEY" ]; then
  mkdir -p "$STAGING/var/lib/sops-nix"
  install -m 600 "$AGE_KEY" "$STAGING/var/lib/sops-nix/key.txt"
  echo "Staging age key from $AGE_KEY"
  EXTRA_FILES=("--extra-files" "$STAGING")
else
  echo "WARNING: age key not found at $AGE_KEY - secrets will not decrypt on target" >&2
  EXTRA_FILES=()
fi

nixos-anywhere \
  --flake "$FLAKE" \
  --target-host "$TARGET" \
  "${EXTRA_FILES[@]}"

echo "Deploy complete!"
