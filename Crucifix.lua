local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Load the Item Spawner module from GitHub
local ItemSpawner = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/ItemSpawner.lua"))()

local currentRooms = workspace:WaitForChild("CurrentRooms")
local GameData = ReplicatedStorage:WaitForChild("GameData")
local LatestRoom = GameData:WaitForChild("LatestRoom")
local seedNumber = GameData:WaitForChild("GameSeedInitial")

local spawnRoom = currentRooms:WaitForChild(tostring(LatestRoom.Value))

local chance = nil

if GameData.Floor.Value == "Archives" or GameData.Floor.Value == "Mines" the
	chance = 125
else
	chance = 75
end

local itemConfig = {
	SpawnChance = 1,
	MaxChance = chance or 125,
	
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
		closet = { -- ONLY ARCHIVES FLOOR SUPPORTED AND WORKING ON IT
			Enabled = false,
			Offset = Vector3.new(0, 0, 0),
			RotationOffset = Vector3.new(90, 0, math.random(0,180)),
		},
		floor = { -- ONLY ARCHIVES FLOOR SUPPORTED
			Enabled = true,
			Offset = Vector3.new(0, -0.4, 0),
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
		MaxActivationDistance = 8,
		RequiresLineOfSight = true,
		KeyboardKeyCode = Enum.KeyCode.E,
	},
	
	callbacks = {
		OnSpawned = function(itemModel: Model | BasePart, room: Model, handle: table)
			local itemHandle = handle.GetItem()
			local holderPart = handle.GetHolder()
			
			local light = Instance.new("PointLight")
			light.Brightness = 0.5
			light.Color = Color3.fromRGB(255,245,234)
			light.Range = 1.66
			light.Parent = itemHandle
			
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://18125587966"
			sound.PlaybackSpeed = 1
			sound.RollOffMaxDistance = 60
			sound.RollOffMinDistance = 7
			sound.Volume = 0.5
			sound.RollOffMode = Enum.RollOffMode.Linear
			sound.Parent = holderPart

			local distortion = Instance.new("DistortionSoundEffect")
			distortion.Level = 0.44
			distortion.Parent = sound

			sound:Play()
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

ItemSpawner.spawn(itemTemplate, spawnRoom, itemConfig, seedNumber.Value)
