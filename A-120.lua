local PathfindingMovement = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Room_Path_Find.lua"))()

        local entityConfig = {
            Model = game:GetObjects("rbxassetid://103020442987735")[1],
            Speed = 60,
            HeightOffset = 6,
            FloorYOffset = -2,
            DelayTime = 5,
            SpawnOffsetRooms = 5,
            AttackType = "Front",

            HitboxRange = 40,
            RaycastHitbox = true,
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
            ShakeAmount = 2.5,
            ShakeRadius = 100,

            ShowPath = false,

            Callbacks = {
                OnSpawned = function(model, actions)
                    model.Main.Name = "A120"
                end,

                OnStartMoving = function(model, actions)
                end,

                OnStartRebounding = function(model, reboundCount, actions)
                end,

                OnEnterRoom = function(model, roomFolder, actions)
                end,

                OnEnterPlayerRoom = function(model, roomFolder, playerCharacter, actions)
                    if playerCharacter and playerCharacter.PrimaryPart then
                        task.wait(0.5)
				        actions.Stop()
                        task.wait(0.1)
                        actions.MoveTo(playerCharacter.PrimaryPart.CFrame.Position + (playerCharacter.PrimaryPart.CFrame.LookVector * 3), {
                            Speed = 60,
                            ReachDistance = 3,
                            HeightOffset = 5
                        })
                        task.wait(0.1)
                        actions.Resume(2)
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
