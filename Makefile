submodule:
	git submodule update --init --recursive

update:
	nix flake update --commit-lock-file

rebuild:
	sudo nixos-rebuild switch --flake .#mh

install/nix:
	sh <(curl -L https://nixos.org/nix/install) --no-daemon && . ~/.nix-profile/etc/profile.d/nix.sh

install/home-manager:
	nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.11.tar.gz home-manager
	nix-channel --update
	nix-shell '<home-manager>' -A install
	home-manager switch --flake ~/.dotfiles/config/home-manager#mh

# There's no easy way to run alacritty right now while it's installed by nixpkgs.
install/nixgl:
	nix-channel --add https://github.com/guibou/nixGL/archive/main.tar.gz nixgl && nix-channel --update
	nix-env -iA nixgl.auto.nixGLDefault

setup/flatpak:
	flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

setup/gtk:
	gsettings set org.gnome.desktop.interface gtk-theme "Nordic"
	gsettings set org.gnome.desktop.wm.preferences theme "Nordic"

install/node:
	fnm install --latest

install/rust:
	# I don't know yet how to make it auto add the bins to the path though...
	# So for now just use rust-anaylzer from arch repo.
	rustup toolchain install nightly \
		--allow-downgrade \
		--profile minimal \
		--component clippy,rust-analyzer-preview
	rustup default nightly

install/lvim:
	LV_BRANCH='release-1.3/neovim-0.9' \
	  bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)

update-modules:
	git submodule update --remote --recursive
