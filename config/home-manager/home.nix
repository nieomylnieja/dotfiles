{ config
, pkgs
, lib
, hyprdynamicmonitorsPkg
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
    hyprdynamicmonitorsPkg
    aider-chat
    anki
    awscli2
    apg
    alacritty
    alejandra
    ansible
    bat
    bash-completion
    bashmount
    bottom
    blesh
    brightnessctl
    cachix
    cargo
    cliphist
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
    flameshot
    flatpak
    fnm
    fzf
    gcc_multi
    gh
    git
    glibcLocales
    go
    gotestsum
    grim # Required by flameshot to work on wayland.
    simple-scan
    simplescreenrecorder
    sushi
    gimp
    gnumake
    gnupg
    gdk
    httpie
    hypridle
    hyprlock
    hyprpaper
    pkgs.stable.inkscape-with-extensions
    jetbrains.goland
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
    nushell
    obsidian
    ocaml
    opam
    openssl
    pamixer
    pass
    pavucontrol
    peek
    playerctl
    pulseaudio # For pactl.
    pdm
    pinentry-qt
    kubectl
    kubecolor
    kubefwd
    ripgrep
    # rpi-imager
    rustc
    kubernetes-helm
    signal-desktop
    slack
    sops
    spotify
    starship
    swayimg
    statix
    terraform
    tidal-hifi
    tree
    # Required for new verison of nvim-treesitter to work.
    tree-sitter
    unzip
    uv
    waybar
    wl-clipboard
    wlr-randr
    zathura
    zoxide
    zip
    yarn
    yubikey-manager
    yq
    vlc
    vivaldi
    pkgs.stable.zoom-us
  ];

  # Directories that need to be writable are symlinked instead of copied.
  home.activation = {
    createLinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run [ -d ${config.xdg.configHome}/nvim ] || ln -s $VERBOSE_ARG ${dotfilesDir}/config/nvim ${config.xdg.configHome}/nvim
      run [ -d ${config.xdg.configHome}/hypr ] || ln -s $VERBOSE_ARG ${dotfilesDir}/config/hypr ${config.xdg.configHome}/hypr
      run [ -d ${config.xdg.configHome}/waybar ] || ln -s $VERBOSE_ARG ${dotfilesDir}/config/waybar ${config.xdg.configHome}/waybar
      ln -s -f $VERBOSE_ARG ${dotfilesDir}/config/vscode/settings.json ${config.xdg.configHome}/Code/User/settings.json
      ln -s -f $VERBOSE_ARG ${dotfilesDir}/config/cspell/cspell.json ${config.xdg.configHome}/cspell/cspell.json
    '';
  };

  home.file = {
    ".bash_logout".source = ../bash/bash_logout;
    ".claude/CLAUDE.md".source = ../claude/CLAUDE.md;
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    initExtra = builtins.readFile ../bash/bashrc;
  };

  xdg.configFile = {
    "git/config".source = ../git/config;
    "starship.toml".source = ../starship/starship.toml;
    "rofi".source = ../rofi;
    "alacritty".source = ../alacritty;
    "ideavim".source = ../ideavim;
    "direnv/direnvrc".source = ../direnv/direnvrc;
    "zathura".source = ../zathura;
    "swayimg".source = ../swayimg;
    "flameshot/flameshot.ini".source = ../flameshot/flameshot.ini;
  };

  xdg.mimeApps =
    let
      imageTypes = [ "png" "jpeg" "gif" "webp" "bmp" "svg+xml" "tiff" ];
      imageAssociations = builtins.listToAttrs (map (t: { name = "image/${t}"; value = [ "swayimg.desktop" ]; }) imageTypes);
    in
    {
      enable = true;
      defaultApplications = {
        "application/pdf" = [ "org.pwmt.zathura.desktop" ];
        "text/html" = "vivaldi-stable.desktop";
        "x-scheme-handler/http" = "vivaldi-stable.desktop";
        "x-scheme-handler/https" = "vivaldi-stable.desktop";
        "x-scheme-handler/about" = "vivaldi-stable.desktop";
        "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
      } // imageAssociations;
    };

  # User session variables (inherited by Hyprland and all launched programs)
  # PATH is set in hyprland.conf instead
  systemd.user.sessionVariables = {
    DOTFILES = "${dotfilesDir}";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    GDK_BACKEND = "wayland";
    QT_QPA_PLATFORM = "wayland";
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    BROWSER = "vivaldi";
    EDITOR = "nvim";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

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
  services.dunst = {
    enable = true;
    configFile = ../dunst/dunstrc;
  };

  # Monitor management - use symlink so TUI changes persist
  home.hyprdynamicmonitors = {
    enable = true;
    extraFlags = [ "--disable-power-events" ];
    installExamples = false;
    configPath = "${dotfilesDir}/config/hyprdynamicmonitors/config.toml";
  };
  # Symlink entire config dir so TUI finds themes and configs
  xdg.configFile."hyprdynamicmonitors".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/config/hyprdynamicmonitors";

  # LLMs
  services.ollama = {
    enable = true;
  };

  # UI
  home.pointerCursor = {
    package = pkgs.nordzy-cursor-theme;
    name = "Nordzy-cursors";
    gtk.enable = true;
    hyprcursor.enable = true;
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

  # Dark mode preference for Electron apps
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Nordic";
    };
  };
}
