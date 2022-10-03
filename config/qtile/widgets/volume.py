import re
import subprocess
from enum import Enum

from libqtile import bar
from libqtile.widget import base
from libqtile.log_utils import logger
from libqtile.lazy import lazy

__all__ = ["Volume", "VolumeCommands"]

# dropped the brackets from the pattern because not every program returns the volume inside brackets
# and searching for ddd% still works with amixer too.
re_vol = re.compile(r"(\d?\d?\d?)%")
mixer_cmd = "pamixer"
mixer_step = "5"


class VolumeCommands(Enum):
    GET_VOLUME = [mixer_cmd, "--get-volume-human"]
    TOGGLE_MUTE = [mixer_cmd, "--toggle-mute"]
    INCREASE_VOLUME = [mixer_cmd, "--unmute", "--increase", mixer_step]
    DECREASE_VOLUME = [mixer_cmd, "--unmute", "--decrease", mixer_step]

    @property
    def lazy(self):
        return lazy.spawn(self.value)

    def __str__(self) -> str:
        return self.value.join(" ")

    def run(self):
        if self == self.GET_VOLUME:
            return subprocess.check_output(self.value).decode("utf-8").strip()
        return subprocess.call(self.value)


class Volume(base._TextBox):
    """Widget that display and change volume
    This widget uses ``pamixer`` to get and set the volume so you have to make
    sure it is installed.
    If theme_path is set it draws widget as icons.
    """

    orientations = base.ORIENTATION_HORIZONTAL
    defaults = [
        ("padding", 3, "Padding left and right. Calculated if None."),
        ("update_interval", 0.5, "Update time in seconds."),
        ("theme_path", None, "Path of the icons"),
        ("check_mute_string", "muted", "String to look for when checking mute"),
        (
            "emoji",
            True,
            "Use emoji to display volume states, only if ``theme_path`` is not set."
            "The specified font needs to contain the correct unicode characters.",
        ),
    ]

    def __init__(self, **config):
        base._TextBox.__init__(self, "0", width=bar.CALCULATED, **config)
        self.add_defaults(Volume.defaults)
        if self.theme_path:
            self.length_type = bar.STATIC
            self.length = 0
        self.surfaces = {}
        self.volume = -1

        self.add_callbacks(
            {
                "Button1": self.cmd_mute,
                "Button4": self.cmd_increase_vol,
                "Button5": self.cmd_decrease_vol,
            }
        )

    def timer_setup(self):
        self.timeout_add(self.update_interval, self.update)
        if self.theme_path:
            self.setup_images()

    def button_press(self, x, y, button):
        base._TextBox.button_press(self, x, y, button)
        self.draw()

    def update(self):
        vol = self.get_volume()
        if vol != self.volume:
            self.volume = vol
            # Update the underlying canvas size before actually attempting
            # to figure out how big it is and draw it.
            self._update_drawer()
            self.bar.draw()
        self.timeout_add(self.update_interval, self.update)

    def _update_drawer(self):
        if self.theme_path:
            self.drawer.clear(self.background or self.bar.background)
            if self.volume <= 0:
                img_name = "audio-volume-muted"
            elif self.volume <= 30:
                img_name = "audio-volume-low"
            elif self.volume < 80:
                img_name = "audio-volume-medium"
            else:  # self.volume >= 80:
                img_name = "audio-volume-high"

            self.drawer.ctx.set_source(self.surfaces[img_name])
            self.drawer.ctx.paint()
        elif self.emoji:
            if self.volume <= 0:
                self.text = f"\U0001f507"
            elif self.volume <= 30:
                self.text = f"\U0001f508 {self.volume}%"
            elif self.volume < 80:
                self.text = f"\U0001f509 {self.volume}%"
            elif self.volume >= 80:
                self.text = f"\U0001f50a {self.volume}"

    def setup_images(self):
        from libqtile import images

        names = (
            "audio-volume-high",
            "audio-volume-low",
            "audio-volume-medium",
            "audio-volume-muted",
        )
        d_images = images.Loader(self.theme_path)(*names)
        for name, img in d_images.items():
            new_height = self.bar.height - 1
            img.resize(height=new_height)
            if img.width > self.length:
                self.length = img.width + self.actual_padding * 2
            self.surfaces[name] = img.pattern

    def get_volume(self):
        try:
            # mixer_out = self.call_process(get_volume_cmd) works with amixer, but with pactl it caused
            # "No such file or directory" errors. subprocess.getoutput() provides the proper command output
            # for amixer, pactl, and pamixer. Parsing pamixer volume output is handled below.
            mixer_out = VolumeCommands.GET_VOLUME.run()
        except subprocess.CalledProcessError as e:
            logger.error("Failed to get volume: %s", e, exc_info=True)
            return -1

        mixer_out = str(mixer_out)
        # Pamixer returns 'muted' string for muted state.
        if self.check_mute_string == mixer_out:
            return -1

        # Pamixer returns percentage volume, thus the regex.
        volgroups = re_vol.search(mixer_out)
        if volgroups:
            return int(volgroups.groups()[0])
        else:
            return -1

    def draw(self):
        if self.theme_path:
            self.drawer.draw(
                offsetx=self.offset, offsety=self.offsety, width=self.length
            )
        else:
            base._TextBox.draw(self)

    def cmd_increase_vol(self):
        return VolumeCommands.INCREASE_VOLUME.run()

    def cmd_decrease_vol(self):
        return VolumeCommands.DECREASE_VOLUME.run()

    def cmd_mute(self):
        return VolumeCommands.TOGGLE_MUTE.run()
