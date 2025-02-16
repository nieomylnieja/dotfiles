update:
	nix flake update --commit-lock-file
	nix flake update --flake ./config/home-manager/flake.nix --commit-lock-file

rebuild:
	sudo nixos-rebuild switch --flake .#work

install/home-manager:
	nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz home-manager
	nix-channel --update
	# Standalone nix on another system:
	#   nix-shell '<home-manager>' -A install
	#   home-manager switch --flake ~/.dotfiles/config/home-manager#mh

install/nix:
	sh <(curl -L https://nixos.org/nix/install) --no-daemon && . ~/.nix-profile/etc/profile.d/nix.sh

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
