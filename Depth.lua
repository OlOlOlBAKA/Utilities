local TS = game:GetService("TweenService")

local function customImage(name, link)
	if isfile(name .. ".PNG") then
		delfile(name .. ".PNG")
    end
    writefile(name .. ".PNG", game:HttpGet(link))

	if getcustomasset then
		task.delay(20, function()
			delfile(name .. ".PNG")
		end)
		return getcustomasset(name .. ".PNG")
	end
end

-- CREDIT TO REGULAR VYNIXU
local CustomAchievements = loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/DOORS-Custom-Achievements/main/init.luau"))()

local PathfindingMovement = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Room_Path_Find.lua"))()

        local entityConfig = {
            Model = game:GetObjects("rbxassetid://136244113612044")[1],
            Speed = 150,
            HeightOffset = 5,
            FloorYOffset = -2,
            DelayTime = 4,
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
            ShakeValues = {4.5, 25, 0.5, 1.75},
            ShakeRadius = 150,

            ShowPath = false,

            Callbacks = {
                OnSpawned = function(model, actions)
			        local lf = Instance.new("Sound", model)
			        lf.SoundId = "rbxassetid://82673534432571"
			        lf.Volume = 1.5
			        lf:Play()
                    for _, room in ipairs(workspace.CurrentRooms:GetChildren()) do
                        if room ~= workspace.CurrentRooms:FindFirstChild(game.ReplicatedStorage.GameData.LatestRoom.Value + 1) then
                            actions.ToggleLight(room, true, Color3.fromRGB(0, 100, 255))
					        if room:FindFirstChild("Assets") then
						        for _,v in ipairs(room.Assets:GetDescendants()) do 
						            if v:IsA("BasePart") and v.Name == "Neon" then
							            TS:Create(v, TweenInfo.new(1.25), {Color = Color3.fromRGB(150,150,255)}):Play()
						            end
				        	    end
					        end
                        end
                    end
                    for _,v in ipairs(model.DepthNew:GetChildren()) do
                        if v:IsA("Sound") then
                            v.Volume = v.Volume * 1.5
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

                OnCrucifixion = function(model: Model | BasePart, actions)
		            model:SetAttribute("Crucified", true)
			        if _G.CrucifyDepth == false then
				        _G.CrucifyDepth = true
				        CustomAchievements:Grant({
                           Title = "Deeper Even More",
                           Desc = "Banished where it belongs.",
                           Reason = "Use a Crucifix against Depth.",
                           Image = customImage("crucifiedDepth", "https://github.com/OlOlOlBAKA/Utilities/blob/main/IMG_6375.png?raw=true")
                       })
			        end
			        if game.Players.LocalPlayer:GetAttribute("Alive") == true and _G.SurviveDepth == false then
				       _G.SurviveDepth = true
				       CustomAchievements:Grant({
                           Title = "The Deep Shift",
                           Desc = "Everything here just turned blue...",
                           Reason = "Successfully survived Depth.",
                           Image = customImage("surviveDepth", "https://github.com/OlOlOlBAKA/Utilities/blob/main/%E0%B9%84%E0%B8%A1%E0%B9%88%E0%B8%A1%E0%B8%B5%E0%B8%8A%E0%B8%B7%E0%B9%88%E0%B8%AD%2092_20261006170600.png?raw=true")
                       })
			        end
	            end,

                OnDespawn = function(model, actions)
                    if model:FindFirstChild("Slam") then
                        model.Slam:Play()
                    end
			        if game.Players.LocalPlayer:GetAttribute("Alive") == true and _G.SurviveDepth == false then
				       _G.SurviveDepth = true
				       CustomAchievements:Grant({
                           Title = "The Deep Shift",
                           Desc = "Everything here just turned blue...",
                           Reason = "Successfully survived Depth.",
                           Image = customImage("surviveDepth", "https://github.com/OlOlOlBAKA/Utilities/blob/main/%E0%B9%84%E0%B8%A1%E0%B9%88%E0%B8%A1%E0%B8%B5%E0%B8%8A%E0%B8%B7%E0%B9%88%E0%B8%AD%2092_20261006170600.png?raw=true")
                       })
			        end
                end
            }
        }

        task.spawn(function()
            PathfindingMovement.MoveThroughRooms(entityConfig)
        end)
