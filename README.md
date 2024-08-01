# dotfiles

Behold, the **.files**

## Home Manager

### Updating nix channel

For standalone home-manager setup only.
If installed through nix flake on NixOS, the process is automated.

1. Make sure there's a new major version available:

    ```shell
    nix-channel --list
    ```

2. Remove the current channel:

    ```shell
    nix-channel --remove home-manager
    ```

3. Add the new major version:

    ```shell
    nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.05.tar.gz home-manager
    nix-channel --update
    ```

4. Finally, switch to the new channel:

    ```shell
    home-manager switch --flake ~/.dotfiles/config/home-manager#mh
    ```
