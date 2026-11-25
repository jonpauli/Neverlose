--[[
	NovaUI demo — uses every control and the config system.

	Host main.lua somewhere (or keep both files next to each other) and run:

		local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/<you>/<repo>/main/main.lua"))()
		loadstring(game:HttpGet("https://raw.githubusercontent.com/<you>/<repo>/main/example.lua"))()

	Or locally, with both files in your executor's workspace folder:

		local UI = loadstring(readfile("main.lua"))()
		loadstring(readfile("example.lua"))()
]]

local UI = getgenv().NovaUI

local Window = UI:Window({
	Title = "Nova",
	Subtitle = "internal · build 1.0.0",
	Size = UDim2.fromOffset(700, 470),
	ToggleKey = Enum.KeyCode.RightShift,
})

-- // Combat --------------------------------------------------------------

local Combat = Window:Tab("Combat")
local Aimbot = Combat:Section("Aimbot")
local Weapon = Combat:Section("Weapon")

Aimbot:Toggle("Enabled", true, function(state)
	print("aimbot", state)
end)

Aimbot:Toggle("Silent aim", false, function(state)
	print("silent aim", state)
end, { DependsOn = "Enabled" })

Aimbot:Toggle("Visible only", true, function(state)
	print("visible only", state)
end, { DependsOn = "Enabled" })

Aimbot:Slider("FOV", 0, 360, 120, function(value)
	print("fov", value)
end, 1, { Suffix = "°" })

Aimbot:Slider("Smoothing", 0, 1, 0.35, function(value)
	print("smoothing", value)
end, 0.01)

Aimbot:Dropdown("Target bone", { "Head", "UpperTorso", "LowerTorso", "Random" }, "Head", function(value)
	print("bone", value)
end)

Aimbot:MultiDropdown("Hit parts", { "Head", "Torso", "Arms", "Legs" }, { "Head", "Torso" }, function(values)
	print("parts", table.concat(values, ", "))
end)

Weapon:Dropdown("Priority", { "Closest", "Lowest health", "Most visible" }, "Closest", function(value)
	print("priority", value)
end)

Weapon:Keybind("Toggle key", Enum.KeyCode.F, function(key)
	print("hotkey", key and key.Name or "none")
end)

Weapon:Input("Weapon filter", "ak47", function(text)
	print("filter", text)
end, { Placeholder = "weapon name" })

Weapon:ColorPicker("Highlight color", Color3.fromRGB(139, 92, 246), function(color)
	print("highlight", color)
end)

Weapon:Button("Reset weapon settings", function()
	print("reset weapon settings")
end)

-- // Visuals -------------------------------------------------------------

local Visuals = Window:Tab("Visuals")
local ESP = Visuals:Section("ESP")
local World = Visuals:Section("World")

ESP:Toggle("Enabled", true, function() end)
ESP:Toggle("Boxes", true, function() end, { DependsOn = "Enabled" })
ESP:Toggle("Names", true, function() end, { DependsOn = "Enabled" })
ESP:Toggle("Health bars", false, function() end, { DependsOn = "Enabled" })

ESP:Slider("Max distance", 100, 5000, 1000, function() end, 50, { Suffix = " studs" })
ESP:Slider("Opacity", 0, 1, 0.8, function() end, 0.05)

ESP:MultiDropdown("Elements", { "Box", "Name", "Health", "Distance", "Skeleton" }, { "Box", "Name" }, function() end)
ESP:ColorPicker("Box color", Color3.fromRGB(74, 222, 128), function() end)

World:Dropdown("Time of day", { "Day", "Sunset", "Night" }, "Night", function() end)
World:Toggle("Remove fog", false, function() end)
World:Slider("Field of view", 70, 120, 90, function() end, 1)
World:Keybind("Panic key", Enum.KeyCode.Delete, function()
	Window:Toggle(false)
end)
World:Divider()
World:Label("World settings apply to the local camera only.")

-- // Interface -----------------------------------------------------------

local Interface = Window:Tab("Interface")
local Accent = Interface:Section("Appearance")
local Info = Interface:Section("About")

Accent:Button("Violet", function()
	UI:SetAccent(Color3.fromRGB(139, 92, 246))
end)
Accent:Button("Cyan", function()
	UI:SetAccent(Color3.fromRGB(34, 211, 238))
end)
Accent:Button("Rose", function()
	UI:SetAccent(Color3.fromRGB(244, 114, 182))
end)
Accent:Toggle("Show keybinds in notifications", true, function() end)
Accent:Input("Window title", "Nova", function(text)
	print("title", text)
end)

Info:Label("Every control writes to UI.Flags, split by tab and section.")
Info:Label("Configs save every control on this window, including multi dropdowns, colors and keybinds.")
Info:Divider()
Info:Button("Notify me", function()
	UI:Notify("Nova", "Notifications stack in the bottom right and dismiss themselves.", 4)
end)

Window:ConfigTab("Configs")

UI:Notify("Nova loaded", "Press RightShift to toggle the menu.", 5)
