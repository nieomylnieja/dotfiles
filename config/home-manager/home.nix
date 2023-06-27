{ 
  config,
  pkgs,
  ... 
}: {
  home = {
    username = "mh";
    homeDirectory = "/home/mh";
    stateVersion = "23.05";

    packages = with pkgs; {
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
      fzf
      gh
      git
      gnupg
      httpie
      jq
      lesspipe
      luajitPackages.luarocks
      neofetch
      neovim
      man
      man-pages
      moreutils
      nitrogen
      pamixer
      pass
      pavucontrol
      picom
      ripgrep
      ripgrep-all
      rofi
      rofi-calc
      starship
      sops
      qtile
      zoxide
      xclip
      xautolock
      yarn
      yq
    };
  }; 

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  programs.home-manager.enable = true;
}
