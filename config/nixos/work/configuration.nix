# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Nix.
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true; # Hardlink identical files.
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.graceful = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # Define your hostname.
  networking.hostName = "nixos";
  # Uses NetworkManager to obtain an IP address and other configuration
  # for all network interfaces that are not manually configured.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Warsaw";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pl_PL.UTF-8";
    LC_IDENTIFICATION = "pl_PL.UTF-8";
    LC_MEASUREMENT = "pl_PL.UTF-8";
    LC_MONETARY = "pl_PL.UTF-8";
    LC_NAME = "pl_PL.UTF-8";
    LC_NUMERIC = "pl_PL.UTF-8";
    LC_PAPER = "pl_PL.UTF-8";
    LC_TELEPHONE = "pl_PL.UTF-8";
    LC_TIME = "pl_PL.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Configure desktop environment.
  services.displayManager.gdm.enable = true;
  services.displayManager.defaultSession = "none+qtile";
  services.xserver.windowManager.session = [{
    name = "qtile";
    start = ''
      ${pkgs.python3.pkgs.qtile}/bin/qtile start -b x11 &
      waitPID=$!
    '';
  }];

  # Keyring.
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  security.pam.services.gdm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.gdm-password.enableGnomeKeyring = true;

  # Lockscreen.
  security.pam.services.i3lock.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "pl";
    variant = "";
  };

  # Configure fast keyboard typing.
  services.xserver.autoRepeatDelay = 200;
  services.xserver.autoRepeatInterval = 26;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  security.rtkit.enable = true;
  # services.pipewire = {
  #   enable = true;
  #   wireplumber.enable = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
  #   pulse.enable = true;
  #   extraConfig.pipewire."99-rnnoise.conf" = {
  #     "context.modules" = [
  #       {
  #         name = "libpipewire-module-filter-chain";
  #         args = {
  #           "node.description" = "Noise Canceling source";
  #           "media.name" = "Noise Canceling source";
  #
  #           "filter.graph" = {
  #             nodes = [
  #               {
  #                 type = "ladspa";
  #                 name = "rnnoise";
  #                 plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
  #                 label = "noise_suppressor_mono";
  #                 control = {
  #                   "VAD Threshold (%)" = 80.0;
  #                   "VAD Grace Period (ms)" = 200;
  #                   "Retroactive VAD Grace (ms)" = 0;
  #                 };
  #               }
  #             ];
  #           };
  #
  #           "capture.props" = {
  #             "node.name" = "capture.rnnoise_source";
  #             "node.passive" = true;
  #             "audio.rate" = 48000;
  #           };
  #
  #           "playback.props" = {
  #             "node.name" = "rnnoise_source";
  #             "media.class" = "Audio/Source";
  #             "audio.rate" = 48000;
  #           };
  #         };
  #       }
  #     ];
  #   };
  # };

  # Bluetooth
  hardware.bluetooth.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mh = {
    isNormalUser = true;
    description = "Mateusz";
    extraGroups = [ "networkmanager" "wheel" "storage" "video" "audio" "lp" "scanner" "docker" "vboxusers" ];
  };

  # Support unpatched binaries out of the box.
  programs.nix-ld.enable = true;

  # Execute shebangs which assume hard coded locations.
  services.envfs.enable = true;
  # A DBus service which allows apps to query and manipulate storage devices.
  services.udisks2.enable = true;
  # Automatic device mounting daemon.
  services.devmon.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Always enable shell system wide, otherwise it won't source the neccessary stuff.
  users.defaultUserShell = pkgs.bash;
  environment.shells = [ pkgs.bash ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim
    wget
    git
    inetutils
    libsecret # For keyring.
    clamav
    # rnnoise-plugin
  ];

  programs.noisetorch.enable = true;

  # Anti-virus
  services.clamav.daemon.enable = true;
  services.clamav.updater.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Yubikey support.
  services.udev.packages = [ pkgs.yubikey-personalization ];
  services.pcscd.enable = true;

  # Podman.
  virtualisation.containers.enable = true;
  virtualisation = {
    podman = {
      enable = true;
      # Create a `docker` alias for podman, to use it as a drop-in replacement
      dockerCompat = true;
      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
    };
  };
  # For seamless migration from Docker.
  # Ref: https://podman-desktop.io/docs/migrating-from-docker/using-the-docker_host-environment-variable
  environment.sessionVariables = {
    DOCKER_HOST = "unix:///run/user/1000/podman/podman.sock";
  };

  # VritualBox.
  # virtualisation.virtualbox = {
  #   host = {
  #     enable = true;
  #     enableExtensionPack = true;
  #   };
  #   guest = {
  #     enable = true;
  #     dragAndDrop = true;
  #     clipboard = true;
  #   };
  # };
  # users.extraGroups.vboxusers.members = [ "mh" ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };

  systemd.services.jumpcloud-agent = {
    enable = true;
    description = "Jumpcloud agent";
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = ''/opt/jc/bin/jumpcloud-agent'';
      Restart = "always";
      RestartSec = 5;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
