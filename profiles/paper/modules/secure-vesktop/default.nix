{ pkgs, config, ... }:

let
  encryptedDir = "${config.xdg.configHome}/vesktop-enc";
  passwordFile = "${config.xdg.dataHome}/vesktop/vesktop-password";

  wrapper = pkgs.writeShellScriptBin "vesktop" ''
    if [ ! -d "${encryptedDir}" ] || [ ! -f "${passwordFile}" ]; then
      echo "Run 'vesktop-setup' first" >&2
      exit 1
    fi

    TMPDIR=$(mktemp -d)
    cleanup() {
      ${pkgs.fuse}/bin/fusermount -u "$TMPDIR" 2>/dev/null || true
      rmdir "$TMPDIR" 2>/dev/null || true
    }
    trap cleanup EXIT

    ${pkgs.gocryptfs}/bin/gocryptfs -passfile "${passwordFile}" "${encryptedDir}" "$TMPDIR"
    exec ${pkgs.vesktop}/bin/vesktop --no-sandbox --ozone-platform=wayland --user-data-dir="$TMPDIR" "$@"
  '';

  setupScript = pkgs.writeShellScriptBin "vesktop-setup" ''
    if [ -d "${encryptedDir}" ]; then
      echo "Already set up."
      exit 0
    fi

    mkdir -p "$(dirname "${passwordFile}")"
    mkdir -p "${encryptedDir}"

    PASSWORD=$(head -c 32 /dev/urandom | base64 | tr -d '\n' | head -c 32)
    echo "$PASSWORD" > "${passwordFile}"
    chmod 600 "${passwordFile}"
    echo "$PASSWORD" | ${pkgs.gocryptfs}/bin/gocryptfs -init "${encryptedDir}"

    if [ -d "${config.xdg.configHome}/vesktop" ]; then
      echo "Migrating existing config..."
      TMPDIR=$(mktemp -d)
      ${pkgs.gocryptfs}/bin/gocryptfs -passfile "${passwordFile}" "${encryptedDir}" "$TMPDIR"
      cp -r "${config.xdg.configHome}/vesktop"/* "$TMPDIR"/ 2>/dev/null || true
      ${pkgs.fuse}/bin/fusermount -u "$TMPDIR" || true
      rmdir "$TMPDIR" || true
      rm -rf "${config.xdg.configHome}/vesktop"
    fi

    echo "Done."
  '';
in
{
  home.packages = [ wrapper setupScript ];

  xdg.desktopEntries.vesktop = {
    name = "Vesktop (Secured)";
    genericName = "Discord Client";
    exec = "vesktop %U";
    icon = "vesktop";
    type = "Application";
    categories = [ "Network" "Chat" "InstantMessaging" ];
    terminal = false;
    mimeType = [ "x-scheme-handler/discord" ];
  };
}
