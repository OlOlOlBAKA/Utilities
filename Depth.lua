local PathfindingMovement = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Room_Path_Find.lua"))()

        local entityConfig = {
            Model = game:GetObjects("rbxassetid://136244113612044")[1],
            Speed = 150,
            HeightOffset = 5,
            FloorYOffset = -2,
            DelayTime = 6,
            SpawnOffsetRooms = 5,
            AttackType = "Back",

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
            ShakeAmount = 3.5,
            ShakeRadius = 100,

            ShowPath = false,

            Callbacks = {
                OnSpawned = function(model, actions)
                    for _, room in ipairs(workspace.CurrentRooms:GetChildren()) do
                        if room ~= workspace.CurrentRooms:FindFirstChild(game.ReplicatedStorage.GameData.LatestRoom.Value + 1) then
                            actions.ToggleLight(room, true, Color3.fromRGB(0, 100, 255))
                        end
                    end
                    for _,v in ipairs(model.DepthNew:GetChildren()) do
                        if v:IsA("Sound") then
                            v.Volume = v.Volume * 1.25
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
                end,

                OnSeePlayer = function(model, playerCharacter, actions)
                end,

                OnKillPlayer = function(model, playerCharacter, actions)
                end,

                OnDespawn = function(model, actions)
                    if model:FindFirstChild("Slam") then
                        model.Slam:Play()
                    end
                end
            }
        }

        task.spawn(function()
            PathfindingMovement.MoveThroughRooms(entityConfig)
        end)
