SHELL := /bin/bash
VIM := nvim


.PHONY: update/nvim
update/nvim: install/nvim

.PHONY: update/vim/plugins
update/vim/plugins:
	git submodule foreach --recursive \
		'if echo "$$sm_path" | grep "^config/${VIM}/pack/plugins" >/dev/null ; then git pull ; fi'
	@${MAKE} install/vim/coc

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

.PHONY: install
install:
	git submodule update --init --recursive --remote
	@${MAKE} install/vim/coc

.PHONY: install/nvim/coc
install/vim/coc:
	yarn install --frozen-lockfile --cwd config/${VIM}/pack/plugins/opt/coc

.PHONY: install/nvim
install/nvim:
	git -C clones/neovim checkout stable
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

