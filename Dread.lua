local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Camera = workspace.CurrentCamera

local modulesClient = ReplicatedStorage:WaitForChild("ModulesClient")
local ModuleEvents = require(modulesClient:WaitForChild("Module_Events"))

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local mainUI = playerGui:WaitForChild("MainUI")
local initiator = mainUI:WaitForChild("Initiator")
local mainGame = initiator:WaitForChild("Main_Game")
local remoteListener = mainGame:WaitForChild("RemoteListener")

local modulesFolder = remoteListener:WaitForChild("Modules")
local dreadFolder = modulesFolder:WaitForChild("Dread")

local ambienceColdSound = dreadFolder:WaitForChild("AmbienceCold")
local ambienceSound = dreadFolder:FindFirstChild("Ambience")
local ambienceEndSound = dreadFolder:FindFirstChild("AmbienceEnd")
local soundBreath = dreadFolder:FindFirstChild("SoundBreath")

-- Jumpscare Module & Sound References
local dreadJumpscareModule = remoteListener:WaitForChild("Jumpscares"):WaitForChild("Dread")
local soundBoom = dreadJumpscareModule:FindFirstChild("Boom") or Instance.new("Sound")
local soundKill = dreadJumpscareModule:FindFirstChild("Kill") or Instance.new("Sound")

-- UI References for Preloading
local mainFrame = mainUI:FindFirstChild("MainFrame")
local dreadVignette = mainFrame and mainFrame:FindFirstChild("DreadVignette")
local dreadSwirl = dreadVignette and dreadVignette:FindFirstChild("Swirl")

local jumpscareUI = mainUI:FindFirstChild("Jumpscare")
local jumpscareDread = jumpscareUI and jumpscareUI:FindFirstChild("Jumpscare_Dread")

-- Preload Audio and GUI Image Assets
task.spawn(function()
	pcall(function()
		local assetsToPreload = {}

		-- Audio Preload
		if ambienceColdSound then table.insert(assetsToPreload, ambienceColdSound) end
		if ambienceSound then table.insert(assetsToPreload, ambienceSound) end
		if ambienceEndSound then table.insert(assetsToPreload, ambienceEndSound) end
		if soundBreath then table.insert(assetsToPreload, soundBreath) end
		if soundBoom then table.insert(assetsToPreload, soundBoom) end
		if soundKill then table.insert(assetsToPreload, soundKill) end

		-- Vignette & Jumpscare GUI Preload
		if dreadVignette then table.insert(assetsToPreload, dreadVignette) end
		if dreadSwirl then table.insert(assetsToPreload, dreadSwirl) end

		if jumpscareDread then
			table.insert(assetsToPreload, jumpscareDread)
			for i = 1, 4 do
				local frame = jumpscareDread:FindFirstChild("Frame" .. i)
				if frame then
					table.insert(assetsToPreload, frame)
				end
			end
		end

		ContentProvider:PreloadAsync(assetsToPreload)
	end)
end)

local gameData = ReplicatedStorage:FindFirstChild("GameData")
if not gameData then
	gameData = Instance.new("Folder")
	gameData.Name = "GameData"
	gameData.Parent = ReplicatedStorage
end

local latestRoomFolder = gameData:FindFirstChild("LatestRoom")
if not latestRoomFolder then
	latestRoomFolder = Instance.new("IntValue")
	latestRoomFolder.Name = "LatestRoom"
	latestRoomFolder.Value = 1
	latestRoomFolder.Parent = gameData
end

-- Turns off all room lights except room index (LatestRoom.Value + 1)
local function TurnOffAllRoomLights()
	local currentRooms = workspace:FindFirstChild("CurrentRooms")
	if not currentRooms then return end

	local targetAmbient = Color3.fromRGB(0, 0, 0)
	local nextRoomIndex = latestRoomFolder.Value + 1
	local nextRoom = currentRooms:FindFirstChild(tostring(nextRoomIndex))

	for _, room in ipairs(currentRooms:GetChildren()) do
		if room ~= nextRoom then
			task.spawn(function()
				pcall(function()
					ModuleEvents.toggle(room, false, targetAmbient)
				end)
			end)
		end
	end
end

-- Lighting Sanity Effect setup
local sanityCC = Lighting:FindFirstChild("Sanity")
if not sanityCC then
	sanityCC = Instance.new("ColorCorrectionEffect")
	sanityCC.Name = "Sanity"
	sanityCC.Enabled = false
	sanityCC.Parent = Lighting
end

local liveSanity = sanityCC:Clone()
liveSanity.Name = "LiveSanity"
liveSanity.Enabled = false
liveSanity.Parent = Camera

-- Sound Equalizer setup
local soundMain = SoundService:FindFirstChild("Main")
if not soundMain then
	soundMain = Instance.new("Folder")
	soundMain.Name = "Main"
	soundMain.Parent = SoundService
end

local sanityEq = soundMain:FindFirstChild("SanityEqualizer")
if not sanityEq then
	sanityEq = Instance.new("EqualizerSoundEffect")
	sanityEq.Name = "SanityEqualizer"
	sanityEq.Enabled = false
	sanityEq.Parent = soundMain
end

-- Camera Shaker setup
local CameraShaker = require(ReplicatedStorage:WaitForChild("CameraShaker"))
local camShakerInstance = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
	if workspace.CurrentCamera then
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * shakeCFrame
	end
end)
camShakerInstance:Start()

-- ColdBox Setup (Cold Particles)
local coldBoxTemplate = dreadFolder:FindFirstChild("ColdBox")
local coldBox = coldBoxTemplate and coldBoxTemplate:Clone() or Instance.new("Part")

pcall(function()
	RunService:UnbindFromRenderStep("dreadfx")
end)

local isDreadActive = false

--------------------------------------------------------------------------------
-- DREAD JUMPSCARE UI ANIMATION & DAMAGE
--------------------------------------------------------------------------------
local function TriggerJumpscare(p1)
	p1.deathtick = tick() + 5

	local targetJumpscareUI = mainUI:FindFirstChild("Jumpscare")
	local jumpscare_Dread = targetJumpscareUI and targetJumpscareUI:FindFirstChild("Jumpscare_Dread")

	if not jumpscare_Dread then return end

	jumpscare_Dread.Visible = true

	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if soundBoom then
		soundBoom.SoundGroup = nil
		soundBoom:Play()
	end

	-- Direct Client Damage / Kill Guarantee
	humanoid.Health = 0

	repeat
		task.wait()
	until humanoid.Health < 0.1 or not p1.stopcam

	if p1.stopcam then
		if soundKill then
			soundKill.SoundGroup = nil
			soundKill:Play()
		end

		for i = 1, 4 do
			local foundChild = jumpscare_Dread:FindFirstChild("Frame" .. i)
			if foundChild then
				foundChild.ImageTransparency = 0
				task.wait(0.06666666666666667)
				foundChild.Rotation = 180

				local randomNumber = math.random(-10, 10)
				local randomNumber2 = math.random(-10, 10)

				jumpscare_Dread.Position = UDim2.new(0.5 + randomNumber / 500, 0, 0.5 + randomNumber2 / 500, 0)
				task.wait(0.06666666666666667)
			end
		end

		local killEq = soundKill:FindFirstChildOfClass("EqualizerSoundEffect")
		if killEq then
			local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
			TweenService:Create(killEq, tweenInfo, { LowGain = -20, MidGain = -80, HighGain = -80 }):Play()
		end

		if soundKill then
			local tweenInfo2 = TweenInfo.new(2, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			TweenService:Create(soundKill, tweenInfo2, { Volume = 0 }):Play()
		end

		jumpscare_Dread.BackgroundTransparency = 0
		p1.deathtick = tick() - 1
		task.wait(0.5)
		jumpscare_Dread.BackgroundTransparency = 1

		return
	end

	jumpscare_Dread.Visible = false
end

--------------------------------------------------------------------------------
-- MAIN DREAD HANDLER
--------------------------------------------------------------------------------
local function RunDread(controller, mode)
	if not controller or controller.dead then return end

	if mode == "clear" then
		isDreadActive = false

		if coldBox then
			for _, child in ipairs(coldBox:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
		end

		if ambienceColdSound then
			TweenService:Create(ambienceColdSound, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Volume = 0 }):Play()
		end

		TweenService:Create(liveSanity, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {
			Saturation = 0, Brightness = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1)
		}):Play()

		task.wait(1)
		if ambienceColdSound then
			ambienceColdSound:Stop()
			ambienceColdSound.Volume = 0.9
		end

	elseif mode == "cold" then
		local initialRoomValue = latestRoomFolder.Value
		isDreadActive = true
		liveSanity.Enabled = true

		TweenService:Create(liveSanity, TweenInfo.new(3, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {
			Saturation = -0.2, Brightness = 0.02, Contrast = 0.04, TintColor = Color3.new(1, 1, 1)
		}):Play()

		if ambienceColdSound then ambienceColdSound:Play() end

		if coldBox then
			coldBox.Parent = controller.skybox or workspace
			for _, child in ipairs(coldBox:GetChildren()) do
				if child:IsA("ParticleEmitter") then
					child:Emit(3)
					child.Enabled = true
				end
			end

			RunService:BindToRenderStep("dreadfx", 102, function()
				if controller.cam then
					coldBox.CFrame = controller.cam.CFrame * CFrame.new(0, -4, 2)
				end
			end)
		end

		local breathParticles = coldBox and coldBox:FindFirstChild("BreathParticles", true)

		while isDreadActive do
			if soundBreath then soundBreath:Play() end

			for _ = 1, 10 do
				task.wait(0.05)
				if breathParticles then
					breathParticles:Emit(1)
				end
			end

			task.wait(1.9)

			if not isDreadActive or initialRoomValue ~= latestRoomFolder.Value then
				break
			end
		end

		if coldBox then
			for _, child in ipairs(coldBox:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
		end

	elseif mode == "spawn" then
		TurnOffAllRoomLights()

		local spawnRoomValue = latestRoomFolder.Value

		local liveEq = sanityEq:Clone()
		liveEq.Name = "SanityEqualizerLive"
		liveEq.Enabled = true
		liveEq.Parent = soundMain

		local totalSat = 1
		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("ColorCorrectionEffect") and effect.Enabled and effect ~= liveSanity then
				totalSat += effect.Saturation
			end
		end

		liveSanity.Enabled = true
		TweenService:Create(liveSanity, TweenInfo.new(4.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {
			Brightness = 0.2, Contrast = 0.4, Saturation = -totalSat, TintColor = Color3.new(1, 1, 1)
		}):Play()

		TweenService:Create(liveEq, TweenInfo.new(4.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {
			LowGain = 0, MidGain = -20, HighGain = -40
		}):Play()

		local shake1, shake2
		if controller.camShaker and controller.camShaker.StartShake then
			shake1 = controller.camShaker:StartShake(1, 16, 4.6, Vector3.new(0, 0, 0))
			shake2 = controller.camShaker:StartShake(8, 1, 4.6, Vector3.new(0, 0, 0))
		end

		isDreadActive = true

		if ambienceSound then
			ambienceSound.SoundGroup = nil
			ambienceSound:Play()
		end

		task.wait(4.6)

		local activeVignette = mainUI:FindFirstChild("MainFrame") and mainUI.MainFrame:FindFirstChild("DreadVignette")
		if activeVignette then
			activeVignette.Visible = true
			activeVignette.ImageColor3 = Color3.new(1, 1, 1)
			activeVignette.Size = UDim2.new(2, 0, 2, 0)
			activeVignette.Rotation = math.random(0, 359)

			TweenService:Create(activeVignette, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				ImageColor3 = Color3.new(0, 0, 0),
				Size = UDim2.new(1.2, 0, 1.2, 0)
			}):Play()

			for _, child in ipairs(activeVignette:GetChildren()) do
				if child:IsA("Frame") then
					child.BackgroundColor3 = Color3.new(1, 1, 1)
					TweenService:Create(child, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
						BackgroundColor3 = Color3.new(0, 0, 0)
					}):Play()
				end
			end

			local activeSwirl = activeVignette:FindFirstChild("Swirl")
			if activeSwirl then
				activeSwirl.ImageTransparency = 0.2
				activeSwirl.Rotation = math.random(0, 359)
				activeSwirl.Size = UDim2.new(1.5, 0, 1.5, 0)

				TweenService:Create(activeSwirl, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
					ImageTransparency = 1,
					Size = UDim2.new(1, 0, 1, 0)
				}):Play()
			end
		end

		pcall(function()
			local voiceModule = ReplicatedStorage:FindFirstChild("VoiceActing")
			if voiceModule then
				require(voiceModule)("Dread", "Spawn")
			end
		end)

		local dreadTemplate = ReplicatedStorage:FindFirstChild("Entities") and ReplicatedStorage.Entities:FindFirstChild("Dread")
		if not dreadTemplate then
			warn("[Dread] Missing ReplicatedStorage.Entities.Dread model")
			isDreadActive = false
			return
		end

		local dreadEntity = dreadTemplate:Clone()
		local activeChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

		if activeChar.PrimaryPart and dreadEntity.PrimaryPart then
			dreadEntity.PrimaryPart.CFrame = CFrame.new(activeChar.PrimaryPart.Position + (Camera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit * -64)

			local currentRooms = workspace:FindFirstChild("CurrentRooms")
			local currentRoomModel = currentRooms and currentRooms:FindFirstChild(tostring(spawnRoomValue))
			if currentRoomModel and currentRoomModel:FindFirstChild("Door") then
				pcall(function()
					local door = currentRoomModel.Door
					door.PrimaryPart.CFrame = CFrame.new(door.PrimaryPart.Position, activeChar.PrimaryPart.Position)
					dreadEntity.PrimaryPart.CFrame = CFrame.new(activeChar.PrimaryPart.Position + (door.PrimaryPart.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit * 64)
				end)
			end
		end

		dreadEntity.Parent = workspace
		if dreadEntity.PrimaryPart and dreadEntity.PrimaryPart:FindFirstChild("Footsteps") then dreadEntity.PrimaryPart.Footsteps:Play() end
		if dreadEntity.PrimaryPart and dreadEntity.PrimaryPart:FindFirstChild("PlaySound") then dreadEntity.PrimaryPart.PlaySound:Play() end

		local chaseSpeed = 9
		task.delay(10, function()
			chaseSpeed = 11
			task.wait(10)
			chaseSpeed = 13
		end)

		while isDreadActive and spawnRoomValue == latestRoomFolder.Value and not controller.dead do
			local dt = task.wait()

			local currentHRP = activeChar and (activeChar:FindFirstChild("HumanoidRootPart") or activeChar.PrimaryPart)
			if not currentHRP or not dreadEntity.PrimaryPart then break end

			local lookVector = CFrame.lookAt(dreadEntity.PrimaryPart.Position, currentHRP.Position - currentHRP.Velocity).LookVector
			local magnitude = (dreadEntity.PrimaryPart.Position - currentHRP.Position).Magnitude
			local proximityRatio = math.clamp(magnitude / 50, 0, 1)

			dreadEntity.PrimaryPart.CFrame = CFrame.new(dreadEntity.PrimaryPart.Position + lookVector * (chaseSpeed * dt))

			if activeVignette then
				activeVignette.Rotation = math.random(0, 359)
				activeVignette.Position = UDim2.new(0.5 + math.random(-10, 10) / 1000, 0, 0.5 + math.random(-10, 10) / 1000, 0)

				local activeSwirl = activeVignette:FindFirstChild("Swirl")
				if activeSwirl then
					activeSwirl.ImageTransparency = proximityRatio
					activeSwirl.Rotation = math.random(0, 359)
					activeSwirl.Size = UDim2.new(proximityRatio + 1, 0, proximityRatio + 1, 0)
				end
			end

			--------------------------------------------------------------------
			-- CAUGHT SEQUENCE WITH POST-ROTATION DELAY (< 7 Distance)
			--------------------------------------------------------------------
			if magnitude < 7 then
				pcall(function()
					if ReplicatedStorage:FindFirstChild("RemotesFolder") and ReplicatedStorage.RemotesFolder:FindFirstChild("Dread") then
						ReplicatedStorage.RemotesFolder.Dread:FireServer()
					end
				end)

				if controller.char and controller.char.PrimaryPart then
					controller.char.PrimaryPart.Anchored = true
				end

				activeChar:PivotTo(CFrame.new(currentHRP.Position, dreadEntity.PrimaryPart.Position))
				controller.stopcam = true

				for _, part in ipairs(controller.char:GetDescendants()) do
					if part:IsA("BasePart") then
						local oldTransparency = part.Transparency
						part.Transparency = 1
						task.delay(1, function()
							repeat
								task.wait(0.1)
							until controller.stopcam == false
							part.Transparency = oldTransparency
						end)
					end
				end

				for _, part in ipairs(dreadEntity:GetDescendants()) do
					if part:IsA("ParticleEmitter") then
						part:Emit(5)
					end
				end

				-- Lock camera onto Dread & wait until rotation tween finishes completely
				local camCF = CFrame.new(Camera.CFrame.Position, dreadEntity.PrimaryPart.Position + Vector3.new(0, 1, 0))
				local camTween = TweenService:Create(Camera, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = camCF })
				camTween:Play()

				TweenService:Create(liveEq, TweenInfo.new(0.1, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
					LowGain = -99, MidGain = -99, HighGain = -99
				}):Play()

				if activeVignette then
					activeVignette.ImageColor3 = Color3.new(1, 1, 1)
					TweenService:Create(activeVignette, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
						ImageColor3 = Color3.new(0, 0, 0), Size = UDim2.new(5, 0, 5, 0)
					}):Play()

					local activeSwirl = activeVignette:FindFirstChild("Swirl")
					if activeSwirl then activeSwirl.ImageTransparency = 1 end
				end

				if ambienceSound then ambienceSound:Stop() end

				-- Wait until camera fully finishes rotating
				camTween.Completed:Wait()

				-- DELAY: Hold for 1.5 seconds AFTER rotation is finished
				task.wait(1.5)

				-- TRIGGER JUMPSCARE UI & KILL PLAYER
				TriggerJumpscare(controller)

				if controller.char and controller.char.PrimaryPart then
					controller.char.PrimaryPart.Anchored = false
				end
				controller.stopcam = false

				break
			end
		end

		task.delay(5, function()
			pcall(function()
				liveEq:Destroy()
			end)
		end)

		if coldBox then
			for _, child in ipairs(coldBox:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
		end

		if ambienceColdSound then ambienceColdSound:Stop() end
		if ambienceSound then ambienceSound:Stop() end

		if activeVignette then activeVignette.Visible = false end
		isDreadActive = false

		if dreadEntity then dreadEntity:Destroy() end
		if shake1 then shake1:StartFadeOut(0.1) end
		if shake2 then shake2:StartFadeOut(0.1) end

		if controller.dead == false then
			if ambienceEndSound then ambienceEndSound:Play() end
			task.wait(0.1)

			TweenService:Create(liveSanity, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1)
			}):Play()

			TweenService:Create(liveEq, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
				LowGain = 0, MidGain = 0, HighGain = 0
			}):Play()

			task.wait(1)
		else
			if shake1 then shake1:StartFadeOut(0.1) end
			if shake2 then shake2:StartFadeOut(0.1) end
		end

		liveSanity.Enabled = false
		pcall(function()
			liveEq:Destroy()
		end)
	end
end

local controller = {
	dead = false,
	cam = workspace.CurrentCamera,
	char = Character,
	skybox = workspace,
	stopcam = false,
	camShaker = camShakerInstance,
	deathtick = tick()
}

LocalPlayer.CharacterAdded:Connect(function(newChar)
	controller.char = newChar
	controller.cam = workspace.CurrentCamera
	controller.dead = false
end)

if Character:FindFirstChildOfClass("Humanoid") then
	Character:FindFirstChildOfClass("Humanoid").Died:Connect(function()
		controller.dead = true
	end)
end

task.spawn(function()
	RunDread(controller, "spawn")
end)
