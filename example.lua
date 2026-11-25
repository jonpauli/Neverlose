--[[
	NeverloseUI demo — a replica of the Neverlose menu shell.
	Run it standalone, or keep it as a reference for your own script.
]]

local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/jonpauli/Neverlose/refs/heads/main/main.lua"))()

local Window = UI:Window({
	Title = "neverlose",
	Subtitle = "v2.4  ·  luau",
	ToggleKey = Enum.KeyCode.Insert,
})

UI:Watermark({ Text = "neverlose.cc  ·  guest", FPS = true, Clock = true })

--=============================================================================
-- Rage
--=============================================================================

local Rage = Window:Tab("Rage")

local Aimbot = Rage:Section("Aimbot")

Aimbot:Toggle("Enabled", true, function(state)
	UI:Notify("Aimbot", state and "enabled" or "disabled")
end)

Aimbot:Dropdown("Target", { "Head", "Neck", "Chest", "Stomach" }, "Head", function(pick)
end)

Aimbot:Dropdown("Priorities", { "FOV", "Distance", "Threat" }, { "FOV", "Distance" })

Aimbot:Keybind("Hold key", Enum.KeyCode.E, function()
end)

Aimbot:Slider("FOV", 0, 180, 90)
Aimbot:Slider("Smoothing", 0.1, 1, 0.45)
Aimbot:Slider("Max distance", 0, 500, 250)

local Weapon = Rage:Section("Weapon", "Right")

Weapon:Toggle("Auto fire", false)
Weapon:Dropdown("Hitbox override", { "Auto", "Head", "Body", "Legs" }, "Auto")
Weapon:Slider("Hitchance", 0, 100, 65)
Weapon:Slider("Min damage", 0, 100, 25)
Weapon:Divider()
Weapon:Button("Reset settings", function()
	UI:Notify("Weapon", "settings reset")
end)

local Exploits = Rage:Section("Exploits", "Right")

Exploits:Toggle("Auto peek", false)
Exploits:Toggle("Double tap", true)
Exploits:Dropdown("Mode", { "Instant", "Legit", "Safe" }, "Legit")
Exploits:Keybind("Panic key", Enum.KeyCode.Delete)
Exploits:Label("Holds the current target while the key is down.")

--=============================================================================
-- Visuals
--=============================================================================

local Visuals = Window:Tab("Visuals")

local ESP = Visuals:Section("ESP")

ESP:Toggle("Enabled", true)
ESP:Toggle("Box", true)
ESP:Toggle("Skeleton", false)
ESP:Toggle("Health bar", true)
ESP:Dropdown("Team check", { "Enemies", "All", "Ignore team" }, "Enemies")
ESP:ColorPicker("Visible color", Color3.fromRGB(0, 158, 255))
ESP:ColorPicker("Occluded color", Color3.fromRGB(255, 74, 74))

local World = Visuals:Section("World", "Right")

World:Toggle("Dropped weapons", false)
World:Toggle("Bomb timer", true)
World:Slider("Render distance", 50, 2000, 750)
World:Dropdown("FOV circle", { "Off", "Static", "Dynamic" }, "Dynamic")
World:Input("Name filter", "", function(text)
end, "player name")

local Removals = Visuals:Section("Removals", "Right")

Removals:Toggle("No flash", true)
Removals:Toggle("No smoke", true)
Removals:Toggle("No scope", false)
Removals:Toggle("No recoil", false)

--=============================================================================
-- Misc
--=============================================================================

local Misc = Window:Tab("Misc")

local Movement = Misc:Section("Movement")

Movement:Toggle("Bunny hop", false)
Movement:Keybind("Speed key", Enum.KeyCode.LeftShift)
Movement:Slider("Speed multiplier", 1, 5, 1.2)
Movement:Slider("Jump height", 0, 100, 50)

local Settings = Misc:Section("Menu", "Right")

Settings:Dropdown("Accent", { "Blue", "Red", "Green", "White" }, "Blue", function(pick)
	local colors = {
		Blue = Color3.fromRGB(0, 158, 255),
		Red = Color3.fromRGB(255, 74, 74),
		Green = Color3.fromRGB(72, 214, 122),
		White = Color3.fromRGB(235, 235, 240),
	}
	UI:SetAccent(colors[pick] or colors.Blue)
end)

Settings:Slider("Menu scale", 0.7, 1.5, 1)
Settings:Toggle("Stream proof", false)
Settings:Keybind("Menu key", Enum.KeyCode.Insert)

UI:Notify("neverlose", "loaded in 0.42s", 3)
