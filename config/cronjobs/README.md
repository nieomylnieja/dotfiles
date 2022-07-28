Make sure `cronie` service is started:

```sh
systemctl enable cronie.service
systemctl start cronie.service
```

You can then apply the `cron.job` with `crontab`:

```sh
crontab cron.job
```

Verify which cron jobs are running:

```sh
crontab -l
```

When spawning Xorg display you have to provide `DISPLAY=:0` env.
When running `dmenu` you have to specify the bus with
`DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`. Bare in mind the value
for bus might be different, check `DBUS_SESSION_BUS_ADDRESS` value first.

Refer to https://wiki.archlinux.org/title/Cron for more details.
