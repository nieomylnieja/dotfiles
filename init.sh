#!/bin/bash

rm ~/.alacritty.yml
ln alacritty.yml ~/.alacritty.yml
ln bashrc ~/.bashrc
ln gitconfig ~/.gitconfig
ln xmonad.hs ~/.xmonad/xmonad.hs

make local-secrets

git config --global core.excludesfile ~/.dotfiles/gitignore_global
