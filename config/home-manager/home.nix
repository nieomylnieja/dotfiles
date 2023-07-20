{ 
  config,
  pkgs,
  ... 
}: {
  home = {
    username = "mh";
    homeDirectory = "/home/mh";
    stateVersion = "23.05";

    packages = with pkgs; [
      apg
      alacritty
      arandr
      bat
      bash-completion
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
      flatpak
      fnm
      fzf
      gcc_multi
      gh
      git
      glibcLocales
      gnupg
      go
      httpie
      jetbrains.goland
      jq
      lesspipe
      libsForQt5.qt5ct
      luajitPackages.luarocks
      neofetch
      neovim
      nodePackages.npm
      man
      man-pages
      mesa
      moreutils
      nitrogen
      (nerdfonts.override { fonts = ["Mononoki"]; })
      pamixer
      pass
      pavucontrol
      picom
      ripgrep
      ripgrep-all
      rofi
      rofi-calc
      flameshot
      sops
      starship
      statix
      qtile
      zoxide
      xautolock
      xclip
      xorg.libXrandr # Required by slock.
      xorg.xrandr
      xorg.xset
      yarn
      yq
    ];

    file = {
      ".bashrc".source = ../bash/bashrc;
      ".bash_logout".source = ../bash/bash_logout;
      ".xprofile".source = ../xorg/xprofile;
      ".xinitrc".source = ../xorg/xinitrc;
      ".profile".source = ../xorg/xinitrc;
      ".Xresources".source = ../xorg/Xresources;
      ".config/git/config".source = ../git/config;
      ".config/starship.toml".source = ../starship/starship.toml;
      ".config/rofi".source = ../rofi;
      ".config/lvim".source = ../lvim;
      ".config/dunst".source = ../dunst;
      ".config/alacritty".source = ../alacritty;
      ".config/picom".source = ../picom;
      ".config/flameshot/flameshot.ini".source = ../flameshot/flameshot.ini;
      ".config/ideavim".source = ../ideavim;
    };
  };

  xdg.configFile = {
    "qtile".source = ../qtile;
  };

  fonts.fontconfig.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  programs.home-manager.enable = true;

  programs.browserpass = {
    enable = true;
    browsers = ["brave"];
  };

  services.gpg-agent = {
    enable = true;
    pinentryFlavor = "gnome3";
  };
}
