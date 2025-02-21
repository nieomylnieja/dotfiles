{ config
, pkgs
, lib
, ...
}:
let
  homeDir = "/home/mh";
  dotfilesDir = "${homeDir}/.dotfiles";
  gdk = pkgs.google-cloud-sdk.withExtraComponents (with pkgs.google-cloud-sdk.components; [
    gke-gcloud-auth-plugin
  ]);
in
{
  programs.home-manager.enable = true;
  # nixpkgs.config = {
  #   allowUnfree = true;
  #   allowUnfreePredicate = _: true;
  # };

  home = {
    username = "mh";
    homeDirectory = homeDir;
    stateVersion = "24.11";
  };

  home.packages = with pkgs; [
    awscli2
    aws-vault
    apg
    alacritty
    alejandra
    ansible
    arandr
    bat
    bash-completion
    bashmount
    bottom
    browserpass
    cachix
    csvkit
    delta
    devbox
    direnv
    discord
    distrobox
    du-dust
    dunst
    eza
    fd
    file
    flatpak
    fnm
    fzf
    gcc_multi
    gh
    git
    glibcLocales
    simple-scan
    sushi
    gimp
    gnumake
    gnupg
    go_1_23
    gdk
    httpie
    i3lock-color
    jetbrains.goland
    jetbrains.idea-community
    jetbrains.jdk # JDK for plugin development.
    jq
    lesspipe
    libsForQt5.qt5ct
    libnotify # For notify-send.
    libreoffice
    luajitPackages.luarocks
    lutris
    man
    man-pages
    mesa
    moreutils
    nemo-with-extensions
    nerd-fonts.mononoki
    neofetch
    neovim
    nixpkgs-fmt
    nordic
    nushell
    obsidian
    ocaml
    opam
    openssl
    pamixer
    pass
    pavucontrol
    pulseaudio # For pactl.
    pdm
    picom
    pinentry-qt
    kubectl
    ripgrep
    rofi-power-menu
    rustup
    kubernetes-helm
    feh
    flameshot
    signal-desktop
    slack
    sops
    spotify
    starship
    statix
    unzip
    zathura
    zoxide
    xclip
    xorg.xrandr
    xorg.xset
    yarn
    yubikey-manager
    yq
    vlc
    vscode
    winbox
  ];

  # Neovim has to be linked as the directory has to be writable.
  home.activation = {
    createLinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run [ -d ${config.xdg.configHome}/nvim ] || ln -s $VERBOSE_ARG ${dotfilesDir}/config/nvim ${config.xdg.configHome}/nvim
    '';
  };

  home.file = {
    ".bashrc".source = ../bash/bashrc;
    ".bash_logout".source = ../bash/bash_logout;
    ".xprofile".source = ../xorg/xprofile;
    ".xinitrc".source = ../xorg/xinitrc;
    ".profile".source = ../xorg/xinitrc;
  };

  xdg.configFile = {
    "qtile".source = ../qtile;
    "git/config".source = ../git/config;
    "starship.toml".source = ../starship/starship.toml;
    "rofi".source = ../rofi;
    "dunst".source = ../dunst;
    "alacritty".source = ../alacritty;
    "picom".source = ../picom;
    "flameshot/flameshot.ini".source = ../flameshot/flameshot.ini;
    "ideavim".source = ../ideavim;
    "direnv/direnvrc".source = ../direnv/direnvrc;
    "zathura".source = ../zathura;
    "Code/User".source = ../vscode;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = [ "zathura" ];
    };
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  fonts.fontconfig.enable = true;

  programs.browserpass = {
    enable = true;
    browsers = [ "firefox" ];
  };

  programs.firefox = {
    enable = true;
    package = pkgs.wrapFirefox pkgs.firefox-unwrapped {
      extraPolicies = {
        CaptivePortal = false;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DisableFirefoxAccounts = false;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        OfferToSaveLoginsDefault = false;
        PasswordManagerEnabled = false;
        FirefoxHome = {
          Search = true;
          Pocket = false;
          Snippets = false;
          TopSites = false;
          Highlights = false;
        };
        UserMessaging = {
          ExtensionRecommendations = false;
          SkipOnboarding = true;
        };
      };
    };
    profiles =
      let
        common = {
          search = {
            force = true;
            default = "DuckDuckGo";
          };
          settings = {
            "general.smoothScroll" = true;
          };
          extraConfig = ''
            user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
            user_pref("full-screen-api.ignore-widgets", true);
            user_pref("media.ffmpeg.vaapi.enabled", true);
            user_pref("media.rdd-vpx.enabled", true);
          '';
        };
      in
      {
        work = {
          id = 0;
          name = "work";
          extensions = with pkgs.nur.repos.rycee.firefox-addons; [
            vimium
            browserpass
            ublock-origin
            privacy-badger
            clearurls
            decentraleyes
            duckduckgo-privacy-essentials
            onepassword-password-manager
          ];
        } // common;
        home = {
          id = 1;
          name = "home";
          extensions = with pkgs.nur.repos.rycee.firefox-addons; [
            vimium
            browserpass
            ublock-origin
            privacy-badger
            clearurls
            decentraleyes
            duckduckgo-privacy-essentials
          ];
        } // common;
      };
  };

  # Can't be listed in packages list, as it will create two colliding binaries.
  programs.rofi = {
    enable = true;
    plugins = with pkgs; [ rofi-calc ];
    pass.enable = true;
  };

  # GPG
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry-qt;
  };

  # Lock screen
  services.xidlehook =
    let
      paths = [
        "$PATH"
        "${pkgs.xorg.xrandr}/bin"
        "${dotfilesDir}/scripts"
        "${pkgs.i3lock-color}/bin"
        "${pkgs.dunst}/bin"
        "${pkgs.bash}/bin"
        "${pkgs.gnugrep}/bin"
        "${pkgs.coreutils-full}/bin"
      ];
    in
    {
      enable = true;
      not-when-audio = true;
      detect-sleep = true;
      environment = {
        "PATH" = builtins.concatStringsSep ":" paths;
      };
      timers = [
        {
          delay = 300;
          command = "brightness set 50";
          canceller = "brightness set 100";
        }
        {
          delay = 10;
          command = "brightness set 100; locker";
        }
        {
          delay = 3600;
          command = "systemctl hibernate || systemctl suspend";
        }
      ];
    };

  # Notifications
  services.dunst.enable = true;

  # UI
  home.pointerCursor = {
    package = pkgs.nordzy-cursor-theme;
    name = "Nordzy-cursors";
    gtk.enable = true;
    x11.enable = true;
  };
  gtk = {
    enable = true;
    theme = {
      package = pkgs.nordic;
      name = "Nordic";
    };
    font = {
      package = pkgs.mononoki;
      name = "Mononoki";
    };
    iconTheme = {
      package = pkgs.nordzy-icon-theme;
      name = "Nordzy";
    };
  };
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "gtk2";
  };
}
