local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StationaryEntity = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Stationary_Entity.lua"))()

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer.PlayerGui
local mainUI = playerGui:WaitForChild("MainUI")
local initiator = mainUI:WaitForChild("Initiator")
local Main_Game = require(initiator:WaitForChild("Main_Game"))

local character = localPlayer.Character

local currentRooms = workspace:WaitForChild("CurrentRooms")
local GameData = ReplicatedStorage:WaitForChild("GameData")
local LatestRoom = GameData:WaitForChild("LatestRoom")

local spawnRoom = currentRooms:WaitForChild(tostring(LatestRoom.Value))

local entityConfig = {
	spawnOffset = Vector3.new(0, 4, 0),
	crucifixRange = 16,
	canBeCrucified = true,
	shakerInstance = Main_Game.camShaker,

	callbacks = {
		OnSpawned = function(entity: Model, room: Model, handle: table)
			-- handle.Destroy()                      -> Instantly destroys the entity and stops its loop.
			-- handle.GetEntity()                    -> Returns the spawned entity model instance.
			-- handle.GetRoom()                      -> Returns the room model instance.
			-- handle.SetCanBeCrucified(bool)        -> Dynamically toggle crucifix immunity.
			-- handle.GetCanBeCrucified() -> boolean -> Check current crucifix vulnerability.

			handle.SetCanBeCrucified(false)
			task.delay(3, function()
				if handle.GetEntity() and handle.GetEntity().Parent then
					handle.SetCanBeCrucified(true)
				end
			end)
			LatestRoom.Changed:Wait()
			handle.Destroy()
		end,

		OnCrucifixion = function(entity: Model, character: Model, handle: table)
		end
	}
}

StationaryEntity.spawn(LoadCustomInstance("https://github.com/OlOlOlBAKA/Utilities/raw/main/LatestBlink.rbxm"), spawnRoom, entityConfig)
