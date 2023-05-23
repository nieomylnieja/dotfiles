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
	LV_BRANCH='release-1.3/neovim-0.9' \
	  bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/release-1.3/neovim-0.9/utils/installer/install.sh)
