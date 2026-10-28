-- Fetch external utilities safely
local httpSuccess, rawCode = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua")
end)

if httpSuccess and rawCode then
	local loadedFunc, err = loadstring(rawCode)
	if type(loadedFunc) == "function" then
		pcall(loadedFunc)
	else
		warn("Failed to compile HTTP code ->", err)
	end
else
	warn("Failed to fetch HTTP functions ->", rawCode)
end

local fetchFunc = (typeof(getgenv) == "function" and getgenv().LoadCustomInstance) or _G.LoadCustomInstance or LoadCustomInstance
local mod = fetchFunc("https://github.com/OlOlOlBAKA/Utilities/raw/main/LatestBlink.rbxm")

local r = Random.new()
local player = game.Players.LocalPlayer

-- Function to handle eye states safely
local function setState(part, openEye: boolean)
	if not part or not part:FindFirstChild("BlinkForeshadow") then return end
	
	if openEye == true then
		part.BlinkForeshadow:Play()
		task.wait(0.2)
		part.Blink:Play()
		part.Attachment.Open.Enabled = true
		part.Attachment.Closed.Enabled = false
		task.wait(0.5)
	else
		part.BlinkForeshadow:Play()
		task.wait(0.2)
		part.Blink:Play()
		part.Attachment.Closed.Enabled = true
		part.Attachment.Open.Enabled = false
		task.wait(0.2)
	end
end

local function onCharacterAdded(char)
	repeat 
		task.wait() 
	until char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid")

	local model = mod:Clone()
	
	local root = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChild("Humanoid")
	local openEyeState = false

	-- Move model contents into the root part safely
	if model and model:FindFirstChild("Main") then
		for _, v in ipairs(model.Main:GetChildren()) do
			v.Parent = root
			if v:IsA("PointLight") then
				v.Range = v.Range * 2
			end
		end
	else
		warn("Failed to find 'Main' inside loaded model!")
		return
	end

	task.wait(0.1)

	if root:FindFirstChild("Spawn") then
		root.Spawn.Volume = 1
		root.Spawn:Play()
	end
	
	if root:FindFirstChild("Whisper") then
		root.Whisper.Volume = root.Whisper.Volume / 2
		root.Whisper:Play()
	end
	
	if root:FindFirstChild("Attachment") then
		root.Attachment.Closed.Enabled = true
	end

	-- Eye blinking loop
	task.spawn(function()
		while char and humanoid and humanoid.Health > 0 do
			task.wait(r:NextNumber(2, 10))
			setState(root, true)
			openEyeState = true
			
			task.wait(r:NextNumber(2, 8))
			setState(root, false)
			openEyeState = false
		end
	end)

	-- Whisper pitch adjustment loop
	task.spawn(function()
		while char and humanoid and humanoid.Health > 0 do
			for _, v in ipairs(char:GetDescendants()) do
		        if v:IsA("BasePart") and v.LocalTransparencyModifier < 1 then
			        v.LocalTransparencyModifier = 1
		        end
	        end
			task.wait(0.5)
			for _, v in ipairs(char:GetDescendants()) do
		        if v:IsA("BasePart") and v.LocalTransparencyModifier < 1 then
			        v.LocalTransparencyModifier = 1
		        end
	        end
			if root:FindFirstChild("Whisper") then
				if openEyeState then
					root.Whisper.PlaybackSpeed = r:NextNumber(0.1, 1.1)
				else
					root.Whisper.PlaybackSpeed = 0.45
				end
			end
		end
	end)
end

-- Initialize on current or future characters
local character = player.Character or player.CharacterAdded:Wait()
if character then
	onCharacterAdded(character)
end

player.CharacterAdded:Connect(function(char)
	onCharacterAdded(char)
end)
