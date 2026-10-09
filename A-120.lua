local CollectionService = game:GetService("CollectionService")
-- CREDIT TO REGULAR VYNIXU

loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"))()

local Main_Game = require(game.Players.LocalPlayer.PlayerGui.MainUI.Initiator.Main_Game)

local ROOT = "https://github.com/RegularVynixu/DOORS-Entity-Spawner-V2/raw/main"


local function Shake()
    local Earthquake = LoadCustomInstance(ROOT.."/Assets/Earthquake.rbxm")
    Earthquake.Parent = workspace
    Earthquake.SoundEarthquake.Volume = 2.5
    Earthquake.SoundEarthquake:Play()
    local v5 = CollectionService:GetTagged("PartCeiling")
    local v6 = {}
    for _, v7 in v5 do
        local v8 = v7.Size.Magnitude * 0.7
        local v9 = math.clamp(v8, 0, 150)
        for _, v10 in Earthquake.Particles:GetChildren() do
            local v11 = v10:Clone()
            v11.Parent = v7
            v11:Emit(v9 / 10)
            v11.Enabled = true
            table.insert(v6, v11)
        end
    end
    task.wait(4)
    for _, v12 in v6 do
        v12.Enabled = false
    end
    task.wait(6)
    Earthquake:Destroy()
end

local PathfindingMovement = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Room_Path_Find.lua"))()
task.spawn(function()
    Main_Game.camShaker:ShakeOnce(21, 2, 3, 3)  
    Shake()
end)

        local entityConfig = {
            Model = game:GetObjects("rbxassetid://103020442987735")[1],
            Speed = 40,
            HeightOffset = 6,
            FloorYOffset = -2,
            DelayTime = 5,
            SpawnOffsetRooms = 5,
            AttackType = "Front",

            HitboxRange = 25,
            RaycastHitbox = false,
            SphereRadius = 3.5,
            Damage = 100,

            LightFlicker = false,
            Duration = 1.5,
            LightBreak = false,

            Rebound = false,
            ReboundCount = 2,
            ReboundTime = 1.5,
            ReboundDelayTime = 1.0,

            EnableCameraShake = true,
            ShakeValues = {1.5, 20, 0.1, 1},
            ShakeRadius = 100,

            ShowPath = false,

            Callbacks = {
                OnSpawned = function(model, actions)
                    model.PrimaryPart = model.Main
			        for _,v in ipairs(model.Main:GetChildren()) do
				        if v:IsA("Sound") then
					        v.RollOffMaxDistance = v.RollOffMaxDistance * 1.5
				        end
				    end
                end,

                OnStartMoving = function(model, actions)
                end,

                OnStartRebounding = function(model, reboundCount, actions)
                end,

                OnEnterRoom = function(model, roomFolder, actions)
                end,

                OnEnterPlayerRoom = function(model, roomFolder, playerCharacter, actions)
                    if playerCharacter and playerCharacter.PrimaryPart then
                        task.wait(0.75)
				        --actions.Stop()
                        --task.wait(0.1)
                        actions.MoveTo(playerCharacter.PrimaryPart.CFrame.Position + (playerCharacter.PrimaryPart.CFrame.LookVector * 3), {
                            Speed = 40,
                            ReachDistance = 3,
                            HeightOffset = 2,
                        })
                        --task.wait(0.1)
                        --actions.Resume(2)
                    end
                end,

                OnSeePlayer = function(model, playerCharacter, actions)
                end,

                OnKillPlayer = function(model, playerCharacter, actions)
                end,
                
                OnCrucifixion = function(model: Model | BasePart, actions)
		    model:SetAttribute("Crucified", true)
	        end,

                OnDespawn = function(model, actions)
                end
            }
        }

        task.spawn(function()
            PathfindingMovement.MoveThroughRooms(entityConfig)
        end)
