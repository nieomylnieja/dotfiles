To enable this, copy the service definition to
`~/.config/systemd/user/ssh-agent.service`.

Make sure env variable is set:

```sh
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
```

Next enable the service:

```sh
systemctl --user enable ssh-agent
systemctl --user start ssh-agent
```

To avoid doing the manual `ssh-add` we can supply this option to
`~/.ssh/config`:

```txt
AddKeysToAgent  yes
```
