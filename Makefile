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

install/lsps:
	go install golang.org/x/tools/gopls@latest
	npm install -g \
		pyright \
		awk-language-server \
		bash-language-server

install/slock:
	@if ! [ -d build/slock ]; then \
		mkdir -p build &&\
		cp -r sources/slock/patched build/slock &&\
		cp sources/slock/config.h build/slock/config.h; fi
	@if grep 'replace-me-.*' build/slock/config.h > /dev/null; then \
		echo "set your user and group manually in config.h" && exit 1; fi
	sudo make -C build/slock install

.PHONY: update/nvim/plugins
update/nvim/plugins:
	git submodule update --recursive --remote
	nvim -c "TSUpdate"
	@${MAKE} nvim/helptags

.PHONY: nvim/helptags
nvim/helptags:
	fd --type f -a -p 'config/nvim/pack/plugins/.*/doc/.*txt' --exec dirname |\
		sort | uniq |\
		xargs -I '{}' nvim --headless --noplugin -c ":helptags {}" -c "qa"
