--!nonstrict
-- Client/UI/Components.lua  (docs/14_ui.md §1)
--
-- Reusable UI pieces built from UIStyle: panel, label, button, toggle, choice, slider, key glyph.
-- Every control is a TextButton, so it works with mouse, touch and gamepad selection alike.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)

local Components = {}

local function apply(instance, props)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	return instance
end

local function corner(parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, UIStyle.CornerRadius)
	c.Parent = parent
end

local function stroke(parent, style)
	local s = Instance.new("UIStroke")
	s.Color = style.Color
	s.Thickness = style.Thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- opts: solid (PanelSolid), accent (amber stroke), padding (px). props: any Frame properties.
function Components.panel(parent, opts, props)
	opts = opts or {}
	local style = if opts.solid then UIStyle.PanelSolid else UIStyle.Panel
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = style.Color
	frame.BackgroundTransparency = style.Transparency
	frame.BorderSizePixel = 0
	corner(frame)
	stroke(frame, if opts.accent then UIStyle.AccentStroke else UIStyle.PanelStroke)
	if opts.padding then
		local padding = Instance.new("UIPadding")
		local value = UDim.new(0, opts.padding)
		padding.PaddingLeft, padding.PaddingRight, padding.PaddingTop, padding.PaddingBottom = value, value, value, value
		padding.Parent = frame
	end
	apply(frame, props)
	frame.Parent = parent
	return frame
end

-- opts: font (UIStyle.Font key, default Body), size (px, default Body), color, wrap. props: TextLabel properties.
function Components.label(parent, text, opts, props)
	opts = opts or {}
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = UIStyle.Font[opts.font or "Body"]
	label.TextSize = opts.size or UIStyle.TextSize.Body
	label.TextColor3 = opts.color or UIStyle.TextPrimary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = opts.wrap == true
	label.Text = text
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = UIStyle.MinTextSize
	constraint.MaxTextSize = math.max(UIStyle.MinTextSize, label.TextSize)
	constraint.Parent = label
	apply(label, props)
	label.Parent = parent
	return label
end

-- A selectable button. The amber stroke shows hover and gamepad selection.
function Components.button(parent, text, onActivated, props)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = UIStyle.PanelSolid.Color
	button.BackgroundTransparency = 0.1
	button.BorderSizePixel = 0
	button.FontFace = UIStyle.Font.Header
	button.TextSize = UIStyle.TextSize.Small
	button.TextColor3 = UIStyle.TextPrimary
	button.Text = text
	button.Size = UDim2.new(1, 0, 0, 44)
	corner(button)
	local outline = stroke(button, UIStyle.PanelStroke)
	local function highlight(on)
		outline.Color = if on then UIStyle.AccentStroke.Color else UIStyle.PanelStroke.Color
		outline.Thickness = if on then UIStyle.AccentStroke.Thickness else UIStyle.PanelStroke.Thickness
	end
	button.MouseEnter:Connect(function()
		highlight(true)
	end)
	button.MouseLeave:Connect(function()
		highlight(false)
	end)
	button.SelectionGained:Connect(function()
		highlight(true)
	end)
	button.SelectionLost:Connect(function()
		highlight(false)
	end)
	if onActivated then
		button.Activated:Connect(onActivated)
	end
	apply(button, props)
	button.Parent = parent
	return button
end

-- A disabled-looking button that can't be selected or pressed.
function Components.disable(button)
	button.Active = false
	button.Selectable = false
	button.TextTransparency = 0.5
	button.BackgroundTransparency = 0.5
end

-- On/off control. Returns the button and a setter that doesn't fire onChanged.
function Components.toggle(parent, value, onChanged, props)
	local state = value
	local button
	local function show()
		button.Text = if state then "ON" else "OFF"
		button.TextColor3 = if state then UIStyle.Accent else UIStyle.TextSecondary
	end
	button = Components.button(parent, "", function()
		state = not state
		show()
		onChanged(state)
	end, props)
	show()
	return button, function(newValue)
		state = newValue
		show()
	end
end

-- Cycles through a list of options ({ value, text }). Returns the button and a setter.
function Components.choice(parent, options, value, onChanged, props)
	local index = 1
	local button
	local function show()
		button.Text = options[index].text
	end
	local function select(newValue)
		for i, option in ipairs(options) do
			if option.value == newValue then
				index = i
			end
		end
		show()
	end
	button = Components.button(parent, "", function()
		index = index % #options + 1
		show()
		onChanged(options[index].value)
	end, props)
	button.TextColor3 = UIStyle.Accent
	select(value)
	return button, select
end

-- Slider: [<] track [>] plus a value text. The track takes clicks and drags; the arrow buttons step, so a
-- gamepad can change the value. spec: { min, max, step, value, format = function(v) -> string }.
function Components.slider(parent, spec, onChanged, props)
	local value = spec.value
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 44)
	apply(holder, props)
	holder.Parent = parent

	local track = Instance.new("TextButton")
	track.AutoButtonColor = false
	track.Text = ""
	track.Selectable = false
	track.BackgroundColor3 = UIStyle.PanelStroke.Color
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 52, 0.5, 0)
	track.Size = UDim2.new(1, -168, 0, 8)
	track.Parent = holder
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = UIStyle.Accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	local text = Components.label(holder, "", { font = "Mono", size = UIStyle.TextSize.Small }, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -52, 0.5, 0),
		Size = UDim2.new(0, 56, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local function show()
		fill.Size = UDim2.fromScale((value - spec.min) / (spec.max - spec.min), 1)
		text.Text = if spec.format then spec.format(value) else tostring(value)
	end
	local function set(newValue, fire)
		newValue = math.clamp(math.floor(newValue / spec.step + 0.5) * spec.step, spec.min, spec.max)
		if newValue ~= value then
			value = newValue
			show()
			if fire then
				onChanged(value)
			end
		end
	end
	local function fromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		set(spec.min + alpha * (spec.max - spec.min), true)
	end

	local dragging = false
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local less = Components.button(holder, "<", function()
		set(value - spec.step, true)
	end, { Size = UDim2.fromOffset(44, 44) })
	local more = Components.button(holder, ">", function()
		set(value + spec.step, true)
	end, { Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0) })
	show()
	return holder, function(newValue)
		set(newValue, false)
	end, less, more
end

-- The key box of prompts and hints: panel with an amber stroke and the glyph in Michroma.
function Components.keyGlyph(parent, text, size)
	local box = Components.panel(parent, { accent = true }, { Size = UDim2.fromOffset(size, size) })
	local label = Components.label(box, text, { font = "Header", size = UIStyle.TextSize.Body }, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = #text > 2,
	})
	return box, label
end

return Components
