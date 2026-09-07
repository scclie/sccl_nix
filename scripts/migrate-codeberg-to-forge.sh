#!/usr/bin/env bash
set -euo pipefail

# One-time migration: Codeberg (scclie) -> self-hosted Forgejo.
# Runs with host DNS (works) and pushes over plain HTTP to the forge.
# Requires env: CODEBERG_TOKEN, FORGEJO_TOKEN; optional FORGEJO_URL.
# Repo list is fetched from Codeberg API, so no names are hardcoded.

: "${CODEBERG_TOKEN:?set CODEBERG_TOKEN}"
: "${FORGEJO_TOKEN:?set FORGEJO_TOKEN}"
FORGEJO_URL="${FORGEJO_URL:-http://10.69.0.10:3000}"
USER="scclie"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

auth_json=$(curl -s -H "Authorization: token $CODEBERG_TOKEN" "https://codeberg.org/api/v1/user/repos?limit=200&page=1")
if ! echo "$auth_json" | grep -q '"id"'; then
  echo "CRIT: cannot fetch repo list from Codeberg, empty response. Aborting."
  exit 1
fi
echo "$auth_json" | jq -r '.[] | @base64' > "$TMP/repos.b64"
count=$(wc -l < "$TMP/repos.b64")
echo "Found $count repos on Codeberg."

ok=0
skip=0
fail=0
while read -r line; do
  [ -n "$line" ] || continue
  name=$(echo "$line" | base64 -d | jq -r '.name')
  priv=$(echo "$line" | base64 -d | jq -r '.private')
  defbr=$(echo "$line" | base64 -d | jq -r '.default_branch')
  echo "== $name"
  git ls-remote --exit-code "$FORGEJO_URL/$USER/$name.git" >/dev/null 2>&1 \
    && skip=$((skip+1)) \
    && echo "   already on forge, skipping" \
    && continue
  git clone --mirror "https://scclie:$CODEBERG_TOKEN@codeberg.org/$USER/$name.git" "$TMP/$name.git" >/dev/null 2>&1 \
    || { fail=$((fail+1)); echo "   CRIT: clone from codeberg failed"; continue; }
  # ensure repo exists on forge (name/visibility/default branch)
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H "Authorization: token $FORGEJO_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$name\",\"private\":$priv,\"auto_init\":false,\"default_branch\":\"$defbr\"}" \
    "$FORGEJO_URL/api/v1/user/repos")
  # push heads and tags only; mirror would also send refs/pull which the forge rejects.
  git -C "$TMP/$name.git" push --prune \
    "http://scclie:$FORGEJO_TOKEN@${FORGEJO_URL#http://}/$USER/$name.git" \
    '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*' >/dev/null 2>&1 \
    || { fail=$((fail+1)); echo "   CRIT: push to forge failed"; continue; }
  ok=$((ok+1))
  echo "   ok (private=$priv, branch=$defbr)"
done < "$TMP/repos.b64"
echo "Done: $ok migrated, $skip already present, $fail failed."
exit $(( fail > 0 ? 1 : 0 ))