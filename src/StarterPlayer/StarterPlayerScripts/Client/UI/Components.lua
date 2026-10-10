--!nonstrict
-- Client/UI/Components.lua  (docs/14_ui.md §1)
--
-- Reusable UI pieces built from UIStyle, in the angular style: every surface is a slab whose left and right
-- edges lean (a parallelogram cut out of a Frame with a UIGradient, no images), titles and key boxes are
-- tilted, and a highlighted control flips to amber over an offset paper-white shadow slab.
-- Every control is a TextButton, so it works with mouse, touch and gamepad selection alike.
--
--   slab(parent, opts, props)          panel(parent, opts, props)      label(parent, text, opts, props)
--   paint(slab, color, transparency)   tweenPaint(slab, info, color)   tweenFade(slab, info, transparency)
--   title(parent, text, props)         button(parent, text, onActivated, props)
--   setText(button, text)              setAccented(button, on)         disable(button)
--   toggle / choice / slider           keyGlyph(parent, text, size)
--   tag(button, text)                  enter(control, delay)           cascade(root, opts)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIStyle = require(ReplicatedStorage:WaitForChild("Shared").Config.UIStyle)

local Components = {}

local HIGHLIGHT_TIME = 0.12
local NO_SELECTION_IMAGE = Instance.new("Frame")
NO_SELECTION_IMAGE.BackgroundTransparency = 1

local function apply(instance, props)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	return instance
end

-- Slanted slabs. A UIGradient can only cut a diagonal edge across a frame about as wide as its lean, so a
-- parallelogram is three frames: a left cap and a right cap (each exactly as wide as the lean, cut corner to
-- corner by a two-step transparency gradient) and a plain middle. The caps follow the slab's size.
local slabParts = setmetatable({}, { __mode = "k" }) -- [slab] = { parts }

local function capGradient(part, slant, opaqueAfter)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = slant
	gradient.Transparency = if opaqueAfter
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.499, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) })
	gradient.Parent = part
end

local function buildParts(frame, slant, color, transparency)
	local parts = {}
	local function part(name)
		local piece = Instance.new("Frame")
		piece.Name = name
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = color
		piece.BackgroundTransparency = transparency
		piece.ZIndex = 0 -- behind whatever the slab holds
		piece.Parent = frame
		table.insert(parts, piece)
		return piece
	end
	local left, middle, right = part("SlabL"), part("SlabM"), part("SlabR")
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	-- A positive slant leans like "/": the left cap is opaque right of its diagonal.
	capGradient(left, slant, slant > 0)
	capGradient(right, slant, slant < 0)
	local tangent = math.tan(math.rad(math.abs(slant)))
	local function update()
		local size = frame.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local cap = math.min(0.5, tangent * size.Y / size.X)
		left.Size = UDim2.fromScale(cap, 1)
		right.Size = UDim2.fromScale(cap, 1)
		middle.Position = UDim2.fromScale(cap, 0)
		middle.Size = UDim2.fromScale(1 - 2 * cap, 1)
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
	slabParts[frame] = parts
end

-- A slab. opts: color (default Ink), transparency, slant (degrees, default UIStyle.Slant; false = a plain
-- rectangle). Children can go inside; use paint/tweenPaint to recolor it.
function Components.slab(parent, opts, props)
	opts = opts or {}
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	local color, transparency = opts.color or UIStyle.Ink, opts.transparency or 0
	if opts.slant == false then
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = transparency
	else
		frame.BackgroundTransparency = 1
		buildParts(frame, opts.slant or UIStyle.Slant, color, transparency)
	end
	apply(frame, props)
	frame.Parent = parent
	return frame
end

-- The frames a slab is drawn with (the slab itself when it is a plain rectangle).
local function piecesOf(slab)
	local parts = slabParts[slab]
	if not parts then
		parts = {}
		for _, name in ipairs({ "SlabL", "SlabM", "SlabR" }) do
			table.insert(parts, slab:FindFirstChild(name))
		end
		if #parts == 0 then
			parts = { slab }
		end
		slabParts[slab] = parts
	end
	return parts
end

-- Recolors a slab (slanted or plain). nil keeps the current value.
function Components.paint(slab, color, transparency)
	for _, piece in ipairs(piecesOf(slab)) do
		if color then
			piece.BackgroundColor3 = color
		end
		if transparency then
			piece.BackgroundTransparency = transparency
		end
	end
end

function Components.tweenPaint(slab, info, color)
	for _, piece in ipairs(piecesOf(slab)) do
		TweenService:Create(piece, info, { BackgroundColor3 = color }):Play()
	end
end

function Components.tweenFade(slab, info, transparency)
	for _, piece in ipairs(piecesOf(slab)) do
		TweenService:Create(piece, info, { BackgroundTransparency = transparency }):Play()
	end
end

-- A content surface (children go inside). opts: solid (opaque Ink instead of the translucent Panel color),
-- padding (px), slant (degrees; default a plain rectangle). A slanted panel draws its slab as a "Backing"
-- child that reaches out over the padding, so padding and layouts only affect the content.
function Components.panel(parent, opts, props)
	opts = opts or {}
	local style = if opts.solid then UIStyle.PanelSolid else UIStyle.Panel
	local frame = Components.slab(nil, { color = style.Color, transparency = if opts.slant then 1 else style.Transparency, slant = false })
	local pad = opts.padding or 0
	if opts.slant then
		Components.slab(frame, { color = style.Color, transparency = style.Transparency, slant = opts.slant }, {
			Name = "Backing",
			Position = UDim2.fromOffset(-pad, -pad),
			Size = UDim2.new(1, 2 * pad, 1, 2 * pad),
			ZIndex = 0,
		})
	end
	if opts.padding then
		local padding = Instance.new("UIPadding")
		local value = UDim.new(0, pad)
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

-- A tilted title block: amber slab with ink text over a paper-white shadow slab. props size the holder.
-- opts: size (text px, default Title), color (slab color, default Accent), width (px of the slab, default
-- fitted to the text).
function Components.title(parent, text, props, opts)
	opts = opts or {}
	local textSize = opts.size or UIStyle.TextSize.Title
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, textSize + 28)
	apply(holder, props)
	local width = opts.width or (#text * textSize + 56)
	local body = UDim2.new(0, width, 1, -8)
	Components.slab(holder, { color = UIStyle.Paper }, {
		Name = "Shadow",
		Position = UDim2.fromOffset(UIStyle.Shadow.X, UIStyle.Shadow.Y),
		Size = body,
		Rotation = UIStyle.Tilt,
	})
	local slab = Components.slab(holder, { color = opts.color or UIStyle.Accent }, { Name = "Slab", Size = body, Rotation = UIStyle.Tilt, ZIndex = 2 })
	Components.label(slab, text, { font = "Header", size = textSize, color = opts.textColor or UIStyle.Ink }, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})
	holder.Parent = parent
	return holder
end

-- A selectable button: a paper-white slab with ink text. Hover and gamepad selection flip it to amber, nudge
-- the text and reveal the shadow slab. An "accented" button (a toggle that is on, the current tab) is an ink
-- slab with amber text and an amber underline.
function Components.button(parent, text, onActivated, props)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.Size = UDim2.new(1, 0, 0, 44)
	button.SelectionImageObject = NO_SELECTION_IMAGE

	local shadow = Components.slab(button, { color = UIStyle.Paper }, {
		Name = "Shadow",
		Position = UDim2.fromOffset(UIStyle.Shadow.X, UIStyle.Shadow.Y),
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})
	local fill = Components.slab(button, { color = UIStyle.Paper }, { Name = "Fill", Size = UDim2.fromScale(1, 1), ZIndex = 2 })
	local label = Components.label(button, text, { font = "Header", size = UIStyle.TextSize.Small, color = UIStyle.Ink }, {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BackgroundColor3 = UIStyle.Accent
	edge.BorderSizePixel = 0
	edge.AnchorPoint = Vector2.new(0, 1)
	edge.Position = UDim2.new(0.08, 0, 1, 0)
	edge.Size = UDim2.new(0.84, 0, 0, 2)
	edge.ZIndex = 3
	edge.Visible = false
	edge.Parent = button
	-- A small ink diamond that slides in at the left while the button is highlighted.
	local tick = Instance.new("Frame")
	tick.Name = "Tick"
	tick.BackgroundColor3 = UIStyle.Ink
	tick.BackgroundTransparency = 1
	tick.BorderSizePixel = 0
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.new(0, 8, 0.5, 0)
	tick.Size = UDim2.fromOffset(8, 8)
	tick.Rotation = 45
	tick.ZIndex = 3
	tick.Parent = button

	button:SetAttribute("Accented", false)
	local info = TweenInfo.new(HIGHLIGHT_TIME, UIStyle.Motion.Style, UIStyle.Motion.Direction)
	local hovered, selected = false, false
	local function refresh()
		if button:GetAttribute("Disabled") then
			return
		end
		local on = hovered or selected
		local accented = button:GetAttribute("Accented") == true
		shadow.Visible = on
		edge.Visible = accented and not on
		Components.tweenPaint(fill, info, if on then UIStyle.Accent elseif accented then UIStyle.Ink else UIStyle.Paper)
		TweenService:Create(label, info, {
			TextColor3 = if accented and not on then UIStyle.Accent else UIStyle.Ink,
			Position = UDim2.fromOffset(if on then 6 else 0, 0),
		}):Play()
		TweenService:Create(tick, info, { BackgroundTransparency = if on then 0 else 1, Position = UDim2.new(0, if on then 26 else 8, 0.5, 0) }):Play()
	end
	button.MouseEnter:Connect(function()
		hovered = true
		refresh()
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		refresh()
	end)
	button.SelectionGained:Connect(function()
		selected = true
		refresh()
	end)
	button.SelectionLost:Connect(function()
		selected = false
		refresh()
	end)
	button:GetAttributeChangedSignal("Accented"):Connect(refresh)
	-- Pressing kicks the slab onto its shadow for a moment.
	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		fill.Position = UDim2.fromOffset(UIStyle.Shadow.X, UIStyle.Shadow.Y)
		TweenService:Create(fill, TweenInfo.new(UIStyle.Pop.Time, UIStyle.Pop.Style, UIStyle.Pop.Direction), { Position = UDim2.new() }):Play()
	end)
	if onActivated then
		button.Activated:Connect(onActivated)
	end
	apply(button, props)
	button.Parent = parent
	return button
end

function Components.setText(button, text)
	button.Label.Text = text
end

-- Accented = the "on" look: ink slab, amber text, amber underline.
function Components.setAccented(button, on)
	button:SetAttribute("Accented", on == true)
end

function Components.getText(button)
	return button.Label.Text
end

-- A disabled-looking button that can't be selected or pressed.
function Components.disable(button)
	button:SetAttribute("Disabled", true)
	button.Active = false
	button.Selectable = false
	button.Label.TextColor3 = UIStyle.Paper
	button.Label.TextTransparency = 0.5
	Components.paint(button.Fill, nil, 0.82)
end

-- On/off control. Returns the button and a setter that doesn't fire onChanged.
function Components.toggle(parent, value, onChanged, props)
	local state = value
	local button
	local function show()
		Components.setText(button, if state then "ON" else "OFF")
		Components.setAccented(button, state)
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
		Components.setText(button, options[index].text)
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
	track.BackgroundTransparency = 1
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 56, 0.5, 0)
	track.Size = UDim2.new(1, -176, 0, 20)
	track.Parent = holder
	Components.slab(track, { color = UIStyle.PanelStroke.Color, slant = false }, { Name = "Groove", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 10) })
	local fill = Components.slab(track, { color = UIStyle.Accent, slant = false }, { Name = "Fill", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), ZIndex = 2 })
	local text = Components.label(holder, "", { font = "Mono", size = UIStyle.TextSize.Small }, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -52, 0.5, 0),
		Size = UDim2.new(0, 56, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local function show()
		fill.Size = UDim2.new((value - spec.min) / (spec.max - spec.min), 0, 0, 10)
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

-- A small mono tag at the left of a button ("01").
function Components.tag(button, text)
	return Components.label(button, text, { font = "Mono", size = UIStyle.TextSize.Tiny, color = UIStyle.Ink }, {
		Name = "Tag",
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(0, 40, 1, 0),
		TextTransparency = if button:GetAttribute("Disabled") then 0.6 else 0.35,
		ZIndex = 3,
	})
end

-- Plays a control's entrance after delay seconds: its slab slides in from the left while it fades up and the
-- text follows. Works for buttons and titles, also inside layouts (only their children move).
Components.ENTER = { Time = 0.32, Slide = 90, Step = 0.045, MaxTotal = 0.5 }

function Components.enter(control, delay)
	local main = control:FindFirstChild("Fill") or control:FindFirstChild("Slab")
	if not main then
		return
	end
	local config = Components.ENTER
	local info = TweenInfo.new(config.Time, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay or 0)
	local fade = TweenInfo.new(config.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0)
	local disabled = control:GetAttribute("Disabled") == true
	main.Position = UDim2.fromOffset(-config.Slide, 0)
	TweenService:Create(main, info, { Position = UDim2.new() }):Play()
	for _, piece in ipairs(piecesOf(main)) do
		piece.BackgroundTransparency = 1
		TweenService:Create(piece, fade, { BackgroundTransparency = if disabled then 0.82 else 0 }):Play()
	end
	for _, name in ipairs({ "Label", "Tag" }) do
		local text = control:FindFirstChild(name)
		if text then
			local shown = text:GetAttribute("Shown") or text.TextTransparency
			text:SetAttribute("Shown", shown)
			text.TextTransparency = 1
			TweenService:Create(text, fade, { TextTransparency = shown }):Play()
		end
	end
	local text = main:FindFirstChildWhichIsA("TextLabel")
	if text then
		text.TextTransparency = 1
		TweenService:Create(text, fade, { TextTransparency = 0 }):Play()
	end
	-- A title's shadow slab comes out from under it.
	local shadow = control:FindFirstChild("Shadow")
	if shadow and main.Name == "Slab" then
		shadow.Position = UDim2.fromOffset(-config.Slide, 0)
		TweenService:Create(shadow, info, { Position = UDim2.fromOffset(UIStyle.Shadow.X, UIStyle.Shadow.Y) }):Play()
		for _, piece in ipairs(piecesOf(shadow)) do
			piece.BackgroundTransparency = 1
			TweenService:Create(piece, fade, { BackgroundTransparency = 0 }):Play()
		end
	end
end

-- Plays the entrance of every button and title under root, one after another (in creation order).
-- opts: delay (s before the first), step (s between two; shortened so the whole run stays under MaxTotal).
function Components.cascade(root, opts)
	opts = opts or {}
	local controls = {}
	for _, descendant in ipairs(root:GetDescendants()) do
		local isButton = descendant:FindFirstChild("Fill") and descendant:FindFirstChild("Label")
		local isTitle = descendant:FindFirstChild("Slab") and descendant:FindFirstChild("Shadow")
		if isButton or isTitle then
			table.insert(controls, descendant)
		end
	end
	local config = Components.ENTER
	local step = math.min(opts.step or config.Step, config.MaxTotal / math.max(1, #controls))
	for index, control in ipairs(controls) do
		Components.enter(control, (opts.delay or 0) + step * (index - 1))
	end
	return #controls
end

-- The key box of prompts and hints: a tilted amber square with the glyph in ink, over a paper shadow.
function Components.keyGlyph(parent, text, size)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent
	Components.slab(holder, { color = UIStyle.Paper, slant = false }, {
		Name = "Shadow",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromScale(1, 1),
		Rotation = 2 * UIStyle.Tilt,
	})
	local box = Components.slab(holder, { color = UIStyle.Accent, slant = false }, { Name = "Box", Size = UDim2.fromScale(1, 1), Rotation = 2 * UIStyle.Tilt, ZIndex = 2 })
	local label = Components.label(box, text, { font = "Header", size = UIStyle.TextSize.Body, color = UIStyle.Ink }, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = #text > 2,
		ZIndex = 3,
	})
	return holder, label
end

return Components
