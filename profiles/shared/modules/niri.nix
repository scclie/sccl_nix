{ config, pkgs, lib
, niriKbLayout ? "colemak_caws,rulemak_caws"
, niriKbOptions ? "caps:backspace,grp:rwin_toggle,lv3:ralt_switch"
, niriOutput ? ''output "DP-2" {
          mode "2560x1440@500"
          scale 1.0
      }''
, niriExtraBinds ? ""
, niriExtraSpawn ? ""
, ... }:

{
  home.packages = with pkgs; [
    niri
    xwayland-satellite
    swaybg
    swayidle
    wayfreeze
    grim
    slurp
    swappy
    cliphist
    wl-clipboard
  ];

  systemd.user.services.cliphist = {
    Unit = {
      Description = "Clipboard history manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.cliphist-images = {
    Unit = {
      Description = "Clipboard history manager for images";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.configFile."xkb/symbols/colemak_dh_wide_en" = {
    enable = true;
    text = ''
      default partial alphanumeric_keys
      xkb_symbols "basic" {
        name[Group1]= "English (Colemak-DH Wide)";

        // Number row: ` 1-6 / 7-0 - =
        key <TLDE> { [     grave,    asciitilde  ] };
        key <AE01> { [         1,      exclam     ] };
        key <AE02> { [         2,          at     ] };
        key <AE03> { [         3,  numbersign     ] };
        key <AE04> { [         4,      dollar     ] };
        key <AE05> { [         5,     percent     ] };
        key <AE06> { [         6, asciicircum     ] };
        key <AE07> { [ backslash,           bar   ] };
        key <AE08> { [         7,     ampersand   ] };
        key <AE09> { [         8,      asterisk   ] };
        key <AE10> { [         9,     parenleft   ] };
        key <AE11> { [         0,    parenright   ] };
        key <AE12> { [     minus,     underscore  ] };
        key <BKSL> { [     equal,         plus    ] };

        // Top row: QWFPB ] JLUY' ;
        key <AD01> { [         q,          Q      ] };
        key <AD02> { [         w,          W      ] };
        key <AD03> { [         f,          F      ] };
        key <AD04> { [         p,          P      ] };
        key <AD05> { [         b,          B      ] };
        key <AD06> { [ bracketright,   braceright  ] };
        key <AD07> { [         j,          J      ] };
        key <AD08> { [         l,          L      ] };
        key <AD09> { [         u,          U      ] };
        key <AD10> { [         y,          Y      ] };
        key <AD11> { [ apostrophe,     quotedbl   ] };
        key <AD12> { [ semicolon,       colon     ] };

        // Home row: ARSTG [ MNEIO
        key <AC01> { [         a,          A      ] };
        key <AC02> { [         r,          R      ] };
        key <AC03> { [         s,          S      ] };
        key <AC04> { [         t,          T      ] };
        key <AC05> { [         g,          G      ] };
        key <AC06> { [ bracketleft,    braceleft   ] };
        key <AC07> { [         m,          M      ] };
        key <AC08> { [         n,          N      ] };
        key <AC09> { [         e,          E      ] };
        key <AC10> { [         i,          I      ] };
        key <AC11> { [         o,          O      ] };

        // Bottom row: XCDVZ / KH , . (Angle)
        key <AB01> { [         x,          X      ] };
        key <AB02> { [         c,          C      ] };
        key <AB03> { [         d,          D      ] };
        key <AB04> { [         v,          V      ] };
        key <AB05> { [         z,          Z      ] };
        key <AB06> { [     slash,      question   ] };
        key <AB07> { [         k,          K      ] };
        key <AB08> { [         h,          H      ] };
        key <AB09> { [     comma,         less    ] };
        key <AB10> { [    period,       greater   ] };

      };
    '';
  };

  xdg.configFile."xkb/symbols/colemak_dh_wide_ru" = {
    enable = true;
    text = ''
      default partial alphanumeric_keys
      xkb_symbols "basic" {
        name[Group1]= "Russian (Rulemak-CAWS DH Wide)";

        // Number row: ё 1-6 э 7-0 - ъ
        key <TLDE> { [     Cyrillic_io,     Cyrillic_IO ] };
        key <AE01> { [               1,          exclam ] };
        key <AE02> { [               2,              at ] };
        key <AE03> { [               3,      numerosign ] };
        key <AE04> { [               4,          dollar ] };
        key <AE05> { [               5,         percent ] };
        key <AE06> { [               6,     asciicircum ] };
        key <AE07> { [      Cyrillic_e,      Cyrillic_E ] };
        key <AE08> { [               7,       ampersand ] };
        key <AE09> { [               8,        asterisk ] };
        key <AE10> { [               9,       parenleft ] };
        key <AE11> { [               0,      parenright ] };
        key <AE12> { [           minus,      underscore ] };
        key <BKSL> { [ Cyrillic_hardsign, Cyrillic_HARDSIGN ] };

        // Top row: Я Ж Ф П Б   Ш Й Л У Ы Ь Ю
        key <AD01> { [     Cyrillic_ya,     Cyrillic_YA ] };
        key <AD02> { [    Cyrillic_zhe,    Cyrillic_ZHE ] };
        key <AD03> { [     Cyrillic_ef,     Cyrillic_EF ] };
        key <AD04> { [     Cyrillic_pe,     Cyrillic_PE ] };
        key <AD05> { [     Cyrillic_be,     Cyrillic_BE ] };
        key <AD06> { [    Cyrillic_sha,    Cyrillic_SHA ] };
        key <AD07> { [ Cyrillic_shorti, Cyrillic_SHORTI ] };
        key <AD08> { [     Cyrillic_el,     Cyrillic_EL ] };
        key <AD09> { [      Cyrillic_u,      Cyrillic_U ] };
        key <AD10> { [   Cyrillic_yeru,   Cyrillic_YERU ] };
        key <AD11> { [ Cyrillic_softsign, Cyrillic_SOFTSIGN ] };
        key <AD12> { [     Cyrillic_yu,     Cyrillic_YU ] };

        // Home row: А Р С Т Г   Щ М Н Е И О
        key <AC01> { [      Cyrillic_a,      Cyrillic_A ] };
        key <AC02> { [     Cyrillic_er,     Cyrillic_ER ] };
        key <AC03> { [     Cyrillic_es,     Cyrillic_ES ] };
        key <AC04> { [     Cyrillic_te,     Cyrillic_TE ] };
        key <AC05> { [    Cyrillic_ghe,    Cyrillic_GHE ] };
        key <AC06> { [  Cyrillic_shcha,  Cyrillic_SHCHA ] };
        key <AC07> { [     Cyrillic_em,     Cyrillic_EM ] };
        key <AC08> { [     Cyrillic_en,     Cyrillic_EN ] };
        key <AC09> { [     Cyrillic_ie,     Cyrillic_IE ] };
        key <AC10> { [      Cyrillic_i,      Cyrillic_I ] };
        key <AC11> { [      Cyrillic_o,      Cyrillic_O ] };

        // Bottom row: Х Ц Д В З   / К Ч , . (Angle)
        key <AB01> { [     Cyrillic_ha,     Cyrillic_HA ] };
        key <AB02> { [    Cyrillic_tse,    Cyrillic_TSE ] };
        key <AB03> { [     Cyrillic_de,     Cyrillic_DE ] };
        key <AB04> { [     Cyrillic_ve,     Cyrillic_VE ] };
        key <AB05> { [     Cyrillic_ze,     Cyrillic_ZE ] };
        key <AB06> { [           slash,       question ] };
        key <AB07> { [     Cyrillic_ka,     Cyrillic_KA ] };
        key <AB08> { [     Cyrillic_che,     Cyrillic_CHE ] };
        key <AB09> { [           comma,           less ] };
        key <AB10> { [          period,        greater ] };

      };
    '';
  };

  xdg.configFile."niri/config.kdl" = {
    enable = true;
    text = ''
      // Niri Configuration
      // Generated by Home Manager

      input {
          keyboard {
              xkb {
                  layout "${niriKbLayout}"
                  options "${niriKbOptions}"
              }
          }

          mouse {
              accel-speed -0.8
          }

          focus-follows-mouse               // am lamer frfr
      }


      ${niriOutput}

      layout {
          gaps 10
          center-focused-column "never"

          border {
              width 1
              active-color "#81a1c1"
              inactive-color "#4c566a"
          }

          focus-ring {
              width 1
              active-color "#81a1c1"
              inactive-color "#4c566a"
          }
      }

      window-rule {
          clip-to-geometry true
          geometry-corner-radius 12
      }

      prefer-no-csd

      binds {                                   // ColemakCAWS keybindings, bad 4 qwerty

      ///////////////////////////////
      ///   WINDOW MANIPULATIONS  ///
      ///////////////////////////////

          Mod+Return { spawn "alacritty"; }
          Mod+A { spawn "fuzzel"; }
          Mod+D { spawn "thunar"; }
          Mod+Tab { toggle-overview; }

          Mod+Q { close-window; }
          Mod+Shift+Q { close-window; }
          Mod+Shift+G { fullscreen-window; }

          Mod+R { focus-column-left; }
          Mod+T { focus-column-right; }
          Mod+F { focus-workspace-up; }
          Mod+S { focus-workspace-down; }

          Mod+Shift+R { move-column-left; }
          Mod+Shift+T { move-column-right; }
          Mod+Shift+F { move-window-up; }
          Mod+Shift+S { move-window-down; }

          Mod+1 { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }
          Mod+3 { focus-workspace 3; }
          Mod+4 { focus-workspace 4; }
          Mod+5 { focus-workspace 5; }
          Mod+6 { focus-workspace 6; }
          Mod+7 { focus-workspace 7; }
          Mod+8 { focus-workspace 8; }
          Mod+9 { focus-workspace 9; }
          Mod+0 { focus-workspace 10; }

          Mod+Shift+1 { move-column-to-workspace 1; } // wane
          Mod+Shift+2 { move-column-to-workspace 2; } // tfo
          Mod+Shift+3 { move-column-to-workspace 3; } // free?
          Mod+Shift+4 { move-column-to-workspace 4; } // for
          Mod+Shift+5 { move-column-to-workspace 5; } // fih
          Mod+Shift+6 { move-column-to-workspace 6; } // sex
          Mod+Shift+7 { move-column-to-workspace 7; } // 676767
          Mod+Shift+8 { move-column-to-workspace 8; } // eih
          Mod+Shift+9 { move-column-to-workspace 9; } // hitler
          Mod+Shift+0 { move-column-to-workspace 10; } // wanenone

          Mod+Escape { focus-workspace-previous; }

          // Screenshots with frozen screen using wayfreeze
          Mod+Shift+Z { spawn "sh" "-c" "wayfreeze & FREEZE_PID=$!; sleep 0.1; grim -g \"$(slurp -d)\" - | wl-copy; kill $FREEZE_PID 2>/dev/null || true"; }
          Mod+Shift+A { spawn "sh" "-c" "wayfreeze & FREEZE_PID=$!; sleep 0.1; grim -g \"$(slurp -d)\" - | swappy -f -; kill $FREEZE_PID 2>/dev/null || true"; }

          XF86AudioRaiseVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; } // inf roll 4 burn out ur headphones
          XF86AudioLowerVolume { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
          XF86AudioMute { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }      // fr i dont have kb with this bttn, but mb ive build it in the future

          // windowo management keybindings
          Mod+W { move-column-left; }
          Mod+P { move-column-right; }

          Mod+M { switch-preset-column-width; }
          Mod+Shift+V { maximize-column; }

          Mod+V { spawn "sh" "-c" "cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"; }
          Mod+B { consume-window-into-column; }
          Mod+Shift+B { expel-window-from-column; }

          Mod+Space { toggle-window-floating; }

          ${niriExtraBinds}



          //////////////////////////
          ///   VIDEO RECORDING  ///
          //////////////////////////

          // Run video rec buffer
          Mod+Alt+Semicolon hotkey-overlay-title="Start 3min Replay Buffer" {
              spawn "sh" "-c" "wf-recorder --buffering 180 -r 60 -c h264_vaapi -d /dev/dri/renderD128 -f ~/Videos/replay-$(date +%s).mp4"
          }

          // save video buffer
          Mod+Shift+Semicolon hotkey-overlay-title="Save Replay" {
              spawn "sh" "-c" r#"
                    pkill -INT wf-recorder
                    file=$(ls -t ~/Videos/replay-*.mp4 | head -n 1)
                    wl-copy "file://$file" -t text/uri-list
                    notify-send -t 2000 "Replay" "Saved & Restarting buffer..."

                    wf-recorder --buffering 180 -r 60 -c h264_vaapi -d /dev/dri/renderD128 -f ~/Videos/replay-$(date +%s).mp4
                "#;
          }

          // stop video buffer
          Mod+Alt+Shift+Semicolon hotkey-overlay-title="Stop & Clear Replay" {
              spawn "pkill" "-9" "wf-recorder"
          }
      }

      spawn-at-startup "sh" "-c" "systemctl --user set-environment XDG_CURRENT_DESKTOP=niri:gnome && systemctl --user import-environment WAYLAND_DISPLAY && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user restart xdg-desktop-portal"
      spawn-at-startup "swaybg" "-i" "/nix/store/4djy86fqw2i5s2wn12ns8jm0qfaprbl8-nix-d-nord-purple.jpg?raw=true" "-m" "fill"
      spawn-at-startup "xwayland-satellite"
      spawn-at-startup "waybar"
      spawn-at-startup "dunst"
      spawn-at-startup "swayidle" "-w" "timeout" "300" "niri msg action power-off-monitors"

      ${niriExtraSpawn}


      animations {
          window-open {
              duration-ms 200
              curve "ease-out-cubic"
          }

          window-close {
              duration-ms 150
              curve "ease-out-cubic"
          }

          workspace-switch {
              duration-ms 250
              curve "ease-out-cubic"
          }
      }

      hotkey-overlay {
          skip-at-startup
      }


    '';
  };
}
