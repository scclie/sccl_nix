{ config, lib, pkgs, ... }:

{
  services.xserver.xkb = {
    layout = "colemak_dh,rulemak";
    options = "caps:backspace,grp:win_space_toggle,lv3:ralt_alt";

    extraLayouts = {
      colemak_dh = {
        description = "Colemak-DH";
        languages = [ "eng" ];
        symbolsFile = pkgs.writeText "colemak_dh" ''
          default partial alphanumeric_keys
          xkb_symbols "basic" {
            name[Group1]= "English (Colemak-DH)";

            key <TLDE> { [     grave,    asciitilde  ] };
            key <AE01> { [         1,      exclam     ] };
            key <AE02> { [         2,          at     ] };
            key <AE03> { [         3,  numbersign    ] };
            key <AE04> { [         4,      dollar     ] };
            key <AE05> { [         5,     percent     ] };
            key <AE06> { [         6, asciicircum     ] };
            key <AE07> { [         7,     ampersand   ] };
            key <AE08> { [         8,      asterisk   ] };
            key <AE09> { [         9,     parenleft   ] };
            key <AE10> { [         0,    parenright   ] };
            key <AE11> { [     minus,     underscore  ] };
            key <AE12> { [     equal,         plus    ] };

            // Colemak-DH top row
            key <AD01> { [         q,          Q     ] };
            key <AD02> { [         w,          W     ] };
            key <AD03> { [         f,          F     ] };
            key <AD04> { [         p,          P     ] };
            key <AD05> { [         g,          G     ] };
            key <AD06> { [         j,          J     ] };
            key <AD07> { [         l,          L     ] };
            key <AD08> { [         u,          U     ] };
            key <AD09> { [         y,          Y     ] };
            key <AD10> { [    semicolon,      colon   ] };
            key <AD11> { [ bracketleft,    braceleft  ] };
            key <AD12> { [ bracketright,   braceright ] };

            // Colemak-DH home row
            key <AC01> { [         a,          A     ] };
            key <AC02> { [         r,          R     ] };
            key <AC03> { [         s,          S     ] };
            key <AC04> { [         t,          T     ] };
            key <AC05> { [         d,          D     ] };
            key <AC06> { [         h,          H     ] };
            key <AC07> { [         n,          N     ] };
            key <AC08> { [         e,          E     ] };
            key <AC09> { [         i,          I     ] };
            key <AC10> { [         o,          O     ] };
            key <AC11> { [ apostrophe,     quotedbl  ] };

            // Colemak-DH bottom row
            key <AB01> { [         z,          Z     ] };
            key <AB02> { [         x,          X     ] };
            key <AB03> { [         c,          C     ] };
            key <AB04> { [         v,          V     ] };
            key <AB05> { [         b,          B     ] };
            key <AB06> { [         k,          K     ] };
            key <AB07> { [         m,          M     ] };
            key <AB08> { [     comma,         less    ] };
            key <AB09> { [    period,       greater   ] };
            key <AB10> { [     slash,      question   ] };

            key <BKSL> { [ backslash,          bar    ] };

            include "level3(ralt_switch)"
          };
        '';
      };

      rulemak = {
        description = "Russian (Rulemak phonetic)";
        languages = [ "rus" ];
        symbolsFile = pkgs.writeText "rulemak" ''
          default partial alphanumeric_keys
          xkb_symbols "basic" {
            name[Group1]= "Russian (Rulemak phonetic)";

            key <TLDE> { [     Cyrillic_io,     Cyrillic_IO ] };
            key <AE01> { [               1,          exclam ] };
            key <AE02> { [               2,              at ] };
            key <AE03> { [               3,      numerosign ] };
            key <AE04> { [               4,          dollar ] };
            key <AE05> { [               5,         percent ] };
            key <AE06> { [               6,     asciicircum ] };
            key <AE07> { [               7,       ampersand ] };
            key <AE08> { [               8,        asterisk ] };
            key <AE09> { [               9,       parenleft ] };
            key <AE10> { [               0,      parenright ] };
            key <AE11> { [           minus,      underscore ] };
            key <AE12> { [           equal,            plus ] };

            key <AD01> { [     Cyrillic_ya,     Cyrillic_YA ] };
            key <AD02> { [    Cyrillic_zhe,    Cyrillic_ZHE ] };
            key <AD03> { [     Cyrillic_ie,     Cyrillic_IE ] };
            key <AD04> { [     Cyrillic_er,     Cyrillic_ER ] };
            key <AD05> { [     Cyrillic_te,     Cyrillic_TE ] };
            key <AD06> { [   Cyrillic_yeru,   Cyrillic_YERU ] };
            key <AD07> { [      Cyrillic_u,      Cyrillic_U ] };
            key <AD08> { [      Cyrillic_i,      Cyrillic_I ] };
            key <AD09> { [      Cyrillic_o,      Cyrillic_O ] };
            key <AD10> { [     Cyrillic_pe,     Cyrillic_PE ] };
            key <AD11> { [    Cyrillic_sha,    Cyrillic_SHA ] };
            key <AD12> { [  Cyrillic_shcha,  Cyrillic_SHCHA ] };
            key <BKSL> { [      Cyrillic_e,      Cyrillic_E ] };

            key <AC01> { [      Cyrillic_a,      Cyrillic_A ] };
            key <AC02> { [     Cyrillic_es,     Cyrillic_ES ] };
            key <AC03> { [     Cyrillic_de,     Cyrillic_DE ] };
            key <AC04> { [     Cyrillic_ef,     Cyrillic_EF ] };
            key <AC05> { [    Cyrillic_ghe,    Cyrillic_GHE ] };
            key <AC06> { [     Cyrillic_che,     Cyrillic_CHE ] };
            key <AC07> { [ Cyrillic_shorti, Cyrillic_SHORTI ] };
            key <AC08> { [     Cyrillic_ka,     Cyrillic_KA ] };
            key <AC09> { [     Cyrillic_el,     Cyrillic_EL ] };
            key <AC10> { [    Cyrillic_zhe,    Cyrillic_ZHE ] };
            key <AC11> { [ Cyrillic_softsign, Cyrillic_SOFTSIGN ] };

            key <AB01> { [     Cyrillic_ze,     Cyrillic_ZE ] };
            key <AB02> { [     Cyrillic_ha,     Cyrillic_HA ] };
            key <AB03> { [     Cyrillic_tse,    Cyrillic_TSE ] };
            key <AB04> { [     Cyrillic_ve,     Cyrillic_VE ] };
            key <AB05> { [     Cyrillic_be,     Cyrillic_BE ] };
            key <AB06> { [     Cyrillic_en,     Cyrillic_EN ] };
            key <AB07> { [     Cyrillic_em,     Cyrillic_EM ] };
            key <AB08> { [     comma,        less        ] };
            key <AB09> { [    period,      greater       ] };
            key <AB10> { [     slash,     question       ] };

            key <FK13> { [ Cyrillic_yu, Cyrillic_YU ] };
            key <FK14> { [ Cyrillic_hardsign, Cyrillic_HARDSIGN ] };

            include "level3(ralt_switch)"
          };
        '';
      };
    };
  };

  console.useXkbConfig = true;
}
