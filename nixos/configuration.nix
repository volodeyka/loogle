{ config, pkgs, modulesPath, lib, environment, loogle_server, nixpkgs, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  # for testing
  # virtualisation.forwardPorts = [
  #   { from = "host"; host.port = 8888; guest.port = 80; }
  # ];
  # virtualisation.memorySize = 2048;
  # users.users.root.initialPassword = "test";

  boot.loader.grub.device = "/dev/sda";
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
  boot.initrd.kernelModules = [ "nvme" ];
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "loogle";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJRd0CZZQXyKTEQSEtrIpcTg15XEoRjuYodwo0nr5hNj jojo@kirk"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMYx13rpT1E87lw5yNyRs1Lq3/vwd3fxjRwq9nJz4b3iVSAGXnwUxDVbi3m2H1NSNCsoOFOVej+yPMkmIs/+Wxo= pixel-tpm"
  ];

  nix.settings.substituters = [
    "https://cache.nixos.org/"
    "https://cache.garnix.io"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
  ];

  # enable nix flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.registry.nixpkgs.flake = nixpkgs;
  nix.nixPath = [
    "nixpkgs=/etc/nixpkgs/channels/nixpkgs}"
    "/nix/var/nix/profiles/per-user/root/channels"
  ];
  systemd.tmpfiles.rules = [
    "L+ /etc/nixpkgs/channels/nixpkgs     - - - - ${nixpkgs}"
  ];


  documentation.nixos.enable = false;
  documentation.enable = false;

  security.acme.defaults.email = "mail@joachim-breitner.de";
  security.acme.acceptTerms = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };


  services.nginx = {
    enable = true;
    enableReload = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;
  };

  services.nginx.virtualHosts = {
    "loogle.nomeata.de" = {
      serverAliases = [ ];
      enableACME = true;
      forceSSL = true;
      locations = {
        "/" = {
          proxyPass = "http://localhost:8080";
          extraConfig =
            # required when the target is also TLS server with multiple hosts
            "proxy_ssl_server_name on;" +
            # required when the server wants to use HTTP Authentication
            "proxy_pass_header Authorization;";
        };
      };
    };
  };

  users.users.loogle = {
    isNormalUser = true;
  };

  systemd.services.loogle = {
    description = "Loogle";
    enable = true;
    after = [
      "network.target"
    ];
    wantedBy = [
      "multi-user.target"
    ];
    serviceConfig = {
      Type = "simple";
      User = "loogle";
      Restart = "always";
      ExecStart = "${loogle_server}/bin/loogle_server";
    };
  };

  swapDevices = [{ device = "/swapfile"; size = 2048; }];

  nix.settings.sandbox = false;

  # Automatic garbage collection. Enabling this frees up space by removing unused builds periodically
  nix.gc = {
    automatic = false;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 22 ];

  services.journald.extraConfig = "SystemMaxUse=100M";

  programs.vim.defaultEditor = true;

  services.fail2ban.enable = true;
  system.stateVersion = "22.11";
}