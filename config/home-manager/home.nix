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
      gnupg
      go
      httpie
      jq
      lesspipe
      luajitPackages.luarocks
      neofetch
      neovim
      nodePackages.npm
      man
      man-pages
      mesa
      moreutils
      nitrogen
      pamixer
      pass
      pavucontrol
      picom
      pinentry-rofi
      ripgrep
      ripgrep-all
      rofi
      rofi-calc
      sops
      starship
      statix
      qtile
      zoxide
      xautolock
      xclip
      xorg.xrandr
      xorg.xset
      yarn
      yq
    ];
  }; 

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  programs.home-manager.enable = true;
}
