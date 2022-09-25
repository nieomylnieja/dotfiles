# Prerequisites

We're gonna go with `yay` to help out with pacman, here's how to install it:
 
```sh
pacman -S --needed git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
rm -rf yay
```

As a side effect we'll get newest go version here.

If we want to setup wifi connection (make sure NetworkManager is installed):

```sh
sudo nmcli dev wifi --ask connect {SSID}
```

# Setting stuff up

1. First thing is getting our browser:

```sh
yay -S brave-bin
```

2. We need to get all of our passwords from wherever we're storing them.

Currently its Icedrvie, so we should grab the AppImage from their site. The AppIamge format requires FUSE, so make sure It's there:

```sh
yay -S fuse
```

We might need to decompress some of that stuff, if we're using ZIP files install:

```sh
yay -S zip unzip
```

3. Next we need to get our password store setup:

Import the private key the passwords are encrypted with:

```sh
gpg --import {path_to_key}
```

Install pass:

```sh
yay -S pass
```

Initialize pass with the imported key id (when you do `gpg --list-keys` it's the `uid`):

```sh
pass init {uid}
```

Next we've got to setup pass for our browser, for chromium it's called `browserpass` and it consists of a [messaging native host](https://github.com/browserpass/browserpass-native) and [browser extension](https://github.com/browserpass/browserpass-extension):

```sh
yay -S browserpass browserpass-chromium
```

After that, follow the installation guide for the extension (jus add the extension, that's all).

Final step to make it work is make sure we have the right `pinentry` GUI program configured for our `gpg-agent`, add the below line to `~/.gnupg/gpg-agent.conf`:

```txt
pinentry-program /usr/bin/pinentry-gnome3
```

Next make sure you provided `ssh-agent` with your keys, otherwsie recursive git submodules init won't work. Generate new ones or use existing:

```sh
ssh-keygen -t rsa -b 4096 -C {email_here}
```

4. It's time to get our .dotfiles

```sh
git clone https://github.com/nieomylnieja/dotfiles.git .dotfiles
```

5. Install the tooling:

- general:

```sh
yay -S neovim nvim-packer-git rofi rofi-calc pamixer pavucontrol nitrogen arandr flameshot nerd-fonts-mononoki nnn dunst cronie qt5c5 lxappearance-gtk3
python -m ensurepip --upgrade --default-pip
pip install --upgrade pip
pip install psutil iwlib
```

- shell:

```sh
yay -S dust starship ripgrep bat zoxide fzf moreutils exa xclip lesspipe git-delta fd bash-completion man-db man-pages nvm yarn bottom jq yq xautolock sops pacman-contrib httpie cht.sh-git apg luarocks github-cli lnav
go install github.com/josephburnett/jd@latest
```

After that we'll use nvm to get `node` and `npm` (make sure it is sourced correctly by now):

```sh
nvm install --lts
```

6. Initialize submodules:

```sh
git submodule update --init --recursive --remote
```

7. Start linking (follow Makefile)

8. Optional

    To get YubiKey working you have to install `ykman`:

    ```sh
    yay -S swig pcsclite
    pip install yubikey-manager
    ```

9. Go NeoVim setup

`go.nvim` is based on treesitter, native nvim-lsp and dap debugger (rather than
delve).

## Awesome programs

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) which is a fork of `youtube-dl`
  along with an UI like [this](https://github.com/jely2002/youtube-dl-gui),
  I use it so rarely I can't ever memorize how to get the metadata first and
  then use it to download the version I want, this UI just makes it easy.

- GIMP for raster graphics editing -- Inkscape for vectors :)

- vlc for video playback

- 
