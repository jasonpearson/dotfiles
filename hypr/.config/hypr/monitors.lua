-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Apple Studio Display over Thunderbolt.
-- Match by description because DP-* output names can change after hotplug/reboot.
hl.monitor({
  output = "desc:Apple Computer Inc StudioDisplay 0xE28178B3",
  mode = "preferred",
  position = "auto",
  scale = 2,
})
