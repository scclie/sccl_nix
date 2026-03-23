{ config, pkgs, ... }:

{
  stylix.targets.waybar.enable = false;

  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34; # not too thicc, not too thin
        spacing = 0;

        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [
          "niri/language"
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "temperature"
          "battery"
          "tray"
        ];

        "niri/workspaces" = {
          format = "{index}";
          on-click = "activate";
        };

        "niri/window" = {
          format = "{}";
          max-length = 50;
          separate-outputs = true;
        };

        "niri/language" = {
          format = " {}";
          format-colemak_caws = "  Colemak";
          format-rulemak_caws = "  Rulemak";
          min-length = 5;
          tooltip = true;
        };

        clock = {
          interval = 1;
          format = "{:%H:%M:%S}";
          format-alt = "{:%A, %d %B %Y}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='#88c0d0'><b>{}</b></span>";
              days = "<span color='#d8dee9'><b>{}</b></span>";
              weeks = "<span color='#81a1c1'><b>W{}</b></span>";
              weekdays = "<span color='#8fbcbb'><b>{}</b></span>";
              today = "<span color='#bf616a'><b><u>{}</u></b></span>";
            };
          };
        };

        cpu = {
          interval = 2;
          format = "  {usage}%";
          tooltip = true;
          min-length = 5;
        };

        memory = {
          interval = 2;
          format = "  {}%";
          tooltip-format = "RAM: {used:0.1f}G / {total:0.1f}G";
          min-length = 5;
        };

        temperature = {
          interval = 2;
          hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
          critical-threshold = 80;
          format = "{icon} {temperatureC}°C";
          format-icons = ["" "" "" "" ""];
          tooltip = true;
        };

        battery = {
          interval = 10;
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-icons = ["" "" "" "" ""];
          tooltip-format = "{timeTo}\n{power}W";
        };

        network = {
          interval = 2;
          format-wifi = " {signalStrength}%";
          format-ethernet = "󰩟 {ipaddr}";
          format-disconnected = " Disconnected";
          tooltip-format = "{essid}\n{ipaddr}/{cidr}\n {bandwidthDownBits}  {bandwidthUpBits}";
          on-click = "nmtui";
        };

        pulseaudio = {
          scroll-step = 5;
          format = "{icon}   {volume}%";
          format-muted = " Muted";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = ["" "" ""];
          };
          on-click = "pavucontrol";
          tooltip-format = "{desc}\n{volume}%";
          min-length = 5;
        };

        tray = {
          icon-size = 18;
          spacing = 10;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", sans-serif;
        font-size: 13px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: transparent;
        color: #effff4;
      }

      window#waybar > box {
        background: rgba(36, 41, 51, 1.0);
        border-radius: 12px;
        margin: 6px 10px 0px 10px;
        padding: 0 8px;
        border: 2px solid rgba(46, 52, 64, 0.9);
      }

      #workspaces {
        background: transparent;
        margin: 5px 5px 5px 10px;
        padding: 0;
      }

      #workspaces button {
        padding: 0 8px;
        background: transparent;
        border-radius: 8px;
        margin: 0 3px;
        transition: all 0.3s;
        box-shadow: none;
        border-bottom: none;
      }

      #workspaces button:hover {
        background: #4c566a;
      }

      #workspaces button.active {
        color: #2e3440;
        box-shadow: none;
        border-bottom: none;
      }

      #workspaces button:nth-child(1) { color: #bf616a; font-weight: 700; background: rgb(46, 52, 64) }  /* not gay rainbow ;/    */
      #workspaces button:nth-child(1).active { background: #bf616a; color: #2e3440; font-weight: 700; }

      #workspaces button:nth-child(2) { color: #d08770; font-weight: 700; background: rgb(46, 52, 64) }
      #workspaces button:nth-child(2).active { background: #d08770; color: #2e3440; font-weight: 700; }

      #workspaces button:nth-child(3) { color: #ebcb8b; font-weight: 700; background: rgb(46, 52, 64) }
      #workspaces button:nth-child(3).active { background: #ebcb8b; color: #2e3440; font-weight: 700; }

      #workspaces button:nth-child(4) { color: #a3be8c; font-weight: 700; background: rgb(46, 52, 64) }
      #workspaces button:nth-child(4).active { background: #a3be8c; color: #2e3440; font-weight: 700; }

      #workspaces button:nth-child(5) { color: #8fbcbb; font-weight: 700; background: rgb(46, 52, 64) }
      #workspaces button:nth-child(5).active { background: #8fbcbb; color: #2e3440; font-weight: 700; }

      #workspaces button:nth-child(6) { color: #88c0d0; font-weight: 700; background: rgb(46, 52, 64) }
      #workspaces button:nth-child(6).active { background: #88c0d0; color: #2e3440; font-weight: 700; }

      #workspaces button:nth-child(7) { color: #81a1c1; font-weight: 700; background: rgb(46, 52, 64) }
      #workspaces button:nth-child(7).active { background: #81a1c1; color: #2e3440; font-weight: 700; }

      #workspaces button:nth-child(8) { color: #5e81ac; font-weight: 700; background: rgb(46, 52, 64) }
      #workspaces button:nth-child(8).active { background: #5e81ac; color: #2e3440; font-weight: 700; }

      #workspaces button:nth-child(9) { color: #b48ead; font-weight: 700; background: rgb(46, 52, 64) }
      #workspaces button:nth-child(9).active { background: #b48ead; color: #2e3440; font-weight: 700; }

      #workspaces button:nth-child(10) { color: #d8dee9; font-weight: 700;background: rgb(46, 52, 64) }
      #workspaces button:nth-child(10).active { background: #d8dee9; color: #2e3440; font-weight: 700; }

      #workspaces button.urgent {
        background: #bf616a;
        color: #eceff4;
        font-weight: 700;
      }

      #window {
        margin: 5px 10px;
        padding: 2px 12px;
        color: #88c0d0;
        font-weight: 500;
        background: none;
      }

      #clock {
        margin: 5px;
        padding: 2px 16px;
        background: #81a1c1;
        color: #2e3440;
        border-radius: 8px;
        font-weight: 700;
      }

      #language,
      #pulseaudio,
      #network,
      #cpu,
      #memory,
      #temperature,
      #battery,
      #tray {
        margin: 5px 2px;
        padding: 2px 10px;
        background: rgb(46, 52, 64);
        color: #eceff4;
        border-radius: 8px;
      }

      #language {
        color: #8fbcbb;
      }

      #pulseaudio {
        color: #88c0d0;
      }

      #network {
        color: #a3be8c;
      }

      #cpu {
        color: #ebcb8b;
      }

      #memory {
        color: #d08770;
      }

      #temperature {
        color: #bf616a;
      }

      #temperature.critical {
        background: #bf616a;
        color: #eceff4;
        animation: blink 1s linear infinite;
      }

      @keyframes blink {
        to {
          background-color: rgba(191, 97, 106, 0.5);
        }
      }

      #battery {
        color: #a3be8c;
      }

      #battery.warning {
        color: #ebcb8b;
      }

      #battery.critical {
        color: #bf616a;
      }

      #battery.charging {
        color: #8fbcbb;
      }

      #idle_inhibitor.activated {
        color: #ebcb8b;
      }

      #tray {
        margin-right: 10px;
        padding: 2px 6px;
      }

      tooltip {
        background: rgb(46, 52, 64);
        border: 2px solid #81a1c1;
        border-radius: 8px;
        color: #eceff4;
      }

      tooltip label {
        color: #eceff4;
      }
    '';
  };
}
