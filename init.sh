#!/bin/bash

rm ~/.alacritty.yml
ln alacritty.yml ~/.alacritty.yml
ln bashrc ~/.bashrc
ln -s gitconfig ~/.gitconfig

make local-secrets
