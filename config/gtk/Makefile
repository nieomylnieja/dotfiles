all:
	mkdir -p "$$HOME/.local/share/themes"
	ln -s "$$DOTFILES/config/gtk/Nordic" "$$HOME/.local/share/themes/Nordic"
	ln -s "$$DOTFILES/config/gtk/settings.ini" "$$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
	gsettings set org.gnome.desktop.interface gtk-theme "Nordic"
	gsettings set org.gnome.desktop.wm.preferences theme "Nordic"
