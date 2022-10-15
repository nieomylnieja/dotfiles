.PHONY: init
init:
	git submodule update --init --recursive --remote

.PHONY: link
link: link/bash link/starship link/qtile

link/starship:
	ln -sf "$$DOTFILES/config/starship/starship.toml" "$$XDG_CONFIG_HOME/starship.toml"

link/bash:
	ln -sf "$$DOTFILES/config/bash/bashrc" "$$HOME/.bashrc"
	ln -sf "$$DOTFILES/config/bash/bash_logout" "$$HOME/.bash_logout"
	ln -sf "$$DOTFILES/config/bash/bash_profile" "$$HOME/.bash_profile"

link/qtile:
	ln -sf "$$DOTFILES/config/qtile/config.py" "$$XDG_CONFIG_HOME/qtile/config.py"
	ln -sf "$$DOTFILES/config/qtile/autostart.sh" "$$XDG_CONFIG_HOME/qtile/autostart.sh"

link/xorg:
	ln -sf "$$DOTFILES/config/xorg/Xresources" "$$HOME/.Xresources"
	ln -sf "$$DOTFILES/config/xorg/xprofile" "$$HOME/.xprofile"
	ln -sf "$$DOTFILES/config/xorg/xinitc" "$$HOME/.xinitrc"

link/systemd:
	mkdir -p "$$XDG_CONFIG_HOME/systemd/user"
	ln -sf "$$DOTFILES/config/systemd/ssh-agent.service" "$$XDG_CONFIG_HOME/systemd/user/ssh-agent.service"

link/rofi:
	ln -sf "$$DOTFILES/config/rofi" "$$XDG_CONFIG_HOME/rofi"

link/nvim:
	ln -sf "$$DOTFILES/config/nvim" "$$XDG_CONFIG_HOME/nvim"

link/alacritty:
	ln -sf "$$DOTFILES/config/alacritty" "$$XDG_CONFIG_HOME/alacritty"

link/qt5ct:
	ln -s "$$DOTFILES/config/qt5ct" "$$XDG_CONFIG_HOME/qt5ct"

link/doom:
	rm -rf "$$HOME/.doom.d"
	ln -s "$$DOTFILES/config/doom" "$$HOME/.doom.d"

link/picom:
	ln -s "$$DOTFILES/config/picom" "$$HOME/.config/picom"

xdg/defaults:
	xdg-mime default org.pwmt.zathura.desktop application/pdf

install/lsps:
	go install golang.org/x/tools/gopls@latest
	npm install -g \
		pyright \
		awk-language-server \
		bash-language-server
	./clones/lua-language-server.sh

install/rust:
	# I don't know yet how to make it auto add the bins to the path though...
	# So for now just use rust-anaylzer from arch repo.
	rustup toolchain install nightly \
		--allow-downgrade \
		--profile minimal \
		--component clippy,rust-analyzer-preview
	rustup default nightly

install/go:
	go install github.com/go-delve/delve/cmd/dlv@latest

install/doomemacs:
	git clone https://github.com/hlissner/doom-emacs ~/.emacs.d
	doom install
	doom doctor

install/slock:
	@if ! [ -d build/slock ]; then \
		mkdir -p build &&\
		cp -r sources/slock/patched build/slock &&\
		cp sources/slock/config.h build/slock/config.h; fi
	@if grep 'replace-me-.*' build/slock/config.h > /dev/null; then \
		echo "set your user and group manually in config.h" && exit 1; fi
	sudo make -C build/slock install

update/nvim/plugins:
	nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync' -c 'MasonToolsUpdate'

# nvim/helptags:
# 	fd --type f -a -p 'config/nvim/pack/plugins/.*/doc/.*txt' --exec dirname |\
# 		sort | uniq |\
# 		xargs -I '{}' nvim --headless --noplugin -c ":helptags {}" -c "qa"

install/fmt-tools:
	yay -S prettier stylua
