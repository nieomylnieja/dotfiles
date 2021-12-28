.PHONY: update
update:
	git submodule foreach --recursive git pull
	@${MAKE} install/vim/coc

.PHONY: update/rust
update/rust:
	rustup update stable
	cargo install-update -a

.PHONY: install
install:
	git submodule update --init --recursive --remote
	@${MAKE} install/vim/coc

.PHONY: install/vim/coc
install/vim/coc:
	yarn install --frozen-lockfile --cwd config/vim/pack/plugins/opt/coc

.PHONY: install/nvim
install/nvim:
	wget https://github.com/neovim/neovim/releases/latest

.PHONY: install/rust
install/cargo:
	curl https://sh.rustup.rs -sSf | sh
	cargo install cargo-update
