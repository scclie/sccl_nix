{ config, lib, pkgs, ... }:

{
  time.timeZone = "Europe/Moscow";

  # putin issue
  # NTP servers by IP
  services.timesyncd = {
    enable = true;
    servers = [
      "162.159.200.123" # time.cloudflare.com
      "216.239.35.0"    # time.google.com
      "194.190.168.1"   # ntp1.vniiftri.ru
    ];
  };

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "ru_RU.UTF-8";
      LC_MONETARY = "ru_RU.UTF-8";
    };
  };
}
