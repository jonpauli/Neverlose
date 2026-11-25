--[[
	NovaUI
	A modern, animated, single-file Roblox UI library.

	Features:
		Window with sidebar tabs and scrolling cards
		Toggle, dependency toggles, sliders, dropdowns, multi dropdowns,
		buttons, text inputs, keybinds, HSV color pickers, labels, dividers
		Smooth animations on window, tabs, toggles, sliders, dropdowns,
		buttons, notifications and dependency reveals
		Config system: save / load / list / delete / reset / auto-save
		Works from `loadstring` and stores itself at getgenv().NovaUI

	Interface code only. Nothing here touches gameplay.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Library = {
	Flags = {},
	Version = "1.0.0",
	_capturing = false,
}
Library.__index = Library

-- // Theme ---------------------------------------------------------------

local Theme = {
	Accent = Color3.fromRGB(139, 92, 246),
	AccentSoft = Color3.fromRGB(46, 34, 74),
	Background = Color3.fromRGB(11, 11, 15),
	Sidebar = Color3.fromRGB(16, 16, 21),
	Panel = Color3.fromRGB(18, 18, 24),
	Control = Color3.fromRGB(25, 25, 33),
	ControlHover = Color3.fromRGB(32, 32, 42),
	Track = Color3.fromRGB(38, 38, 48),
	Stroke = Color3.fromRGB(42, 42, 55),
	Text = Color3.fromRGB(240, 240, 247),
	Muted = Color3.fromRGB(143, 143, 162),
	Success = Color3.fromRGB(74, 222, 128),
	Danger = Color3.fromRGB(248, 113, 113),
}
Library.Theme = Theme

-- // Instance helpers ----------------------------------------------------

local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = inst
	return c
end

local function stroke(inst, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Stroke
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function tween(inst, props, time, style, dir)
	if not inst then return nil end
	local info = TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
	local tw = TweenService:Create(inst, info, props)
	tw:Play()
	return tw
end

local function textLabel(props, parent)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	if parent then
		p.Parent = parent
	end
	return new("TextLabel", p)
end

local function runCallback(callback, ...)
	if type(callback) ~= "function" then return end
	local args = { ... }
	task.spawn(function()
		local ok, err = pcall(callback, table.unpack(args))
		if not ok then
			warn("[NovaUI] callback error: " .. tostring(err))
		end
	end)
end

local accentBindings = {}
local repaints = {}

local function bindAccent(fn)
	table.insert(accentBindings, fn)
	pcall(fn)
end

local function onRepaint(fn)
	table.insert(repaints, fn)
end

local function guiParent()
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end
	local ok, cg = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and cg then
		return cg
	end
	if LocalPlayer then
		local ok2, pg = pcall(function()
			return LocalPlayer:WaitForChild("PlayerGui")
		end)
		if ok2 then
			return pg
		end
	end
	return nil
end

local function attachGui(gui)
	local parent = guiParent()
	if parent then
		local ok = pcall(function()
			gui.Parent = parent
		end)
		if ok and gui.Parent then
			return true
		end
	end
	if LocalPlayer then
		local ok = pcall(function()
			gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
		end)
		if ok and gui.Parent then
			return true
		end
	end
	return false
end

-- drags the mouse/touch pointer inside `hit`, calling onMove(x, y)
local function bindDrag(hit, onMove)
	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		onMove(input.Position.X, input.Position.Y)
		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
				onMove(i.Position.X, i.Position.Y)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				if moveConn then moveConn:Disconnect() end
				if endConn then endConn:Disconnect() end
			end
		end)
	end)
end

-- // JSON ----------------------------------------------------------------

local JSON = {}

local ESCAPES = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
	["\b"] = "\\b",
	["\f"] = "\\f",
}

local function encodeString(value)
	return '"' .. value:gsub('[%c"\\]', function(c)
		return ESCAPES[c] or string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

local function encodeValue(value)
	local t = type(value)
	if t == "string" then
		return encodeString(value)
	elseif t == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "0"
		end
		return string.format("%.14g", value)
	elseif t == "boolean" then
		return value and "true" or "false"
	elseif t == "table" then
		local count, isArray = 0, true
		for k in pairs(value) do
			count += 1
			if type(k) ~= "number" then
				isArray = false
			end
		end
		if count == 0 then
			return "[]"
		end
		local parts = {}
		if isArray then
			for _, item in ipairs(value) do
				parts[#parts + 1] = encodeValue(item)
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		for k, item in pairs(value) do
			parts[#parts + 1] = encodeString(tostring(k)) .. ":" .. encodeValue(item)
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local function decodeValue(text)
	local pos = 1
	local len = #text

	local function peek()
		return text:sub(pos, pos)
	end

	local function skip()
		while pos <= len do
			local c = text:sub(pos, pos)
			if c == " " or c == "\n" or c == "\t" or c == "\r" then
				pos += 1
			else
				break
			end
		end
	end

	local parseValue

	local function parseString()
		pos += 1
		local out = {}
		while pos <= len do
			local c = text:sub(pos, pos)
			if c == '"' then
				pos += 1
				return table.concat(out)
			elseif c == "\\" then
				local n = text:sub(pos + 1, pos + 1)
				pos += 2
				if n == "n" then
					out[#out + 1] = "\n"
				elseif n == "t" then
					out[#out + 1] = "\t"
				elseif n == "r" then
					out[#out + 1] = "\r"
				elseif n == "b" then
					out[#out + 1] = "\b"
				elseif n == "f" then
					out[#out + 1] = "\f"
				elseif n == "u" then
					local hex = text:sub(pos, pos + 3)
					pos += 4
					out[#out + 1] = utf8.char(tonumber(hex, 16) or 63)
				else
					out[#out + 1] = n
				end
			else
				out[#out + 1] = c
				pos += 1
			end
		end
		error("unterminated string")
	end

	local function parseNumber()
		local s, e = text:find("^-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
		if not s then
			error("invalid number")
		end
		local num = tonumber(text:sub(s, e))
		if not num then
			error("invalid number")
		end
		pos = e + 1
		return num
	end

	local function parseArray()
		pos += 1
		local out = {}
		skip()
		if peek() == "]" then
			pos += 1
			return out
		end
		while true do
			out[#out + 1] = parseValue()
			skip()
			local c = peek()
			if c == "," then
				pos += 1
			elseif c == "]" then
				pos += 1
				break
			else
				error("invalid array")
			end
		end
		return out
	end

	local function parseObject()
		pos += 1
		local out = {}
		skip()
		if peek() == "}" then
			pos += 1
			return out
		end
		while true do
			skip()
			if peek() ~= '"' then
				error("invalid object key")
			end
			local key = parseString()
			skip()
			if peek() ~= ":" then
				error("missing colon")
			end
			pos += 1
			out[key] = parseValue()
			skip()
			local c = peek()
			if c == "," then
				pos += 1
			elseif c == "}" then
				pos += 1
				break
			else
				error("invalid object")
			end
		end
		return out
	end

	function parseValue()
		skip()
		local c = peek()
		if c == '"' then
			return parseString()
		elseif c == "{" then
			return parseObject()
		elseif c == "[" then
			return parseArray()
		elseif c == "t" then
			pos += 4
			return true
		elseif c == "f" then
			pos += 5
			return false
		elseif c == "n" then
			pos += 4
			return nil
		end
		return parseNumber()
	end

	local result = parseValue()
	skip()
	if pos <= len then
		error("trailing data")
	end
	return result
end

function JSON.encode(value)
	return encodeValue(value)
end

function JSON.decode(text)
	local ok, result = pcall(decodeValue, text)
	if ok then
		return result
	end
	return nil
end

-- // File storage --------------------------------------------------------

local FS = {
	available = typeof(writefile) == "function" and typeof(readfile) == "function",
	mem = {},
}

local function ensureFolders(path)
	if not FS.available then return end
	if typeof(makefolder) ~= "function" then return end
	local parts = {}
	for segment in string.gmatch(path, "[^/\\]+") do
		parts[#parts + 1] = segment
	end
	local acc = nil
	for _, segment in ipairs(parts) do
		if acc then
			acc = acc .. "/" .. segment
		else
			acc = segment
		end
		local exists = false
		if typeof(isfolder) == "function" then
			local ok, result = pcall(isfolder, acc)
			if ok then
				exists = result
			end
		end
		if not exists then
			pcall(makefolder, acc)
		end
	end
end

local function writeRaw(path, data)
	if FS.available then
		local ok, err = pcall(writefile, path, data)
		if not ok then
			return false, tostring(err)
		end
		return true
	end
	FS.mem[path] = data
	return true
end

local function readRaw(path)
	if FS.available then
		local ok, data = pcall(readfile, path)
		if ok and type(data) == "string" then
			return data
		end
		return nil
	end
	return FS.mem[path]
end

local function deleteRaw(path)
	if FS.available then
		if typeof(delfile) == "function" then
			local ok, err = pcall(delfile, path)
			if not ok then
				return false, tostring(err)
			end
			return true
		end
		return false, "delfile unavailable"
	end
	FS.mem[path] = nil
	return true
end

local function listRaw(folder)
	if FS.available and typeof(listfiles) == "function" then
		local ok, files = pcall(listfiles, folder)
		if ok and type(files) == "table" then
			return files
		end
		return {}
	end
	local out = {}
	local prefix = folder .. "/"
	for path in pairs(FS.mem) do
		if path:sub(1, #prefix) == prefix then
			out[#out + 1] = path
		end
	end
	return out
end

-- // Config --------------------------------------------------------------

local Config = {
	Folder = "NovaUI/Configs",
	Extension = ".json",
	Entries = {},
	Dirty = false,
	AutoName = nil,
	AutoInterval = 30,
}

Library.Config = Config

function Config:IsFileSystemAvailable()
	return FS.available
end

function Config:SetFolder(folder)
	if folder and tostring(folder) ~= "" then
		self.Folder = tostring(folder)
	end
	ensureFolders(self.Folder)
	return self
end

function Config:Path(name)
	return self.Folder .. "/" .. name .. self.Extension
end

function Config:_clean(name)
	name = tostring(name or ""):gsub("[^%w%-_ ]", "")
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if #name == 0 then
		return nil
	end
	if #name > 32 then
		name = name:sub(1, 32)
	end
	return name
end

function Config:Register(id, entry)
	self.Entries[id] = entry
end

function Config:MarkDirty()
	self.Dirty = true
end

function Config:Collect()
	local values = {}
	for id, entry in pairs(self.Entries) do
		if entry.Save then
			local ok, value = pcall(entry.Save)
			if ok and value ~= nil then
				values[id] = value
			end
		end
	end
	return values
end

function Config:Apply(values)
	local applied = 0
	for id, entry in pairs(self.Entries) do
		local value = values[id]
		if value ~= nil and entry.Load then
			if pcall(entry.Load, value) then
				applied += 1
			end
		end
	end
	self.Dirty = false
	return applied
end

function Config:Save(name)
	local clean = self:_clean(name)
	if not clean then
		return false, "Enter a valid config name."
	end
	self:SetFolder(self.Folder)
	local payload = {
		version = 1,
		saved = os.time(),
		values = self:Collect(),
	}
	local ok, err = writeRaw(self:Path(clean), JSON.encode(payload))
	if not ok then
		return false, err or "Could not write the config file."
	end
	self.Dirty = false
	return true, clean
end

function Config:Load(name)
	local clean = self:_clean(name)
	if not clean then
		return false, "Enter a valid config name."
	end
	local data = readRaw(self:Path(clean))
	if not data then
		return false, "Config not found."
	end
	local decoded = JSON.decode(data)
	if type(decoded) ~= "table" or type(decoded.values) ~= "table" then
		return false, "That config file is invalid."
	end
	local applied = self:Apply(decoded.values)
	return true, applied
end

function Config:Delete(name)
	local clean = self:_clean(name)
	if not clean then
		return false, "Enter a valid config name."
	end
	local ok, err = deleteRaw(self:Path(clean))
	if not ok then
		return false, err or "Could not delete the config."
	end
	return true, clean
end

function Config:List()
	self:SetFolder(self.Folder)
	local out = {}
	for _, path in ipairs(listRaw(self.Folder)) do
		local base = path:match("([^/\\]+)$") or path
		if base:sub(-#self.Extension) == self.Extension then
			local name = base:sub(1, #base - #self.Extension)
			if #name > 0 then
				out[#out + 1] = name
			end
		end
	end
	table.sort(out, function(a, b)
		return a:lower() < b:lower()
	end)
	return out
end

function Config:Reset()
	for _, entry in pairs(self.Entries) do
		if entry.Reset then
			pcall(entry.Reset)
		end
	end
	self.Dirty = false
	return true
end

function Config:AutoSave(name, interval)
	self.AutoName = name and self:_clean(name) or nil
	self.AutoInterval = math.max(5, tonumber(interval) or 30)
	if self.AutoName and not self._autoRunning then
		self._autoRunning = true
		task.spawn(function()
			while self.AutoName do
				task.wait(self.AutoInterval)
				if self.AutoName and self.Dirty then
					self:Save(self.AutoName)
				end
			end
			self._autoRunning = false
		end)
	end
	return self.AutoName ~= nil
end

-- // Notifications -------------------------------------------------------

local toastGui = nil
local toastHolder = nil
local toastCount = 0

local function ensureToasts()
	if toastGui and toastGui.Parent ~= nil and toastHolder then
		return toastHolder
	end
	toastGui = new("ScreenGui", {
		Name = "NovaUI_Toasts",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 2000,
	})
	if not attachGui(toastGui) then
		toastGui = nil
		return nil
	end
	toastHolder = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 300, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = toastGui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Parent = toastHolder,
	})
	return toastHolder
end

function Library:Notify(title, body, duration)
	duration = tonumber(duration) or 4
	local holder = ensureToasts()
	if not holder then
		return
	end
	toastCount += 1

	local card = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		LayoutOrder = toastCount,
		Parent = holder,
	})
	corner(card, 10)
	stroke(card, Theme.Stroke, 1, 0.3)
	local cardScale = new("UIScale", { Scale = 0.95, Parent = card })

	local accent = new("Frame", {
		Size = UDim2.new(0, 3, 1, -20),
		Position = UDim2.new(0, 0, 0, 10),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = card,
	})
	corner(accent, 2)

	textLabel({
		Text = tostring(title or "Notification"),
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
	}, card)

	textLabel({
		Text = tostring(body or ""),
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -30, 0, 26),
		TextSize = 11,
		TextColor3 = Theme.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)

	local progress = new("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = card,
	})
	corner(progress, 1)

	tween(card, { GroupTransparency = 0 }, 0.25)
	tween(cardScale, { Scale = 1 }, 0.32)
	tween(progress, { Size = UDim2.new(0, 0, 0, 2) }, duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	local dismissed = false
	local function dismiss()
		if dismissed then return end
		dismissed = true
		tween(card, { GroupTransparency = 1 }, 0.2)
		tween(cardScale, { Scale = 1.03 }, 0.2)
		task.delay(0.25, function()
			if card and card.Parent then
				card:Destroy()
			end
		end)
	end

	task.delay(duration, dismiss)
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dismiss()
		end
	end)
	return dismiss
end

-- // Window --------------------------------------------------------------

local TabAPI = {}
TabAPI.__index = TabAPI

local SectionAPI = {}
SectionAPI.__index = SectionAPI

local WindowAPI = {}
WindowAPI.__index = WindowAPI

function Library:Window(config)
	config = config or {}
	local win = setmetatable({}, WindowAPI)
	win.Title = tostring(config.Title or "Nova")
	win.Subtitle = tostring(config.Subtitle or ("v" .. Library.Version))
	win.ToggleKey = config.ToggleKey ~= nil and config.ToggleKey or Enum.KeyCode.RightShift
	win.Size = config.Size or UDim2.fromOffset(700, 470)
	win.Tabs = {}
	win.Deps = {}
	win.Dropdowns = {}
	win.Connections = {}
	win.Flags = Library.Flags
	win.Visible = true
	win.Current = nil
	win.Destroyed = false

	local gui = new("ScreenGui", {
		Name = "NovaUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000,
	})
	win.Gui = gui

	local shadow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(win.Size.X.Scale, win.Size.X.Offset + 30, win.Size.Y.Scale, win.Size.Y.Offset + 30),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Parent = gui,
	})
	corner(shadow, 24)
	win.Shadow = shadow

	local root = new("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = win.Size,
		BackgroundColor3 = Theme.Background,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		GroupTransparency = 1,
		Parent = gui,
	})
	corner(root, 14)
	stroke(root, Theme.Stroke, 1, 0.35)
	local winScale = new("UIScale", { Scale = 0.96, Parent = root })
	win.Root = root
	win.Scale = winScale

	-- sidebar rail
	local sidebar = new("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(0, 72, 1, -16),
		BackgroundColor3 = Theme.Sidebar,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Parent = root,
	})
	corner(sidebar, 10)
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sidebar,
	})
	new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 9),
		PaddingRight = UDim.new(0, 9),
		Parent = sidebar,
	})
	win.Sidebar = sidebar

	local brand = new("Frame", {
		Size = UDim2.new(0, 28, 0, 28),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		LayoutOrder = 0,
		Parent = sidebar,
	})
	corner(brand, 9)
	local brandGradient = new("UIGradient", {
		Rotation = 45,
		Color = ColorSequence.new(Theme.Accent, Color3.fromRGB(96, 165, 250)),
		Parent = brand,
	})
	bindAccent(function()
		brand.BackgroundColor3 = Theme.Accent
		brandGradient.Color = ColorSequence.new(Theme.Accent, Color3.fromRGB(96, 165, 250))
	end)
	textLabel({
		Text = "N",
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	}, brand)

	local version = textLabel({
		Text = "v" .. Library.Version,
		Size = UDim2.new(0, 72, 0, 12),
		Position = UDim2.new(0, 8, 1, -22),
		TextSize = 9,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	}, root)
	version.Text = "v" .. Library.Version

	-- header
	local header = new("Frame", {
		Position = UDim2.fromOffset(92, 0),
		Size = UDim2.new(1, -106, 0, 58),
		BackgroundTransparency = 1,
		Active = true,
		Parent = root,
	})
	win.Header = header

	textLabel({
		Text = win.Title,
		Position = UDim2.fromOffset(2, 12),
		Size = UDim2.new(1, -70, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
	}, header)

	textLabel({
		Text = win.Subtitle,
		Position = UDim2.fromOffset(2, 31),
		Size = UDim2.new(1, -70, 0, 14),
		TextSize = 11,
		TextColor3 = Theme.Muted,
	}, header)

	local hide = new("TextButton", {
		Size = UDim2.fromOffset(46, 22),
		Position = UDim2.new(1, -46, 0, 17),
		BackgroundColor3 = Theme.Control,
		AutoButtonColor = false,
		Text = "HIDE",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = Theme.Muted,
		Parent = header,
	})
	corner(hide, 6)
	hide.MouseEnter:Connect(function()
		tween(hide, { BackgroundColor3 = Theme.ControlHover }, 0.15)
	end)
	hide.MouseLeave:Connect(function()
		tween(hide, { BackgroundColor3 = Theme.Control }, 0.15)
	end)
	hide.MouseButton1Click:Connect(function()
		win:Toggle(false)
	end)

	new("Frame", {
		Position = UDim2.fromOffset(92, 58),
		Size = UDim2.new(1, -106, 0, 1),
		BackgroundColor3 = Theme.Stroke,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = root,
	})

	local content = new("Frame", {
		Position = UDim2.fromOffset(92, 70),
		Size = UDim2.new(1, -106, 1, -84),
		BackgroundTransparency = 1,
		Parent = root,
	})
	win.Content = content

	-- floating layer for dropdown lists and color popups, above the scroll
	local overlay = new("Frame", {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		Active = false,
		ClipsDescendants = false,
		ZIndex = 50,
		Parent = root,
	})
	win.Overlay = overlay

	-- drag
	local dragOffset = Vector2.new(0, 0)
	local dragging = false
	header.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(i)
			if not dragging then return end
			if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local scale = winScale.Scale
			if scale <= 0 then scale = 1 end
			dragOffset = Vector2.new(dragOffset.X + i.Delta.X / scale, dragOffset.Y + i.Delta.Y / scale)
			root.Position = UDim2.new(0.5, dragOffset.X, 0.5, dragOffset.Y)
			shadow.Position = root.Position
		end)
		endConn = UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				if moveConn then moveConn:Disconnect() end
				if endConn then endConn:Disconnect() end
			end
		end)
	end)

	-- toggle key
	local toggleConn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed or Library._capturing then return end
		if input.KeyCode ~= win.ToggleKey then return end
		if UserInputService:GetFocusedTextBox() then return end
		win:Toggle()
	end)
	table.insert(win.Connections, toggleConn)

	if not attachGui(gui) then
		warn("[NovaUI] Could not attach the interface to a GUI parent.")
	end

	if config.Accent then
		Library:SetAccent(config.Accent)
	end

	tween(root, { GroupTransparency = 0 }, 0.28)
	tween(winScale, { Scale = 1 }, 0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	return win
end

function WindowAPI:_placePopup(popup, anchor, width, height, opts)
	opts = opts or {}
	local scale = self.Scale.Scale
	if scale <= 0 then
		scale = 1
	end
	local rootPosition = self.Root.AbsolutePosition
	local windowWidth = self.Root.AbsoluteSize.X / scale
	local windowHeight = self.Root.AbsoluteSize.Y / scale
	local margin = opts.Margin or 8
	local gap = opts.Gap or 6

	local anchorX = (anchor.AbsolutePosition.X - rootPosition.X) / scale
	local anchorY = (anchor.AbsolutePosition.Y - rootPosition.Y) / scale
	local anchorWidth = anchor.AbsoluteSize.X / scale
	local anchorHeight = anchor.AbsoluteSize.Y / scale

	local popupWidth = width or anchorWidth
	local spaceBelow = windowHeight - (anchorY + anchorHeight) - margin
	local spaceAbove = anchorY - margin
	local placeAbove = false
	local maxHeight = height

	if spaceBelow >= height then
		placeAbove = false
	elseif spaceAbove >= height then
		placeAbove = true
	else
		placeAbove = spaceAbove > spaceBelow
		local available = placeAbove and spaceAbove or spaceBelow
		maxHeight = math.max(48, math.floor(available))
	end

	local x
	if opts.AlignRight then
		x = anchorX + anchorWidth - popupWidth
	else
		x = anchorX
	end
	x = math.clamp(x, margin, math.max(margin, windowWidth - popupWidth - margin))

	if placeAbove then
		popup.AnchorPoint = Vector2.new(0, 1)
		popup.Position = UDim2.fromOffset(x, anchorY - gap)
	else
		popup.AnchorPoint = Vector2.new(0, 0)
		popup.Position = UDim2.fromOffset(x, anchorY + anchorHeight + gap)
	end

	return popupWidth, maxHeight
end

function WindowAPI:_track(connection)
	if connection and connection.Disconnect then
		table.insert(self.Connections, connection)
	end
	return connection
end

function WindowAPI:RefreshDeps()
	for _, fn in ipairs(self.Deps) do
		pcall(fn)
	end
end

function WindowAPI:CloseDropdowns(except)
	for _, entry in ipairs(self.Dropdowns) do
		if entry ~= except then
			pcall(function()
				entry:Close()
			end)
		end
	end
end

function WindowAPI:Toggle(visible)
	if self.Destroyed then return end
	if visible == nil then
		visible = not self.Visible
	end
	if visible == self.Visible then return end
	self.Visible = visible
	if visible then
		self.Root.Visible = true
		self.Root.GroupTransparency = 1
		self.Scale.Scale = 0.96
		tween(self.Root, { GroupTransparency = 0 }, 0.22)
		tween(self.Scale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		tween(self.Shadow, { BackgroundTransparency = 0.75 }, 0.22)
	else
		self:CloseDropdowns(nil)
		tween(self.Root, { GroupTransparency = 1 }, 0.18)
		tween(self.Scale, { Scale = 0.96 }, 0.2)
		tween(self.Shadow, { BackgroundTransparency = 1 }, 0.2)
		task.delay(0.21, function()
			if not self.Visible and not self.Destroyed then
				self.Root.Visible = false
			end
		end)
	end
end

function WindowAPI:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self.Visible = false
	for _, connection in ipairs(self.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	self.Connections = {}
	Library._capturing = false
	tween(self.Root, { GroupTransparency = 1 }, 0.18)
	tween(self.Scale, { Scale = 0.95 }, 0.2)
	tween(self.Shadow, { BackgroundTransparency = 1 }, 0.2)
	task.delay(0.22, function()
		pcall(function()
			self.Gui:Destroy()
		end)
	end)
end

-- // Tabs ----------------------------------------------------------------

function WindowAPI:Tab(name)
	name = tostring(name)
	for _, existing in ipairs(self.Tabs) do
		if existing.Name == name then
			return existing
		end
	end

	local tab = setmetatable({
		Name = name,
		Window = self,
		Index = #self.Tabs + 1,
		Sections = {},
	}, TabAPI)

	local button = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Control,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = tab.Index,
		Parent = self.Sidebar,
	})
	corner(button, 9)
	local bar = new("Frame", {
		Size = UDim2.new(0, 3, 0, 18),
		Position = UDim2.new(0, 0, 0.5, -9),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = button,
	})
	corner(bar, 2)
	local label = textLabel({
		Text = name,
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -8, 1, 0),
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, button)
	label.ZIndex = 2

	tab.Button = button
	tab.Bar = bar
	tab.Label = label

	local page = new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = self.Content,
	})
	local pageScale = new("UIScale", { Scale = 1, Parent = page })
	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		ScrollBarImageTransparency = 0.2,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = page,
	})
	new("UIPadding", {
		PaddingRight = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 6),
		Parent = scroll,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	table.insert(self.Connections, scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if self.Current == tab then
			self:CloseDropdowns(nil)
		end
	end))
	tab.Page = page
	tab.PageScale = pageScale
	tab.Scroll = scroll

	button.MouseButton1Click:Connect(function()
		self:SetTab(tab)
	end)
	button.MouseEnter:Connect(function()
		if self.Current ~= tab then
			tween(button, { BackgroundTransparency = 0.9 }, 0.15)
		end
	end)
	button.MouseLeave:Connect(function()
		if self.Current ~= tab then
			tween(button, { BackgroundTransparency = 1 }, 0.15)
		end
	end)

	table.insert(self.Tabs, tab)
	if not self.Current then
		self:SetTab(tab)
	end
	return tab
end

function TabAPI:_setActive(active)
	tween(self.Button, { BackgroundColor3 = Theme.Control }, 0.18)
	tween(self.Button, { BackgroundTransparency = active and 0 or 1 }, 0.18)
	tween(self.Label, { TextColor3 = active and Theme.Text or Theme.Muted }, 0.18)
	tween(self.Bar, { BackgroundTransparency = active and 0 or 1 }, 0.2)
end

function WindowAPI:SetTab(tab)
	local target = tab
	if type(tab) == "string" then
		for _, candidate in ipairs(self.Tabs) do
			if candidate.Name == tab then
				target = candidate
				break
			end
		end
	end
	if not target or target == self.Current or not target.Page then
		return
	end
	self:CloseDropdowns(nil)
	local previous = self.Current
	self.Current = target
	if previous then
		previous.Page.Visible = false
		previous:_setActive(false)
	end
	target.Page.Visible = true
	target.Page.GroupTransparency = 1
	target.PageScale.Scale = 0.985
	tween(target.Page, { GroupTransparency = 0 }, 0.25)
	tween(target.PageScale, { Scale = 1 }, 0.3)
	target:_setActive(true)
end

-- // Sections ------------------------------------------------------------

function TabAPI:Section(name, opts)
	opts = opts or {}
	name = tostring(name)
	local tabName = self.Name
	local flagsForTab = self.Window.Flags[tabName]
	if not flagsForTab then
		flagsForTab = {}
		self.Window.Flags[tabName] = flagsForTab
	end
	if not flagsForTab[name] then
		flagsForTab[name] = {}
	end

	local section = setmetatable({
		Name = name,
		Tab = self,
		Window = self.Window,
		Flags = flagsForTab[name],
		Id = tabName .. "/" .. name,
		_last = 0,
	}, SectionAPI)

	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LayoutOrder = #self.Sections + 1,
		Parent = self.Scroll,
	})
	corner(card, 12)
	local cardStroke = stroke(card, Theme.Stroke, 1, 0.45)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		Parent = card,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = card,
	})

	local head = new("Frame", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		LayoutOrder = 0,
		Parent = card,
	})
	local accentBar = new("Frame", {
		Size = UDim2.fromOffset(3, 12),
		Position = UDim2.new(0, 0, 0.5, -6),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = head,
	})
	corner(accentBar, 2)
	bindAccent(function()
		accentBar.BackgroundColor3 = Theme.Accent
	end)
	textLabel({
		Text = name,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -10, 1, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
	}, head)

	local bodyOrder = 1
	if opts.Description then
		textLabel({
			Text = tostring(opts.Description),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 10,
			TextColor3 = Theme.Muted,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 1,
		}, card)
		bodyOrder = 2
	end

	section.Body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = bodyOrder,
		Parent = card,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = section.Body,
	})
	section.Card = card

	card.MouseEnter:Connect(function()
		tween(cardStroke, { Transparency = 0.2 }, 0.2)
	end)
	card.MouseLeave:Connect(function()
		tween(cardStroke, { Transparency = 0.45 }, 0.2)
	end)

	table.insert(self.Sections, section)
	return section
end

function SectionAPI:_order()
	self._last += 1
	return self._last
end

function SectionAPI:_row(height, opts)
	opts = opts or {}
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = not opts.Unclipped,
		LayoutOrder = self:_order(),
		Parent = self.Body,
	})
	corner(row, 8)
	return row
end

function SectionAPI:_register(name, saveFn, loadFn, resetFn, opts)
	if opts and opts.NoSave then
		return
	end
	Library.Config:Register(self.Id .. "/" .. name, {
		Save = saveFn,
		Load = loadFn,
		Reset = resetFn,
	})
end

local function dependencyCheck(section, opts)
	if opts.Dependency then
		return opts.Dependency
	end
	local dep = opts.DependsOn
	if dep == nil then
		return nil
	end
	if type(dep) == "string" then
		return function()
			local value = section.Flags[dep]
			return value ~= nil and value ~= false
		end
	end
	if type(dep) == "table" then
		local tabName = dep.Tab or section.Tab.Name
		local flagsForTab = section.Window.Flags[tabName]
		local target = flagsForTab and flagsForTab[dep.Section or section.Name]
		local wanted = dep.Value
		return function()
			if not target then
				return false
			end
			local value = target[dep.Name]
			if wanted == nil then
				return value ~= nil and value ~= false
			end
			return value == wanted
		end
	end
	return nil
end

function SectionAPI:_dependency(row, heightFn, opts)
	local check = dependencyCheck(self, opts or {})
	if not check then
		return
	end
	local shown = nil
	local function apply(animate)
		local ok, wanted = pcall(check)
		wanted = (ok and wanted) and true or false
		if shown == wanted then
			return
		end
		local first = shown == nil
		shown = wanted
		if wanted then
			row.Visible = true
			if first or not animate then
				row.Size = UDim2.new(1, 0, 0, heightFn())
			else
				row.Size = UDim2.new(1, 0, 0, 0)
				tween(row, { Size = UDim2.new(1, 0, 0, heightFn()) }, 0.26)
			end
		else
			self.Window:CloseDropdowns(nil)
			if first or not animate then
				row.Size = UDim2.new(1, 0, 0, 0)
				row.Visible = false
			else
				tween(row, { Size = UDim2.new(1, 0, 0, 0) }, 0.2)
				task.delay(0.22, function()
					if shown == false then
						row.Visible = false
					end
				end)
			end
		end
	end
	apply(false)
	table.insert(self.Window.Deps, function()
		apply(true)
	end)
end

-- // Toggle --------------------------------------------------------------

function SectionAPI:Toggle(name, default, callback, opts)
	opts = opts or {}
	name = tostring(name)
	default = default and true or false

	local row = self:_row(32)
	textLabel({
		Text = name,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -70, 1, 0),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local track = new("Frame", {
		Size = UDim2.fromOffset(38, 20),
		Position = UDim2.new(1, -46, 0.5, -10),
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		Parent = row,
	})
	corner(track, 10)

	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(knob, 7)
	local knobScale = new("UIScale", { Scale = 1, Parent = knob })

	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 4,
		Parent = row,
	})

	local state = default
	local window, section = self.Window, self
	local obj = {}

	local function paint(animate)
		local color = state and Theme.Accent or Theme.Track
		local position = state and UDim2.fromOffset(28, 10) or UDim2.fromOffset(10, 10)
		if animate then
			tween(track, { BackgroundColor3 = color }, 0.18)
			tween(knob, { Position = position }, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			knobScale.Scale = 0.88
			tween(knobScale, { Scale = 1 }, 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		else
			track.BackgroundColor3 = color
			knob.Position = position
			knobScale.Scale = 1
		end
	end

	local function setState(value, fire)
		state = value and true or false
		section.Flags[name] = state
		Library.Config:MarkDirty()
		paint(true)
		window:RefreshDeps()
		if fire ~= false then
			runCallback(callback, state)
		end
	end

	function obj:Set(value, fire)
		setState(value, fire)
	end

	function obj:Get()
		return state
	end

	function obj:Toggle(fire)
		setState(not state, fire)
	end

	hit.MouseButton1Click:Connect(function()
		setState(not state, true)
	end)
	hit.MouseEnter:Connect(function()
		tween(row, { BackgroundTransparency = 0.96 }, 0.15)
	end)
	hit.MouseLeave:Connect(function()
		tween(row, { BackgroundTransparency = 1 }, 0.15)
	end)

	section.Flags[name] = state
	paint(false)

	self:_register(name, function()
		return state
	end, function(value)
		setState(value, true)
	end, function()
		setState(default, true)
	end, opts)

	self:_dependency(row, function()
		return 32
	end, opts)

	onRepaint(function()
		paint(false)
	end)

	self.Window:RefreshDeps()
	return obj
end

-- // Button --------------------------------------------------------------

function SectionAPI:Button(name, callback, opts)
	opts = opts or {}
	name = tostring(name)

	local row = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,
		LayoutOrder = self:_order(),
		Parent = self.Body,
	})
	corner(row, 8)
	stroke(row, Theme.Stroke, 1, 0.5)
	textLabel({
		Text = name,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	local rowScale = new("UIScale", { Scale = 1, Parent = row })

	local function ripple(px, py)
		local dot = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(px, py),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = row,
		})
		corner(dot, 999)
		tween(dot, { Size = UDim2.fromOffset(180, 180), BackgroundTransparency = 1 }, 0.45)
		task.delay(0.5, function()
			if dot and dot.Parent then
				dot:Destroy()
			end
		end)
	end

	row.MouseButton1Click:Connect(function()
		runCallback(callback)
	end)
	row.MouseButton1Down:Connect(function()
		tween(rowScale, { Scale = 0.97 }, 0.1)
		local mouse = UserInputService:GetMouseLocation()
		ripple(mouse.X - row.AbsolutePosition.X, mouse.Y - row.AbsolutePosition.Y)
	end)
	row.MouseButton1Up:Connect(function()
		tween(rowScale, { Scale = 1 }, 0.22)
	end)
	row.MouseEnter:Connect(function()
		tween(row, { BackgroundColor3 = Theme.ControlHover }, 0.15)
	end)
	row.MouseLeave:Connect(function()
		tween(row, { BackgroundColor3 = Theme.Control }, 0.15)
	end)

	self:_dependency(row, function()
		return 34
	end, opts)
end

-- // Slider --------------------------------------------------------------

function SectionAPI:Slider(name, min, max, default, callback, step, opts)
	opts = opts or {}
	name = tostring(name)
	min = tonumber(min) or 0
	max = tonumber(max) or 100
	if max < min then
		min, max = max, min
	end
	step = tonumber(step) or 1
	if step <= 0 then
		step = 1
	end
	default = tonumber(default) or min

	local row = self:_row(44)
	textLabel({
		Text = name,
		Position = UDim2.fromOffset(10, 5),
		Size = UDim2.new(1, -110, 0, 15),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	local valueLabel = textLabel({
		Text = "",
		Position = UDim2.new(1, -100, 0, 5),
		Size = UDim2.new(0, 90, 0, 15),
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
	bindAccent(function()
		valueLabel.TextColor3 = Theme.Accent
	end)

	local track = new("Frame", {
		Size = UDim2.new(1, -20, 0, 4),
		Position = UDim2.fromOffset(10, 31),
		BackgroundColor3 = Theme.Track,
		BorderSizePixel = 0,
		Parent = row,
	})
	corner(track, 2)
	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	corner(fill, 2)
	bindAccent(function()
		fill.BackgroundColor3 = Theme.Accent
	end)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(13, 13),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	})
	corner(knob, 7)
	local knobScale = new("UIScale", { Scale = 1, Parent = knob })

	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 4,
		Parent = row,
	})

	local decimals = 0
	if step < 1 then
		if step >= 0.1 then
			decimals = 1
		elseif step >= 0.01 then
			decimals = 2
		else
			decimals = 3
		end
	end
	local suffix = opts.Suffix or ""

	local function format(value)
		return string.format("%." .. decimals .. "f", value) .. suffix
	end

	local function snap(value)
		value = math.clamp(tonumber(value) or min, min, max)
		if step > 0 then
			value = min + math.floor((value - min) / step + 0.5) * step
		end
		local mult = 10 ^ decimals
		value = math.floor(value * mult + 0.5) / mult
		return math.clamp(value, min, max)
	end

	local value = snap(default)
	local window, section = self.Window, self
	local obj = {}

	local function alphaOf(v)
		if max == min then
			return 0
		end
		return math.clamp((v - min) / (max - min), 0, 1)
	end

	local function paint(instant)
		local alpha = alphaOf(value)
		if instant then
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		else
			tween(fill, { Size = UDim2.fromScale(alpha, 1) }, 0.18)
			tween(knob, { Position = UDim2.new(alpha, 0, 0.5, 0) }, 0.18)
		end
		valueLabel.Text = format(value)
	end

	local function setValue(next_value, fire, instant)
		value = snap(next_value)
		section.Flags[name] = value
		Library.Config:MarkDirty()
		paint(instant == true)
		window:RefreshDeps()
		if fire ~= false then
			runCallback(callback, value)
		end
	end

	function obj:Set(next_value, fire)
		setValue(next_value, fire, false)
	end

	function obj:Get()
		return value
	end

	local dragging = false
	local moveConn, endConn
	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		dragging = true
		tween(knobScale, { Scale = 1.35 }, 0.12)
		local trackSize = track.AbsoluteSize.X
		if trackSize > 0 then
			local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / trackSize, 0, 1)
			setValue(min + (max - min) * alpha, true, true)
		end
		moveConn = UserInputService.InputChanged:Connect(function(i)
			if not dragging then return end
			if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local width = track.AbsoluteSize.X
			if width <= 0 then return end
			local alpha = math.clamp((i.Position.X - track.AbsolutePosition.X) / width, 0, 1)
			setValue(min + (max - min) * alpha, true, true)
		end)
		endConn = UserInputService.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				tween(knobScale, { Scale = 1 }, 0.2)
				if moveConn then moveConn:Disconnect() end
				if endConn then endConn:Disconnect() end
				moveConn, endConn = nil, nil
			end
		end)
	end)
	hit.MouseEnter:Connect(function()
		tween(row, { BackgroundTransparency = 0.97 }, 0.15)
		tween(knobScale, { Scale = 1.12 }, 0.15)
	end)
	hit.MouseLeave:Connect(function()
		tween(row, { BackgroundTransparency = 1 }, 0.15)
		if not dragging then
			tween(knobScale, { Scale = 1 }, 0.15)
		end
	end)

	section.Flags[name] = value
	paint(true)

	self:_register(name, function()
		return value
	end, function(next_value)
		setValue(next_value, true, false)
	end, function()
		setValue(default, true, false)
	end, opts)

	self:_dependency(row, function()
		return 44
	end, opts)

	onRepaint(function()
		paint(true)
	end)

	self.Window:RefreshDeps()
	return obj
end

-- // Input ---------------------------------------------------------------

function SectionAPI:Input(name, default, callback, opts)
	opts = opts or {}
	name = tostring(name)
	default = tostring(default or "")

	local row = self:_row(38)
	textLabel({
		Text = name,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -190, 1, 0),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local field = new("TextBox", {
		Size = UDim2.new(0, 170, 0, 26),
		Position = UDim2.new(1, -178, 0.5, -13),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		Text = default,
		PlaceholderText = opts.Placeholder or "",
		PlaceholderColor3 = Theme.Muted,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		Parent = row,
	})
	corner(field, 7)
	local fieldStroke = stroke(field, Theme.Stroke, 1, 0.4)

	local window, section = self.Window, self
	local obj = {}
	local last = default

	function obj:Set(text, fire)
		text = tostring(text or "")
		field.Text = text
		last = text
		section.Flags[name] = text
		Library.Config:MarkDirty()
		window:RefreshDeps()
		if fire ~= false then
			runCallback(callback, text)
		end
	end

	function obj:Get()
		return field.Text
	end

	field.Focused:Connect(function()
		tween(field, { BackgroundColor3 = Theme.ControlHover }, 0.15)
		tween(fieldStroke, { Color = Theme.Accent, Transparency = 0 }, 0.15)
	end)
	field.FocusLost:Connect(function()
		tween(field, { BackgroundColor3 = Theme.Control }, 0.15)
		tween(fieldStroke, { Color = Theme.Stroke, Transparency = 0.4 }, 0.15)
		local text = field.Text
		section.Flags[name] = text
		Library.Config:MarkDirty()
		window:RefreshDeps()
		if text ~= last then
			last = text
			runCallback(callback, text)
		end
	end)
	field.MouseEnter:Connect(function()
		if not field:IsFocused() then
			tween(field, { BackgroundColor3 = Theme.ControlHover }, 0.15)
		end
	end)
	field.MouseLeave:Connect(function()
		if not field:IsFocused() then
			tween(field, { BackgroundColor3 = Theme.Control }, 0.15)
		end
	end)

	section.Flags[name] = default

	self:_register(name, function()
		return field.Text
	end, function(value)
		obj:Set(value, true)
	end, function()
		obj:Set(default, true)
	end, opts)

	self:_dependency(row, function()
		return 38
	end, opts)

	self.Window:RefreshDeps()
	return obj
end

-- // Keybind -------------------------------------------------------------

function SectionAPI:Keybind(name, default, callback, opts)
	opts = opts or {}
	name = tostring(name)

	local row = self:_row(32)
	textLabel({
		Text = name,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -130, 1, 0),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local box = new("Frame", {
		Size = UDim2.new(0, 108, 0, 24),
		Position = UDim2.new(1, -116, 0.5, -12),
		BackgroundColor3 = Theme.Control,
		BorderSizePixel = 0,
		Parent = row,
	})
	corner(box, 7)
	local boxStroke = stroke(box, Theme.Stroke, 1, 0.4)
	local keyLabel = textLabel({
		Text = "None",
		Size = UDim2.fromScale(1, 1),
		TextSize = 10,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, box)
	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 4,
		Parent = row,
	})

	local key = nil
	if default ~= nil then
		if typeof(default) == "EnumItem" then
			key = default
		elseif type(default) == "string" and Enum.KeyCode[default] then
			key = Enum.KeyCode[default]
		end
	end
	local initialKey = key

	local listening = false
	local listenConn = nil
	local window, section = self.Window, self
	local obj = {}

	local function paint(animate)
		if listening then
			return
		end
		keyLabel.Text = key and key.Name or "None"
		keyLabel.TextColor3 = key and Theme.Text or Theme.Muted
		if animate then
			tween(box, { BackgroundColor3 = Theme.Control }, 0.15)
			tween(boxStroke, { Color = Theme.Stroke, Transparency = 0.4 }, 0.15)
		end
	end

	local function setKey(nextKey, fire)
		key = nextKey
		section.Flags[name] = key and key.Name or nil
		Library.Config:MarkDirty()
		paint(true)
		window:RefreshDeps()
		if fire ~= false then
			runCallback(callback, key)
		end
	end

	function obj:Set(value, fire)
		if value == nil then
			setKey(nil, fire)
		elseif typeof(value) == "EnumItem" then
			setKey(value, fire)
		elseif type(value) == "string" and Enum.KeyCode[value] then
			setKey(Enum.KeyCode[value], fire)
		end
	end

	function obj:Get()
		return key
	end

	local function stopListening()
		if not listening then return end
		listening = false
		Library._capturing = false
		if listenConn then
			listenConn:Disconnect()
			listenConn = nil
		end
		paint(true)
	end

	local function startListening()
		if listening then return end
		listening = true
		Library._capturing = true
		keyLabel.Text = "PRESS A KEY"
		keyLabel.TextColor3 = Theme.Accent
		tween(box, { BackgroundColor3 = Theme.ControlHover }, 0.15)
		tween(boxStroke, { Color = Theme.Accent, Transparency = 0 }, 0.15)
		listenConn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			local pressed = input.KeyCode
			stopListening()
			if pressed == Enum.KeyCode.Escape or pressed == Enum.KeyCode.Backspace then
				setKey(nil, true)
			else
				setKey(pressed, true)
			end
		end)
		task.delay(5, function()
			if listening then
				stopListening()
			end
		end)
	end

	hit.MouseButton1Click:Connect(startListening)
	hit.MouseEnter:Connect(function()
		tween(row, { BackgroundTransparency = 0.96 }, 0.15)
	end)
	hit.MouseLeave:Connect(function()
		tween(row, { BackgroundTransparency = 1 }, 0.15)
	end)

	local pressConn = UserInputService.InputBegan:Connect(function(input, processed)
		if listening or not key then return end
		if processed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode ~= key then return end
		if UserInputService:GetFocusedTextBox() then return end
		runCallback(callback, key)
	end)
	window:_track(pressConn)

	section.Flags[name] = key and key.Name or nil
	paint(false)

	self:_register(name, function()
		return key and key.Name or ""
	end, function(value)
		if type(value) == "string" and value ~= "" and Enum.KeyCode[value] then
			setKey(Enum.KeyCode[value], true)
		else
			setKey(nil, true)
		end
	end, function()
		setKey(initialKey, true)
	end, opts)

	self:_dependency(row, function()
		return 32
	end, opts)

	onRepaint(function()
		paint(false)
	end)

	self.Window:RefreshDeps()
	return obj
end

-- // Dropdowns -----------------------------------------------------------

function SectionAPI:_Dropdown(name, options, default, callback, multi, opts)
	opts = opts or {}
	name = tostring(name)

	local headerHeight = 36
	local optionHeight = 28
	local gap = 4

	local block = self:_row(headerHeight, { Unclipped = true })
	block.ClipsDescendants = true
	block.BackgroundTransparency = 1

	local header = new("TextButton", {
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = Theme.Control,
		BackgroundTransparency = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = block,
	})
	corner(header, 8)
	local headerStroke = stroke(header, Theme.Stroke, 1, 0.35)
	textLabel({
		Text = name,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -150, 1, 0),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)
	local valueLabel = textLabel({
		Text = "None",
		Position = UDim2.new(1, -176, 0, 0),
		Size = UDim2.new(0, 150, 1, 0),
		TextSize = 11,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)

	local chevron = new("Frame", {
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.new(1, -22, 0.5, -5),
		BackgroundTransparency = 1,
		Parent = header,
	})
	local chevLeft = new("Frame", {
		Size = UDim2.fromOffset(6, 1.6),
		Position = UDim2.new(0, 0, 0.5, 3),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = 45,
		BackgroundColor3 = Theme.Muted,
		BorderSizePixel = 0,
		Parent = chevron,
	})
	corner(chevLeft, 1)
	local chevRight = new("Frame", {
		Size = UDim2.fromOffset(6, 1.6),
		Position = UDim2.new(1, 0, 0.5, 3),
		AnchorPoint = Vector2.new(1, 0.5),
		Rotation = -45,
		BackgroundColor3 = Theme.Muted,
		BorderSizePixel = 0,
		Parent = chevron,
	})
	corner(chevRight, 1)

	local list = new("ScrollingFrame", {
		Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Stroke,
		ScrollBarImageTransparency = 0.2,
		ZIndex = 2,
		Parent = self.Window.Overlay,
	})
	corner(list, 8)
	stroke(list, Theme.Stroke, 1, 0.35)

	local optionList = {}
	for _, option in ipairs(options or {}) do
		optionList[#optionList + 1] = tostring(option)
	end

	local rows = {}
	local selected = nil
	local multiSet = {}
	local open = false
	local blockHeight = headerHeight
	local window, section = self.Window, self
	local obj = {}

	if multi then
		if type(default) == "table" then
			for _, value in ipairs(default) do
				multiSet[tostring(value)] = true
			end
		end
	else
		selected = default ~= nil and tostring(default) or nil
	end

	local function getValue()
		if multi then
			local out = {}
			for _, option in ipairs(optionList) do
				if multiSet[option] then
					out[#out + 1] = option
				end
			end
			return out
		end
		return selected
	end

	local function headerText()
		if multi then
			local picked = {}
			for _, option in ipairs(optionList) do
				if multiSet[option] then
					picked[#picked + 1] = option
				end
			end
			if #picked == 0 then
				return "None"
			elseif #picked <= 2 then
				return table.concat(picked, ", ")
			end
			return tostring(#picked) .. " selected"
		end
		return selected or "None"
	end

	local function listHeight()
		return math.max(1, #optionList) * optionHeight + 8
	end

	local function isSelected(option)
		if multi then
			return multiSet[option] == true
		end
		return selected == option
	end

	local repaint = function() end

	local function commit(fire)
		section.Flags[name] = getValue()
		Library.Config:MarkDirty()
		window:RefreshDeps()
		valueLabel.Text = headerText()
		if fire ~= false then
			runCallback(callback, getValue())
		end
	end

	local function place(instant)
		local width, maxHeight = window:_placePopup(list, header, nil, listHeight(), { Gap = gap })
		local target = math.min(listHeight(), maxHeight)
		if instant then
			list.Size = UDim2.fromOffset(width, target)
		else
			list.Size = UDim2.fromOffset(width, 0)
			tween(list, { Size = UDim2.fromOffset(width, target) }, 0.22)
		end
	end

	local function setOpen(wanted, instant)
		wanted = wanted and true or false
		if open == wanted then
			return
		end
		open = wanted
		if open then
			window:CloseDropdowns(obj)
			list.Visible = true
			list.CanvasPosition = Vector2.new(0, 0)
			place(instant)
		else
			local width = list.Size.X.Offset
			if instant then
				list.Size = UDim2.fromOffset(width, 0)
			else
				tween(list, { Size = UDim2.fromOffset(width, 0) }, 0.18)
			end
			task.delay(0.2, function()
				if not open then
					list.Visible = false
				end
			end)
		end
		if instant then
			chevron.Rotation = open and 180 or 0
			headerStroke.Color = open and Theme.Accent or Theme.Stroke
		else
			tween(chevron, { Rotation = open and 180 or 0 }, 0.25, Enum.EasingStyle.Back)
			tween(headerStroke, { Color = open and Theme.Accent or Theme.Stroke }, 0.18)
		end
	end

	local function rebuild()
		list:ClearAllChildren()
		new("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			Parent = list,
		})
		new("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = list,
		})
		rows = {}

		if #optionList == 0 then
			textLabel({
				Text = "No options",
				Size = UDim2.new(1, 0, 0, optionHeight),
				TextSize = 11,
				TextColor3 = Theme.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = list,
			})
			return
		end

		for index, option in ipairs(optionList) do
			local optionRow = new("TextButton", {
				Size = UDim2.new(1, 0, 0, optionHeight),
				BackgroundColor3 = Theme.Control,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				LayoutOrder = index,
				Parent = list,
			})
			corner(optionRow, 6)
			textLabel({
				Text = option,
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -42, 1, 0),
				TextSize = 11,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, optionRow)

			local mark
			local check
			if multi then
				mark = new("Frame", {
					Size = UDim2.fromOffset(14, 14),
					Position = UDim2.new(1, -22, 0.5, -7),
					BackgroundColor3 = Theme.Track,
					BorderSizePixel = 0,
					Parent = optionRow,
				})
				corner(mark, 4)
				check = new("Frame", {
					Size = UDim2.fromOffset(6, 6),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = mark,
				})
				corner(check, 3)
			else
				mark = new("Frame", {
					Size = UDim2.fromOffset(6, 6),
					Position = UDim2.new(1, -18, 0.5, -3),
					BackgroundColor3 = Theme.Accent,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = optionRow,
				})
				corner(mark, 3)
			end

			local entry = { Option = option }
			entry.Paint = function()
				local on = isSelected(option)
				tween(optionRow, { BackgroundTransparency = on and 0 or 1 }, 0.15)
				if multi then
					tween(mark, { BackgroundColor3 = on and Theme.Accent or Theme.Track }, 0.15)
					tween(check, { BackgroundTransparency = on and 0 or 1 }, 0.15)
				else
					tween(mark, { BackgroundTransparency = on and 0 or 1 }, 0.15)
				end
			end

			optionRow.MouseEnter:Connect(function()
				if not isSelected(option) then
					tween(optionRow, { BackgroundTransparency = 0.92 }, 0.15)
				end
			end)
			optionRow.MouseLeave:Connect(function()
				if not isSelected(option) then
					tween(optionRow, { BackgroundTransparency = 1 }, 0.15)
				end
			end)
			optionRow.MouseButton1Click:Connect(function()
				if multi then
					if multiSet[option] then
						multiSet[option] = nil
					else
						multiSet[option] = true
					end
					commit(true)
					repaint()
				else
					selected = option
					commit(true)
					repaint()
					setOpen(false)
				end
			end)

			rows[#rows + 1] = entry
		end
	end

	repaint = function()
		for _, entry in ipairs(rows) do
			entry.Paint()
		end
	end

	function obj:Set(value, fire)
		if multi then
			multiSet = {}
			if type(value) == "table" then
				for _, item in ipairs(value) do
					multiSet[tostring(item)] = true
				end
			end
		else
			selected = value ~= nil and tostring(value) or nil
		end
		repaint()
		commit(fire)
	end

	function obj:Get()
		return getValue()
	end

	function obj:SetOptions(nextOptions)
		optionList = {}
		for _, option in ipairs(nextOptions or {}) do
			optionList[#optionList + 1] = tostring(option)
		end
		if multi then
			for key in pairs(multiSet) do
				local found = false
				for _, option in ipairs(optionList) do
					if option == key then
						found = true
						break
					end
				end
				if not found then
					multiSet[key] = nil
				end
			end
		elseif selected ~= nil then
			local found = false
			for _, option in ipairs(optionList) do
				if option == selected then
					found = true
					break
				end
			end
			if not found then
				selected = nil
			end
		end
		rebuild()
		repaint()
		commit(false)
		if open then
			place(true)
		end
	end

	function obj:SetOpen(value)
		setOpen(value, false)
	end

	function obj:Close()
		setOpen(false)
	end

	header.MouseButton1Click:Connect(function()
		setOpen(not open, false)
	end)
	header.MouseEnter:Connect(function()
		tween(header, { BackgroundColor3 = Theme.ControlHover }, 0.15)
	end)
	header.MouseLeave:Connect(function()
		tween(header, { BackgroundColor3 = Theme.Control }, 0.15)
	end)

	rebuild()
	repaint()
	valueLabel.Text = headerText()
	section.Flags[name] = getValue()

	table.insert(window.Dropdowns, obj)

	self:_register(name, function()
		return getValue()
	end, function(value)
		obj:Set(value, true)
	end, function()
		obj:Set(default, true)
	end, opts)

	self:_dependency(block, function()
		return blockHeight
	end, opts)

	self.Window:RefreshDeps()
	return obj
end

function SectionAPI:Dropdown(name, options, default, callback, opts)
	return self:_Dropdown(name, options, default, callback, false, opts)
end

function SectionAPI:MultiDropdown(name, options, default, callback, opts)
	return self:_Dropdown(name, options, default or {}, callback, true, opts)
end

-- // Color picker --------------------------------------------------------

function SectionAPI:ColorPicker(name, default, callback, opts)
	opts = opts or {}
	name = tostring(name)
	local base = default
	if typeof(base) ~= "Color3" then
		base = Theme.Accent
	end

	local row = self:_row(36, { Unclipped = true })
	row.ZIndex = 30
	row.ClipsDescendants = false

	textLabel({
		Text = name,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -120, 1, 0),
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	local hexLabel = textLabel({
		Text = "",
		Position = UDim2.new(1, -104, 0, 0),
		Size = UDim2.new(0, 52, 1, 0),
		TextSize = 10,
		Font = Enum.Font.Code,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
	local swatch = new("TextButton", {
		Size = UDim2.fromOffset(42, 21),
		Position = UDim2.new(1, -50, 0.5, -10.5),
		BackgroundColor3 = base,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
		Parent = row,
	})
	corner(swatch, 6)
	stroke(swatch, Theme.Stroke, 1, 0.3)

	local popup = new("CanvasGroup", {
		Size = UDim2.fromOffset(196, 156),
		Position = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 2,
		Parent = self.Window.Overlay,
	})
	corner(popup, 10)
	stroke(popup, Theme.Stroke, 1, 0.25)
	local popupScale = new("UIScale", { Scale = 1, Parent = popup })

	local square = new("Frame", {
		Size = UDim2.fromOffset(180, 92),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromHSV(0, 1, 1),
		ClipsDescendants = true,
		BorderSizePixel = 0,
		Parent = popup,
	})
	corner(square, 6)
	local saturation = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = square,
	})
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = saturation,
	})
	local darkness = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = square,
	})
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = darkness,
	})
	local svKnob = new("Frame", {
		Size = UDim2.fromOffset(10, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = square,
	})
	corner(svKnob, 5)
	stroke(svKnob, Color3.new(0, 0, 0), 1, 0.4)
	local squareHit = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		Parent = square,
	})

	local hue = new("Frame", {
		Size = UDim2.fromOffset(180, 10),
		Position = UDim2.fromOffset(8, 108),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = popup,
	})
	corner(hue, 5)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.166, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.666, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
		}),
		Parent = hue,
	})
	local hueKnob = new("Frame", {
		Size = UDim2.fromOffset(8, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = hue,
	})
	corner(hueKnob, 3)
	stroke(hueKnob, Color3.new(0, 0, 0), 1, 0.4)
	local hueHit = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		Parent = hue,
	})

	local preview = new("Frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(8, 126),
		BackgroundColor3 = base,
		BorderSizePixel = 0,
		Parent = popup,
	})
	corner(preview, 6)
	stroke(preview, Theme.Stroke, 1, 0.3)
	local popupHex = textLabel({
		Text = "",
		Position = UDim2.fromOffset(38, 126),
		Size = UDim2.new(1, -46, 0, 22),
		TextSize = 11,
		Font = Enum.Font.Code,
	}, popup)

	local h, s, v = base:ToHSV()
	local window, section = self.Window, self
	local obj = {}

	local function current()
		return Color3.fromHSV(h, s, v)
	end

	local function hex(color)
		return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	end

	local function paint(animate)
		local color = current()
		square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		if animate then
			tween(svKnob, { Position = UDim2.fromScale(s, 1 - v) }, 0.12)
			tween(hueKnob, { Position = UDim2.new(h, 0, 0.5, 0) }, 0.12)
			tween(preview, { BackgroundColor3 = color }, 0.15)
			tween(swatch, { BackgroundColor3 = color }, 0.15)
		else
			svKnob.Position = UDim2.fromScale(s, 1 - v)
			hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
			preview.BackgroundColor3 = color
			swatch.BackgroundColor3 = color
		end
		hexLabel.Text = hex(color)
		popupHex.Text = hex(color)
	end

	local function commit(fire)
		section.Flags[name] = current()
		Library.Config:MarkDirty()
		paint(true)
		window:RefreshDeps()
		if fire ~= false then
			runCallback(callback, current())
		end
	end

	local function setSV(x, y)
		local size = square.AbsoluteSize
		s = math.clamp((x - square.AbsolutePosition.X) / math.max(size.X, 1), 0, 1)
		v = 1 - math.clamp((y - square.AbsolutePosition.Y) / math.max(size.Y, 1), 0, 1)
		commit(true)
	end

	local function setHue(x)
		local width = math.max(hue.AbsoluteSize.X, 1)
		h = math.clamp((x - hue.AbsolutePosition.X) / width, 0, 1)
		commit(true)
	end

	bindDrag(squareHit, setSV)
	bindDrag(hueHit, setHue)

	local open = false
	local function setOpen(wanted)
		wanted = wanted and true or false
		if open == wanted then
			return
		end
		open = wanted
		if open then
			window:CloseDropdowns(obj)
			local _, maxHeight = window:_placePopup(popup, swatch, 196, 156, { AlignRight = true, Gap = 6 })
			local fit = math.clamp(maxHeight / 156, 0.55, 1)
			popup.Visible = true
			popup.GroupTransparency = 1
			popupScale.Scale = fit * 0.95
			tween(popup, { GroupTransparency = 0 }, 0.18)
			tween(popupScale, { Scale = fit }, 0.24)
		else
			tween(popup, { GroupTransparency = 1 }, 0.14)
			tween(popupScale, { Scale = 0.96 }, 0.16)
			task.delay(0.17, function()
				if not open then
					popup.Visible = false
				end
			end)
		end
	end

	swatch.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)
	swatch.MouseEnter:Connect(function()
		tween(swatch, { BackgroundColor3 = current() }, 0.12)
	end)

	function obj:Close()
		setOpen(false)
	end

	table.insert(window.Dropdowns, obj)

	function obj:Set(color, fire)
		if typeof(color) == "Color3" then
			h, s, v = color:ToHSV()
		elseif type(color) == "table" and color[1] and color[2] and color[3] then
			h, s, v = Color3.fromRGB(color[1], color[2], color[3]):ToHSV()
		end
		paint(true)
		commit(fire)
	end

	function obj:Get()
		return current()
	end

	section.Flags[name] = current()
	paint(false)

	self:_register(name, function()
		local color = current()
		return {
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5),
		}
	end, function(value)
		obj:Set(value, true)
	end, function()
		obj:Set(base, true)
	end, opts)

	self:_dependency(row, function()
		return 36
	end, opts)

	onRepaint(function()
		paint(false)
	end)

	self.Window:RefreshDeps()
	return obj
end

-- // Label / divider -----------------------------------------------------

function SectionAPI:Label(text, opts)
	opts = opts or {}
	local row = self:_row(0)
	row.ClipsDescendants = false
	row.AutomaticSize = Enum.AutomaticSize.Y
	local lbl = textLabel({
		Text = tostring(text or ""),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = opts.TextSize or 11,
		TextColor3 = opts.Color or Theme.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, row)
	local obj = {}
	function obj:Set(value)
		lbl.Text = tostring(value or "")
	end
	function obj:Get()
		return lbl.Text
	end
	return obj
end

function SectionAPI:Divider()
	local row = self:_row(9)
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0.5, -0.5),
		BackgroundColor3 = Theme.Stroke,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = row,
	})
	return row
end

-- // Built-in config tab -------------------------------------------------

function WindowAPI:ConfigTab(name)
	local tab = self:Tab(name or "Configs")
	local section = tab:Section("Config manager", {
		Description = "Saves every control on this window. Colors, keybinds, dropdowns and sliders included.",
	})

	local state = {
		name = (Library.Config:List()[1]) or "default",
	}

	local nameInput = section:Input("Config name", state.name, function(text)
		state.name = text
	end, { Placeholder = "config name", NoSave = true })

	local list = section:Dropdown("Saved configs", Library.Config:List(), nil, function(choice)
		state.name = choice
		nameInput:Set(choice, false)
	end, { NoSave = true })

	local status = section:Label("Folder: " .. Library.Config.Folder)

	local function refresh()
		list:SetOptions(Library.Config:List())
	end

	section:Button("Save config", function()
		local ok, result = Library.Config:Save(state.name)
		if ok then
			status:Set("Saved \"" .. result .. "\".")
			Library:Notify("Config saved", "\"" .. result .. "\" was written to disk.", 3)
			refresh()
		else
			status:Set(tostring(result))
			Library:Notify("Save failed", tostring(result), 4)
		end
	end)

	section:Button("Load config", function()
		local ok, result = Library.Config:Load(state.name)
		if ok then
			status:Set("Loaded \"" .. state.name .. "\" (" .. tostring(result) .. " values).")
			Library:Notify("Config loaded", "\"" .. state.name .. "\" was applied.", 3)
		else
			status:Set(tostring(result))
			Library:Notify("Load failed", tostring(result), 4)
		end
	end)

	section:Button("Delete config", function()
		local ok, result = Library.Config:Delete(state.name)
		if ok then
			status:Set("Deleted \"" .. result .. "\".")
			refresh()
		else
			status:Set(tostring(result))
		end
	end)

	section:Button("Refresh list", function()
		refresh()
		status:Set("Folder: " .. Library.Config.Folder)
	end)

	section:Divider()
	section:Toggle("Auto save", false, function(enabled)
		Library.Config:AutoSave(enabled and state.name or nil, 30)
	end, { NoSave = true })
	section:Label("Auto save writes the named config every 30 seconds when something changed.")

	return tab
end

-- // Public helpers -----------------------------------------------------

function Library:SetAccent(color)
	if typeof(color) ~= "Color3" then
		return
	end
	Theme.Accent = color
	Theme.AccentSoft = Color3.new(color.R * 0.28, color.G * 0.28, color.B * 0.28)
	for _, fn in ipairs(accentBindings) do
		pcall(fn)
	end
	for _, fn in ipairs(repaints) do
		pcall(fn)
	end
end

function Library:SetTheme(overrides)
	for key, value in pairs(overrides or {}) do
		if Theme[key] ~= nil then
			Theme[key] = value
		end
	end
	for _, fn in ipairs(accentBindings) do
		pcall(fn)
	end
	for _, fn in ipairs(repaints) do
		pcall(fn)
	end
end

if typeof(getgenv) == "function" then
	getgenv().NovaUI = Library
end

return Library
