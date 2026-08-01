{ config, pkgs, ... }:

{
  home.file.".config/hyfetch/nixowos.txt".text = ''
           ▗▄▄▄       ▗▄▄▄▄    ▄▄▄▖
           ▜███▙       ▜███▙  ▟███▛
            ▜███▙       ▜███▙▟███▛       ▗
     ▐▄      ▜███▙       ▜██████▛    ▄▄▞▀▛
      ▜▀▀▀▄▄  ▜█████████▙ ▜████▛  ▄█▛▀  ▗▘
       ▌   ▀█▄▟██████████▙ ▜███▙▟█▛    ▗▞
       ▐  ▙▖▟▙▄▄▖           ▜████▙▄▟▘  ▟▘
        ▜▖▝████▛             ▜██▛██▄▄▄▞▘
         ▝▟███▛ ▀▚▄       ▄▞▀ ▜▛ ▟███▛
 ▟███████████▛ ▗▄▄▞▘     ▝▚▄▄▖  ▟██████████▙
 ▜██████████▛  /// ▟▘ ▄ ▝▙ /// ▟███████████▛
       ▟███▛ ▟▙    ▜▄▟▀▙▄▛    ▟███▛
      ▟███▛ ▟██▙             ▟███▛      ▄
     ▟███▛  ▜███▙           ▝▀▀▀▀  ▗▄▛▀▀
     ▜██▛  ▗▌▜███▙ ▜██████████████████▛
      ▜▛  ▗▛ ▟████▙ ▜████████████████▛
          ▝▌▟██████▙     ▄▄▜███▙
           ▟███▛▜███▙▄▄▟▀▘  ▜███▙
          ▟███▛▄▄▜███▙       ▜███▙
          ▝▀▀▀    ▀▀▀▀▘       ▀▀▀▘
  '';

  programs.fish.shellAliases = {
    hyowofetch = "hyfetch --ascii-file ~/.config/hyfetch/nixowos.txt";
    fastowofetch = "fastfetch --logo-type file --logo ~/.config/hyfetch/nixowos.txt";
  };

  programs.fish.functions.fastfetch = {
    body = ''
      command fastfetch --logo-type file --logo ~/.config/hyfetch/nixowos.txt $argv
    '';
  };

  programs.bash.shellAliases = {
    hyowofetch = "hyfetch --ascii-file ~/.config/hyfetch/nixowos.txt";
    neowofetch = "fastfetch --logo-type file --logo ~/.config/hyfetch/nixowos.txt";
    fastowofetch = "fastfetch --logo-type file --logo ~/.config/hyfetch/nixowos.txt";
  };
}
