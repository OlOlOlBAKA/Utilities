local ReSt = game:GetService("ReplicatedStorage")
        local TS = game:GetService("TweenService")
local isCrucified = false
        task.wait(1)
        local PathfindingMovement = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Room_Path_Find.lua"))()

        local entityConfig = {
            Model = game:GetObjects("rbxassetid://77366392445371")[1],
            Speed = 60,
            HeightOffset = 5,
            FloorYOffset = -2,
            DelayTime = 4,
            SpawnOffsetRooms = 5,
            AttackType = "Front",

            HitboxRange = 50,
            RaycastHitbox = true,
            SphereRadius = 4,
            Damage = 100,

            LightFlicker = false,
            Duration = 1.5,
            LightBreak = false,

            Rebound = false,
            ReboundCount = 2,
            ReboundTime = 1.5,
            ReboundDelayTime = 1.0,

            EnableCameraShake = true,
            ShakeAmount = 5,
            ShakeRadius = 100,

            ShowPath = false,

            Callbacks = {
                OnSpawned = function(model, actions)
                    local ReboundColor = Instance.new("ColorCorrectionEffect", game.Lighting)
                    game:GetService("Debris"):AddItem(ReboundColor, 24)
                    ReboundColor.Name = "Warn"
                    ReboundColor.TintColor = Color3.fromRGB(65,138,255)
                    ReboundColor.Saturation = -0.7
                    ReboundColor.Contrast = 0.2
                    TS:Create(ReboundColor, TweenInfo.new(15), {TintColor = Color3.new(1,1,1), Saturation = 0, Contrast = 0}):Play()
                    
                    task.spawn(function()
                        task.wait(15)
                        if ReboundColor then ReboundColor:Destroy() end
                    end)
                    model.Rebound_Cue2.Volume = 0.5
                    model.Rebound_Cue:Play()
                    model.Rebound_Cue2:Play()
                    model.ReboundNew.Close.Volume = 0.75
                    model.ReboundNew.Idle.Volume = 0.75
                    model.ReboundNew.Sound.Volume = 4

                    task.wait(3.5)
                    model.Rebound_Cue.TimePosition = 0
                    model.Rebound_Cue:Play()
                end,

                OnStartMoving = function(model, actions)
                    for _,v in pairs(model.ReboundNew:GetChildren()) do
                        if v:IsA("Sound") then
                            v:Play()
                        end
                    end
                end,

                OnStartRebounding = function(model, reboundCount, actions)
                end,

                OnEnterRoom = function(model, roomFolder, actions)
                end,

                OnEnterPlayerRoom = function(model, roomFolder, playerCharacter, actions)
                end,

                OnSeePlayer = function(model, playerCharacter, actions)
                end,

                OnKillPlayer = function(model, playerCharacter, actions)
                end,

                OnCrucifixion = function(model: Model | BasePart, actions)
		            isCrucified = true
			        model:SetAttribute("Crucified", true)
		        end

                OnDespawn = function(model, actions)
                end
            }
        }

        task.spawn(function()
            PathfindingMovement.MoveThroughRooms(entityConfig)
        end)

        -- Handle the 3 room progression rebounds
        task.spawn(function()
            local reboundsLeft = 3
            local latestRoom = ReSt.GameData.LatestRoom

            while reboundsLeft > 0 do
                if isCrucified == true then
				    print("Rebound got crucified, the spawn loop is ended")
                    break
                end
                latestRoom.Changed:Wait()
                reboundsLeft = reboundsLeft - 1
                task.wait(2.5)

                local entityConfig2 = {
                    Model = game:GetObjects("rbxassetid://77366392445371")[1],
                    Speed = 60,
                    HeightOffset = 5,
                    FloorYOffset = -2,
                    DelayTime = 0.75,
                    SpawnOffsetRooms = 5,
                    AttackType = "Front",

                    HitboxRange = 50,
                    RaycastHitbox = true,
                    SphereRadius = 4,
                    Damage = 100,

                    LightFlicker = false,
                    Duration = 1.5,
                    LightBreak = false,

                    Rebound = false,
                    ReboundCount = 2,
                    ReboundTime = 1.5,
                    ReboundDelayTime = 1.0,

                    EnableCameraShake = true,
                    ShakeAmount = 5,
                    ShakeRadius = 100,

                    ShowPath = false,

                    Callbacks = {
                        OnSpawned = function(model, actions)
                            model.ReboundNew.Close.Volume = 0.75
                            model.ReboundNew.Idle.Volume = 0.75
                            model.ReboundNew.Sound.Volume = 4
                            model.Rebound_Cue.TimePosition = 0
                            model.Rebound_Cue:Play()
                        end,

                        OnStartMoving = function(model, actions)
                            for _,v in pairs(model.ReboundNew:GetChildren()) do
                                if v:IsA("Sound") then
                                    v:Play()
                                end
                            end
                        end,

                        OnStartRebounding = function(model, reboundCount, actions)
                        end,

                        OnEnterRoom = function(model, roomFolder, actions)
                        end,

                        OnEnterPlayerRoom = function(model, roomFolder, playerCharacter, actions)
                        end,

                        OnSeePlayer = function(model, playerCharacter, actions)
                        end,

                        OnKillPlayer = function(model, playerCharacter, actions)
                        end,

                        OnCrucifixion = function(model: Model | BasePart, actions)
			                isCrucified = true
							model:SetAttribute("Crucified", true)
		                end

                        OnDespawn = function(model, actions)
                        end
                    }
                }

                PathfindingMovement.MoveThroughRooms(entityConfig2)
            end
        end)
