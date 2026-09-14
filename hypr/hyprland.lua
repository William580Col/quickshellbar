-- This is an example Hyprland Lua config file.
-- Refer to the wiki for more information.
-- https://wiki.hypr.land/Configuring/Start/

-- Please note not all available settings / options are set here.
-- For a full list, see the wiki

-- You can (and should!!) split this configuration into multiple files
-- Create your files separately and then require them like this:
-- require("myColors")
-- =====================================================================
------------------
---- MONITORS ----
------------------


-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "LVDS-1",
    mode     = "1366x768@60",
    position = "0x0",
    scale    = "1",
})

---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal    = "alacritty"
local fileManager = "thunar"
local menu        = "fuzzel"


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()

    -- 1. Iniciar el demonio de cliphist para guardar texto
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    
    -- 2. Iniciar el demonio de cliphist para guardar imágenes (por ejemplo, tus capturas con grim)
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    hl.exec_cmd("quickshell -c ~/.config/quickshell")
    hl.exec_cmd("nm-applet --indicator")

end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- Cursores y tamaño
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Variables de idioma (Locale)
hl.env("LANG", "es_CO.UTF-8")
hl.env("LC_ALL", "es_CO.UTF-8")

-- Identificación del entorno de escritorio
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Variables para Steam y Juegos (XWayland)
hl.env("SDL_VIDEODRIVER", "x11") 
hl.env("XMODIFIERS", "")
hl.env("WINE_FULLSCREEN_FOSS", "1") 

-- Apariencia e Interfaz (GTK y QT)
hl.env("ADW_DEBUG_COLOR_SCHEME", "prefer-dark")
hl.env("QT_QPA_PLATFORM", "wayland;xcb") 
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE", "Darkly")



-----------------------
---- LOOK AND FEEL ----
-----------------------
-- Primero cargamos los colores de Matugen de forma global en la memoria
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/colors.lua")

-- Refer to https://hypr.land
-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
-----------------------
---- LOOK AND FEEL ----
-----------------------

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- 1. Intentar cargar de forma segura la tabla de colores generada por Matugen
local success, matugen_colors = pcall(function()
    return loadfile(os.getenv("HOME") .. "/.config/hypr/colors.lua")()
end)

-- 2. Configurar el entorno visual inyectando los colores dinámicos si la carga fue exitosa
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 14,
        border_size = 3,
        layout = "dwindle",
        resize_on_border = false,
        allow_tearing = true,

        -- Si Matugen cargó correctamente la tabla, la inyecta; si no, usa el fallback estático
        col = (success and matugen_colors) or {
            active_border = {
                colors = { "rgba(ffb3b0ee)", "rgba(e3c28cee)" },
                angle = 45,
            },
            inactive_border = "rgba(a08c8baa)",
        },
    },

    decoration = {
        rounding = 0,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = { enabled = false },
        blur = { enabled = false },
    },

    animations = {
        enabled = false,
    },
})




-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

-- Mantenemos las declaraciones por compatibilidad pero las animaciones están apagadas arriba globalmente
hl.animation({ leaf = "global",        enabled = false,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = false,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = false,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = false,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = false,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = false,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = false,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = false,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = false,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = false,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = false,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = false,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = false,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = false,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = false,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = false,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = false,  speed = 7,    bezier = "quick" })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
    dwindle = {
        preserve_split = true,
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
    master = {
        new_status = "master",
    },
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,     -- Desactivar fondos animados pesados
        disable_hyprland_logo   = true,  -- Desactivar el logo aleatorio para ahorrar recursos de arranque
        vrr = 0,                         -- Cambiado a 0 (Apagado) para evitar parpadeos y lag de refresco
        }
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "es",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

-- Example per-device config
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))    -- dwindle only
-- Alternar pantalla completa (Fullscreen) con Super + F
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({}))
-- Abrir Firefox con Super + B
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("firefox"))
-- Abrir Steam con no-cef-sandbox (fix para Hyprland/XWayland)
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("steam --no-cef-sandbox"))
-- Abrir Heroic Games Launcher con Super + ESCAPE
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("heroic"))
-- Captura la pantalla, la guarda en Pictures y la copia al portapapeles
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("grim - | tee ~/Pictures/Screenshot_$(date +'%Y%m%d_%H%M%S').png | wl-copy"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("gnome-calculator"))
-- Captura de región seleccionada con Super + Shift + PrintScreen
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("grim -g \"$(slurp)\" ~/Pictures/Screenshot_$(date +'%Y%m%d_%H%M%S').png"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Activar/Desactivar el modo pestañas (Toggle Group)
hl.bind(mainMod .. " + G", hl.dsp.group.toggle({}))

-- Cambiar a la siguiente ventana/pestaña del grupo
hl.bind(mainMod .. " + TAB", hl.dsp.group.next({}))

-- Cambiar a la pestaña anterior del grupo
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.group.prev({}))

local zoomFactor = 1.0

hl.bind("SUPER + CTRL + mouse_up", function()
  zoomFactor = zoomFactor * 1.1
  hl.config({ cursor = { zoom_factor = zoomFactor } })
end)

hl.bind("SUPER + CTRL + mouse_down", function()
  zoomFactor = zoomFactor * 0.9
  if zoomFactor < 1.0 then zoomFactor = 1.0 end
  hl.config({ cursor = { zoom_factor = zoomFactor } })
end)

hl.config({ binds = { scroll_event_delay = 0 } })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Ignore maximize requests from all apps
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Move kitty to 100 100 and add an anim style (named rule)
hl.window_rule({
  name      = "move-kitty",
  match     = { class = "kitty" },
  move      = {100, 100},
  animation = "popin",
})

-- Disable blur for firefox
hl.window_rule({ match = { class = "firefox" }, no_blur = true })

-- Move kitty to the center of the cursor
hl.window_rule({
  match = { class = "kitty" },
  move  = {"cursor_x-(window_w*0.5)", "cursor_y-(window_h*0.5)"},
})


-- Set opacity to 1.0 active, 0.5 inactive and 0.8 fullscreen for kitty
hl.window_rule({
  match   = { class = "kitty" },
  opacity = "1.0 override 0.5 override 0.8 override",
})

-- Set rounding to 10 for kitty
hl.window_rule({ match = { class = "kitty" }, rounding = 10 })

-- Fix pinentry losing focus
hl.window_rule({
  match       = { class = "(pinentry-)(.*)" },
  stay_focused = true,
})

-- Reglas para Firefox Picture-in-Picture
hl.window_rule({ match = { class = "firefox", title = "Picture-in-Picture" }, float = true })
hl.window_rule({ match = { class = "firefox", title = "Picture-in-Picture" }, pin = true })
hl.window_rule({ match = { class = "firefox", title = "Picture-in-Picture" }, size = "640 360" })
hl.window_rule({ match = { class = "firefox", title = "Picture-in-Picture" }, move = "100%-660 100%-380" })

-- Reglas para Chrome Picture-in-Picture
hl.window_rule({ match = { title = "Pantalla en pantalla" }, float = true })
hl.window_rule({ match = { title = "Pantalla en pantalla" }, pin = true })
hl.window_rule({ match = { title = "Pantalla en pantalla" }, size = "640 360" })
hl.window_rule({ match = { title = "Pantalla en pantalla" }, move = "100%-660 100%-380" })

hl.window_rule({
    name  = "mpv",
    match = {
        class = "^mpv$",
    },     
    float  = true,
    center = true,
    size   = { 920, 780 }, 
})

hl.window_rule({
    name  = "thunar-progress-float-center",
    match = {
        class = "^thunar$",
        title = ".*[Pp]rogreso.*",
    },
    float  = true,
    center = true,
    size   = { 600, 300 },
})

hl.window_rule({
    name  = "thunar-rename-float-center",
    match = {
        class = "^thunar$",
        title = ".*[Rr]enombrar.*",
    },
    float  = true,
    center = true,
    size   = { 600, 300 },
})

hl.window_rule({
    name  = "Gnome Calculator",
    match = {
        class = "^org.gnome.Calculator$",
        title = "Calculadora",
    },
    float  = true,
    center = true,
    size   = { 600, 300 },
})

-- 🎮 REGLAS EXTRA PARA FORZAR RENDIMIENTO INMEDIATO EN JUEGOS XWAYLAND
hl.window_rule({ match = { class = "^steam_app_.*" }, immediate = true })
hl.window_rule({ match = { class = "^heroic$" },      immediate = true })
hl.window_rule({ match = { class = "^gamescope$" },   immediate = true })
