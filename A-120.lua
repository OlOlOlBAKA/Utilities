local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
-- CREDIT TO REGULAR VYNIXU

loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"))()

local Main_Game = require(LocalPlayer.PlayerGui.MainUI.Initiator.Main_Game)

local ROOT = "https://github.com/RegularVynixu/DOORS-Entity-Spawner-V2/raw/main"

-- Configuration
local maxShakeDistance = 200 -- Maximum distance where player feels the shake
local baseMagnitude = 8    -- Max shake magnitude when right next to the entity
local baseRoughness = 14    -- Shake frequency
local fadeOutTime = 0.2    -- Fade time
local loudnessThreshold = 250 -- Minimum PlaybackLoudness required to trigger a shake pulse
local cooldown = 0.2       -- Minimum time between shakes to prevent overlapping spam

local function startPlaybackLoudnessShake(model)
	task.spawn(function()
		-- Safely locate the sound inside model.Main
		local mainPart = model and model:FindFirstChild("Main")
		local sound = mainPart and mainPart:FindFirstChild("PlaySound")
		
		if not sound then
			local foundMain = model:WaitForChild("Main", 5)
			sound = foundMain and foundMain:WaitForChild("PlaySound", 5)
		end

		if not sound then return end

		local lastShakeTime = 0

		while model and model.Parent do
			local character = LocalPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")

			if model:GetAttribute("Despawned") == true then break end
			
			if rootPart and sound.IsPlaying then
				local entityPos = model:IsA("Model") and model:GetPivot().Position or model.Position
				local distance = (rootPart.Position - entityPos).Magnitude

				if distance <= maxShakeDistance then
					local loudness = sound.PlaybackLoudness

					-- Trigger shake only when sound is loud enough and cooldown has passed
					local currentTime = os.clock()
					if loudness > loudnessThreshold and (currentTime - lastShakeTime >= cooldown) then
						lastShakeTime = currentTime

						-- Factor 1: Distance intensity (1.0 close, 0.0 at max distance)
						local distanceIntensity = 1 - (distance / maxShakeDistance)
						
						-- Factor 2: Sound loudness intensity (scales higher on louder peaks)
						local loudnessFactor = math.clamp(loudness / 250, 0.3, 1.0)

						-- Combined final magnitude
						local currentMagnitude = baseMagnitude * distanceIntensity * loudnessFactor

						if Main_Game and Main_Game.camShaker and currentMagnitude > 1 then
							Main_Game.camShaker:ShakeOnce(currentMagnitude, baseRoughness, 0, fadeOutTime)
						end
					end
				end
			end

			RunService.Heartbeat:Wait()
		end
	end)
end


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
            Speed = 50,
            HeightOffset = 6,
            FloorYOffset = -2,
            DelayTime = 5,
            SpawnOffsetRooms = 5,
            AttackType = "Front",

            HitboxRange = 30,
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

            ShakeValues = {0, 0, 0, 0},
            ShakeRadius = 0,

            ShowPath = false,

            Callbacks = {
                OnSpawned = function(model, actions)
                    model.PrimaryPart = model.Main
			        startPlaybackLoudnessShake(model)
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
                        actions.MoveTo(playerCharacter.PrimaryPart, {
                            Speed = 50,
                            ReachDistance = 2,
                            HeightOffset = 3,
						    Offset = Vector3.new(0,0,-5),
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
			        model:SetAttribute("Despawned", true)
	            end,

                OnDespawn = function(model, actions)
			        model:SetAttribute("Despawned", true)
                end
            }
        }

        task.spawn(function()
            PathfindingMovement.MoveThroughRooms(entityConfig)
        end)
