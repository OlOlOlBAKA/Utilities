local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Load the Item Spawner module from GitHub
local ItemSpawner = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/ItemSpawner.lua"))()

local currentRooms = workspace:WaitForChild("CurrentRooms")
local GameData = ReplicatedStorage:WaitForChild("GameData")
local LatestRoom = GameData:WaitForChild("LatestRoom")

local spawnRoom = currentRooms:WaitForChild(tostring(LatestRoom.Value))

local itemConfig = {
	SpawnWeight = 50,
	SpawnChance = 100,
	AllowedLocations = { "Table", "DrawerContainer" },
	
	Offset = Vector3.new(0, 0.2, 0),
	RotationOffset = Vector3.new(0, 0, 0),
	
	Prompt = {
		HoldDuration = 0,
		MaxActivationDistance = 6,
		RequiresLineOfSight = true,
		KeyboardKeyCode = Enum.KeyCode.E,
	},
	
	callbacks = {
		OnSpawned = function(itemModel: Model | BasePart, room: Model, handle: table)
			print("Item spawned successfully in room:", room.Name)
		end,
		
		OnTriggered = function(player: Player, itemModel: Model | BasePart, handle: table)
			print(player.Name, "picked up the item!")
			handle.Destroy()
		end
	}
}

local fetchFunc = (typeof(getgenv) == "function" and getgenv().LoadCustomInstance) or _G.LoadCustomInstance or LoadCustomInstance
local itemTemplate = fetchFunc("https://github.com/RegularVynixu/DOORS-Crucifix-Everything/raw/refs/heads/main/Assets/Crucifix.rbxm")

ItemSpawner.spawn(itemTemplate, spawnRoom, itemConfig)
