local tweenService: TweenService = game:GetService("TweenService")
local replicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local runService: RunService = game:GetService("RunService")
local players: Players = game:GetService("Players")
local LocalPlayer = players.LocalPlayer
local random = Random.new()

loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"))()

local noiseModel: Instance = LoadCustomInstance("https://github.com/OlOlOlBAKA/Utilities/raw/main/NoiseModel.rbxm")

-- ป้องกันข้อผิดพลาดกรณีโหลด TapeZeroColor ไม่สำเร็จ (แก้ปัญหา nil table ที่บรรทัด 82)
local success, result = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/TapeZeroColor.lua"))()
end)

local tapeZeroColors = (success and type(result) == "table") and result or {
	sample = function()
		return Color3.fromRGB(25, 0, 0), 1, false
	end
}

local gameData = replicatedStorage:FindFirstChild("GameData")
local floor = gameData and gameData:FindFirstChild("Floor")

local function isHalloween()
	return floor and floor.Value == "Halloween26"
end

local PALETTE_NORMAL = {
	highlight = Color3.fromRGB(350, 0, 0),
	outline = Color3.fromRGB(255, 0, 0),
	light = Color3.fromRGB(255, 30, 30),
	texture = Color3.fromRGB(99999, -100, -100),
	screen = Color3.fromRGB(25, 0, 0),
	static = Color3.fromRGB(255, 0, 0)
}

local PALETTE_HALLOWEEN = {
	highlight = Color3.fromRGB(350, 192, 0),
	outline = Color3.fromRGB(255, 140, 0),
	light = Color3.fromRGB(255, 150, 20),
	texture = Color3.fromRGB(99999, 55000, -100),
	screen = Color3.fromRGB(25, 14, 0),
	static = Color3.fromRGB(255, 140, 0)
}

local function hijackPalette()
	return isHalloween() and PALETTE_HALLOWEEN or PALETTE_NORMAL
end

local function runTapeFX(tvObject)
	local tvMain = tvObject and tvObject:FindFirstChild("TVMain")
	local tvScreen = tvMain and tvMain:FindFirstChild("TVScreen")
	if not tvScreen then return end

	local videoGui = tvScreen:FindFirstChild("VideoGui")
	local videoFrame = videoGui and videoGui:FindFirstChild("VideoFrame")
	if not videoFrame then return end

	if not tapeZeroColors or type(tapeZeroColors.sample) ~= "function" then
		return
	end

	local lightList = {}
	local lightBrightness = {}

	for _, child in tvScreen:GetDescendants() do
		if child:IsA("Light") then
			child.Enabled = true
			lightBrightness[child] = child.Brightness
			table.insert(lightList, child)
		end
	end

	tvScreen.Material = Enum.Material.Neon
	tvScreen.Highlight.Enabled = false

	local startTime = os.clock()
	local connection

	connection = runService.RenderStepped:Connect(function()
		local isStopped = not tvScreen.Parent or not videoGui.Enabled or (os.clock() - startTime > 1)

		if isStopped then
			connection:Disconnect()

			for light, bright in lightBrightness do
				light.Brightness = bright
			end

			tvScreen.Highlight.Enabled = false

			if tvScreen:GetAttribute("RedLit") then
				local palette = hijackPalette()
				tvScreen.Material = Enum.Material.Neon
				tvScreen.Color = palette.screen

				for _, light in lightList do
					light.Enabled = true
					light.Color = palette.light
				end
				return
			end

			tvScreen.Material = Enum.Material.Glass
			tvScreen.Color = Color3.fromRGB(29, 30, 38)

			for _, light in lightList do
				light.Enabled = false
			end
			return
		end

		local sampleColor, sampleBright, hasFlicker = tapeZeroColors.sample(videoFrame.TimePosition)
		if not sampleColor then return end

		if hasFlicker then
			sampleBright *= random:NextNumber(0.55, 1.15)
			if random:NextInteger(1, 6) == 1 then
				local offset = random:NextNumber(-0.06, 0.06)
				sampleColor = Color3.new(
					math.clamp(sampleColor.R + offset, 0, 1),
					math.clamp(sampleColor.G + offset, 0, 1),
					math.clamp(sampleColor.B + offset, 0, 1)
				)
			end
		end

		tvScreen.Color = sampleColor
		for _, light in lightList do
			light.Color = sampleColor
			light.Brightness = sampleBright * 2.2
		end
	end)
end

return function(p7, newScript, ...)
	local argString, argInstance

	return function(p7, newScript, ...)
	local argString, argInstance

	for _, val in pairs({ ... }) do -- แก้ตรงนี้ให้มี pairs() ครอบ
		if typeof(val) == "string" then
			argString = val
		elseif typeof(val) == "Instance" then
			argInstance = val
		elseif typeof(val) == "table" then
			for _, subVal in pairs(val) do -- และแก้ตรงนี้ให้มี pairs(val)
				if typeof(subVal) == "string" then
					argString = subVal
				elseif typeof(subVal) == "Instance" then
					argInstance = subVal
				end
			end
		end
	end

	if p7.noiseVisuals then
		if argString then
			p7.noiseVisuals.tapeFX(argString, argInstance)
		end
		return p7.noiseVisuals
	end

	local hiddenNoiseRigs = workspace:FindFirstChild("HiddenNoiseRigs")
	if not hiddenNoiseRigs then
		hiddenNoiseRigs = Instance.new("Folder")
		hiddenNoiseRigs.Name = "HiddenNoiseRigs"
		hiddenNoiseRigs.Parent = workspace
	end

	local activeNoises = {}
	local playerVisibility = {}

	local function shouldShow(data)
		if data.folder and (data.folder:GetAttribute("Spotlight") or data.folder:GetAttribute("Host") or data.folder:GetAttribute("Crucified")) then
			return true
		end
		local override = playerVisibility[data.targetUserId]
		if override == nil then
			return data.targetUserId == LocalPlayer.UserId
		end
		return override
	end

	local function applyVisibility(data)
		local visible = shouldShow(data)
		data.noise.Parent = visible and p7.cam or hiddenNoiseRigs
		if data.setAudible then
			data.setAudible(visible)
		end
	end

	local function buildNoise(p10)
		local targetUserId = p10:GetAttribute("TargetUserId")
		local userVisibility = playerVisibility[targetUserId]
		local isAllowed = true

		if not p10:GetAttribute("Spotlight") and not p10:GetAttribute("Host") and not p10:GetAttribute("Crucified") then
			isAllowed = (userVisibility ~= nil and userVisibility) or (targetUserId == LocalPlayer.UserId)
		end

		if not isAllowed then
			local deferredData = { deferred = true, targetUserId = targetUserId, folder = p10 }
			activeNoises[p10] = deferredData

			p10.Destroying:Connect(function()
				if activeNoises[p10] == deferredData then
					activeNoises[p10] = nil
				end
			end)

			for _, attr in { "Spotlight", "Host", "Crucified" } do
				p10:GetAttributeChangedSignal(attr):Connect(function()
					if p10:GetAttribute(attr) and activeNoises[p10] == deferredData then
						activeNoises[p10] = nil
						task.spawn(buildNoise, p10)
					end
				end)
			end
			return
		end

		local tv = p10:WaitForChild("TV", 10)
		local victim = p10:WaitForChild("Victim", 10)

		if tv and victim then
			local startTime = os.clock()
			while tv.Value == nil and p10.Parent and os.clock() - startTime < 10 do
				task.wait()
			end

			local tvValue = tv.Value
			if not tvValue then return end

			local clone = noiseModel:Clone()
			local clonePrimaryPart = clone.PrimaryPart
			
			local isAlive = true
			local isKilling = false
			local stateMode = nil
			local heartConnection = nil
			local isEnraged = p10:GetAttribute("Enraged") == true
			local noiseData = { noise = clone, targetUserId = targetUserId, folder = p10 }

			activeNoises[p10] = noiseData
			
			-- ค้นหา NoiseAttach จากโครงสร้าง Base ภายในทีวีอย่างปลอดภัย
			noiseData.tvAttach = tvValue:FindFirstChild("NoiseAttach", true)
			clone:PivotTo(CFrame.new(0, -1000, 0))

			local visible = shouldShow(noiseData)
			clone.Parent = visible and p7.cam or hiddenNoiseRigs

			local particleList = {}
			local basePartList = {}
			local textureList = {}
			local highlightList = {}
			local soundMap = {}
			local soundVolumeMap = {}
			local originalPartColors = {}

			for _, desc in clone:GetDescendants() do
				if desc:IsA("ParticleEmitter") and not desc:HasTag("noinclude") then
					table.insert(particleList, desc)
				elseif desc:IsA("BasePart") and desc.Transparency < 1 then
					table.insert(basePartList, desc)
					originalPartColors[desc] = desc.Color
				elseif not desc:IsA("Texture") and not desc:IsA("Decal") then
					if desc:IsA("Highlight") then
						table.insert(highlightList, desc)
					elseif desc:IsA("Sound") then
						soundMap[desc.Name] = desc
						soundVolumeMap[desc] = desc.Volume
					end
				else
					table.insert(textureList, desc)
				end
			end

			local animTracks = {}
			for _, anim in clone.Animations:GetChildren() do
				animTracks[anim.Name] = clone.AnimationController:LoadAnimation(anim)
			end

			local currentLocoTrack = nil
			local function playLoco(track)
				if currentLocoTrack then currentLocoTrack:Stop(0) end
				currentLocoTrack = track
				if track then
					track:Play(0.1, 1, 1)
				end
			end

			noiseData.setAudible = function(audible)
				for sound, vol in soundVolumeMap do
					sound.Volume = audible and vol or 0
				end
			end

			noiseData.setAudible(shouldShow(noiseData))

			-- จัดการสีตัวละคร: ตอนกำลังเกิด (Emerging) หรือเดิน เป็นสีขาว | ตอนหยุด (Paused) เป็นสีดำ
			local function updateVisuals()
				local isEmerging = (p10:GetAttribute("State") == "Emerging")
				local isPaused = (stateMode == "Paused" and not isEnraged and not isEmerging)
				
				local baseColor = isPaused and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(245, 245, 245)
				local textCol = isPaused and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(0, 0, 0)
				local fillCol = isPaused and Color3.fromRGB(10, 10, 10) or Color3.fromRGB(218, 218, 218)
				local fillTrans = isPaused and -999999 or 10

				for _, part in basePartList do
					part.Color = (not isPaused and (part:GetAttribute("NoiseColor") or originalPartColors[part])) or baseColor
				end

				for _, tex in textureList do
					tex.Transparency = isPaused and 0.85 or 0
				end

				for _, hl in highlightList do
					hl.FillColor = fillCol
					hl.FillTransparency = fillTrans
				end
			end

			local function setMode(mode)
				if mode == stateMode then return end
				stateMode = mode
				updateVisuals()

				if mode == "Paused" then
					if soundMap.Pause then soundMap.Pause:Play() end
					if soundMap.FastForward then soundMap.FastForward:Stop() end
					playLoco(nil)
				else
					if soundMap.Pause then soundMap.Pause:Stop() end
					if mode == "FastForward" then
						if soundMap.FastForward then soundMap.FastForward:Play() end
					else
						if soundMap.FastForward then soundMap.FastForward:Stop() end
					end
					if p10:GetAttribute("State") ~= "Emerging" then
						playLoco(animTracks.Walk)
					end
				end
			end

			local function cleanup()
				if not isAlive then return end
				isAlive = false
				if heartConnection then heartConnection:Disconnect() end
				activeNoises[p10] = nil
				clone:Destroy()
			end

			heartConnection = runService.Heartbeat:Connect(function(dt)
				if not isAlive or isKilling then return end
				local targetCF = p10:GetAttribute("TargetCF")
				if not targetCF then return end

				local pivot = clone:GetPivot()
				if stateMode == "Paused" then
					clone:PivotTo(pivot + random:NextUnitVector() * random:NextNumber(0.001, 0.05))
					return
				end

				local newPos = pivot.Position:Lerp(targetCF.Position, 1 - math.exp(-12 * dt))
				local curYaw = math.atan2(-pivot.LookVector.X, -pivot.LookVector.Z)
				local targetYaw = math.atan2(-targetCF.LookVector.X, -targetCF.LookVector.Z)
				local newYaw = curYaw + ((targetYaw - curYaw + math.pi) % (math.pi * 2) - math.pi) * math.min(6 * dt, 1)

				clone:PivotTo(CFrame.Angles(0, newYaw, 0) + newPos)
			end)

			p10:GetAttributeChangedSignal("State"):Connect(function()
				local newState = p10:GetAttribute("State")
				if not isAlive or isKilling then return end

				if newState == "Killing" then
					isKilling = true
					local victimChar = victim.Value
					if victimChar then
						clonePrimaryPart.Anchored = true
						if victimChar == p7.char then p7.fovtarget = 100 end
						if animTracks.Kill then animTracks.Kill:Play() end
						task.delay(5.4, cleanup)
					end
				elseif newState == "Paused" or newState == "FastForward" or newState == "Walking" then
					setMode(newState)
				end
			end)

			p10.Destroying:Connect(cleanup)

			-- จัดการอนิเมชันตอนเกิด (ใช้ .Ended รอจนจบเป๊ะๆ และบังคับตัวเป็นสีขาว)
			task.spawn(function
				updateVisuals() -- บังคับสีขาวตอนเกิด
				if animTracks.Spawn then 
					animTracks.Spawn:Play(0, 1, 1) 
					animTracks.Spawn.Ended:Wait() -- รอจนจบแอนิมิชัน Spawn สมบูรณ์แบบ
				else
					task.wait(1.2)
				end
				
				if soundMap.Idle and isAlive then 
					soundMap.Idle:Play() 
				end
				
				if p10:GetAttribute("State") == "Emerging" then
					p10:SetAttribute("State", "Walking")
					playLoco(animTracks.Walk)
				end
			end)

			return
		end
	end

	task.spawn(function()
		local noiseReplication = newScript:WaitForChild("NoiseReplication")
		noiseReplication.ChildAdded:Connect(function(child)
			task.spawn(buildNoise, child)
		end)
		for _, child in noiseReplication:GetChildren() do
			task.spawn(buildNoise, child)
		end
	end)

	local vignette = newScript:WaitForChild("NoiseVignette"):Clone()
	vignette.Amount.Value = 0
	vignette.Visible = false
	vignette.Parent = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainUI")

	local api = {
		setVisible = function(userId, visible)
			playerVisibility[userId] = visible
			for p10, data in activeNoises do
				if data.targetUserId == userId then
					applyVisibility(data)
				end
			end
		end,
		tapeFX = function(fxType, targetObj)
			if fxType == "Rewind" and newScript:FindFirstChild("HijackRewind") then
				newScript.HijackRewind:Play()
			elseif fxType == "Tape" and newScript:FindFirstChild("TapePlaying") then
				newScript.TapePlaying:Play()
				runTapeFX(targetObj)
			elseif fxType == "Cancel" then
				if newScript:FindFirstChild("HijackRewind") then newScript.HijackRewind:Stop() end
				if newScript:FindFirstChild("TapePlaying") then newScript.TapePlaying:Stop() end
			end
		end
	}

	p7.noiseVisuals = api
	if argString then api.tapeFX(argString, argInstance) end

	return api
end
