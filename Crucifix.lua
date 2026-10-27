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
	SpawnChance = 1,
	MaxChance = 200,
	
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
            local Players = game:GetService("Players")
            local LocalPlayer = Players.LocalPlayer
			local backpack = LocalPlayer:WaitForChild("Backpack")
			local char = LocalPlayer.Character

			local checkCrucifix = char:FindFirstChild("Crucifix") or backpack:FindFirstChild("Crucifix")
			if checkCrucifix then
				local Event = ReplicatedStorage.RemotesFolder.FlashSpecify
                firesignal(Event.OnClientEvent, 
                    "AmountMax",
                    checkCrucifix,
                    1
                )
				return
			end

            local asset = LoadCustomInstance("https://github.com/RegularVynixu/DOORS-Crucifix-Everything/raw/refs/heads/main/Assets/Crucifix.rbxm")

            if asset then
                local tool = nil

                if asset:IsA("Tool") then
                    tool = asset
                    tool.Name = "Crucifix"
                else
                    tool = Instance.new("Tool")
                    tool.Name = "Crucifix"
                    tool.CanBeDropped = false
        
                    asset.Name = "Handle"
                    asset.Parent = tool
                end
                tool:AddTag("Crucifix")
                tool.Parent = backpack

				print(player.Name, "picked up the item!")
			    handle.Destroy()
            end
		end
	}
}

local fetchFunc = (typeof(getgenv) == "function" and getgenv().LoadCustomInstance) or _G.LoadCustomInstance or LoadCustomInstance
local itemTemplate = fetchFunc("https://github.com/RegularVynixu/DOORS-Crucifix-Everything/raw/refs/heads/main/Assets/Crucifix.rbxm")

ItemSpawner.spawn(itemTemplate, spawnRoom, itemConfig)
