import subprocess

import dotbot


class Flatpak(dotbot.Plugin):
    _directive = "flatpak"

    def can_handle(self, directive):
        return self._directive == directive

    def handle(self, directive, data):
        if directive != self._directive:
            raise ValueError(f"flatpak cannot handle directive {directive}")

        defaults = self._context.defaults().get(self._directive, {})
        success = True
        for source in data:
            remote = defaults.get("remote", "")
            host = defaults.get("host", "")
            app = source

            if isinstance(source, dict):
                remote = source.get("remote", remote)
                host = source.get("host", host)
                app = source.get("app", "")
            try:
                subprocess.run(
                    ["flatpak install --noninteractive " +
                     f"{remote} {host}.{app}"],
                    shell=True,
                    check=True)
            except subprocess.CalledProcessError:
                success = False
        if success:
            self._log.info("All packages have been installed")
        else:
            self._log.error("Some packages failed to be installed")
        return success
