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
