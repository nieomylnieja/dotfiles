xdg/defaults:
	xdg-mime default org.pwmt.zathura.desktop application/pdf

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

install/lvim:
	LV_BRANCH='release-1.2/neovim-0.8' bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/fc6873809934917b470bff1b072171879899a36b/utils/installer/install.sh)

install/astronvim:
	git clone --depth 1 https://github.com/AstroNvim/AstroNvim ~/.config/nvim
	ln -s "$$DOTFILES/config/astronvim" "$$XDG_CONFIG_HOME/nvim/lua/user"

update/nvim/plugins:
	nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync' -c 'MasonToolsUpdate'

# nvim/helptags:
# 	fd --type f -a -p 'config/nvim/pack/plugins/.*/doc/.*txt' --exec dirname |\
# 		sort | uniq |\
# 		xargs -I '{}' nvim --headless --noplugin -c ":helptags {}" -c "qa"

install/fmt-tools:
	yay -S prettier stylua
