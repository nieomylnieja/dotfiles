1. Linking configs

```shell
ln -sf profile ~/.profile
ln -sf bashrc ~/.bashrc
ln -sf bash_logout ~/.bash_logout
ln -sf xprofile ~/.xprofile
mkdir -p ~/.config/alacritty && ln -sf alacritty.yml ~/.config/alacritty/alacritty.yml
ln -sf starship.toml ~/.config/starship.toml
ln -sf tmux.confg ~/.tmux.conf
ln -sf vimrc ~/.vimrc
ln -sf gitconfig ~/.gitconfig
mkdir -p ~/.config/xmobar && ln -sf xmobar.conf ~/.config/xmobar/xmobar.config
ln -sf vim ~/.vim
git config --global core.excludesfile ~/.dotfiles/gitignore_global
ln -sf qtile/qtile.desktop 
```

1. Install `nvm`

```shell
ln -s "$DOTFILES/nord_dircolors/src/dir_colors" "~/.dir_colors"
```

1. Vim

Make sure It has the right options, you might need to install `vim-athena` or `vim-gnome` to enable clipboard support
For `coc` to work at all you'll have to install a recent nodejs version. I prefer using `nvm` for managing those with ease.

```shell
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash && nvm install node
```

```shell
cd vim/pack/plugins/opt/coc && yarn install && cd -
```


1. Tmux

Link the `tmux.conf` and then install `tpm` (tmux plugin manager)

```shell
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

[Tmux urlview](https://github.com/tmux-plugins/tmux-urlview) requires [urlview](https://github.com/sigpipe/urlview)

```shell
sudo apt install urlview
```

1. [Alacirtty](https://github.com/alacritty/alacritty/blob/master/INSTALL.md)

Best installed manually, at least for ubuntu...

1. [Install Rust](https://doc.rust-lang.org/cargo/getting-started/installation.html), this will also install `cargo`!

```shell
curl https://sh.rustup.rs -sSf | shell
```

1. Those fany Rust based speedos-torpedos:

- [dust](https://github.com/bootandy/dust) -- replaces `du`

```shell
cargo install du-dust
```

- [ripgrep](https://github.com/BurntSushi/ripgrep) -- replaces `grep`

```shell
cargo install ripgrep
```

- [fdfind](https://github.com/sharkdp/fd) -- replaces `find`

```shell
cargo install fd-find
```

- [exa](https://github.com/ogham/exa) -- replaces `ls`

```shell
cargo install exa
```

- [bottom](https://github.com/ClementTsang/bottom) -- replaces `htop`

```shell
cargo install --git https://github.com/ClementTsang/bottom
```

- [bat](https://github.com/sharkdp/bat) -- replaces `cat` (sort of)

```shell
cargo install bat
```

- [delta](https://github.com/dandavison/delta) -- a neat viewer for diff output

```shell
cargo install git-delta
```

1. Other core programs utilized in my srcripts and aliases

- [ag](https://github.com/ggreer/the_silver_searcher)

```shell
sudo apt-get install silversearcher-ag
```

- [jq](https://stedolan.github.io/jq/download/)

- [yq](https://github.com/kislyuk/yq)

```shell
pip3 install yq
```

1. For managing notes use [Joplina](https://joplinapp.org/)

1. [pfetch](https://github.com/dylanaraps/pfetch) -- which is added as submodule to this repo will display nice system info on each shell session start

```shell
cd pfetch/ || exit && sudo make install && cd -
```

1. Python related stuff

- [pyenv](https://github.com/pyenv/pyenv)

```shell
curl https://pyenv.run | bashell
```

After that you might need some more stuff to get the newest python to work...

```shell
sudo apt-get install -y make build-essential libssl-dev zlib1g-dev libbz2-dev \
libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
xz-utils tk-dev libffi-dev liblzma-dev python-openssl git
```

- [pipenv](https://pipenv.pypa.io/en/latest/)

```shell
pip install pipenv
```

1. Gnome good look

- gnome-tweaks

```shell
sudo apt install gnome-tweaks
```

- [nord theme](https://github.com/EliverLara/Nordic)
- remove the ubuntu dock

```shell
sudo apt remove gnome-shell-extension-ubuntu-dock
```

- [zafiro icons](https://www.opendesktop.org/s/Gnome/p/1209330/)

1. [Haskell](https://docs.haskellstack.org/en/stable/install_and_upgrade/)

```shell
curl -sSL https://get.haskellstack.org/ | shell
```

1. Xmonad

```shell
sudo apt install xmonad libghc-xmonad-contrib-dev dmenu xmobar
```

1. [Unix standard pass manager](https://www.passwordstore.org/)

1. Brave browser

- [browserpass native](https://github.com/browserpass/browserpass-native)
- [browserpass extension](https://github.com/browserpass/browserpass-extension)

1. [Golang](https://golang.org/doc/install)

1. [Docker](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-20-04)

1. Qtile Window Manager

Installation steps for X11:

```shell
pip install xcffib
pip install cairocffi
pip install qtile
pip install dbus-next
```

1. Spotify

Do not install `spotify` from snap, as It cannot be modified!
[Spicetify](https://github.com/khanhas/spicetify-cli) for nice looks! -- follow the instructions listed on the wiki pages.

```shell
cp clones/spicetify-themes/Dribbblish/dribbblish.js "$(dirname "$(spicetify -c)")/Extensions
cp clones/spicetify-themes/Dribbblish "$(dirname "$(spicetify -c)")/Themes/Dribbblish
spicetify config extensions dribbblish.js
spicetify config current_theme Dribbblish color_scheme nord-dark
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1
spicetify apply
```

1. Httpie

An awesome curl simplification for testing and what not.
See the [docs](https://httpie.io/docs#installation) for the installation.

```shell
python -m pip install --upgrade pip wheel
python -m pip install httpie
```

1. [Unix utils](https://joeyh.name/code/moreutils/)

```
sudo apt install moreutils
```
