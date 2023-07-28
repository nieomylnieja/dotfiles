{
  config,
  pkgs,
  ...
}: {
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  home = {
    username = "mh";
    homeDirectory = "/home/mh";
    stateVersion = "23.05";
  };

  home.packages = with pkgs; [
    apg
    alacritty
    alejandra
    arandr
    bat
    bash-completion
    bashmount
    bottom
    browserpass
    brave
    cachix
    delta
    docker
    docker-compose
    du-dust
    dunst
    exa
    fd
    file
    flatpak
    fnm
    fzf
    gcc_multi
    gh
    git
    glibcLocales
    gnumake
    gnupg
    go
    httpie
    i3lock-color
    jetbrains.goland
    jq
    lesspipe
    libsForQt5.qt5ct
    luajitPackages.luarocks
    man
    man-pages
    mesa
    moreutils
    cinnamon.nemo-with-extensions
    (nerdfonts.override {fonts = ["Mononoki"];})
    neofetch
    neovim
    nodejs
    nodePackages.npm
    pamixer
    pass
    pavucontrol
    picom
    ripgrep
    ripgrep-all
    rofi-power-menu
    feh
    flameshot
    sops
    starship
    statix
    unzip
    qtile
    zoxide
    xautolock
    xclip
    xorg.xrandr
    xorg.xset
    yarn
    yubikey-manager
    yq
  ];

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
  };

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;

  programs.browserpass = {
    enable = true;
    browsers = ["brave" "firefox"];
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
    profiles = {
      main = {
        id = 0;
        name = "mateusz";
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
        extensions = with pkgs.nur.repos.rycee.firefox-addons; [
          vimium
          browserpass
          ublock-origin
          privacy-badger
          clearurls
          decentraleyes
          duckduckgo-privacy-essentials
          darkreader
        ];
      };
    };
  };

  # Can't be listed in packages list, as it will create two colliding binaries.
  programs.rofi = {
    enable = true;
    plugins = with pkgs; [rofi-calc];
    pass.enable = true;
  };

  # GPG
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentryFlavor = "gtk2";
  };

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
    platformTheme = "gtk";
    style.name = "gtk2";
  };
}
