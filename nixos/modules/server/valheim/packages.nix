{ stdenvNoCC, fetchurl, unzip, lib }:

let

  plugin = { name, version, url, hash, files ? [ ], copySubdir ? null, dir ? null }:
    stdenvNoCC.mkDerivation {
      pname = "valheim-${name}";
      inherit version;
      src = fetchurl { inherit url hash; };
      nativeBuildInputs = [ unzip ];
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;
      installPhase = ''
        runHook preInstall
        unzip_status=0
        unzip -q "$src" -d unpacked || unzip_status=$?
        if [ "$unzip_status" -gt 1 ]; then
          echo "$pname: unzip failed with status $unzip_status" >&2
          exit 1
        fi
        mkdir -p "$out/plugins${lib.optionalString (dir != null) "/${dir}"}"
        ${lib.concatMapStringsSep "\n        " (file: ''
          found=$(find unpacked -type f -name ${lib.escapeShellArg file} -print -quit)
          if [ -z "$found" ]; then
            echo "$pname: ${file} missing after unzip (status $unzip_status); the archive no longer ships it" >&2
            exit 1
          fi
          cp "$found" "$out/plugins${lib.optionalString (dir != null) "/${dir}"}/${file}"
        '') files}
        ${lib.optionalString (copySubdir != null) ''
          subdir=$(find unpacked -type d -name ${lib.escapeShellArg copySubdir} -print -quit)
          if [ -z "$subdir" ]; then
            echo "$pname: directory ${copySubdir} missing after unzip (status $unzip_status); the archive no longer ships it" >&2
            exit 1
          fi
          cp -r "$subdir" "$out/plugins${lib.optionalString (dir != null) "/${dir}"}/${copySubdir}"
        ''}
        runHook postInstall
      '';
    };
in
rec {

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
      cp unpacked/BepInExPack_Valheim/start_game_bepinex.sh "$out/"
      cp unpacked/BepInExPack_Valheim/start_server_bepinex.sh "$out/"
      cp unpacked/BepInExPack_Valheim/.doorstop_version "$out/"
      chmod 0755 "$out/start_game_bepinex.sh" "$out/start_server_bepinex.sh"
      runHook postInstall
    '';
  };

  # Tristan-ValheimRcon. ships a single ValheimRcon.dll at the archive root.
  rcon = plugin {
    name = "rcon";
    version = "1.6.3";
    url = "https://thunderstore.io/package/download/Tristan/ValheimRcon/1.6.3/";
    hash = "sha256-+AqunyZ+EEiyRu3pJiV4Ky/E/xx5Ros3yfOigp8zbN4=";
    files = [ "ValheimRcon.dll" ];
  };

  # nwesterhausen DiscordConnector. One ILRepacked DLL for both sides
  discord = plugin {
    name = "discordconnector";
    version = "3.1.3";
    url = "https://thunderstore.io/package/download/nwesterhausen/DiscordConnector/3.1.3/";
    hash = "sha256-QPl7W25dUj9vTxZZ77E4x7HdaTmSMFuFVWUaPyE2VOM=";
    files = [ "DiscordConnector.dll" ];
  };

  # f00d4tehg0dz/valheim-webmap. Archive holds plugins/WebMap/ with WebMap.dll
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

      runHook postInstall
    '';
  };

  # DooDesch ServerPasswordOnce. Single ServerPasswordOnce.dll
  pwonce = plugin {
    name = "serverpasswordonce";
    version = "1.0.0";
    url = "https://thunderstore.io/package/download/DooDesch/ServerPasswordOnce/1.0.0/";
    hash = "sha256-7C55eB1Gvh4PVNKbA3mu9KL+76OQ2dr+1++ZujuTr5o=";
    files = [ "ServerPasswordOnce.dll" ];
  };

  # Baka_Gaijin AutoSaveInterval.
  autosave = plugin {
    name = "autosaveinterval";
    version = "1.0.2";
    url = "https://thunderstore.io/package/download/Baka_Gaijin/AutoSaveInterval/1.0.2/";
    hash = "sha256-ECGy5rbbD7Bn+0Tamy01OeU43MrCdv41dr1Kh8u07PE=";
    files = [ "AutoSaveInterval.dll" ];
  };

  # Libraries pulled in by the mods below.

  # ValheimModding Jotunn.
  jotunn = plugin {
    name = "jotunn";
    version = "2.30.2";
    url = "https://thunderstore.io/package/download/ValheimModding/Jotunn/2.30.2/";
    hash = "sha256-iq6S2ivg62ggzUz1fi9sHWrQ1zjUkVlm58PXqU6amw8=";
    files = [ "Jotunn.dll" ];
    dir = "Jotunn";
  };

  # EpicLoot's config and loot table serializer.
  jsonDotNet = plugin {
    name = "jsondotnet";
    version = "13.0.4";
    url = "https://thunderstore.io/package/download/ValheimModding/JsonDotNET/13.0.4/";
    hash = "sha256-oiHHvnFjq5c5J0uWL70fY6veZbFBiDmmLwKsohCGgUc=";
    files = [
      "Newtonsoft.Json.dll"
      "NewtonsoftJsonDetector.dll"
    ];
  };

  # ProtectiveWards' config format.
  yamlDotNet = plugin {
    name = "yamldotnet";
    version = "16.3.1";
    url = "https://thunderstore.io/package/download/ValheimModding/YamlDotNet/16.3.1/";
    hash = "sha256-IoBIDSrdfWp6F7iC+bdVFFFgyFLomhR5TRST0ISV0qw=";
    files = [
      "YamlDotNet.dll"
      "YamlDotNetDetector.dll"
    ];
  };


  # Client-side modpack

  reefCharacters = plugin {
    name = "reefcharacters";
    version = "0.1.0";
    url = "https://thunderstore.io/package/download/ReefTeam/ReefCharacters/0.1.0/";
    hash = "sha256-4VdaVf5dgP1gHby2P57t4LesFW686MYupUw3vAMgjsY=";
    files = [ "ReefCharacters.dll" ];
  };

  # RandyKnapp EpicLoot: magic through ancient loot, effects, shard slots, tempering.
  epicLoot = plugin {
    name = "epicloot";
    version = "0.14.13";
    url = "https://thunderstore.io/package/download/RandyKnapp/EpicLoot/0.14.13/";
    hash = "sha256-j9GRMsRlJ0cQkqxzK3FlHhGGLywLeE/JB7OHtqzju08=";
    files = [ "EpicLoot.dll" ];
    dir = "EpicLoot";
  };

  # Advize PlantEverything: cultivator recipes and crops outside their vanilla biome and terrain restrictions.
  plantEverything = plugin {
    name = "planteverything";
    version = "1.21.3";
    url = "https://thunderstore.io/package/download/Advize/PlantEverything/1.21.3/";
    hash = "sha256-pzEidUjUuwxmnaj687TRfwLqJpa2+shfzunPw8/TJEY=";
    files = [ "Advize_PlantEverything.dll" ];
  };

  # shudnal ProtectiveWards: base access control, guilds, and ten active offerings that
  protectiveWards = plugin {
    name = "protectivewards";
    version = "2.0.15";
    url = "https://thunderstore.io/package/download/shudnal/ProtectiveWards/2.0.15/";
    hash = "sha256-RSwzg3d3vEqY9AUjfMgRm3mh0Uo9otubnioESGk9OMc=";
    files = [ "ProtectiveWards.dll" ];
  };

  # Moopfam FarmGridRemake
  farmGridRemake = plugin {
    name = "farmgridremake";
    version = "1.1.3";
    url = "https://thunderstore.io/package/download/Moopfam/FarmGridRemake/1.1.3/";
    hash = "sha256-LRS1/U9Vsf8YWtOmOuAgflQCJX/3hd8RkRh+QpcJVhw=";
    files = [ "FarmGridRemake.dll" ];
  };

  # shudnal ConditionalConfigSync
  conditionalConfigSync = plugin {
    name = "conditionalconfigsync";
    version = "1.0.8";
    url = "https://thunderstore.io/package/download/shudnal/ConditionalConfigSync/1.0.8/";
    hash = "sha256-7A1L68ZMs3ytcus0TTUP7cU3K4XQ8yj+2JoPSAywSK8=";
    files = [
      "ConditionalConfigSync.dll"
      "ConditionalConfigSync.Plugin.dll"
    ];
  };

  # Goneryx QuickStackPlus: quick stack into nearby containers
  quickStackPlus = plugin {
    name = "quickstackplus";
    version = "1.1.2";
    url = "https://thunderstore.io/package/download/Goneryx/QuickStackPlus/1.1.2/";
    hash = "sha256-U0AvuMva3KTrevNJ7Nz9Pu3vEiCNWBPH33OYBRvrDNA=";
    files = [ "QuickStackPlus.dll" ];
  };

  # Client side HUD and camera mods.
  azuClock = plugin {
    name = "azuclock";
    version = "1.1.0";
    url = "https://thunderstore.io/package/download/Azumatt/AzuClock/1.1.0/";
    hash = "sha256-SHUBcjJOmlBBltznqPYPN7K5CyYrP0o0xWrhAfWfKTQ=";
    files = [ "AzuClock.dll" ];
  };

  # Azumatt Build Camera Custom Hammers Edition
  buildCamera = plugin {
    name = "buildcamera";
    version = "1.3.1";
    url = "https://thunderstore.io/package/download/Azumatt/Build_Camera_Custom_Hammers_Edition/1.3.1/";
    hash = "sha256-MBjsr3O/77recyEm7bjbzCJ7GoBAWKhhtWxRvt8gQHs=";
    files = [ "Build Camera.dll" ];
  };

  # Searica AdvancedTerrainModifiers
  advancedTerrainModifiers = plugin {
    name = "advancedterrainmodifiers";
    version = "1.5.4";
    url = "https://thunderstore.io/package/download/Searica/AdvancedTerrainModifiers/1.5.4/";
    hash = "sha256-1OICOo74xf2Ck+dB5Okg55oky8r4fsf/e26akQcne88=";
    files = [ "TerrainTools.dll" ];
  };

  # cjayride ConfigurationManager
  configurationManager = plugin {
    name = "configurationmanager";
    version = "0.6.2";
    url = "https://thunderstore.io/package/download/cjayride/ConfigurationManager/0.6.2/";
    hash = "sha256-6JzNMe7cnjOGTW4oN97fr5gz8XaZNJJBwY///7orOhE=";
    files = [ "ConfigurationManager.dll" ];
  };

  # MathiasDecrock PlanBuild
  planBuild = plugin {
    name = "planbuild";
    version = "0.20.0";
    url = "https://thunderstore.io/package/download/MathiasDecrock/PlanBuild/0.20.0/";
    hash = "sha256-eYWeXzmJ2G4xZWOmUqqBfVghkD/lPKabFPiVY976/90=";
    copySubdir = "PlanBuild";
  };

  # BasilPanda NoStamCosts - QoL of building
  noStamCosts = plugin {
    name = "nostamcosts";
    version = "0.1.2";
    url = "https://thunderstore.io/package/download/BasilPanda/NoStamCosts/0.1.2/";
    hash = "sha256-EM7QP40/KMKgRJinr6fnhBiBIuanp980J3sjClGehk8=";
    files = [ "NoStamCosts.dll" ];
  };

  # OdinPlus OdinArchitect: 200+ building pieces
  odinArchitect = plugin {
    name = "odinarchitect";
    version = "1.7.9";
    url = "https://thunderstore.io/package/download/OdinPlus/OdinArchitect/1.7.9/";
    hash = "sha256-4ySRWjLXtpBJs2nuN/pYk7og/R5kx3QUmgOSWK3mjkM=";
    copySubdir = "OdinArchitect";
  };

  # OdinPlus OdinHorse
  odinHorse = plugin {
    name = "odinhorse";
    version = "1.7.7";
    url = "https://thunderstore.io/package/download/OdinPlus/OdinHorse/1.7.7/";
    hash = "sha256-NREe/36CNSF6XChU7N2GktK+9Fa8+RxCv9mRcJqj6RE=";
    files = [ "OdinHorse.dll" ];
  };

  # Nextek SpeedyPaths: paths and constructions give a speed bonus and cheaper sprinting
  speedyPaths = plugin {
    name = "speedypaths";
    version = "1.0.9";
    url = "https://thunderstore.io/package/download/Nextek/SpeedyPaths/1.0.9/";
    hash = "sha256-42nAdflJ3jcWiQtDphGpFTzQKdSSo8EWEeRg2zcDsYo=";
    files = [ "SpeedyPaths.dll" ];
  };

  # ComfyMods ComfyLadders: ladders auto-jumpable, the maintained replacement for the 2021 BetterLadders
  comfyLadders = plugin {
    name = "comfyladders";
    version = "1.1.0";
    url = "https://thunderstore.io/package/download/ComfyMods/ComfyLadders/1.1.0/";
    hash = "sha256-P2tnwA+XfdkOYs5aTsyo3V8NtUrLXsx+kHzpnorOHj4=";
    files = [ "ComfyLadders.dll" ];
  };

  # JereKuusela Wearable_Trophies: cosmetics only. the settings sync to clients.
  wearableTrophies = plugin {
    name = "wearabletrophies";
    version = "1.11.0";
    url = "https://thunderstore.io/package/download/JereKuusela/Wearable_Trophies/1.11.0/";
    hash = "sha256-1pQ6ATwZqh53scMyWIiSo29wjoTHJd8mVSSHS+5x1GY=";
    files = [ "WearableTrophies.dll" ];
  };

  # RandyKnapp EquipmentAndQuickSlots: armour slots and six quick slots. C
  equipmentAndQuickSlots = plugin {
    name = "equipmentandquickslots";
    version = "3.1.3";
    url = "https://thunderstore.io/package/download/RandyKnapp/EquipmentAndQuickSlots/3.1.3/";
    hash = "sha256-u1tR+2OEKGS4mgQIU1raqCkL3lYFV57WnBfgzc2XId0=";
    files = [ "EquipmentAndQuickSlots.dll" ];
  };

  # PONEIS CraftFromChestsPlus: craft, build and smelt from chests near a placed totem.
  # Server and all clients at the same version.
  craftFromChestsPlus = plugin {
    name = "craftfromchestsplus";
    version = "1.1.6";
    url = "https://thunderstore.io/package/download/PONEIS/CraftFromChestsPlus/1.1.6/";
    hash = "sha256-4bmUdeKcMgQ0ou4bpNM2emY1POgkCmbzEuEfbZQOiLg=";
    files = [ "CraftFromChestsPlus.dll" ];
  };

  # ComfyMods ComfyGizmo: building rotation hotkeys and snap angles. Client only
  gizmo = plugin {
    name = "gizmo";
    version = "1.16.0";
    url = "https://thunderstore.io/package/download/ComfyMods/Gizmo/1.16.0/";
    hash = "sha256-ksKkfwFCaN4SlB0ZDLdwZVLBPiLNT+2aInJd/Wq+B6g=";
    files = [ "ComfyGizmo.dll" ];
  };

  # VerdantsAscent FiresGhettoNetworking: transport and traffic tuning for a busy server.
  ghettoNetworking = plugin {
    name = "firesghettoneworking";
    version = "1.5.19";
    url = "https://thunderstore.io/package/download/VerdantsAscent/FiresGhettoNetworking/1.5.19/";
    hash = "sha256-TV0myoU3K9ZPnUlL1NZ5vhZ6f3bW90mfK7Rkr1lZVkc=";
    files = [ "VAGhettoNetworking.dll" ];
  };
}
