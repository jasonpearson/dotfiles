-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Apple Studio Display over Thunderbolt.
-- It exposes two DP streams with the same description; after reboot the stream
-- with real display modes is DP-2 while DP-1 only exposes 640x480 and produces
-- a blank display.
hl.monitor({ output = "DP-2", mode = "2560x1440@60", position = "0x0", scale = omarchy_monitor_scale })
hl.monitor({ output = "DP-1", disabled = true })
