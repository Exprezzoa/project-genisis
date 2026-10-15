--!nonstrict
-- Client/UI/ChapterEndCard.lua  (docs/14_ui.md §9 "Chapter End"; docs/05 S43)
--
-- Black: CHAPTER ONE (Michroma 18, secondary) / THE LAST QUIET MORNING (Michroma 32) / Evidence found: N/3
-- (TitilliumWeb 18) / To be continued in Chapter Two: CLASSIFIED (italic, secondary) / Continue. The lines come up
-- one after another; a hairline draws under the title. It stays until Continue (click, Enter / Space, or A).
--
--   ChapterEndCard.show(parent, data, onContinue) -> close()      data = { chapter, title, evidence, total, next }

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Components)

local ChapterEndCard = {}

local CONTINUE_ACTION = "PG_CardContinue"

function ChapterEndCard.show(parent, data, onContinue)
	local root = Instance.new("Frame")
	root.Name = "ChapterEnd"
	root.BackgroundColor3 = UIStyle.Ink
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 20
	root.Parent = parent
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.46)
	column.Size = UDim2.fromOffset(900, 300)
	column.ZIndex = 21
	column.Parent = root
	local entries = {
		{ data.chapter or "CHAPTER ONE", "Header", 18, UIStyle.TextSecondary, 0 },
		{ data.title or "THE LAST QUIET MORNING", "Header", 32, UIStyle.Paper, 32 },
		{ ("Evidence found: %d/%d"):format(data.evidence or 0, data.total or 3), "Body", 18, UIStyle.TextPrimary, 116 },
		{ data.next or "To be continued in Chapter Two: CLASSIFIED", "BodyItalic", 18, UIStyle.TextSecondary, 150 },
	}
	local labels = {}
	for index, entry in ipairs(entries) do
		local label = Components.label(column, entry[1], { font = entry[2], size = entry[3], color = entry[4] }, {
			Position = UDim2.fromOffset(0, entry[5] + 8), Size = UDim2.new(1, 0, 0, entry[3] + 12),
			TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1, ZIndex = 22,
		})
		labels[index] = label
		task.delay(0.4 + (index - 1) * 0.55, function()
			if label.Parent then
				TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
					TextTransparency = 0, Position = UDim2.fromOffset(0, entry[5]),
				}):Play()
			end
		end)
	end
	local rule = Components.slab(column, { color = UIStyle.Accent, transparency = 0.3, slant = false }, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.fromOffset(0, 2), ZIndex = 22,
	})
	task.delay(1.1, function()
		if rule.Parent then
			TweenService:Create(rule, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(420, 2) }):Play()
		end
	end)

	local closed = false
	local button
	local function close()
		if closed then
			return
		end
		closed = true
		ContextActionService:UnbindAction(CONTINUE_ACTION)
		if GuiService.SelectedObject == button then
			GuiService.SelectedObject = nil
		end
		TweenService:Create(root, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		for _, label in ipairs(labels) do
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
		rule.Visible = false
		button.Visible = false
		task.delay(0.42, function()
			root:Destroy()
		end)
		onContinue()
	end
	button = Components.button(root, "Continue", close, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.46, 190), Size = UDim2.fromOffset(220, 48), ZIndex = 22,
	})
	button.Visible = false
	task.delay(0.4 + #entries * 0.55 + 0.6, function()
		if closed then
			return
		end
		button.Visible = true
		Components.enter(button)
		GuiService.SelectedObject = button
		ContextActionService:BindAction(CONTINUE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.Return, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	end)
	return close
end

return ChapterEndCard
