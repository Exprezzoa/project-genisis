--!nonstrict
-- Client/Controllers/DebugController.lua  (docs/19_testing_and_debug.md §2)
--
-- Studio-only debug panel: F2 opens a command box. Server commands go out as Debug_Command; the client
-- handles /fps (stats overlay), /nav (nav nodes and links) and /help. Outside Studio it does nothing.
--
--   run(text) -> message?      isOpen()      getOverlayText()

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Debug = require(Shared.Config.Debug)
local UIStyle = require(Shared.Config.UIStyle)
local Net = require(Shared.Modules.Net)

local Components = require(script.Parent.Parent.UI.Components)
local HUDController = require(script.Parent.HUDController)
local UIController = require(script.Parent.UIController)

local IS_STUDIO = RunService:IsStudio()

local DebugController = {}

local panel, box, overlay
local navFolder = nil
local fpsConnection = nil

local function split(text)
	local words = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(words, word)
	end
	return words
end

local function pingMs()
	local ok, value = pcall(function()
		return Players.LocalPlayer:GetNetworkPing() * 1000
	end)
	return if ok then value else 0
end

local function toggleFps()
	if fpsConnection then
		fpsConnection:Disconnect()
		fpsConnection = nil
		overlay.Visible = false
		return "stats overlay off"
	end
	overlay.Visible = true
	local frames, elapsed = 0, 0
	fpsConnection = RunService.RenderStepped:Connect(function(dt)
		frames += 1
		elapsed += dt
		if elapsed >= 0.5 then
			local parts = 0
			for _, descendant in ipairs(workspace:GetDescendants()) do
				if descendant:IsA("BasePart") then
					parts += 1
				end
			end
			overlay.Text = ("FPS %.0f | ping %.0f ms | parts %d | physics %.0f Hz | memory %.0f MB"):format(
				frames / elapsed,
				pingMs(),
				parts,
				workspace:GetRealPhysicsFPS(),
				Stats:GetTotalMemoryUsageMb()
			)
			frames, elapsed = 0, 0
		end
	end)
	return "stats overlay on"
end

local function toggleNav()
	if navFolder then
		navFolder:Destroy()
		navFolder = nil
		return "nav display off"
	end
	navFolder = Instance.new("Folder")
	navFolder.Name = "DebugNav"
	local nodes = {}
	for _, part in ipairs(CollectionService:GetTagged("NavNode")) do
		nodes[part:GetAttribute("NavId")] = part
	end
	local count, links = 0, 0
	for id, part in pairs(nodes) do
		count += 1
		local marker = Instance.new("Part")
		marker.Shape = Enum.PartType.Ball
		marker.Size = Vector3.new(1, 1, 1)
		marker.Position = part.Position + Vector3.new(0, 0.5, 0)
		marker.Anchored, marker.CanCollide, marker.CanQuery = true, false, false
		marker.Material = Enum.Material.Neon
		marker.Color = UIStyle.Accent
		marker.Parent = navFolder
		for otherId in string.gmatch(part:GetAttribute("Links") or "", "[^,]+") do
			local other = nodes[otherId]
			if other and id < otherId then
				links += 1
				local a, b = part.Position + Vector3.new(0, 0.5, 0), other.Position + Vector3.new(0, 0.5, 0)
				local line = Instance.new("Part")
				line.Size = Vector3.new(0.15, 0.15, (b - a).Magnitude)
				line.CFrame = CFrame.lookAt((a + b) / 2, b)
				line.Anchored, line.CanCollide, line.CanQuery = true, false, false
				line.Material = Enum.Material.Neon
				line.Color = UIStyle.Accent
				line.Transparency = 0.4
				line.Parent = navFolder
			end
		end
	end
	navFolder.Parent = workspace
	return ("nav display on: %d nodes, %d links"):format(count, links)
end

local function help()
	local names = {}
	for name, command in pairs(Debug.Commands) do
		if command.phase <= Debug.CURRENT_PHASE then
			table.insert(names, command.usage)
		end
	end
	table.sort(names)
	return table.concat(names, "   ")
end

-- Runs one command line ("/tp SPAWN_OPS"). Returns the message of a client command, nil for a server one.
function DebugController.run(text)
	if not IS_STUDIO then
		return nil
	end
	local words = split(text)
	local name = string.lower(string.gsub(words[1] or "", "^/", ""))
	table.remove(words, 1)
	local command = Debug.Commands[name]
	local message
	if not command then
		message = "unknown command /" .. name .. " (try /help)"
	elseif command.side == "server" then
		Net.fireServer("Debug_Command", { cmd = name, args = words })
		return nil
	elseif command.phase > Debug.CURRENT_PHASE then
		message = ("/%s is not available until Phase %d"):format(name, command.phase)
	elseif name == "fps" then
		message = toggleFps()
	elseif name == "nav" then
		message = toggleNav()
	else
		message = help()
	end
	HUDController.toast(message)
	return message
end

function DebugController.isOpen()
	return panel ~= nil and panel.Visible
end

function DebugController.getOverlayText()
	return if overlay and overlay.Visible then overlay.Text else nil
end

function DebugController.Init()
	if not IS_STUDIO then
		return
	end
	local layer = UIController.getLayer("Cards")
	panel = Components.panel(layer, { solid = true, accent = true, padding = UIStyle.Padding }, {
		Name = "DebugPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(720, 64),
		Visible = false,
	})
	box = Instance.new("TextBox")
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.FontFace = UIStyle.Font.Mono
	box.TextSize = UIStyle.TextSize.Body
	box.TextColor3 = UIStyle.Accent
	box.PlaceholderText = "debug command, e.g. /tp SPAWN_OPS   (/help)"
	box.PlaceholderColor3 = UIStyle.TextSecondary
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Parent = panel
	overlay = Components.label(UIController.getLayer("HUD"), "", { font = "Mono", size = UIStyle.TextSize.Small, color = UIStyle.Accent }, {
		Name = "DebugStats",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(640, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
end

function DebugController.Start()
	if not IS_STUDIO then
		return
	end
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Debug.TOGGLE_KEY then
			panel.Visible = not panel.Visible
			if panel.Visible then
				box:CaptureFocus()
			else
				box:ReleaseFocus()
			end
		end
	end)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed and box.Text ~= "" then
			DebugController.run(box.Text)
			box.Text = ""
			box:CaptureFocus()
		end
	end)
end

return DebugController
