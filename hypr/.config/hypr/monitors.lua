hl.env("GDK_SCALE", "1")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- Apple Studio Display over Thunderbolt. DP-1 exposes only 640x480 and blanks.
hl.monitor({ output = "DP-2", mode = "2560x1440@60", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-1", disabled = true })
