import os
import subprocess

from typing import List  # noqa: F401

from libqtile import bar, layout, widget, hook
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy
from libqtile.command import lazy

from widgets.volume import Volume, VolumeCommands

mod = "mod4"
terminal = "alacritty"
browser = "brave"


keys = [
    # The basics
    Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),
    Key(
        [mod, "shift"],
        "Return",
        lazy.spawn("rofi -show drun -show-icons -auto-select"),
        desc="Launch launcher",
    ),
    Key([mod], "e", lazy.spawn("emacsclient -nc"), desc="Launch emacs"),
    Key([mod], "b", lazy.spawn(browser), desc="Launch browser"),
    Key([mod], "s", lazy.spawn("xautolock -locknow"), desc="Lock the screen"),
    Key([mod], "Tab", lazy.next_layout(), desc="Toggle through layouts"),
    Key([mod], "d", lazy.window.kill(), desc="Kill active window"),
    Key([mod, "shift"], "d", lazy.spawn("displays"), desc="Kill active window"),
    Key([mod, "shift"], "r", lazy.restart(), desc="Restart Qtile"),
    Key(
        [mod],
        "q",
        lazy.spawn("rofi -show power-menu -modi power-menu:rofi-power-menu"),
        desc="Show power menu",
    ),
    # Utils
    Key(
        [mod],
        "p",
        lazy.spawn("flameshot gui --accept-on-select"),
        desc="Take a screenshot and save it instantly after selecting",
    ),
    Key([mod, "shift"], "p", lazy.spawn("flameshot gui"), desc="Take a screenshot"),
    Key(
        [mod],
        "c",
        lazy.spawn(
            "rofi -show calc -modi calc -no-show-match -no-sort "
            + "-calc-command \"echo -n '{result}' | xclip -sel c\""
        ),
        desc="Open calculator",
    ),
    # Switch between windows
    Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    Key([mod], "space", lazy.layout.next(), desc="Move window focus to other window"),
    # Move windows between left/right columns or move up/down in current stack.
    # Moving out of range in Columns layout will create new column.
    Key(
        [mod, "shift"], "h", lazy.layout.shuffle_left(), desc="Move window to the left"
    ),
    Key(
        [mod, "shift"],
        "l",
        lazy.layout.shuffle_right(),
        desc="Move window to the right",
    ),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Move window down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),
    # Grow windows. If current window is on the edge of screen and direction
    # will be to screen edge - window would shrink.
    Key([mod, "control"], "h", lazy.layout.grow_left(), desc="Grow window to the left"),
    Key(
        [mod, "control"], "l", lazy.layout.grow_right(), desc="Grow window to the right"
    ),
    Key([mod, "control"], "j", lazy.layout.grow_down(), desc="Grow window down"),
    Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),
    Key(
        [mod],
        "m",
        lazy.layout.maximize(),
        desc="Toggle window between minimum and maximum sizes",
    ),
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Toggle fullscreen"),
    Key([mod, "shift"], "f", lazy.window.toggle_floating(), desc="toggle floating"),
    Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
    # Switch focus of monitors
    Key([mod], "period", lazy.next_screen(), desc="Move focus to next monitor"),
    Key([mod], "comma", lazy.prev_screen(), desc="Move focus to prev monitor"),
    # Media keys
    Key([mod], "F1", VolumeCommands.TOGGLE_MUTE.lazy, desc="Mute the audio"),
    Key([], "XF86AudioMute", VolumeCommands.TOGGLE_MUTE.lazy, desc="Mute the audio"),
    Key(
        [mod], "Page_Up", VolumeCommands.INCREASE_VOLUME.lazy, desc="Raise volume level"
    ),
    Key(
        [mod],
        "Page_Down",
        VolumeCommands.DECREASE_VOLUME.lazy,
        desc="Lower volume level",
    ),
    Key(
        [],
        "XF86AudioRaiseVolume",
        VolumeCommands.INCREASE_VOLUME.lazy,
        desc="Raise volume level",
    ),
    Key(
        [],
        "XF86AudioLowerVolume",
        VolumeCommands.DECREASE_VOLUME.lazy,
        desc="Lower volume level",
    ),
    Key([mod], "F7", lazy.spawn("brightness up 5"), desc="Increase brightness level"),
    Key([mod], "F6", lazy.spawn("brightness down 5"), desc="Lower brightness level"),
    Key(
        [],
        "XF86MonBrightnessUp",
        lazy.spawn("brightness up 5"),
        desc="Increase brightness level",
    ),
    Key(
        [],
        "XF86MonBrightnessDown",
        lazy.spawn("brightness down 5"),
        desc="Lower brightness level",
    ),
]

groups = [Group(i) for i in "123456789"]

for i in groups:
    keys.extend(
        [
            # mod1 + letter of group = switch to group
            Key(
                [mod],
                i.name,
                lazy.group[i.name].toscreen(),
                desc="Switch to group {}".format(i.name),
            ),
            # mod1 + shift + letter of group = switch to & move focused window to group
            Key(
                [mod, "shift"],
                i.name,
                lazy.window.togroup(i.name, switch_group=True),
                desc="Switch to & move focused window to group {}".format(i.name),
            ),
        ]
    )

# See https://www.nordtheme.com/docs/colors-and-palettes
colors = {
    "polar-0": "#2E3440",
    "polar-1": "#3B4252",
    "polar-2": "#434C5E",
    "polar-3": "#4C566A",
    "snow-0": "#D8DEE9",
    "snow-1": "#E5E9F0",
    "snow-2": "#ECEFF4",
    "frost-0": "#8FBCBB",
    "frost-1": "#88C0D0",
    "frost-2": "#81A1C1",
    "frost-3": "#5E81AC",
    "aurora-0": "#BF616A",
    "aurora-1": "#D08770",
    "aurora-2": "#EBCB8B",
    "aurora-3": "#A3BE8C",
    "aurora-4": "#B48EAD",
}

layout_theme = {
    "border_width": 2,
    "margin": 8,
    "border_focus": colors["frost-0"],
    "border_normal": colors["polar-0"],
}

layouts = [
    layout.MonadTall(**layout_theme),
    layout.MonadWide(**layout_theme),
    layout.Max(**layout_theme),
    layout.Stack(**layout_theme, num_stacks=2),
    layout.RatioTile(**layout_theme),
]

widget_defaults = dict(
    font="mononoki Nerd Font Mono",
    fontsize=12,
    padding=3,
)

bar_defaults = dict(
    size=23,
    background=colors["polar-0"],
    # margin = [6,6,0,6],
    opacity=0.8,
)

extension_defaults = widget_defaults.copy()

widgets = [
    # widget.Sep(
    #     foreground=colors["snow-0"],
    #     linewidth=1,
    #     padding=10,
    # ),
    widget.Image(
        filename="~/.config/qtile/icons/python.png",
        margin=2,
    ),
    # widget.Sep(
    #     foreground=colors["snow-0"],
    #     linewidth=1,
    #     padding=10,
    # ),
    widget.GroupBox(
        active=colors["frost-2"],
        inactive=colors["snow-1"],
        highlight_color=colors["polar-1"],
        borderwidth=2,
        disable_drag=True,
        fontsize=14,
        highlight_method="line",
        margin_x=0,
        margin_y=3,
        padding_x=5,
        padding_y=8,
        rounded=False,
        this_current_screen_border=colors["aurora-2"],  # ebcb8b
        urgent_alert_method="line",
    ),
    widget.Prompt(),
    widget.WindowName(),
    widget.Chord(
        chords_colors={
            "launch": ("#ff0000", "#ffffff"),
        },
        name_transform=lambda name: name.upper(),
    ),
    widget.Systray(),
    widget.Battery(
        **widget_defaults,
        charge_char="",
        discharge_char="",
        empty_char="",
        full_char="",
        unknown_char="",
        format="{char} {percent:2.0%}",
        show_short_text=False,
    ),
    Volume(
        **widget_defaults,
        # FIXME: This doesn't work right now.
        # mouse_callbacks={"Button3": lambda: qtile.cmd_spawn("easyeffects")},
    ),
    widget.Net(
        **widget_defaults,
        # FIXME: I should be able to automate that somehow... What if I change
        # the laptop or sth?
        interface="wlan0",
        prefix="M",
        format="{down} {up}",
    ),
    widget.CurrentLayout(padding=5),
    widget.Clock(format="%Y-%m-%d %a %I:%M %p"),
]

screens = [
    Screen(
        top=bar.Bar(
            widgets,
            **bar_defaults,
        ),
    ),
]

# Drag floating layouts.
mouse = [
    Drag(
        [mod],
        "Button1",
        lazy.window.set_position_floating(),
        start=lazy.window.get_position(),
    ),
    Drag(
        [mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()
    ),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

dgroups_key_binder = None
dgroups_app_rules = []  # type: List
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False

floating_layout = layout.Floating(
    float_rules=[
        # Run the utility of `xprop` to see the wm class and name of an X client.
        *layout.Floating.default_float_rules,
        Match(wm_class="confirmreset"),  # gitk
        Match(wm_class="makebranch"),  # gitk
        Match(wm_class="maketag"),  # gitk
        Match(wm_class="ssh-askpass"),  # ssh-askpass
        Match(title="branchdialog"),  # gitk
        Match(title="pinentry"),  # GPG key password entry
    ]
)
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True

# If things like steam games want to auto-minimize themselves when losing
# focus, should we respect this or not?
auto_minimize = True


@hook.subscribe.startup
def start():
    home = os.path.expanduser("~")
    subprocess.call([home + "/.config/qtile/autostart.sh"])


# XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
# string besides java UI toolkits; you can see several discussions on the
# mailing lists, GitHub issues, and other WM documentation that suggest setting
# this string if your java app doesn't work correctly. We may as well just lie
# and say that we're a working one by default.
#
# We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
# java that happens to be on java's whitelist.
wmname = "LG3D"
