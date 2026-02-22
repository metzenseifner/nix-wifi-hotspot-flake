# Auto-start Behavior
#
# The WiFi hotspot will automatically start on boot when:
#
#     ✅ services.wifi-hotspot.enable = true activates the systemd services
#     ✅ systemd-networkd is enabled and set to start automatically
#     ✅ hostapd service is configured to start on boot
#     ✅ The network interface (wlan0) will be configured immediately
{
  description = "WiFi Hotspot";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      nixosModules.wifi-hotspot =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.services.wifi-hotspot;
        in
        {
          options.services.wifi-hotspot = {
            enable = mkEnableOption "WiFi hotspot";

            interface = mkOption {
              type = types.str;
              default = "wlan0";
              description = "Wireless interface to use for the hotspot";
            };

            ssid = mkOption {
              type = types.str;
              default = "RaspberryPi-Hotspot";
              description = "WiFi network name (SSID)";
            };

            password = mkOption {
              type = types.str;
              description = "WiFi password (WPA2)";
            };

            channel = mkOption {
              type = types.int;
              default = 6;
              description = "WiFi channel (1-11 for 2.4GHz, 36-165 for 5GHz)";
            };

            band = mkOption {
              type = types.enum [
                "2g"
                "5g"
              ];
              default = "2g";
              description = "WiFi band: 2g (2.4GHz) or 5g (5GHz)";
            };

            countryCode = mkOption {
              type = types.str;
              default = "US";
              description = "Two-letter country code for regulatory domain";
            };

            hwMode = mkOption {
              type = types.nullOr (
                types.enum [
                  "a"
                  "b"
                  "g"
                ]
              );
              default = null;
              description = "Hardware mode (leave null for automatic based on band)";
            };

            authMode = mkOption {
              type = types.enum [
                "wpa2-sha256"
                "wpa3-sae"
                "wpa3-sae-transition"
              ];
              default = "wpa2-sha256";
              description = "Authentication mode";
            };

            hidden = mkOption {
              type = types.bool;
              default = false;
              description = "Hide SSID (don't broadcast)";
            };

            maxClients = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "Maximum number of connected clients";
            };

            subnet = mkOption {
              type = types.str;
              default = "192.168.50.0/24";
              description = "Subnet for the hotspot network";
            };

            gatewayAddress = mkOption {
              type = types.str;
              default = "192.168.50.1";
              description = "Gateway IP address";
            };

            dhcpPoolOffset = mkOption {
              type = types.int;
              default = 10;
              description = "DHCP pool start offset";
            };

            dhcpPoolSize = mkOption {
              type = types.int;
              default = 100;
              description = "DHCP pool size";
            };
          };

          config = mkIf cfg.enable {
            # Enable systemd-networkd
            networking.useNetworkd = true;
            systemd.network.enable = true;

            # WiFi hotspot configuration with hostapd
            services.hostapd = {
              enable = true;
              radios.${cfg.interface} = {
                band = cfg.band;
                channel = cfg.channel;
                countryCode = cfg.countryCode;

                networks.${cfg.interface} = {
                  ssid = cfg.ssid;
                  authentication = {
                    mode = cfg.authMode;
                    wpaPassword = cfg.password;
                  };
                  settings = mkMerge [
                    (mkIf cfg.hidden {
                      ignore_broadcast_ssid = 1;
                    })
                    (mkIf (cfg.maxClients != null) {
                      max_num_sta = cfg.maxClients;
                    })
                    (mkIf (cfg.hwMode != null) {
                      hw_mode = cfg.hwMode;
                    })
                  ];
                };
              };
            };

            # systemd-networkd configuration for the wireless interface
            systemd.network.networks."40-${cfg.interface}" = {
              matchConfig.Name = cfg.interface;
              address = [ "${cfg.gatewayAddress}/24" ];
              networkConfig = {
                DHCPServer = true;
                IPMasquerade = "ipv4";
              };
              dhcpServerConfig = {
                PoolOffset = cfg.dhcpPoolOffset;
                PoolSize = cfg.dhcpPoolSize;
                DNS = [ cfg.gatewayAddress ];
              };
            };

            # Enable IP forwarding
            boot.kernel.sysctl = {
              "net.ipv4.ip_forward" = 1;
            };

            # Ensure necessary packages are available
            environment.systemPackages = with pkgs; [
              hostapd
              iw
              wirelesstools
            ];
          };
        };

      # Example configuration for direct use
      nixosConfigurations.raspberry-pi-hotspot = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          self.nixosModules.wifi-hotspot
          {
            services.wifi-hotspot = {
              enable = true;
              ssid = "MyRaspberryPi";
              password = "changeme123";
              channel = 11;
              band = "2g";
              countryCode = "GB";
              authMode = "wpa2-sha256";
              maxClients = 10;
              hidden = false;
            };
          }
        ];
      };
    };
}
