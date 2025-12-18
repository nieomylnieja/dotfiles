{ config
, pkgs
, lib
, ...
}:
let
  homeDir = "/home/mh";
  dotfilesDir = "${homeDir}/.dotfiles";
  gdk = pkgs.stable.google-cloud-sdk.withExtraComponents (with pkgs.stable.google-cloud-sdk.components; [
    gke-gcloud-auth-plugin
  ]);
in
{
  programs.home-manager.enable = true;

  home = {
    username = "mh";
    homeDirectory = homeDir;
    stateVersion = "24.11";
  };

  home.packages = with pkgs; [
    aider-chat
    anki
    awscli2
    apg
    alacritty
    alejandra
    ansible
    arandr
    bat
    bash-completion
    bashmount
    bazecor
    bottom
    cachix
    cargo
    csvkit
    delta
    direnv
    discord
    distrobox
    dust
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
    go
    gotestsum
    simple-scan
    simplescreenrecorder
    sushi
    gimp
    gnumake
    gnupg
    gdk
    httpie
    i3lock-color
    pkgs.stable.inkscape-with-extensions
    jetbrains.goland
    jetbrains.idea-community
    jetbrains.jdk # JDK for plugin development.
    jq
    krita
    lesspipe
    libsForQt5.qt5ct
    libnotify # For notify-send.
    libreoffice
    luajitPackages.luarocks
    lutris
    man
    man-pages
    mesa
    mirrord
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
    peek
    pulseaudio # For pactl.
    pdm
    picom
    pinentry-qt
    kubectl
    kubecolor
    ripgrep
    rofi-power-menu
    # rpi-imager
    rustc
    kubernetes-helm
    feh
    flameshot
    signal-desktop
    slack
    sops
    spotify
    starship
    statix
    terraform
    tree
    # Required for new verison of nvim-treesitter to work.
    tree-sitter
    unzip
    uv
    zathura
    zoxide
    zip
    xclip
    xorg.xrandr
    xorg.xset
    yarn
    yubikey-manager
    yq
    vlc
    vivaldi
    pkgs.stable.zoom-us
  ];

  # Neovim has to be linked as the directory has to be writable.
  home.activation = {
    createLinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run [ -d ${config.xdg.configHome}/nvim ] || ln -s $VERBOSE_ARG ${dotfilesDir}/config/nvim ${config.xdg.configHome}/nvim
      ln -s -f $VERBOSE_ARG ${dotfilesDir}/config/vscode/settings.json ${config.xdg.configHome}/Code/User/settings.json
      ln -s -f $VERBOSE_ARG ${dotfilesDir}/config/cspell/cspell.json ${config.xdg.configHome}/cspell/cspell.json
    '';
  };

  home.file = {
    ".bashrc".source = ../bash/bashrc;
    ".bash_logout".source = ../bash/bash_logout;
    ".xprofile".source = ../xorg/xprofile;
    ".xinitrc".source = ../xorg/xinitrc;
    ".profile".source = ../xorg/xinitrc;
    ".claude/CLAUDE.md".source = ../claude/CLAUDE.md;
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
    "feh".source = ../feh;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = [ "zathura.desktop" ];
      "text/html" = "vivaldi-stable.desktop";
      "x-scheme-handler/http" = "vivaldi-stable.desktop";
      "x-scheme-handler/https" = "vivaldi-stable.desktop";
      "x-scheme-handler/about" = "vivaldi-stable.desktop";
      "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
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

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhsWithPackages (ps: with ps; [
      # Essentially everything Electron needs to run.
      # This is necessary for Extension Test Runner to spawn a test VS Code instance.
      alsa-lib
      at-spi2-atk
      cairo
      cups
      dbus
      distrobox
      expat
      gdk-pixbuf
      glib
      gtk3
      gtk4
      nss
      nspr
      xorg.libX11
      xorg.libxcb
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxkbfile
      xorg.libxshmfence
      pango
      pciutils
      stdenv.cc.cc
      systemd
      libnotify
      pipewire
      libsecret
      libpulseaudio
      speechd-minimal
      libdrm
      mesa
      libxkbcommon
      libGL
      vulkan-loader
      openssl
    ]);
  };

  programs.poetry = {
    enable = true;
    package = pkgs.poetry.withPlugins (ps: with ps; [ poetry-plugin-shell ]);
    settings = {
      virtualenvs.create = true;
      virtualenvs.in-project = true;
    };
  };

  # Can't be listed in packages list, as it will create two colliding binaries.
  programs.rofi = {
    enable = true;
    plugins = with pkgs; [ rofi-calc ];
    pass.enable = true;
  };

  # Easily find linked libraries.
  programs.nix-index = {
    enable = true;
    enableBashIntegration = true;
  };

  # GPG
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentry = {
      package = pkgs.pinentry-qt;
    };
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

  # Claude code
  programs.claude-code = {
    enable = true;
    settings = (builtins.fromJSON (builtins.readFile ../claude/settings.json));
    mcpServers = (builtins.fromJSON (builtins.readFile ../claude/mcp.json)).mcpServers;
    skills = {
      "golang" = ../claude/skills/golang;
    };
  };

  # Notifications
  services.dunst.enable = true;

  # LLMs
  services.ollama = {
    enable = true;
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
    platformTheme.name = "gtk";
    style.name = "gtk2";
  };
}
