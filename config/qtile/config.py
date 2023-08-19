import os
import re
import subprocess

from libqtile import bar, hook, layout, widget
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy
from widgets.volume import Volume, VolumeCommands

mod = "mod4"


keys = [
    # The basics
    Key([mod],
        "Return",
        lazy.spawn("alacritty"),
        desc="Launch terminal"),
    Key([mod],
        "v",
        lazy.spawn("neovide --notabs"),
        desc="Launch Neovide"),
    Key([mod, "shift"],
        "Return",
        lazy.spawn("rofi -show drun -show-icons -auto-select"),
        desc="Launch launcher"),
    Key([mod],
        "b",
        lazy.spawn(["bash", "-c", "${BROWSER-firefox}"]),
        desc="Launch browser"),
    Key([mod, "shift"],
        "b",
        lazy.spawn("rofi-bluetooth"),
        desc="Launch bluetooth manager."),
    Key([mod],
        "s",
        lazy.spawn("locker"),
        desc="Lock the screen"),
    Key([mod],
        "Tab",
        lazy.next_layout(),
        desc="Toggle through layouts"),
    Key([mod],
        "d",
        lazy.window.kill(),
        desc="Kill active window"),
    Key([mod],
        "m",
        lazy.spawn("displays.sh"),
        desc="Select displays preset"),
    Key([mod, "shift"],
        "m",
        lazy.spawn("monitors.sh"),
        desc="Select monitors layout"),
    Key([mod],
        "o",
        lazy.spawn("rofi-pass"),
        desc="Launch bluetooth manager."),
    Key([mod, "shift"],
        "r",
        lazy.restart(),
        desc="Restart Qtile"),
    Key([mod], "q",
        lazy.spawn("rofi -show power-menu -modi power-menu:rofi-power-menu"),
        desc="Show power menu"),
    # Utils
    Key([mod],
        "p",
        lazy.spawn("flameshot gui --accept-on-select"),
        desc="Take a screenshot and save it instantly after selecting"),
    Key([mod, "shift"],
        "p",
        lazy.spawn("flameshot gui"),
        desc="Take a screenshot"),
    Key([mod, "shift"],
        "c",
        lazy.spawn(
            "rofi -show calc -modi calc -no-show-match -no-sort "
            + "-calc-command \"echo -n '{result}' | xclip -sel c\""),
        desc="Open calculator"),
    Key([mod],
        "c",
        lazy.spawn("rofi -modi \"clipboard:greenclip print\" "
                   + "-show clipboard -run-command '{cmd}'"),
        desc="Browse clipboard history."),
    # Switch between windows
    Key([mod],
        "h",
        lazy.layout.left(),
        desc="Move focus to left"),
    Key([mod],
        "l",
        lazy.layout.right(),
        desc="Move focus to right"),
    Key([mod],
        "j",
        lazy.layout.down(),
        desc="Move focus down"),
    Key([mod],
        "k",
        lazy.layout.up(),
        desc="Move focus up"),
    Key([mod],
        "space",
        lazy.layout.next(),
        desc="Move window focus to other window"),
    # Move windows between left/right columns or move up/down in current stack.
    # Moving out of range in Columns layout will create new column.
    Key([mod, "shift"],
        "h",
        lazy.layout.shuffle_left(),
        desc="Move window to the left"),
    Key([mod, "shift"],
        "l",
        lazy.layout.shuffle_right(),
        desc="Move window to the right"),
    Key([mod, "shift"],
        "j",
        lazy.layout.shuffle_down(),
        desc="Move window down"),
    Key([mod, "shift"],
        "k",
        lazy.layout.shuffle_up(),
        desc="Move window up"),
    # Grow windows. If current window is on the edge of screen and direction
    # will be to screen edge - window would shrink.
    Key([mod, "control"],
        "i",
        lazy.layout.grow(),
        desc="Grow window"),
    Key([mod, "control"],
        "o",
        lazy.layout.shrink(),
        desc="Shrink window"),
    Key([mod, "control"],
        "h",
        lazy.layout.grow_left(),
        desc="Grow window to the left"),
    Key([mod, "control"],
        "l",
        lazy.layout.grow_right(),
        desc="Grow window to the right"),
    Key([mod, "control"],
        "j",
        lazy.layout.grow_down(),
        desc="Grow window down"),
    Key([mod, "control"],
        "k",
        lazy.layout.grow_up(),
        desc="Grow window up"),
    Key([mod],
        "n",
        lazy.layout.maximize(),
        desc="Toggle window between minimum and maximum sizes"),
    Key([mod],
        "f",
        lazy.window.toggle_fullscreen(), desc="Toggle fullscreen"),
    Key([mod, "shift"],
        "f",
        lazy.window.toggle_floating(), desc="toggle floating"),
    Key([mod, "shift"],
        "n",
        lazy.layout.normalize(),
        desc="Reset all window sizes"),
    # Switch focus of monitors
    Key([mod],
        "period",
        lazy.next_screen(),
        desc="Move focus to next monitor"),
    Key([mod],
        "comma",
        lazy.prev_screen(),
        desc="Move focus to prev monitor"),
    # Media keys
    Key([mod],
        "F1",
        VolumeCommands.TOGGLE_MUTE.lazy,
        desc="Mute the audio"),
    Key([], "XF86AudioMute",
        VolumeCommands.TOGGLE_MUTE.lazy,
        desc="Mute the audio"),
    Key([mod],
        "Page_Up",
        VolumeCommands.INCREASE_VOLUME.lazy,
        desc="Raise volume level"),
    Key(
        [mod],
        "Page_Down",
        VolumeCommands.DECREASE_VOLUME.lazy,
        desc="Lower volume level"),
    Key([],
        "XF86AudioRaiseVolume",
        VolumeCommands.INCREASE_VOLUME.lazy,
        desc="Raise volume level"),
    Key([],
        "XF86AudioLowerVolume",
        VolumeCommands.DECREASE_VOLUME.lazy,
        desc="Lower volume level"),
    Key([mod],
        "F7",
        lazy.spawn("brightness up 5"),
        desc="Increase brightness level"),
    Key([mod],
        "F6",
        lazy.spawn("brightness down 5"),
        desc="Lower brightness level"),
    Key([],
        "XF86MonBrightnessUp",
        lazy.spawn("brightness up 5"),
        desc="Increase brightness level"),
    Key([],
        "XF86MonBrightnessDown",
        lazy.spawn("brightness down 5"),
        desc="Lower brightness level"),
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
                desc="Switch to & move focused window to group {}".format(
                    i.name),
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
    "border_width": 3,
    "margin": 10,
    "border_focus": colors["polar-3"],
    "border_normal": colors["polar-0"],
}

layouts = [
    layout.MonadTall(**layout_theme),
    layout.MonadWide(
        **layout_theme,
        ratio=0.75,
    ),
    layout.Max(**layout_theme),
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
    margin=[6, 10, 0, 10],
    opacity=0.8,
)

music_widget = widget.Mpris2(
    **widget_defaults,
    display_metadata=["xesam:album", "xesam:artist"],
    scroll=True,
    width=150,
    objname="org.mpris.MediaPlayer2.spotifyd",
)

widgets = [
    widget.Image(
        **widget_defaults,
        filename="~/.config/qtile/icons/python.png",
        margin=2,
    ),
    widget.GroupBox(
        **widget_defaults,
        active=colors["frost-2"],
        inactive=colors["snow-1"],
        highlight_color=colors["polar-1"],
        borderwidth=2,
        disable_drag=True,
        highlight_method="line",
        margin_x=0,
        margin_y=3,
        padding_y=8,
        rounded=False,
        this_current_screen_border=colors["aurora-2"],  # ebcb8b
        urgent_alert_method="line",
    ),
    widget.WindowName(**widget_defaults),
    music_widget,
    widget.Systray(**widget_defaults),
    widget.Sep(**widget_defaults),
    widget.CPU(**widget_defaults, format="{freq_current}GHz {load_percent}%"),
    widget.Memory(**widget_defaults,
                  format="{MemUsed:.0f}{mm}/{MemTotal:.0f}{mm}"),
    widget.Sep(**widget_defaults),
    widget.Battery(
        **widget_defaults,
        charge_char="󰂄",
        discharge_char="󰂌",
        empty_char="󰂎",
        full_char="󰁹",
        unknown_char="󰂑",
        format="{char} {percent:2.0%}",
        show_short_text=False,
    ),
    Volume(
        **widget_defaults,
        # FIXME: This doesn't work right now.
        # mouse_callbacks={"Button3": lambda: qtile.cmd_spawn("easyeffects")},
    ),
    widget.Sep(**widget_defaults),
    widget.CurrentLayout(**widget_defaults),
    widget.Clock(**widget_defaults, format="%H:%M %a %Y-%m-%d"),
]

keys.extend([
    Key([],
        "XF86AudioPlay",
        lazy.function(lambda _: music_widget.cmd_play_pause()),
        desc="Play/Pause playback"),
    Key([],
        "XF86AudioNext",
        lazy.function(lambda _: music_widget.cmd_next()),
        desc="Next track"),
    Key([],
        "XF86AudioPrev",
        lazy.function(lambda _: music_widget.cmd_previous()),
        desc="Previous track"),
    Key([],
        "XF86AudioStop",
        lazy.function(lambda _: music_widget.cmd_stop()),
        desc="Stop playback"),
])

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
    Drag([mod], "Button3", lazy.window.set_size_floating(),
         start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

dgroups_key_binder = None
dgroups_app_rules = []
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False

floating_layout = layout.Floating(
    float_rules=[
        # Run the utility of `xprop` to see the wm class and name of an X client.
        *layout.Floating.default_float_rules,
        Match(wm_class="ssh-askpass"),
        Match(wm_class="pinentry"),
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


def get_keys_description() -> str:
    key_help = ""
    for k in keys:
        mods = ""

        for m in k.modifiers:
            if m == "mod4":
                mods += "Super + "
            else:
                mods += m.capitalize() + " + "

        if len(k.key) > 1:
            mods += k.key.capitalize()
        else:
            mods += k.key

        key_help += "{:<30} {}".format(mods, k.desc + "\n")

    return key_help


keys.extend(
    [
        Key(
            [mod, "shift"],
            "slash",
            lazy.spawn(
                "sh -c 'echo \""
                + get_keys_description()
                + '" | rofi -dmenu -i -mesg "Keyboard shortcuts"\''
            ),
            desc="Print keyboard bindings",
        ),
    ]
)

# XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
# string besides java UI toolkits; you can see several discussions on the
# mailing lists, GitHub issues, and other WM documentation that suggest setting
# this string if your java app doesn't work correctly. We may as well just lie
# and say that we're a working one by default.
#
# We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
# java that happens to be on java's whitelist.
wmname = "LG3D"
