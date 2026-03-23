{ config, lib, pkgs, ... }:

{
  services.xserver.xkb = {
    layout = "us,rulemak_vial";
    options = "caps:backspace,grp:win_space_toggle,lv3:ralt_alt";
    
    extraLayouts = {
      rulemak_vial = {
        description = "Rulemak for Vial Colemak-DH";
        languages = [ "rus" ];
        symbolsFile = pkgs.writeText "rulemak_vial" ''
          default partial alphanumeric_keys
          xkb_symbols "basic" {
            name[Group1]= "Russian (Rulemak for Vial Colemak-DH)";
            
            // XKB rows are QWERTY physical positions
            // But Vial remaps them to Colemak-DH before sending
            // So we map Russian letters to QWERTY physical positions
            
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
      
      // Top row: Q W E R T Y U I O P [ ] \
      key <AD01> { [     Cyrillic_ya,     Cyrillic_YA ] };  // Q Я
      key <AD02> { [    Cyrillic_zhe,    Cyrillic_ZHE ] };  // W Ж
      key <AD03> { [     Cyrillic_ie,     Cyrillic_IE ] };  // E Е
      key <AD04> { [     Cyrillic_er,     Cyrillic_ER ] };  // R Р
      key <AD05> { [     Cyrillic_te,     Cyrillic_TE ] };  // T Т
      key <AD06> { [   Cyrillic_yeru,   Cyrillic_YERU ] };  // Y Ы
      key <AD07> { [      Cyrillic_u,      Cyrillic_U ] };  // U У
      key <AD08> { [      Cyrillic_i,      Cyrillic_I ] };  // I И
      key <AD09> { [      Cyrillic_o,      Cyrillic_O ] };  // O О
      key <AD10> { [     Cyrillic_pe,     Cyrillic_PE ] };  // P П
      key <AD11> { [    Cyrillic_sha,    Cyrillic_SHA ] };  // [ Ш
      key <AD12> { [  Cyrillic_shcha,  Cyrillic_SHCHA ] };  // ] Щ
      key <BKSL> { [      Cyrillic_e,      Cyrillic_E ] };  // \ Э
      
      // Home row: A S D F G H J K L ; '
      key <AC01> { [      Cyrillic_a,      Cyrillic_A ] };  // A А
      key <AC02> { [     Cyrillic_es,     Cyrillic_ES ] };  // S С
      key <AC03> { [     Cyrillic_de,     Cyrillic_DE ] };  // D Д
      key <AC04> { [     Cyrillic_ef,     Cyrillic_EF ] };  // F Ф
      key <AC05> { [    Cyrillic_ghe,    Cyrillic_GHE ] };  // G Г
      key <AC06> { [     Cyrillic_che,     Cyrillic_CHE ] };  // H Ч
      key <AC07> { [ Cyrillic_shorti, Cyrillic_SHORTI ] };  // J Й
      key <AC08> { [     Cyrillic_ka,     Cyrillic_KA ] };  // K К
      key <AC09> { [     Cyrillic_el,     Cyrillic_EL ] };  // L Л
      key <AC10> { [    Cyrillic_zhe,    Cyrillic_ZHE ] };  // ; Ж (duplicate for convenience)
      key <AC11> { [ Cyrillic_softsign, Cyrillic_SOFTSIGN ] };  // ' Ь
      
            // Bottom row: Z X C V B N M , . /
      key <AB01> { [     Cyrillic_ze,     Cyrillic_ZE ] };  // Z З
      key <AB02> { [     Cyrillic_ha,     Cyrillic_HA ] };  // X Х (duplicate)
      key <AB03> { [     Cyrillic_tse,    Cyrillic_TSE ] };  // C Ц
      key <AB04> { [     Cyrillic_ve,     Cyrillic_VE ] };  // V В
      key <AB05> { [     Cyrillic_be,     Cyrillic_BE ] };  // B Б
      key <AB06> { [     Cyrillic_en,     Cyrillic_EN ] };  // N Н
      key <AB07> { [     Cyrillic_em,     Cyrillic_EM ] };  // M М
      key <AB08> {	[     comma,	less		]	};
      key <AB09> {	[    period,	greater		]	};
      key <AB10> {	[     slash,	question	]	};

      key <FK13> { [ Cyrillic_yu, Cyrillic_YU ] };  // Ю
      key <FK14> { [ Cyrillic_hardsign, Cyrillic_HARDSIGN ] };  // Ъ
      
      include "level3(ralt_switch)"
            
            include "level3(ralt_switch)"
          };
        '';
      };
    };
  };
  
  # Vial keyboard support
  services.udev.extraRules = ''
    # Specific keyboard: MTKB W-SOFLE
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="55d4", ATTRS{idProduct}=="0664", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
    
    # Generic Vial support (all Vial-enabled keyboards)
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';
  
  console.useXkbConfig = true;
}
