--!strict
-- Client/Controllers/UIController.lua  (docs/14_ui.md §1, §11)
--
-- Creates the ScreenGui layers (HUD 10, Prompts 15, Dialogue 20, Cards 30, Menu 40, Letterbox 50, Fade 90),
-- keeps their UIScale in step with the viewport, and owns the one global fade.
--
--   getLayer(name) -> ScreenGui    getScale() -> number
--   fade(to, duration)             -- to: 1 = black, 0 = clear; yields until done. Also driven by the Fade remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIStyle = require(Shared.Config.UIStyle)
local Net = require(Shared.Modules.Net)

-- Full-screen layers ignore the inset; HUD layers stay inside the safe area.
local FULL_SCREEN = { Cards = true, Menu = true, Letterbox = true, Fade = true, Subtitles = true }
-- Subtitles sit over the fade: radio lines play over black (S01, S33) and through cinematics (D-083).
local LAYERS = { "HUD", "Prompts", "Dialogue", "Cards", "Menu", "Letterbox", "Fade", "Subtitles" }
-- Core UI this game replaces or doesn't use (Tab opens the Mission Log; there is no on-foot health).
local HIDDEN_CORE = { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu }

local UIController = {}

local layers: { [string]: ScreenGui } = {}
local scales: { UIScale } = {}
local fadeFrame: Frame
local fadeTween: Tween? = nil
local scale = 1

local function computeScale(viewport: Vector2): number
	local rule = UIStyle.Scale
	local value = math.clamp(math.min(viewport.X / rule.Reference.X, viewport.Y / rule.Reference.Y), rule.Min, rule.Max)
	if math.min(viewport.X, viewport.Y) < rule.PhoneSide then
		value *= rule.PhoneBoost
	end
	return value
end

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	scale = computeScale(camera.ViewportSize)
	for _, uiScale in ipairs(scales) do
		uiScale.Scale = scale
	end
end

function UIController.getLayer(name: string): ScreenGui
	local layer = layers[name]
	if not layer then
		error("UIController: unknown layer " .. tostring(name), 2)
	end
	return layer
end

function UIController.getScale(): number
	return scale
end

function UIController.fade(to: number, duration: number?)
	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end
	local target = 1 - math.clamp(to, 0, 1)
	if not duration or duration <= 0 then
		fadeFrame.BackgroundTransparency = target
		return
	end
	local tween = TweenService:Create(fadeFrame, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = target })
	fadeTween = tween
	tween:Play()
	tween.Completed:Wait()
end

function UIController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, name in ipairs(LAYERS) do
		local gui = Instance.new("ScreenGui")
		gui.Name = "PG_" .. name
		gui.DisplayOrder = (UIStyle.DisplayOrder :: any)[name]
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		if FULL_SCREEN[name] then
			gui.IgnoreGuiInset = true
		else
			gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		end
		-- The fade covers the screen at any scale, so it gets no UIScale.
		if name ~= "Fade" then
			local uiScale = Instance.new("UIScale")
			uiScale.Parent = gui
			table.insert(scales, uiScale)
		end
		gui.Parent = playerGui
		layers[name] = gui
	end

	fadeFrame = Instance.new("Frame")
	fadeFrame.Name = "Fade"
	fadeFrame.Size = UDim2.fromScale(1, 1)
	fadeFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	fadeFrame.BackgroundTransparency = 1
	fadeFrame.BorderSizePixel = 0
	fadeFrame.Active = false
	fadeFrame.Parent = layers.Fade
	updateScale()
end

function UIController.Start()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	Net.on("Fade", function(payload: { to: number, duration: number? })
		UIController.fade(payload.to, payload.duration)
	end)
	task.spawn(function()
		-- SetCoreGuiEnabled can fail while the core scripts are still loading.
		for _ = 1, 10 do
			local ok = pcall(function()
				for _, coreType in ipairs(HIDDEN_CORE) do
					StarterGui:SetCoreGuiEnabled(coreType, false)
				end
			end)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)
end

return UIController
