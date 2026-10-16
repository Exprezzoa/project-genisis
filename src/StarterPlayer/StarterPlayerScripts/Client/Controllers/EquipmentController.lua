--!nonstrict
-- Client/Controllers/EquipmentController.lua  (docs/17_saving_progression_monetization.md §6; map_01 §7)
--
-- The Equipment Terminal's screen (UI/EquipmentScreen) as a Menu screen: the server opens it (UI_Open
-- { screen = "Equipment" }) when the terminal is used; BUY asks the server (ProgressionController.buy, Upgrade_Buy)
-- and the answer (Upgrade_Result) plays on the screen.
--
--   open()   getScreen() -> screen

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Modules.Net)

local EquipmentScreen = require(script.Parent.Parent.UI.EquipmentScreen)
local MenuController = require(script.Parent.MenuController)
local ProgressionController = require(script.Parent.ProgressionController)
local UIController = require(script.Parent.UIController)

local EquipmentController = {}

local screen
local pending = false -- a purchase is on its way: its answer animates the credits, not the snapshot

-- Filled in before it shows, so the entrance animation runs on the right BUY state.
function EquipmentController.open()
	screen.refresh(ProgressionController.get())
	MenuController.open("Equipment")
end

function EquipmentController.getScreen()
	return screen
end

function EquipmentController.Init()
	screen = EquipmentScreen.build(UIController.getLayer("Menu"), {
		onBuy = function(upgradeId)
			if not pending then
				pending = true
				ProgressionController.buy(upgradeId)
			end
		end,
		onClose = MenuController.close,
	})
	MenuController.registerScreen("Equipment", screen.frame, screen.first, { blur = true })
end

function EquipmentController.Start()
	Net.on("UI_Open", function(payload)
		if payload.screen == "Equipment" then
			EquipmentController.open()
		end
	end)
	ProgressionController.Changed:Connect(function(state)
		if screen.frame.Visible and not pending then
			screen.refresh(state)
		end
	end)
	ProgressionController.Result:Connect(function(result)
		pending = false
		screen.result(result, ProgressionController.get())
	end)
end

return EquipmentController
