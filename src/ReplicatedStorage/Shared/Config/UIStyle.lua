--!strict
-- Shared/Config/UIStyle.lua  (docs/14_ui.md §1)
--
-- Style tokens for every screen. All UI is built in code from these; no images.

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local TITILLIUM = "rbxasset://fonts/families/TitilliumWeb.json"

local UIStyle = {
	Panel = { Color = hex("#0E1216"), Transparency = 0.25 },
	PanelSolid = { Color = hex("#0B0E10"), Transparency = 0 },
	PanelStroke = { Color = hex("#2E3640"), Thickness = 1 },
	AccentStroke = { Color = hex("#E8A33D"), Thickness = 2 },

	TextPrimary = hex("#E8ECEF"),
	TextSecondary = hex("#9AA6B2"),
	Accent = hex("#E8A33D"),
	Danger = hex("#E5484D"),
	Success = hex("#46C17A"),
	Warning = hex("#E07A1F"),
	TitanHP = hex("#E25B2D"),
	TitanPoise = hex("#E8B923"),
	FrameIntegrity = hex("#E8A33D"),
	FrameEnergy = hex("#FFD38A"),
	Resonance = hex("#7FE3F0"), -- anomaly only

	CornerRadius = 4,
	Padding = 12,
	Gap = 8,

	Font = {
		Header = Font.fromEnum(Enum.Font.Michroma),
		Body = Font.new(TITILLIUM, Enum.FontWeight.Regular),
		BodyBold = Font.new(TITILLIUM, Enum.FontWeight.SemiBold),
		BodyItalic = Font.new(TITILLIUM, Enum.FontWeight.Regular, Enum.FontStyle.Italic),
		Mono = Font.fromEnum(Enum.Font.RobotoMono),
	},
	-- At UIScale 1.
	TextSize = { Tiny = 12, Small = 14, Body = 18, Large = 22, Title = 28, Hero = 40 },
	MinTextSize = 12,
	SubtitleSize = { S = 18, M = 22, L = 26 }, -- docs/11 §7

	Motion = { Time = 0.2, Style = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out, Slide = 12 },

	DisplayOrder = { HUD = 10, Prompts = 15, Dialogue = 20, Cards = 30, Menu = 40, Letterbox = 50, Fade = 90, Loading = 100 },

	-- UIScale = clamp(min(viewportX / 1920, viewportY / 1080), 0.65, 1.25); x 1.15 on phones (smallest side < 500).
	Scale = { Reference = Vector2.new(1920, 1080), Min = 0.65, Max = 1.25, PhoneSide = 500, PhoneBoost = 1.15 },

	Toast = { Width = 360, Duration = 3.5, Max = 3 },
	Prompt = { Size = Vector2.new(220, 64), KeyBox = 40, StudsOffset = Vector3.new(0, 2, 0) },
}

return UIStyle
