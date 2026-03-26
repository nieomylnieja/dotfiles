{ config
, pkgs
, lib
, hyprdynamicmonitorsPkg
, googleworkspaceCliPkg
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
    googleworkspaceCliPkg
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
    # blesh TODO: try making it work better
    brightnessctl
    bun
    cachix
    cargo
    cliphist
    csvkit
    codex
    delta
    direnv
    # Discord wrapped to force XWayland for keybinding support (PTT, etc.)
    (pkgs.symlinkJoin {
      name = "discord";
      paths = [ pkgs.discord ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/discord \
          --set NIXOS_OZONE_WL ""
      '';
    })
    distrobox
    dust
    dunst
    eza
    fastfetch
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
    glow
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
    jc
    jq
    just
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
    markdownlint-cli
    markdown-link-check
    moreutils
    nemo-with-extensions
    nerd-fonts.mononoki
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
    python3
    pinentry-qt
    r2modman # for Valheim mods
    kubectl
    kubecolor
    kubefwd
    kubelogin-oidc
    ripgrep
    repomix
    # rpi-imager
    rustc
    kubernetes-helm
    signal-desktop
    (pkgs.symlinkJoin {
      name = "slack";
      paths = [ pkgs.slack ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/slack \
          --add-flags "--remote-debugging-port=9222"
      '';
    })
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
    installGlobalNpmPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run env PATH="${pkgs.nodejs}/bin:$PATH" ${pkgs.nodejs}/bin/npm install \
        --global --prefix ${homeDir}/.npm-global \
        --package-lock false \
        $(${pkgs.jq}/bin/jq -r '.dependencies | to_entries[] | "\(.key)@\(.value)"' \
          ${dotfilesDir}/config/npm/global-packages.json)
    '';

    createLinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run [ -d ${config.xdg.configHome}/nvim ] || ln -s $VERBOSE_ARG ${dotfilesDir}/config/nvim ${config.xdg.configHome}/nvim
      run [ -d ${config.xdg.configHome}/hypr ] || ln -s $VERBOSE_ARG ${dotfilesDir}/config/hypr ${config.xdg.configHome}/hypr
      run [ -d ${config.xdg.configHome}/waybar ] || ln -s $VERBOSE_ARG ${dotfilesDir}/config/waybar ${config.xdg.configHome}/waybar
      ln -s -f $VERBOSE_ARG ${dotfilesDir}/config/vscode/settings.json ${config.xdg.configHome}/Code/User/settings.json
      ln -s -f $VERBOSE_ARG ${dotfilesDir}/config/cspell/cspell.json ${config.xdg.configHome}/cspell/cspell.json
      ln -s -f -n $VERBOSE_ARG ${dotfilesDir}/config/agents ${homeDir}/.agents
      ln -s -f -n $VERBOSE_ARG ${dotfilesDir}/config/agents/skills ${homeDir}/.claude/skills
      ln -s -f -n $VERBOSE_ARG ${dotfilesDir}/config/agents/commands ${homeDir}/.claude/commands
      ln -s -f -n $VERBOSE_ARG ${dotfilesDir}/config/agents/agents ${homeDir}/.claude/agents
      ln -s -f -n $VERBOSE_ARG ${dotfilesDir}/config/agents/commands ${config.xdg.configHome}/opencode/commands
      ln -s -f -n $VERBOSE_ARG ${dotfilesDir}/config/agents/agents ${config.xdg.configHome}/opencode/agents
      run mkdir -p ${homeDir}/.claude/hooks
      for f in ${dotfilesDir}/config/claude/hooks/*; do
        ln -s -f $VERBOSE_ARG "$f" ${homeDir}/.claude/hooks/
      done
      run mkdir -p ${config.xdg.stateHome}/skills
      ln -s -f $VERBOSE_ARG ${dotfilesDir}/config/agents/.skill-lock.json ${config.xdg.stateHome}/skills/.skill-lock.json
    '';
  };

  home.file = {
    ".bash_logout".source = ../bash/bash_logout;
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    initExtra = builtins.readFile ../bash/bashrc;
  };

  xdg.desktopEntries.slack = {
    name = "Slack";
    exec = "slack --remote-debugging-port=9222 -s %U";
    icon = "slack";
    comment = "Slack Desktop";
    genericName = "Slack Client for Linux";
    categories = [ "Network" "InstantMessaging" ];
    mimeType = [ "x-scheme-handler/slack" ];
    startupNotify = true;
    settings = {
      StartupWMClass = "Slack";
    };
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
    "dunst".source = ../dunst;
    "flameshot/flameshot.ini".source = ../flameshot/flameshot.ini;
    "glow".source = ../glow;
    "blesh/init.sh".source = ../blesh/blerc;
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
    GOLAND_VM_OPTIONS = "${dotfilesDir}/config/jetbrains/idea.vmoptions";
    GOPATH = "${homeDir}/go";
    STARSHIP_LOG = "error";
    SKILLS_AGENTS = "opencode"; # claude-code is already linked, so no need to install it
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
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxkbfile
      libxshmfence
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

  programs.mcp = {
    enable = true;
    servers = (builtins.fromJSON (builtins.readFile ../agents/mcp.json)).mcpServers;
  };

  # Claude Code - settings and CLAUDE.md via HM module (stable config)
  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
    settings = (builtins.fromJSON (builtins.readFile ../claude/settings.json));
    memory.source = ../agents/AGENTS.md;
  };

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    rules = ../agents/AGENTS.md;
  };

  programs.go = {
    enable = true;
    env.GOPROXY = "https://proxy.golang.org,direct";
  };

  programs.gemini-cli = {
    enable = true;
    settings = (builtins.fromJSON (builtins.readFile ../gemini/settings.json));
  };

  # Notifications
  services.dunst = {
    enable = true;
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
