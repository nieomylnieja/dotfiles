{ 
  config,
  pkgs,
  ... 
}: {
  home = {
    username = "mh";
    homeDirectory = "/home/mh";
    stateVersion = "23.05";
  };

  home.packages = with pkgs; [
    apg
    alacritty
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
    (nerdfonts.override { fonts = ["Mononoki"]; })
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
    feh
    flameshot
    sops
    starship
    statix
    tabnine
    unzip
    qtile
    zoxide
    xautolock
    xclip
    xorg.xrandr
    xorg.xset
    yarn
    yq
  ];

  home.file = {
    ".bashrc".source = ../bash/bashrc;
    ".bash_logout".source = ../bash/bash_logout;
    ".xprofile".source = ../xorg/xprofile;
    ".xinitrc".source = ../xorg/xinitrc;
    ".profile".source = ../xorg/xinitrc;
    ".Xresources".source = ../xorg/Xresources;
  };

  xdg.configFile = {
    "qtile".source = ../qtile;
    "git/config".source = ../git/config;
    "starship.toml".source = ../starship/starship.toml;
    "rofi".source = ../rofi;
    "lvim".source = ../lvim;
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

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  programs.home-manager.enable = true;

  programs.browserpass = {
    enable = true;
    browsers = ["brave" "firefox"];
  };

  # Can't be listed in packages list, as it will create two colliding binaries.
  programs.rofi = {
    enable = true;
    plugins = with pkgs; [
      rofi-calc
      rofi-power-menu
      rofi-bluetooth
    ];
    pass.enable = true;
  };

  services.gpg-agent = {
    enable = true;
    pinentryFlavor = "gnome3";
  };
}
