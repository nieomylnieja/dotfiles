#!/bin/bash

# This installs alacritty terminal on ubuntu (https://github.com/jwilm/alacritty)
# You have to have rust/cargo installed for this to work

# Install required tools
sudo apt-get install -y cmake libfreetype6-dev libfontconfig1-dev xclip

# Download, compile and install Alacritty
git clone https://github.com/jwilm/alacritty
cd alacritty
cargo install

# Add Man-Page entries
sudo mkdir -p /usr/local/share/man/man1
gzip -c alacritty.man | sudo tee /usr/local/share/man/man1/alacritty.1.gz > /dev/null

# Add shell completion for bash and zsh
mkdir -p ~/.bash_completion
cp alacritty-completions.bash ~/.bash_completion/alacritty
echo "\n# alacritty bash completion\nsource ~/.bash_completion/alacritty" >> ~/.bashrc

# Copy default config into home dir
cp alacritty.yml ~/.alacritty.yml

# Create desktop file
cp Alacritty.desktop ~/.local/share/applications/

# Copy binary to path
sudo cp target/release/alacritty /usr/local/bin

# Use Alacritty as default terminal (Ctrl + Alt + T)
gsettings set org.gnome.desktop.default-applications.terminal exec 'alacritty'

# Remove temporary dir
cd ..
rm -r alacritty
