--[[
	NeverloseUI for Roblox · Luau
	--------------------------------------------
	A Neverlose-styled menu: near-black panels, thin strokes,
	top tab strip, two-column sections, animated toggles,
	draggable sliders, dropdowns, keybinds, HSV color picker,
	notifications and a watermark.

	Usage:
		local UI = loadstring(game:HttpGet("https://your.host/main.lua"))()
		local Window = UI:Window({ Title = "neverlose", Subtitle = "v2" })
		local Tab = Window:Tab("Rage")
		local Section = Tab:Section("Aimbot")
		Section:Toggle("Enabled", false, function(state) end)

	This is interface code only. It ships no game logic.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local Library = {}
Library.Version = "1.0"
Library.Flags = {}
Library._accentBindings = {}

--=============================================================================
-- Theme
--=============================================================================

local Theme = {
	Accent = Color3.fromRGB(0, 158, 255),

	Background = Color3.fromRGB(8, 8, 10),
	Panel = Color3.fromRGB(15, 15, 18),
	PanelAlt = Color3.fromRGB(22, 22, 27),
	PanelHover = Color3.fromRGB(30, 30, 36),
	Stroke = Color3.fromRGB(32, 32, 39),

	Text = Color3.fromRGB(232, 232, 238),
	Muted = Color3.fromRGB(118, 118, 130),
	Off = Color3.fromRGB(36, 36, 43),

	Font = Enum.Font.Gotham,
	Bold = Enum.Font.GothamBold,
	Mono = Enum.Font.Code,
}

Library.Theme = Theme

--=============================================================================
-- Instance helpers
--=============================================================================

local function new(class, properties, parent)
	local object = Instance.new(class)
	if properties then
		for property, value in properties do
			if property ~= "Parent" then
				object[property] = value
			end
		end
	end
	object.Parent = parent or (properties and properties.Parent)
	return object
end

local function cornerize(object, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, object)
end

local function outline(object, color, thickness)
	return new("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end

local function padding(object, top, right, bottom, left)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
	}, object)
end

local function stack(object, gap, horizontal)
	return new("UIListLayout", {
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, object)
end

local function labelText(parent, properties)
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}
	for property, value in properties do
		defaults[property] = value
	end
	return new("TextLabel", defaults, parent)
end

local function tween(object, duration, properties)
	local animation = TweenService:Create(
		object,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		properties
	)
	animation:Play()
	return animation
end

local function bindAccent(callback)
	table.insert(Library._accentBindings, callback)
	callback(Theme.Accent)
end

local function getRoot()
	if typeof(gethui) == "function" then
		local ok, hidden = pcall(gethui)
		if ok and hidden then
			return hidden
		end
	end
	local ok, core = pcall(function()
		local probe = Instance.new("Folder")
		probe.Parent = game:GetService("CoreGui")
		probe:Destroy()
		return game:GetService("CoreGui")
	end)
	if ok and core then
		return core
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function pointer()
	return UserInputService:GetMouseLocation()
end

--=============================================================================
-- Public theming
--=============================================================================

function Library:SetAccent(color)
	Theme.Accent = color
	for _, callback in Library._accentBindings do
		callback(color)
	end
end

--=============================================================================
-- Controls
--=============================================================================

-- Every control stores its value under Library.Flags[<section>][<label>]
local function setFlag(section, name, value)
	local group = Library.Flags[section.Name]
	if not group then
		group = {}
		Library.Flags[section.Name] = group
	end
	group[name] = value
end

local Controls = {}

local function addRow(section, height)
	section.Index += 1
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = section.Index,
	}, section.Frame)
	if height == 0 then
		row.AutomaticSize = Enum.AutomaticSize.Y
	end
	return row
end

function Controls.Label(section, text)
	local row = addRow(section, 0)
	local label = labelText(row, {
		Text = text,
		TextSize = 11,
		TextColor3 = Theme.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	return label
end

function Controls.Divider(section)
	local row = addRow(section, 1)
	local line = new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
	}, row)
	return line
end

function Controls.Toggle(section, name, default, callback)
	local row = addRow(section, 22)
	local state = default and true or false

	labelText(row, {
		Text = name,
		Size = UDim2.new(1, -48, 1, 0),
	})

	local switch = new("Frame", {
		Size = UDim2.new(0, 34, 0, 17),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = state and Theme.Accent or Theme.Off,
		BorderSizePixel = 0,
	}, row)
	cornerize(switch, 9)
	outline(switch, Theme.Stroke)

	local knob = new("Frame", {
		Size = UDim2.new(0, 11, 0, 11),
		Position = UDim2.new(0, state and 20 or 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.Muted,
		BorderSizePixel = 0,
	}, switch)
	cornerize(knob, 6)

	local hitbox = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
	}, row)

	local function render(animated)
		local duration = animated and 0.14 or 0
		if duration == 0 then
			switch.BackgroundColor3 = state and Theme.Accent or Theme.Off
			knob.Position = UDim2.new(0, state and 20 or 3, 0.5, 0)
			knob.BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.Muted
			return
		end
		tween(switch, duration, { BackgroundColor3 = state and Theme.Accent or Theme.Off })
		tween(knob, duration, {
			Position = UDim2.new(0, state and 20 or 3, 0.5, 0),
			BackgroundColor3 = state and Color3.new(1, 1, 1) or Theme.Muted,
		})
	end

	local function set(value, animated)
		state = value and true or false
		setFlag(section, name, state)
		render(animated ~= false)
		if callback then
			task.spawn(callback, state)
		end
	end

	hitbox.MouseButton1Click:Connect(function()
		set(not state, true)
	end)

	bindAccent(function(color)
		if state then
			switch.BackgroundColor3 = color
		end
	end)

	setFlag(section, name, state)
	render(false)

	return {
		Set = function(_, value)
			set(value, true)
		end,
		Get = function()
			return state
		end,
	}
end

function Controls.Button(section, name, callback)
	local row = addRow(section, 24)
	local button = new("TextButton", {
		Text = name,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PanelAlt,
		BorderSizePixel = 0,
		Font = Theme.Font,
		TextSize = 12,
		TextColor3 = Theme.Text,
		Size = UDim2.new(1, 0, 1, 0),
	}, row)
	cornerize(button, 4)
	outline(button, Theme.Stroke)

	button.MouseEnter:Connect(function()
		tween(button, 0.12, { BackgroundColor3 = Theme.PanelHover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, 0.12, { BackgroundColor3 = Theme.PanelAlt })
	end)
	button.MouseButton1Click:Connect(function()
		if callback then
			task.spawn(callback)
		end
	end)

	return button
end

function Controls.Slider(section, name, min, max, default, callback, step)
	local row = addRow(section, 32)

	min = tonumber(min) or 0
	max = tonumber(max) or 100
	local value = math.clamp(tonumber(default) or min, min, max)
	local localStep = tonumber(step)

	if not localStep then
		local range = math.abs(max - min)
		localStep = (range >= 5) and 1 or 0.01
	end

	labelText(row, {
		Text = name,
		Size = UDim2.new(1, -60, 0, 16),
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local valueText = labelText(row, {
		Text = "",
		Size = UDim2.new(0, 60, 0, 16),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Mono,
		TextSize = 12,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 0, 26),
		BackgroundColor3 = Theme.Off,
		BorderSizePixel = 0,
	}, row)
	cornerize(track, 2)

	local fill = new("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, track)
	cornerize(fill, 2)

	local knob = new("Frame", {
		Size = UDim2.new(0, 9, 0, 9),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, track)
	cornerize(knob, 5)

	local hitbox = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 17),
	}, row)

	local dragging = false

	local function format(number)
		if localStep >= 1 then
			return tostring(math.floor(number + 0.5))
		end
		return string.format("%.2f", number)
	end

	local function render()
		local alpha = (value - min) / math.max(max - min, 1e-6)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueText.Text = format(value)
	end

	local function setFromX(x, fireCallback)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local raw = min + (max - min) * alpha
		raw = math.floor(raw / localStep + 0.5) * localStep
		raw = math.clamp(raw, min, max)
		if raw == value then
			return
		end
		value = raw
		setFlag(section, name, value)
		render()
		if fireCallback and callback then
			task.spawn(callback, value)
		end
	end

	hitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(pointer().X, true)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			setFromX(pointer().X, true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	bindAccent(function(color)
		fill.BackgroundColor3 = color
	end)

	setFlag(section, name, value)
	render()

	return {
		Set = function(_, number)
			value = math.clamp(tonumber(number) or value, min, max)
			setFlag(section, name, value)
			render()
		end,
		Get = function()
			return value
		end,
	}
end

function Controls.Dropdown(section, name, options, default, callback)
	options = options or {}
	local multiple = typeof(default) == "table"
	local selected = {}

	for _, option in options do
		selected[option] = false
	end

	local initial
	if multiple then
		for _, option in default do
			if selected[option] ~= nil then
				selected[option] = true
			end
			initial = initial or option
		end
	elseif default ~= nil then
		if selected[default] ~= nil then
			selected[default] = true
		end
		initial = default
	end

	initial = initial or options[1]

	local row = addRow(section, 0)
	stack(row, 3)

	local header = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PanelAlt,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 1,
	}, row)
	cornerize(header, 3)

	local headerTitle = labelText(header, {
		Text = name,
		Size = UDim2.new(1, -78, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
	})

	local headerValue = labelText(header, {
		Text = "",
		Size = UDim2.new(0, 62, 1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Muted,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local chevron = labelText(header, {
		Text = "›",
		Size = UDim2.new(0, 10, 0, 10),
		Position = UDim2.new(1, -2, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Muted,
		TextSize = 12,
		Rotation = 90,
	})

	local list = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		LayoutOrder = 2,
	}, row)
	cornerize(list, 3)
	outline(list, Theme.Stroke)
	padding(list, 3, 3, 3, 3)
	stack(list, 1)

	local function values()
		local result = {}
		for _, option in options do
			if selected[option] then
				table.insert(result, option)
			end
		end
		return result
	end

	local function render()
		local picked = values()
		if multiple then
			if #picked == 0 then
				headerValue.Text = "none"
			elseif #picked == 1 then
				headerValue.Text = picked[1]
			else
				headerValue.Text = picked[1] .. " +" .. tostring(#picked - 1)
			end
			setFlag(section, name, picked)
		else
			headerValue.Text = picked[1] or "none"
			setFlag(section, name, picked[1])
		end
	end

	local optionButtons = {}

	local function select(option)
		if multiple then
			selected[option] = not selected[option]
		else
			for key in selected do
				selected[key] = false
			end
			selected[option] = true
			list.Visible = false
			chevron.Rotation = 90
			header.BackgroundTransparency = 1
		end
		render()
		for key, button in optionButtons do
			button.TextColor3 = selected[key] and Theme.Accent or Theme.Muted
		end
		if callback then
			local picked = values()
			task.spawn(callback, multiple and picked or picked[1])
		end
	end

	for index, option in options do
		local button = new("TextButton", {
			Text = option,
			AutoButtonColor = false,
			BackgroundColor3 = Theme.PanelAlt,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Theme.Font,
			TextSize = 11,
			TextColor3 = Theme.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 19),
			LayoutOrder = index,
		}, list)
		cornerize(button, 2)
		padding(button, 0, 6, 0, 6)

		button.MouseEnter:Connect(function()
			button.BackgroundTransparency = 0.55
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundTransparency = 1
		end)
		button.MouseButton1Click:Connect(function()
			select(option)
		end)

		optionButtons[option] = button
	end

	header.MouseEnter:Connect(function()
		if not list.Visible then
			header.BackgroundTransparency = 0.5
		end
	end)
	header.MouseLeave:Connect(function()
		header.BackgroundTransparency = 1
	end)
	header.MouseButton1Click:Connect(function()
		list.Visible = not list.Visible
		chevron.Rotation = list.Visible and -90 or 90
		header.BackgroundTransparency = 1
	end)

	bindAccent(function(color)
		for key, button in optionButtons do
			if selected[key] then
				button.TextColor3 = color
			end
		end
	end)

	render()

	return {
		Set = function(_, value)
			if typeof(value) == "table" then
				for key in selected do
					selected[key] = false
				end
				for _, option in value do
					if selected[option] ~= nil then
						selected[option] = true
					end
				end
			else
				for key in selected do
					selected[key] = key == value
				end
			end
			render()
			for key, button in optionButtons do
				button.TextColor3 = selected[key] and Theme.Accent or Theme.Muted
			end
		end,
		Get = function()
			local picked = values()
			return multiple and picked or picked[1]
		end,
	}
end

function Controls.Keybind(section, name, default, onPress)
	local row = addRow(section, 22)
	local keybind = default

	labelText(row, {
		Text = name,
		Size = UDim2.new(1, -70, 1, 0),
	})

	local box = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PanelAlt,
		BorderSizePixel = 0,
		Font = Theme.Mono,
		TextSize = 11,
		TextColor3 = Theme.Text,
		Size = UDim2.new(0, 66, 0, 18),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
	}, row)
	cornerize(box, 3)
	local boxStroke = outline(box, Theme.Stroke)

	local listening = false

	local function render()
		if listening then
			box.Text = "[ ... ]"
			boxStroke.Color = Theme.Accent
			box.TextColor3 = Theme.Accent
			return
		end
		box.Text = keybind and tostring(keybind.Name) or "[ none ]"
		box.TextColor3 = keybind and Theme.Text or Theme.Muted
		boxStroke.Color = Theme.Stroke
	end

	local function setKey(key)
		keybind = key
		setFlag(section, name, key and key.Name or nil)
		render()
	end

	box.MouseButton1Click:Connect(function()
		listening = not listening
		render()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if listening then
			if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
				setKey(nil)
			elseif input.KeyCode ~= Enum.KeyCode.Unknown then
				setKey(input.KeyCode)
			end
			listening = false
			render()
			return
		end
		if keybind and input.KeyCode == keybind and onPress then
			task.spawn(onPress)
		end
	end)

	bindAccent(function(color)
		if listening then
			boxStroke.Color = color
			box.TextColor3 = color
		end
	end)

	setKey(default)

	return {
		Set = function(_, key)
			setKey(key)
		end,
		Get = function()
			return keybind
		end,
	}
end

function Controls.Input(section, name, default, callback, placeholder)
	local row = addRow(section, 22)

	labelText(row, {
		Text = name,
		Size = UDim2.new(1, -112, 1, 0),
	})

	local box = new("TextBox", {
		Text = default or "",
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = Theme.Muted,
		ClearTextOnFocus = false,
		BackgroundColor3 = Theme.PanelAlt,
		BorderSizePixel = 0,
		Font = Theme.Mono,
		TextSize = 11,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0, 106, 0, 18),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
	}, row)
	cornerize(box, 3)
	outline(box, Theme.Stroke)
	padding(box, 0, 6, 0, 6)

	local function commit()
		if callback then
			task.spawn(callback, box.Text)
		end
		setFlag(section, name, box.Text)
	end

	box.FocusLost:Connect(commit)
	setFlag(section, name, box.Text)

	return box
end

function Controls.ColorPicker(section, name, default, callback)
	local row = addRow(section, 22)
	local color = default or Theme.Accent

	labelText(row, {
		Text = name,
		Size = UDim2.new(1, -44, 1, 0),
	})

	local swatch = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 30, 0, 14),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
	}, row)
	cornerize(swatch, 2)
	outline(swatch, Theme.Stroke)

	setFlag(section, name, color)

	local hud = section.Window.Gui

	local function updateColor(newColor, fireCallback)
		color = newColor
		swatch.BackgroundColor3 = newColor
		setFlag(section, name, newColor)
		if fireCallback and callback then
			task.spawn(callback, newColor)
		end
	end

	swatch.MouseButton1Click:Connect(function()
		local hue, saturation, value = color:ToHSV()
		local origin = swatch.AbsolutePosition
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)

		local popup = new("Frame", {
			Size = UDim2.new(0, 170, 0, 156),
			Position = UDim2.new(0, math.clamp(origin.X - 130, 8, viewport.X - 178), 0, math.clamp(origin.Y + 22, 8, viewport.Y - 164)),
			BackgroundColor3 = Theme.Panel,
			BorderSizePixel = 0,
			ZIndex = 60,
		}, hud)
		cornerize(popup, 5)
		outline(popup, Theme.Stroke)
		padding(popup, 11, 11, 11, 11)

		local field = new("Frame", {
			Size = UDim2.new(1, 0, 0, 86),
			BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 61,
		}, popup)
		cornerize(field, 3)

		local white = new("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 62,
		}, field)
		cornerize(white, 3)
		new("UIGradient", {
			Transparency = NumberSequence.new(0, 1),
			Rotation = 0,
		}, white)

		local black = new("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 63,
		}, field)
		cornerize(black, 3)
		new("UIGradient", {
			Transparency = NumberSequence.new(1, 0),
			Rotation = 90,
		}, black)

		local cursor = new("Frame", {
			Size = UDim2.new(0, 9, 0, 9),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 64,
		}, field)
		cornerize(cursor, 5)
		outline(cursor, Color3.new(1, 1, 1), 1.5)

		local hueBar = new("Frame", {
			Size = UDim2.new(1, 0, 0, 8),
			Position = UDim2.new(0, 0, 0, 96),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 61,
		}, popup)
		cornerize(hueBar, 2)
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
			}),
			Rotation = 0,
		}, hueBar)

		local hueCursor = new("Frame", {
			Size = UDim2.new(0, 3, 0, 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 64,
		}, hueBar)
		cornerize(hueCursor, 2)

		local preview = new("Frame", {
			Size = UDim2.new(0, 20, 0, 20),
			Position = UDim2.new(0, 0, 0, 112),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 61,
		}, popup)
		cornerize(preview, 3)
		outline(preview, Theme.Stroke)

		local hex = labelText(popup, {
			Text = "",
			Size = UDim2.new(1, -28, 0, 20),
			Position = UDim2.new(0, 28, 0, 112),
			Font = Theme.Mono,
			TextSize = 11,
			ZIndex = 61,
		})

		local function renderCursor()
			cursor.Position = UDim2.new(saturation, 0, 1 - value, 0)
			hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
			black.BackgroundColor3 = Color3.new(0, 0, 0)
			field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			local current = Color3.fromHSV(hue, saturation, value)
			preview.BackgroundColor3 = current
			hex.Text = string.format("#%02X%02X%02X", math.floor(current.R * 255 + 0.5), math.floor(current.G * 255 + 0.5), math.floor(current.B * 255 + 0.5))
			updateColor(current, true)
		end

		local draggingField = false
		local draggingHue = false

		local function applyField()
			local position = pointer()
			saturation = math.clamp((position.X - field.AbsolutePosition.X) / math.max(field.AbsoluteSize.X, 1), 0, 1)
			value = math.clamp(1 - (position.Y - field.AbsolutePosition.Y) / math.max(field.AbsoluteSize.Y, 1), 0, 1)
			renderCursor()
		end

		local function applyHue()
			local position = pointer()
			hue = math.clamp((position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
			renderCursor()
		end

		field.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingField = true
				applyField()
			end
		end)
		hueBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingHue = true
				applyHue()
			end
		end)

		local moveConnection
		moveConnection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			if draggingField then
				applyField()
			elseif draggingHue then
				applyHue()
			end
		end)

		local endConnection
		endConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				draggingField = false
				draggingHue = false
			end
		end)

		local closer = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 55,
		}, hud)

		local function close()
			if moveConnection then
				moveConnection:Disconnect()
			end
			if endConnection then
				endConnection:Disconnect()
			end
			closer:Destroy()
			popup:Destroy()
		end

		closer.MouseButton1Click:Connect(close)
		section.Window:_TrackClose(close)

		cursor.Position = UDim2.new(saturation, 0, 1 - value, 0)
		hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
		local current = Color3.fromHSV(hue, saturation, value)
		preview.BackgroundColor3 = current
		hex.Text = string.format("#%02X%02X%02X", math.floor(current.R * 255 + 0.5), math.floor(current.G * 255 + 0.5), math.floor(current.B * 255 + 0.5))
	end)

	return {
		Set = function(_, newColor)
			updateColor(newColor, false)
		end,
		Get = function()
			return color
		end,
	}
end

--=============================================================================
-- Window
--=============================================================================

function Library:Window(config)
	config = config or {}

	assert(LocalPlayer, "NeverloseUI must be executed on the client")

	local Window = {}
	Window.Tabs = {}
	Window.Sections = {}
	Window.Title = config.Title or "neverlose"
	Window.Subtitle = config.Subtitle or "v2"
	Window.Visible = true
	Window._closes = {}

	local closeCallbacks = Window._closes
	function Window:_TrackClose(callback)
		table.insert(closeCallbacks, callback)
	end

	local gui = new("ScreenGui", {
		Name = "NeverloseUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	}, getRoot())
	Window.Gui = gui

	local size = config.Size or UDim2.fromOffset(640, 430)
	local openHeight = size.Y.Offset + 40
	local collapsedHeight = 40 + 46

	local container = new("Frame", {
		Name = "Container",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(size.X.Scale, size.X.Offset + 40, size.Y.Scale, openHeight),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, gui)

	local shadow = new("ImageLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Image = "rbxassetid://1316045217",
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.4,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		ZIndex = 1,
	}, container)

	local main = new("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -40, 1, -40),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		ZIndex = 2,
	}, container)
	cornerize(main, 6)
	outline(main, Theme.Stroke)
	Window.Frame = main

	-- Top bar -------------------------------------------------------------
	local topbar = new("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 3,
	}, main)

	local logo = new("Frame", {
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.PanelAlt,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, topbar)
	cornerize(logo, 4)
	outline(logo, Theme.Stroke)
	bindAccent(function(color)
		outline(logo, color)
		logo.BackgroundColor3 = Theme.PanelAlt
	end)

	labelText(logo, {
		Text = "N",
		Size = UDim2.new(1, 0, 1, 0),
		Font = Theme.Bold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 5,
	})

	labelText(topbar, {
		Text = Window.Title,
		Size = UDim2.new(0, 200, 0, 26),
		Position = UDim2.new(0, 42, 0.5, -8),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Theme.Bold,
		TextSize = 13,
		ZIndex = 4,
	})

	labelText(topbar, {
		Text = Window.Subtitle,
		Size = UDim2.new(0, 200, 0, 16),
		Position = UDim2.new(0, 42, 0.5, 9),
		AnchorPoint = Vector2.new(0, 0.5),
		TextSize = 10,
		TextColor3 = Theme.Muted,
		Font = Theme.Mono,
		ZIndex = 4,
	})

	local function barButton(text, order)
		local button = new("TextButton", {
			Text = text,
			AutoButtonColor = false,
			BackgroundColor3 = Theme.PanelAlt,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Theme.Font,
			TextSize = 14,
			TextColor3 = Theme.Muted,
			Size = UDim2.new(0, 20, 0, 20),
			Position = UDim2.new(1, -12 - (order - 1) * 24, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			ZIndex = 4,
		}, topbar)
		cornerize(button, 3)
		button.MouseEnter:Connect(function()
			button.TextColor3 = Theme.Text
			button.BackgroundTransparency = 0.4
		end)
		button.MouseLeave:Connect(function()
			button.TextColor3 = Theme.Muted
			button.BackgroundTransparency = 1
		end)
		return button
	end

	local closeButton = barButton("×", 1)
	local minimizeButton = barButton("–", 2)

	-- Tab strip -----------------------------------------------------------
	local tabbar = new("Frame", {
		Name = "Tabbar",
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.new(0, 12, 0, 46),
		BackgroundTransparency = 1,
		ZIndex = 3,
		ClipsDescendants = false,
	}, main)
	stack(tabbar, 2, true)

	local divider = new("Frame", {
		Size = UDim2.new(1, -20, 0, 1),
		Position = UDim2.new(0, 10, 0, 74),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, main)

	-- Content -------------------------------------------------------------
	local contentArea = new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -20, 1, -92),
		Position = UDim2.new(0, 10, 0, 82),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, main)

	local function column(x, widthScale, widthOffset)
		local frame = new("ScrollingFrame", {
			Size = UDim2.new(widthScale, widthOffset, 1, 0),
			Position = UDim2.new(x, 0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Theme.Stroke,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			ClipsDescendants = true,
			ZIndex = 3,
		}, contentArea)
		stack(frame, 8)
		return frame
	end

	local leftColumn = column(0, 0.5, -4)
	local rightColumn = column(0.5, 0.5, -4)

	-- Window behaviour ----------------------------------------------------
	local tabButtons = {}
	local activeTab

	function Window:SetTab(tab)
		activeTab = tab
		Window.ActiveTab = tab
		for _, section in Window.Sections do
			section.Frame.Visible = (section.Tab == tab)
		end
		for key, entry in tabButtons do
			local isActive = key == tab
			entry.Button.TextColor3 = isActive and Theme.Text or Theme.Muted
			entry.Underline.BackgroundTransparency = isActive and 0 or 1
		end
	end

	function Window:Tab(name)
		local Tab = { Name = name, Window = Window, Sections = {} }

		local button = new("TextButton", {
			Name = name,
			Text = name,
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = Theme.PanelAlt,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Font = Theme.Font,
			TextSize = 12,
			TextColor3 = Theme.Muted,
			LayoutOrder = #Window.Tabs,
			ZIndex = 4,
		}, tabbar)
		padding(button, 0, 10, 0, 10)

		local underline = new("Frame", {
			Size = UDim2.new(0, -8, 0, 2),
			Position = UDim2.new(0.5, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, button)

		bindAccent(function(color)
			underline.BackgroundColor3 = color
		end)

		button.MouseEnter:Connect(function()
			if activeTab ~= Tab then
				button.TextColor3 = Theme.Text
			end
		end)
		button.MouseLeave:Connect(function()
			if activeTab ~= Tab then
				button.TextColor3 = Theme.Muted
			end
		end)
		button.MouseButton1Click:Connect(function()
			Window:SetTab(Tab)
		end)

		tabButtons[Tab] = { Button = button, Underline = underline }
		table.insert(Window.Tabs, Tab)

		function Tab:Section(sectionName, side)
			local parent = (side == "Right" or side == "right") and rightColumn or leftColumn

			local frame = new("Frame", {
				Name = sectionName,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Theme.Panel,
				BorderSizePixel = 0,
				LayoutOrder = #Window.Sections,
				Visible = (activeTab == Tab),
				ZIndex = 3,
			}, parent)
			cornerize(frame, 4)
			outline(frame, Theme.Stroke)
			padding(frame, 9, 10, 10, 10)
			stack(frame, 6)

			labelText(frame, {
				Text = string.upper(sectionName),
				Size = UDim2.new(1, 0, 0, 12),
				Font = Theme.Bold,
				TextSize = 10,
				TextColor3 = Theme.Muted,
				LayoutOrder = 0,
			})

			local Section = {
				Name = sectionName,
				Tab = Tab,
				Window = Window,
				Frame = frame,
				Index = 0,
			}

			Section.Toggle = Controls.Toggle
			Section.Button = Controls.Button
			Section.Slider = Controls.Slider
			Section.Dropdown = Controls.Dropdown
			Section.Keybind = Controls.Keybind
			Section.Input = Controls.Input
			Section.ColorPicker = Controls.ColorPicker
			Section.Label = Controls.Label
			Section.Divider = Controls.Divider

			table.insert(Window.Sections, Section)
			table.insert(Tab.Sections, Section)

			return Section
		end

		if not activeTab then
			Window:SetTab(Tab)
		end

		return Tab
	end

	function Window:Toggle(force)
		local show = (force == nil) and not Window.Visible or (force and true or false)
		Window.Visible = show
		main.Visible = show
		shadow.Visible = show
	end

	local dragStart, dragOrigin

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = pointer()
			dragOrigin = container.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragStart then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local delta = pointer() - dragStart
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local x = math.clamp(dragOrigin.X.Offset + delta.X, 90 - viewport.X / 2, viewport.X / 2 - 90)
		local y = math.clamp(dragOrigin.Y.Offset + delta.Y, 40 - viewport.Y / 2, viewport.Y / 2 - 40)
		container.Position = UDim2.new(dragOrigin.X.Scale, x, dragOrigin.Y.Scale, y)
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = nil
		end
	end)

	closeButton.MouseButton1Click:Connect(function()
		Window:Toggle(false)
	end)

	minimizeButton.MouseButton1Click:Connect(function()
		local collapsed = Window.Collapsed
		Window.Collapsed = not collapsed
		local target = Window.Collapsed and collapsedHeight or openHeight
		tabbar.Visible = not Window.Collapsed
		divider.Visible = not Window.Collapsed
		contentArea.Visible = not Window.Collapsed
		tween(container, 0.18, { Size = UDim2.new(container.Size.X.Scale, container.Size.X.Offset, container.Size.Y.Scale, target) })
	end)

	local toggleKey = config.ToggleKey or Enum.KeyCode.Insert
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == toggleKey then
			Window:Toggle()
		end
	end)

	function Window:Destroy()
		for _, callback in closeCallbacks do
			pcall(callback)
		end
		gui:Destroy()
	end

	return Window
end

--=============================================================================
-- Notifications
--=============================================================================

local notifyGui
local notifyStack

local function ensureNotifyLayer()
	if notifyGui and notifyStack and notifyStack.Parent then
		return notifyStack
	end
	notifyGui = new("ScreenGui", {
		Name = "NeverloseNotify",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000,
	}, getRoot())

	notifyStack = new("Frame", {
		Name = "Stack",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.new(0, 250, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, notifyGui)

	local layout = stack(notifyStack, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	return notifyStack
end

function Library:Notify(title, text, duration)
	duration = duration or 4
	local stackFrame = ensureNotifyLayer()

	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, stackFrame)
	cornerize(card, 4)
	outline(card, Theme.Stroke)

	local accent = new("Frame", {
		Size = UDim2.new(0, 2, 1, -12),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, card)

	local titleLabel = labelText(card, {
		Text = title,
		Size = UDim2.new(1, -22, 0, 16),
		Position = UDim2.new(0, 11, 0, 8),
		Font = Theme.Bold,
		TextSize = 12,
		TextTransparency = 1,
	})

	local textLabel = labelText(card, {
		Text = text or "",
		Size = UDim2.new(1, -22, 0, 16),
		Position = UDim2.new(0, 11, 0, 25),
		TextSize = 11,
		TextColor3 = Theme.Muted,
		TextTransparency = 1,
	})

	tween(card, 0.15, { BackgroundTransparency = 0.05 })
	tween(accent, 0.15, { BackgroundTransparency = 0 })
	tween(titleLabel, 0.15, { TextTransparency = 0 })
	tween(textLabel, 0.15, { TextTransparency = 0 })

	task.delay(duration, function()
		if not card.Parent then
			return
		end
		tween(card, 0.2, { BackgroundTransparency = 1 })
		tween(accent, 0.2, { BackgroundTransparency = 1 })
		tween(titleLabel, 0.2, { TextTransparency = 1 })
		tween(textLabel, 0.2, { TextTransparency = 1 })
		task.wait(0.25)
		card:Destroy()
	end)

	return card
end

--=============================================================================
-- Watermark
--=============================================================================

function Library:Watermark(config)
	config = config or {}
	local text = config.Text or "neverlose.cc"

	local gui = new("ScreenGui", {
		Name = "NeverloseWatermark",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000,
	}, getRoot())

	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(0, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, gui)
	cornerize(holder, 3)
	outline(holder, Theme.Stroke)
	padding(holder, 0, 8, 0, 8)
	stack(holder, 4, true)

	local brand = labelText(holder, {
		Text = "nl",
		Size = UDim2.new(0, 14, 1, 0),
		Font = Theme.Bold,
		TextSize = 11,
		TextColor3 = Theme.Accent,
		LayoutOrder = 1,
	})

	local info = labelText(holder, {
		Text = text,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Theme.Mono,
		TextSize = 11,
		TextColor3 = Theme.Muted,
		LayoutOrder = 2,
	})

	bindAccent(function(color)
		brand.TextColor3 = color
	end)

	if config.Clock or config.FPS then
		local frames = 0
		local elapsed = 0
		local base = text
		local connection
		connection = RunService.RenderStepped:Connect(function(delta)
			frames += 1
			elapsed += delta
			if elapsed < 0.5 then
				return
			end
			local fps = math.floor(frames / elapsed + 0.5)
			frames = 0
			elapsed = 0
			local suffix = base
			if config.FPS then
				suffix = suffix .. "  " .. tostring(fps) .. " fps"
			end
			if config.Clock then
				suffix = suffix .. "  " .. os.date("%H:%M:%S")
			end
			info.Text = suffix
		end)
		Library._watermarkConnection = connection
	end

	return gui
end

--=============================================================================
-- Exports
--=============================================================================

Library.Controls = Controls

if typeof(getgenv) == "function" then
	getgenv().NeverloseUI = Library
end

return Library
