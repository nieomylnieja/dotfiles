install/nix:
	sh <(curl -L https://nixos.org/nix/install) --daemon

install/home-manager:
	nix-channel --add https://github.com/nix-community/home-manager/archive/release-23.05.tar.gz home-manager
	nix-channel --update
	nix-shell '<home-manager>' -A install
	home-manager switch --flake ~/.dotfiles/config/home-manager#mh

install/rust:
	# I don't know yet how to make it auto add the bins to the path though...
	# So for now just use rust-anaylzer from arch repo.
	rustup toolchain install nightly \
		--allow-downgrade \
		--profile minimal \
		--component clippy,rust-analyzer-preview
	rustup default nightly

install/slock:
	@if ! [ -d build/slock ]; then \
		mkdir -p build &&\
		cp -r sources/slock/patched build/slock &&\
		cp sources/slock/config.h build/slock/config.h; fi
	@if grep 'replace-me-.*' build/slock/config.h > /dev/null; then \
		echo "set your user and group manually in config.h" && exit 1; fi
	sudo make -C build/slock install

install/lvim:
	LV_BRANCH='release-1.3/neovim-0.9' \
	  bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)

xdg/defaults:
	xdg-mime default org.pwmt.zathura.desktop application/pdf

update-modules:
	git submodule update --remote --recursive
