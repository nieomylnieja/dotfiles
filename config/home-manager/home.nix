{ config
, pkgs
, lib
, googleworkspaceCliPkg
, ...
}:
let
  homeDir = "/home/mh";
  dotfilesDir = "${homeDir}/.dotfiles";
  gdk = pkgs.stable.google-cloud-sdk.withExtraComponents (with pkgs.stable.google-cloud-sdk.components; [
    gke-gcloud-auth-plugin
  ]);
  sessionVariables = {
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
    SKILLS_AGENTS = "opencode";
    OPENCODE_TUI_CONFIG = "${dotfilesDir}/config/opencode/tui.json";
  };
  rpiImagerRootLauncher = pkgs.writeShellScriptBin "rpi-imager-wayland" ''
    set -euo pipefail

    original_uid="''${PKEXEC_UID:-1000}"
    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$original_uid}"
    export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
    export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
    export QT_QPA_PLATFORM=wayland
    unset DISPLAY
    ulimit -c 0

    ${pkgs.rpi-imager}/bin/rpi-imager "$@"
  '';
  rpiImagerLauncher = pkgs.writeShellScriptBin "rpi-imager-pkexec" ''
    set -euo pipefail

    /run/wrappers/bin/pkexec --disable-internal-agent ${rpiImagerRootLauncher}/bin/rpi-imager-wayland "$@"
  '';
in
{
  programs.home-manager.enable = true;

  home = {
    username = "mh";
    homeDirectory = homeDir;
    stateVersion = "24.11";
    inherit sessionVariables;
  };

  home.packages = with pkgs; [
    googleworkspaceCliPkg
    anki
    alacritty
    (pkgs.symlinkJoin {
      name = "agent-browser";
      paths = [ pkgs.agent-browser ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/agent-browser \
          --set-default AGENT_BROWSER_SKILLS_DIR "${pkgs.agent-browser}/share/agent-browser/skills" \
          --set-default AGENT_BROWSER_EXECUTABLE_PATH "${pkgs.chromium}/bin/chromium"
      '';
    })
    awscli2
    apg
    alejandra
    ansible
    bat
    bash-completion
    bashmount
    bottom
    # blesh TODO: try making it work better
    brightnessctl
    bubblewrap # sandboxing for codex
    bun
    cachix
    cargo
    cliphist
    csvkit
    codex-acp
    ddcutil
    delta
    diffnav
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
    flatpak
    fnm
    fzf
    gcc_multi
    gh
    gh-dash
    gh-enhance
    git
    glibcLocales
    glow
    gotestsum
    gopls
    grim
    satty
    simple-scan
    kooha
    sushi
    gimp
    gnumake
    gnupg
    gdk
    httpie
    hyprdynamicmonitors
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
    lua
    luajitPackages.luarocks
    ltspice
    pkgs.stable.lutris
    man
    man-pages
    manim
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
    playerctl
    pulseaudio # For pactl.
    pkgs.stable.pdm
    (python3.withPackages (ps: [ ps.pillow ]))
    pinentry-qt
    proton-vpn
    r2modman # for Valheim mods
    kubectl
    kubecolor
    kubefwd
    kubelogin-oidc
    ripgrep
    repomix
    rpi-imager
    rpiImagerLauncher
    rustc
    kubernetes-helm
    shfmt
    shellcheck
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
    slurp
    spotify
    starship
    ssm-session-manager-plugin # for awscli2
    swayimg
    statix
    terraform
    tree
    # Required for new verison of nvim-treesitter to work.
    tree-sitter
    unzip
    uv
    waybar
    wezterm
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
      ln -s -f -n $VERBOSE_ARG ${dotfilesDir}/config/agents/commands ${config.xdg.configHome}/opencode/commands
      run mkdir -p ${config.xdg.configHome}/opencode
      for f in ${dotfilesDir}/config/opencode/*; do
        case "$(basename "$f")" in
          opencode.json|node_modules|.devbox|.envrc|devbox.json|devbox.lock|bun.lock|package.json|tsconfig.json) continue ;;
        esac
        ln -s -f -n $VERBOSE_ARG "$f" ${config.xdg.configHome}/opencode/
      done
      run mkdir -p ${homeDir}/.claude/hooks
      for f in ${dotfilesDir}/config/claude/hooks/*; do
        ln -s -f $VERBOSE_ARG "$f" ${homeDir}/.claude/hooks/
      done
      run mkdir -p ${config.xdg.stateHome}/skills
      ln -s -f $VERBOSE_ARG ${dotfilesDir}/config/agents/.skill-lock.json ${config.xdg.stateHome}/skills/.skill-lock.json
      ln -s -f $VERBOSE_ARG ${dotfilesDir}/config/wezterm/wezterm.lua ${config.xdg.configHome}/wezterm/wezterm.lua
      run mkdir -p ${config.xdg.stateHome}/hyprdynamicmonitors
      run [ -e ${config.xdg.stateHome}/hyprdynamicmonitors/monitors.conf ] || ${pkgs.coreutils}/bin/install -m 0644 ${dotfilesDir}/config/hyprdynamicmonitors/hyprconfigs/laptop-only.conf ${config.xdg.stateHome}/hyprdynamicmonitors/monitors.conf
    '';
    syncCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${homeDir}/.codex
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

  programs.prismlauncher = {
    enable = true;
  };

  programs.cursor = {
    enable = true;
    argvSettings = {
      password-store = "gnome-libsecret";
    };
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

  xdg.desktopEntries."com.raspberrypi.rpi-imager" = {
    name = "Raspberry Pi Imager";
    exec = "${rpiImagerLauncher}/bin/rpi-imager-pkexec";
    icon = "${pkgs.rpi-imager}/share/icons/hicolor/scalable/apps/rpi-imager.svg";
    comment = "Tool for writing images to SD cards for Raspberry Pi";
    categories = [ "Utility" ];
    mimeType = [
      "x-scheme-handler/rpi-imager"
      "application/vnd.raspberrypi.imager-manifest+json"
    ];
    startupNotify = false;
  };

  xdg.configFile = {
    "git/config".source = ../git/config;
    "starship.toml".source = ../starship/starship.toml;
    "rofi".source = ../rofi;
    # "wezterm".source = ../wezterm;
    "alacritty".source = ../alacritty;
    "ideavim".source = ../ideavim;
    "direnv/direnvrc".source = ../direnv/direnvrc;
    "zathura".source = ../zathura;
    "swayimg".source = ../swayimg;
    "dunst".source = ../dunst;
    "satty".source = ../satty;
    "hyprdynamicmonitors/config.toml".source = ../hyprdynamicmonitors/config.toml;
    "hyprdynamicmonitors/hyprconfigs/external-only.conf.tmpl".source = ../hyprdynamicmonitors/hyprconfigs/external-only.conf.tmpl;
    "hyprdynamicmonitors/hyprconfigs/laptop-only.conf".source = ../hyprdynamicmonitors/hyprconfigs/laptop-only.conf;
    "glow".source = ../glow;
    "blesh/init.sh".source = ../blesh/blerc;
    # "gh-dash/config.yml".source = ../gh-dash/config.yml;
  };

  xdg.mimeApps =
    let
      imageTypes = [ "png" "jpeg" "gif" "webp" "bmp" "svg+xml" "tiff" ];
      imageAssociations = builtins.listToAttrs (map
        (t: {
          name = "image/${t}";
          value = [ "swayimg.desktop" ];
        })
        imageTypes);
    in
    {
      enable = true;
      defaultApplications =
        {
          "application/pdf" = [ "org.pwmt.zathura.desktop" ];
          "text/html" = "vivaldi-stable.desktop";
          "x-scheme-handler/http" = "vivaldi-stable.desktop";
          "x-scheme-handler/https" = "vivaldi-stable.desktop";
          "x-scheme-handler/about" = "vivaldi-stable.desktop";
          "x-scheme-handler/unknown" = "vivaldi-stable.desktop";
          "x-scheme-handler/prismlauncher" = [
            "org.prismlauncher.PrismLauncher.desktop"
            "prismlauncher.desktop"
          ];
        }
        // imageAssociations;
    };

  # User session variables for login shells and systemd/UWSM-launched programs.
  # PATH is set in hyprland.conf instead.
  systemd.user.sessionVariables = sessionVariables;

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit = {
      Description = "Polkit GNOME authentication agent";
    };

    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "XDG_CURRENT_DESKTOP=Hyprland"
        "XDG_RUNTIME_DIR=%t"
        "XDG_SESSION_TYPE=wayland"
        "WAYLAND_DISPLAY=wayland-1"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services."hyprdynamicmonitors-prepare" = {
    Unit = {
      Description = "HyprDynamicMonitors boot-time cleanup";
      Before = [ "graphical-session-pre.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/.local/state/hyprdynamicmonitors";
      ExecStart = "${pkgs.hyprdynamicmonitors}/bin/hyprdynamicmonitors prepare";
      TimeoutStartSec = 3;
      RemainAfterExit = true;
    };

    Install.WantedBy = [ "default.target" "graphical-session-pre.target" ];
  };

  systemd.user.services.hyprdynamicmonitors = {
    Unit = {
      Description = "HyprDynamicMonitors";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStartPre = "${pkgs.hyprdynamicmonitors}/bin/hyprdynamicmonitors prepare";
      ExecStart = "${pkgs.hyprdynamicmonitors}/bin/hyprdynamicmonitors run --disable-power-events";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = "PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.hyprland pkgs.systemd ]}";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar status bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "always";
      RestartSec = 2;
      Environment = [
        "PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.gawk pkgs.jq pkgs.procps ]}"
        "XDG_DATA_DIRS=${pkgs.hicolor-icon-theme}/share:${homeDir}/.nix-profile/share:/etc/profiles/per-user/mh/share:/run/current-system/sw/share"
      ];
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  fonts.fontconfig.enable = true;

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhsWithPackages (ps:
      with ps; [
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
      package = pkgs.pinentry-curses;
    };
  };

  services.gnome-keyring.enable = true;

  programs.mcp = {
    enable = true;
    servers = (builtins.fromJSON (builtins.readFile ../agents/mcp.json)).mcpServers;
  };

  # Claude Code - settings and CLAUDE.md via HM module (stable config)
  programs.claude-code = {
    enable = true;
    enableMcpIntegration = true;
    settings = builtins.fromJSON (builtins.readFile ../claude/settings.json);
    context = ../agents/AGENTS.md;
  };

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    settings = builtins.fromJSON (builtins.readFile ../opencode/opencode.json);
    context = ../agents/AGENTS.md;
  };

  programs.codex = {
    enable = true;
    context = builtins.readFile ../agents/AGENTS.md;
  };

  programs.go = {
    enable = true;
    env.GOPROXY = "https://proxy.golang.org,direct";
  };

  # Notifications
  services.dunst = {
    enable = true;
  };

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
    gtk4.theme = config.gtk.theme;
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
    platformTheme.name = "gtk3";
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
