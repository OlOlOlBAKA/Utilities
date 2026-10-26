local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Load the Item Spawner module from GitHub
local ItemSpawner = nil

local rawCodeSuccess, rawCodeOrErr = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/ItemSpawner.lua")
end)

if not rawCodeSuccess then
	warn("[Item Spawner Network Error]: Failed to download source ->", rawCodeOrErr)
	return
end

-- 1. Check for Compilation / Syntax Errors
local compiledFunction, syntaxError = loadstring(rawCodeOrErr)
if not compiledFunction then
	warn("[Item Spawner Syntax Error]: The downloaded code has syntax issues ->", syntaxError)
	return
end

-- 2. Check for Runtime/Execution Errors during initialization
local runSuccess, runError = pcall(function()
	ItemSpawner = compiledFunction()
end)

if not runSuccess then
	warn("[Item Spawner Initialization Error]: The script ran but crashed immediately ->", runError)
	return
elseif type(PathfindingMovement) ~= "table" then
	warn("[Item Spawner Content Error]: The script executed successfully, but did not return a valid module table! It returned type:", type(PathfindingMovement))
	return
end

local currentRooms = workspace:WaitForChild("CurrentRooms")
local GameData = ReplicatedStorage:WaitForChild("GameData")
local LatestRoom = GameData:WaitForChild("LatestRoom")

local spawnRoom = currentRooms:WaitForChild(tostring(LatestRoom.Value))

local itemConfig = {
	SpawnWeight = 50,
	SpawnChance = 100,
	
	Locations = {
		table = {
			Enabled = true,
			Offset = Vector3.new(0, 0, 0),
			RotationOffset = Vector3.new(90, 0, math.random(0,180)),
		},
		drawer = {
			Enabled = true,
			Offset = Vector3.new(0, 0, 0),
			RotationOffset = Vector3.new(90, 0, math.random(0,180)),
		},
		chest = {
			Enabled = true,
			Offset = Vector3.new(0, 0, 0),
			RotationOffset = Vector3.new(90, 0, math.random(0,180)),
		},
		wall = {
			Enabled = true,
			Offset = Vector3.new(0, 0, 0),
			RotationOffset = Vector3.new(0, 0, 0),
		},
	},
	
	Offset = Vector3.new(0, 0, 0),
	RotationOffset = Vector3.new(90, 0, math.random(0,180)),
	
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
