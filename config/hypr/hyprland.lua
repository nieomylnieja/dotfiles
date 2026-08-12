-- Hyprland configuration
-- Translated from the Qtile configuration

local home = assert(os.getenv("HOME"), "HOME is not set")
local state_home = os.getenv("XDG_STATE_HOME") or home .. "/.local/state"
local mod = "SUPER"
local terminal = "wezterm start -- tmux new-session \\; set-option destroy-unattached on"

-- Monitor configuration
hl.monitor({
    output = "eDP-1",
    mode = "preferred",
    position = "auto",
    scale = 1.6,
})

-- HyprDynamicMonitors creates this file. The eDP rule above is the startup fallback.
local dynamic_monitor_config = state_home .. "/hyprdynamicmonitors/monitors.lua"
local dynamic_monitor_file = io.open(dynamic_monitor_config, "r")
if dynamic_monitor_file ~= nil then
    dynamic_monitor_file:close()
    require(dynamic_monitor_config)
end

-- Environment variables
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("DOTFILES", home .. "/.dotfiles")
hl.env(
    "PATH",
    table.concat({
        home .. "/.dotfiles/scripts",
        home .. "/.dotfiles/scripts/k8s",
        home .. "/.local/bin",
        home .. "/.cargo/bin",
        home .. "/go/bin",
        home .. "/.npm-global/bin",
        assert(os.getenv("PATH"), "PATH is not set"),
    }, ":")
)

-- Autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_RUNTIME_DIR PATH")
    hl.exec_cmd("systemctl --user restart hyprdynamicmonitors.service")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("systemctl --user restart waybar.service")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

hl.config({
    input = {
        kb_layout = "pl",
        repeat_delay = 200,
        repeat_rate = 26,
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 3,
        col = {
            active_border = "rgb(4C566A)",
            inactive_border = "rgb(2E3440)",
        },
        layout = "master",
    },
    decoration = {
        rounding = 0,
        blur = {
            enabled = false,
        },
        shadow = {
            enabled = false,
        },
    },
    animations = {
        enabled = true,
    },
    master = {
        new_status = "slave",
        mfact = 0.5,
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
})

-- Animation curves
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0 }, { 0.35, 1 } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.36, 0 }, { 0.66, -0.56 } } })
hl.curve("smoothIn", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

-- Window animations
hl.animation({ leaf = "windowsIn", enabled = false })
hl.animation({ leaf = "windowsOut", enabled = false })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "easeOutQuint" })

-- Fade animations
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 3, bezier = "smoothOut" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 3, bezier = "easeInOutCubic" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 3, bezier = "easeInOutCubic" })

-- Border animations
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "easeOutQuint" })
hl.animation({ leaf = "borderangle", enabled = false })

-- Workspace animations
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })

-- Layer animations
hl.animation({ leaf = "layers", enabled = true, speed = 4, bezier = "smoothIn", style = "slide" })
hl.layer_rule({
    match = { namespace = "notifications" },
    animation = "slide right",
})

-- Keybindings
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("neovide --notabs"))
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd("rofi -show drun -show-icons -auto-select"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("vivaldi"))
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd("rofi-bluetooth"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mod .. " + Tab", hl.dsp.layout("swapwithmaster"))
hl.bind(mod .. " + D", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exec_cmd("systemctl --user restart hyprdynamicmonitors.service"))
hl.bind(mod .. " + O", hl.dsp.exec_cmd("rofi-pass"))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mod .. " + Q", hl.dsp.exec_cmd("rofi -show power-menu -modi power-menu:rofi-power-menu"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("rofi-hypr-windows"))
hl.bind(mod .. " + Y", hl.dsp.workspace.toggle_special("music"))
hl.bind(mod .. " + SHIFT + Y", hl.dsp.window.move({ workspace = "special:music" }))

-- Utilities
hl.bind(mod .. " + P", hl.dsp.exec_cmd([[grim -g "$(slurp -c '##bf616aff'; sleep 0.2)" -t ppm - | satty --filename -]]))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("grim -t ppm - | satty --filename -"))
hl.bind(
    mod .. " + SHIFT + C",
    hl.dsp.exec_cmd([[rofi -show calc -modi calc -no-show-match -no-sort -calc-command "echo -n '{result}' | wl-copy"]])
)
hl.bind(mod .. " + C", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))
hl.bind(
    mod .. " + grave",
    hl.dsp.exec_cmd("rofi -show notifications -modi notifications:rofi-notifications -show-icons")
)

-- Switch between windows
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + Space", hl.dsp.window.cycle_next())

-- Move windows
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))

-- Resize windows
hl.bind(mod .. " + CTRL + H", hl.dsp.layout("mfact -0.05"))
hl.bind(mod .. " + CTRL + L", hl.dsp.layout("mfact +0.05"))
hl.bind(mod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 40, relative = true }))
hl.bind(mod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -40, relative = true }))
hl.bind(mod .. " + CTRL + I", hl.dsp.layout("addmaster"))
hl.bind(mod .. " + CTRL + O", hl.dsp.layout("removemaster"))

-- Window management
hl.bind(mod .. " + N", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + N", hl.dsp.layout("orientationnext"))

-- Switch focus between monitors
hl.bind(mod .. " + period", hl.dsp.focus({ monitor = "+1" }))
hl.bind(mod .. " + comma", hl.dsp.focus({ monitor = "-1" }))

-- Workspaces
for workspace = 1, 9 do
    hl.bind(mod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mod .. " + SHIFT + " .. workspace, hl.dsp.window.move({ workspace = workspace }))
end

-- Volume
hl.bind(mod .. " + F1", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind(mod .. " + Page_Up", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind(mod .. " + Page_Down", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))

-- Brightness
hl.bind(mod .. " + F7", hl.dsp.exec_cmd("brightness up 5"))
hl.bind(mod .. " + F6", hl.dsp.exec_cmd("brightness down 5"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightness up 5"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightness down 5"))

-- Playback
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"))

-- Mouse bindings
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Window rules
hl.window_rule({
    name = "ssh-askpass-float",
    match = { class = "^(ssh-askpass)$" },
    float = true,
})

hl.window_rule({
    name = "pinentry-float",
    match = { class = "^(pinentry-.*)$" },
    float = true,
})

hl.window_rule({
    name = "pavucontrol-float",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name = "picture-in-picture-float",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
})

hl.window_rule({
    name = "file-dialogs-float",
    match = { title = "^(Open Files)$" },
    float = true,
})

hl.window_rule({
    name = "spotify-special-workspace",
    match = { class = "^([Ss]potify)$" },
    workspace = "special:music silent",
})

-- Window rules for JetBrains IDEs running in Wayland mode
hl.window_rule({
    name = "jetbrains-tooltips-no-focus",
    match = {
        class = "^(.*jetbrains.*)$",
        title = "^(win.*)$",
    },
    no_initial_focus = true,
})

hl.window_rule({
    name = "jetbrains-dialogs-stay-focused",
    match = {
        class = "^(.*jetbrains.*)$",
        title = "^$",
        float = true,
    },
    stay_focused = true,
})

hl.window_rule({
    name = "jetbrains-tab-drag-no-focus",
    match = {
        class = "^(.*jetbrains.*)$",
        title = [[^\s$]],
    },
    no_initial_focus = true,
})

hl.window_rule({
    name = "jetbrains-tabs-tile",
    match = {
        class = "^(jetbrains-*)",
        float = false,
    },
    tile = true,
})
