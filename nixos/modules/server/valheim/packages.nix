{ stdenvNoCC, fetchurl, unzip }:

rec {
  # BepInEx 5 pack for Valheim, plus UnityDoorstop 4.4.0. Archive holds
  # BepInExPack_Valheim/{BepInEx,doorstop_libs,winhttp.dll,doorstop_config.ini}.
  bepinex = stdenvNoCC.mkDerivation {
    pname = "valheim-bepinex";
    version = "5.4.2351";
    src = fetchurl {
      url = "https://thunderstore.io/package/download/denikson/BepInExPack_Valheim/5.4.2351/";
      hash = "sha256-vOYxSXl2qTl3zrCOFmcS5sMdFSRJVvifF98JKpti4p8=";
    };
    nativeBuildInputs = [ unzip ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      unzip -q "$src" -d unpacked
      cp -r unpacked/BepInExPack_Valheim/BepInEx "$out/"
      cp -r unpacked/BepInExPack_Valheim/doorstop_libs "$out/"
      cp unpacked/BepInExPack_Valheim/winhttp.dll "$out/"
      cp unpacked/BepInExPack_Valheim/doorstop_config.ini "$out/"
      runHook postInstall
    '';
  };

  # Tristan-ValheimRcon. ships a single ValheimRcon.dll at the archive root.
  rcon = stdenvNoCC.mkDerivation {
    pname = "valheim-rcon";
    version = "1.6.3";
    src = fetchurl {
      url = "https://thunderstore.io/package/download/Tristan/ValheimRcon/1.6.3/";
      hash = "sha256-+AqunyZ+EEiyRu3pJiV4Ky/E/xx5Ros3yfOigp8zbN4=";
    };
    nativeBuildInputs = [ unzip ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/plugins"
      unzip -q "$src" -d unpacked
      cp unpacked/ValheimRcon.dll "$out/plugins/"
      runHook postInstall
    '';
  };

  # nwesterhausen DiscordConnector. Single ILRepacked DLL at the archive root.
  # DiscordConnector-Client is deliberately not installed, clients stay vanilla.
  # Shout and ping default to true in the mod and are left alone.
  discord = stdenvNoCC.mkDerivation {
    pname = "valheim-discordconnector";
    version = "3.1.3";
    src = fetchurl {
      url = "https://thunderstore.io/package/download/nwesterhausen/DiscordConnector/3.1.3/";
      hash = "sha256-QPl7W25dUj9vTxZZ77E4x7HdaTmSMFuFVWUaPyE2VOM=";
    };
    nativeBuildInputs = [ unzip ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/plugins"
      unzip -q "$src" -d unpacked
      cp unpacked/DiscordConnector.dll "$out/plugins/"
      runHook postInstall
    '';
  };

  # f00d4tehg0dz/valheim-webmap. Archive holds plugins/WebMap/ with WebMap.dll,
  # websocket-sharp.dll and web/. The plugin is a directory because the mod writes
  # map_data/ next to its own assembly, so $out is that folder and deploy.nix copies
  # the DLL rather than symlinking it. See the webmap block in deploy.nix
  webmap = stdenvNoCC.mkDerivation {
    pname = "valheim-webmap";
    version = "2.1.6";
    src = fetchurl {
      url = "https://github.com/f00d4tehg0dz/valheim-webmap/releases/download/v2.1.6/ValheimWebMap-2.1.6.zip";
      hash = "sha256-6LEbVrCTm/hcpBuWnIZFKeR8gtVZI139uWkPnSmlP9E=";
    };
    nativeBuildInputs = [ unzip ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      unzip -q "$src" -d unpacked
      cp -r unpacked/plugins/WebMap "$out/WebMap"
      # tools/ holds standalone extract_textures.py / extract_meshes.py. The mod
      # runs those against the game files itself, so there is nothing to ship.
      runHook postInstall
    '';
  };

  # DooDesch ServerPasswordOnce. Single ServerPasswordOnce.dll at the archive root,
  # no dependencies and no config to pre-write: it reads the password BepInEx
  # already passes to the game and has nothing to bind.
  pwonce = stdenvNoCC.mkDerivation {
    pname = "valheim-serverpasswordonce";
    version = "1.0.0";
    src = fetchurl {
      url = "https://thunderstore.io/package/download/DooDesch/ServerPasswordOnce/1.0.0/";
      hash = "sha256-7C55eB1Gvh4PVNKbA3mu9KL+76OQ2dr+1++ZujuTr5o=";
    };
    nativeBuildInputs = [ unzip ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/plugins"
      unzip -q "$src" -d unpacked
      cp unpacked/ServerPasswordOnce.dll "$out/plugins/"
      runHook postInstall
    '';
  };

  # Baka_Gaijin AutoSaveInterval. The one plugin entry is named
  # "plugins\AutoSaveInterval.dll", a backslash where a separator belongs. unzip
  # translates it into a real plugins/ directory and exits 1 with UZ_WARNING, so
  # set -e would abort the build before the cp runs. Tolerate status 1 only, and
  # check the file is there afterwards so a re-pin that moves it fails loudly.
  autosave = stdenvNoCC.mkDerivation {
    pname = "valheim-autosaveinterval";
    version = "1.0.2";
    src = fetchurl {
      url = "https://thunderstore.io/package/download/Baka_Gaijin/AutoSaveInterval/1.0.2/";
      hash = "sha256-ECGy5rbbD7Bn+0Tamy01OeU43MrCdv41dr1Kh8u07PE=";
    };
    nativeBuildInputs = [ unzip ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/plugins"
      unzip_status=0
      unzip -q "$src" -d unpacked || unzip_status=$?
      if [ "$unzip_status" -gt 1 ]; then
        echo "valheim-autosaveinterval: unzip failed with status $unzip_status" >&2
        exit 1
      fi
      if ! test -f unpacked/plugins/AutoSaveInterval.dll; then
        echo "valheim-autosaveinterval: unpacked/plugins/AutoSaveInterval.dll missing after unzip (status $unzip_status); the archive layout changed" >&2
        exit 1
      fi
      cp unpacked/plugins/AutoSaveInterval.dll "$out/plugins/"
      runHook postInstall
    '';
  };
}
