SHELL := /bin/bash
VIM := nvim


.PHONY: update/nvim
update/nvim: install/nvim

.PHONY: update/vim/plugins
update/vim/plugins:
	git submodule foreach --recursive \
		'if echo "$$sm_path" | grep "^config/${VIM}/pack/plugins" >/dev/null ; then git pull ; fi'
	@${MAKE} update/vim/coc
	${VIM} -c "TSUpdate"

.PHONY: update/rust
update/rust:
	rustup update stable
	cargo install-update -a

.PHONY: update/python
update/python:
	python -m pip install --upgrade pip
	pip freeze --user | cut -d'=' -f1 | xargs -n1 pip install -U

.PHONY: update/npm
update/npm:
	npm install -g npm@latest
	npm update -g

.PHONY: update/fzf
update/fzf:
	git submodule update --remote clones/fzf
	./clones/fzf/install --all --xdg --no-update-rc

.PHONY: update/autojump
update/autojump:
	git submodule update --remote clones/autojump
	@${MAKE} install/autojump

.PHONY: update/pfetch
update/pfetch:
	git submodule update --remote clones/pfetch
	@${MAKE} install/pfetch

.PHONY: update/tmux
update/tmux:
	./config/tmux/tpm/bin/update_plugins all

.PHONY: update/yt-dlp
update/yt-dlp:
	yt-dlp -U

.PHONY: update/vim/coc
update/vim/coc:
	yarn install --cwd config/${VIM}/pack/plugins/opt/coc
	${VIM} -c 'CocUpdate'

.PHONY: install
install:
	git submodule update --init --recursive --remote
	@${MAKE} install/vim/coc

.PHONY: install/vim/coc
install/vim/coc:
	yarn install --frozen-lockfile --cwd config/${VIM}/pack/plugins/opt/coc
	${VIM} -c 'CocInstall coc-json coc-pyrigth'

.PHONY: install/nvim
install/nvim:
	git -C clones/neovim checkout master
	git -C clones/neovim pull
	make -C clones/neovim
	sudo make -C clones/neovim install

.PHONY: install/autojump
install/autojump:
	cd clones/autojump && sudo ./install.py --system

.PHONY: install/pfetch
install/pfetch:
	sudo make -C clones/pfetch install

.PHONY: install/rust
install/cargo:
	curl https://sh.rustup.rs -sSf | sh
	cargo install cargo-update

.PHONY: install/tmux
install/tmux:
	./config/tmux/tpm/bin/install_plugins

.PHONY: install/yt-dlp
install/yt-dlp:
	sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
	sudo chmod a+rx /usr/local/bin/yt-dlp

.PHONY: install/gnu-parallel
install/gnu-parallel:
	mkdir -p build
	wget -P build https://ftpmirror.gnu.org/parallel/parallel-latest.tar.bz2
	tar -C build -xjf build/parallel-latest.tar.bz2
	cd build/parallel-* && ./configure && make && sudo make install
	rm -rf build

.PHONY: install/gawk
install/gawk:
	mkdir -p build
	wget -P build https://ftp.gnu.org/gnu/gawk/gawk-5.1.1.tar.gz
	tar -C build -xvpzf build/gawk-5.1.1.tar.gz
	cd build/gawk-5.1.1 && ./configure && make && make check && sudo make install
	rm -rf build

.PHONY: install/qtile
install/qtile:
	pip install --no-cache-dir xcffib cairocffi dbus-next
	pip install qtile

define pandoc_version
pandoc-$$(cat build/pandoc-latest.json | jq -r .tag_name)
endef

.PHONY: install/markdown
install/markdown:
	mkdir -p build
	curl https://api.github.com/repos/jgm/pandoc/releases/latest > build/pandoc-latest.json
	cat build/pandoc-latest.json | jq '.assets[] | select(.name? | match("linux.*amd64")) | .browser_download_url' | xargs wget -P build
	tar -C build -xvpzf build/$(call pandoc_version)-linux-amd64.tar.gz
	sudo cp build/$(call pandoc_version)/bin/pandoc /usr/local/bin
	sudo cp build/$(call pandoc_version)/share/man/man1/pandoc.1.gz /usr/local/share/man/man1
	rm -rf build

.PHONY: install/compton
install/compton:
	sudo apt install compton
	ln -sf $$DOTFILES/config/compton/compton.conf $$XDG_CONFIG_HOME/compton.conf

.PHONY: install/nitrogen
install/nitrogen:
	sudo apt install nitrogen

.PHONY: install/slock
install/slock:
	@if ! [ -d build/slock ]; then \
		mkdir -p build &&\
		cp -r sources/slock/patched build/slock &&\
		cp sources/slock/config.h build/slock/config.h; fi
	@if grep 'replace-me-.*' build/slock/config.h > /dev/null; then \
		echo "set your user and group manually in config.h" && exit 1; fi
	sudo make -C build/slock install
	rm -rf build

.PHONY: install/xautolock
install/xautolock:
	sudo apt install xautolock

.PHONY: install/pavucontrol
install/pavucontrol:
	cd clones/pavucontrol && ./bootstrap.sh && ./configure && make && sudo make install

.PHONY: install/lsps
install/lsps:
	npm i -g pyright

define github_release_version
$(1)-$$(cat build/$(1)-latest.json | jq -r .tag_name)
endef

.PHONY: install/rofi
install/rofi:
	mkdir -p build
	curl https://api.github.com/repos/davatorium/rofi/releases/latest > build/rofi-latest.json
	cat build/rofi-latest.json | jq '.assets[] | select(.name | (match(".*tar.gz"))) | .browser_download_url' | xargs wget -P build
	tar -C build -xvpzf build/$(call github_release_version,rofi).tar.gz
	cd build/$(call github_release_version,rofi) &&\
		mkdir -p build &&\
		cd build &&\
		../configure &&\
		make &&\
		sudo make install
	rm -rf build

.PHONY: install/nordic-gtk
install/nordic-gtk: link/nordic-gtk
	gsettings set org.gnome.desktop.interface gtk-theme "Nordic"
	gsettings set org.gnome.desktop.wm.preferences theme "Nordic"

.PHONY: install/arandr
install/arandr:
	sudo aptitude install arandr

.PHONY: link
link:
	source config/bash/bashrc
	@${MAKE} link/tmux
	@${MAKE} link/git

.PHONY: link/tmux
link/tmux:
	mkdir -p $$XDG_CONFIG_HOME/tmux
	ln -sf $$DOTFILES/config/tmux/tmux.conf $$XDG_CONFIG_HOME/tmux/tmux.conf
	ln -sf $$DOTFILES/config/tmux/tpm $$XDG_CONFIG_HOME/tmux/tpm

.PHONY: link/git
link/git:
	mkdir -p $$XDG_CONFIG_HOME/git
	ln -sf $$DOTFILES/config/git/config $$XDG_CONFIG_HOME/git/config

.PHONY: link/qtile
link/qtile:
	sudo ln -sf $$DOTFILES/config/qtile/qtile.desktop /usr/share/xsessions/qtile.desktop
	ln -sf $$DOTFILES/config/qtile/config.py $$XDG_CONFIG_HOME/qtile/config.py
	ln -sf $$DOTFILES/config/qtile/autostart.sh $$XDG_CONFIG_HOME/qtile/autostart.sh

.PHONY: link/rofi
link/rofi:
	ln -sf $$DOTFILES/config/rofi $$XDG_CONFIG_HOME/rofi

.PHONY: link/nordic-gtk
link/nordic-gtk:
	sudo ln -sf $$DOTFILES/clones/Nordic /usr/share/themes/Nordic

.PHONY: link/pulseaudio-ctl
link/pulseaudio-ctl:
	mkdir -p $$XDG_CONFIG_HOME/pulseaudio-ctl
	ln -sf $$DOTFILES/config/pulseaudio/pulseaudio-ctl-config $$XDG_CONFIG_HOME/pulseaudio-ctl/config

.PHONY: link/xprofile
link/xprofile:
	ln -sf $$DOTFILES/config/Xorg/xprofile $$HOME/.xprofile
	ln -sf $$DOTFILES/config/Xorg/Xresources $$HOME/.Xresources
