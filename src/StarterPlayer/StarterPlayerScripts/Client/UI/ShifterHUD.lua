--!nonstrict
-- Client/UI/ShifterHUD.lua  (D-096; docs/14 §5 style: slanted slabs, amber UI, Lattice cyan for the Shifter's own)
--
-- The Titan form's HUD, bottom-left where the Frame HUD sits when piloting (ShifterController drives it):
--   TITAN FORM
--   HP        ███████████░░  9000      (the rig's Integrity / IntegrityMax)
--   STRENGTH  ███████░░░░░░  2:31      (the meter, player attribute ShiftEnergy, and how long it lasts at its drain)
--   [Q] HARDENING   READY / 12 s / ACTIVE 9 s        [T] next   (when more than one special is unlocked)
--
--   ShifterHUD.build(layer) -> hud      hud.show(on)      hud.update(state)
--   state = { hp, hpMax, energy, special, specialReady (0..1), specialActive (seconds left)?, more (boolean),
--             buffs = { { label, left } }, specialKey, nextKey }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShifterConfig = require(Shared.Config.ShifterConfig)
local UIStyle = require(Shared.Config.UIStyle)

local Components = require(script.Parent.Components)

local ShifterHUD = {}

local WIDTH = 380

local function bar(parent, y, labelText, color)
	Components.label(parent, labelText, { font = "Header", size = 12, color = UIStyle.TextSecondary }, {
		Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(84, 16),
	})
	local track = Components.slab(parent, { color = UIStyle.Paper, transparency = 0.82, slant = false }, {
		Position = UDim2.fromOffset(88, y + 4), Size = UDim2.fromOffset(WIDTH - 160, 8),
	})
	local fill = Components.slab(track, { color = color, slant = false }, { Size = UDim2.fromScale(1, 1) })
	local value = Components.label(parent, "", { font = "Mono", size = 14, color = UIStyle.TextPrimary }, {
		Position = UDim2.fromOffset(WIDTH - 66, y - 1), Size = UDim2.fromOffset(66, 18), TextXAlignment = Enum.TextXAlignment.Right,
	})
	return fill, value
end

function ShifterHUD.build(layer)
	local root = Instance.new("Frame")
	root.Name = "ShifterHUD"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 36, 1, -36)
	root.Size = UDim2.fromOffset(WIDTH, 150)
	root.Visible = false
	root.Parent = layer
	Components.slab(root, { color = UIStyle.Ink, transparency = 0.3 }, { Name = "Back", Position = UDim2.fromOffset(-14, 22), Size = UDim2.new(1, 28, 1, -22) })
	local title = Components.slab(root, { color = UIStyle.Resonance }, { Name = "Title", Size = UDim2.fromOffset(170, 26), Rotation = UIStyle.Tilt })
	Components.label(title, "TITAN FORM", { font = "Header", size = 16, color = UIStyle.Ink }, {
		Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2,
	})
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 38)
	body.Size = UDim2.new(1, 0, 1, -38)
	body.Parent = root
	local hpFill, hpValue = bar(body, 0, "HP", UIStyle.Paper)
	local energyFill, energyValue = bar(body, 26, "STRENGTH", UIStyle.Resonance)

	-- The special: its key, its name, and its state; the next-special key when there is more than one.
	local specialRow = Instance.new("Frame")
	specialRow.BackgroundTransparency = 1
	specialRow.Position = UDim2.fromOffset(0, 54)
	specialRow.Size = UDim2.new(1, 0, 0, 34)
	specialRow.Parent = body
	local specialGlyph, specialKey = Components.keyGlyph(specialRow, "Q", 28)
	specialGlyph.Position = UDim2.fromOffset(0, 2)
	local specialName = Components.label(specialRow, "", { font = "Header", size = 14, color = UIStyle.Paper }, {
		Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(150, 18),
	})
	local specialState = Components.label(specialRow, "", { font = "Mono", size = 12, color = UIStyle.TextSecondary }, {
		Position = UDim2.fromOffset(40, 17), Size = UDim2.fromOffset(150, 14),
	})
	local cooldownTrack = Components.slab(specialRow, { color = UIStyle.Paper, transparency = 0.85, slant = false }, {
		Position = UDim2.fromOffset(40, 32), Size = UDim2.fromOffset(150, 2),
	})
	local cooldownFill = Components.slab(cooldownTrack, { color = UIStyle.Resonance, slant = false }, { Size = UDim2.fromScale(1, 1) })
	local nextGlyph, nextKey = Components.keyGlyph(specialRow, "T", 22)
	nextGlyph.Position = UDim2.fromOffset(206, 6)
	local nextLabel = Components.label(specialRow, "NEXT", { font = "Header", size = 11, color = UIStyle.TextSecondary }, {
		Position = UDim2.fromOffset(234, 8), Size = UDim2.fromOffset(50, 16),
	})
	local buffsLabel = Components.label(root, "", { font = "Header", size = 13, color = UIStyle.Resonance }, {
		Position = UDim2.fromOffset(180, 4), Size = UDim2.fromOffset(WIDTH - 180, 18), TextXAlignment = Enum.TextXAlignment.Right,
	})

	local hud = {}
	local shown = false
	function hud.show(on)
		if on == shown then
			return
		end
		shown = on
		root.Visible = on
		if on then
			root.Position = UDim2.new(0, 36, 1, 20)
			TweenService:Create(root, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0, 36, 1, -36) }):Play()
		end
	end
	function hud.update(state)
		hpFill.Size = UDim2.fromScale(math.clamp(state.hp / math.max(state.hpMax, 1), 0, 1), 1)
		hpValue.Text = tostring(math.floor(state.hp + 0.5))
		energyFill.Size = UDim2.fromScale(math.clamp(state.energy / ShifterConfig.energy.max, 0, 1), 1)
		local seconds = math.max(0, state.energy / ShifterConfig.energy.drain)
		energyValue.Text = ("%d:%02d"):format(math.floor(seconds / 60), math.floor(seconds % 60))
		energyFill.BackgroundColor3 = if state.energy < 15 then UIStyle.Danger else UIStyle.Resonance
		specialKey.Text = state.specialKey or "Q"
		nextKey.Text = state.nextKey or "T"
		nextGlyph.Visible, nextLabel.Visible = state.more == true, state.more == true
		if state.special then
			specialGlyph.Visible = true
			specialName.Text = ShifterConfig.specials[state.special].label
			if state.specialActive then
				specialState.Text = ("ACTIVE %d S"):format(math.ceil(state.specialActive))
			elseif (state.specialReady or 1) < 1 then
				specialState.Text = "RECHARGING"
			else
				specialState.Text = ("READY  -%d"):format(ShifterConfig.specials[state.special].cost)
			end
			cooldownFill.Size = UDim2.fromScale(state.specialReady or 1, 1)
		else
			specialGlyph.Visible = false
			specialName.Text = "NO SPECIAL"
			specialState.Text = "UNLOCKED THROUGH THE STORY"
			cooldownFill.Size = UDim2.fromScale(0, 1)
		end
		local chips = {}
		for _, buff in ipairs(state.buffs or {}) do
			table.insert(chips, ("%s %ds"):format(buff.label, math.ceil(buff.left)))
		end
		buffsLabel.Text = table.concat(chips, "   ")
	end
	return hud
end

return ShifterHUD
