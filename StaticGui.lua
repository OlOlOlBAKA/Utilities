-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = localPlayer:WaitForChild("PlayerGui")
local random = Random.new()

if playerGui:FindFirstChild("StaticScreenGui") then return end

loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"))()

-- 1. Custom Font Loader Function
local function loadCustomFont(fontUrl, fileName, fontName)
	local ttfFileName = fileName .. ".ttf"
	local jsonFileName = fileName .. ".font"

	if not isfile(ttfFileName) then
		writefile(ttfFileName, game:HttpGet(fontUrl))
	end

	local ttfAssetId = getcustomasset(ttfFileName)

	local fontConfig = {
		name = fontName or fileName,
		faces = {
			{
				name = "Regular",
				weight = 400,
				style = "normal",
				assetId = ttfAssetId
			}
		}
	}

	writefile(jsonFileName, HttpService:JSONEncode(fontConfig))
	local customFontAsset = getcustomasset(jsonFileName)

	return Font.new(customFontAsset)
end

-- Load VCR OSD Mono Font for Timer
local vcrFont = loadCustomFont("https://github.com/OlOlOlBAKA/Utilities/blob/main/VCR_OSD_MONO_1.001.ttf?raw=true", "VCR_OSD_MONO", "VCR OSD Mono")

-- 2. Configuration Settings
local BASE_TRANSPARENCY = 0.9 -- Default max transparency (faint/idle)
local MIN_TRANSPARENCY = 0.6  -- Min transparency when monster is on top of player (heavy static)
local MAX_DETECTION_DIST = 150 -- Distance in studs where static starts ramping up
local FADE_SPEED = 3 -- Speed multiplier for smooth proximity transparency transition

local MAX_ROTATION = 90
local UPDATE_INTERVAL = 0.03
local timeAccumulator = 0

-- Timer Accumulator
local tapeTimeSeconds = 0

local STATIC_IMAGE_ID = "rbxassetid://9470965"

-- Image Asset IDs for each TapeAction state
local ASSET_IDS = {
	PLAY = LoadCustomAsset("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/main/Play.PNG"),
	REPLAY = LoadCustomAsset("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/main/Replay.PNG"),
	REWIND = LoadCustomAsset("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/main/Rewind.PNG"),
	PAUSE = LoadCustomAsset("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/main/Pause.PNG")
}

-- 3. TapeAction StringValue in PlayerGui
local tapeAction = playerGui:FindFirstChild("TapeAction")
if not tapeAction then
	tapeAction = Instance.new("StringValue")
	tapeAction.Name = "TapeAction"
	tapeAction.Value = "PLAY" -- Options: "PLAY", "REPLAY", "REWIND", "PAUSE"
	tapeAction.Parent = playerGui
end

-- 4. Create Static Blur Effect in Lighting (Permanent Size 7)
local blurEffect = Lighting:FindFirstChild("StaticBlurEffect")
if not blurEffect then
	blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "StaticBlurEffect"
	blurEffect.Size = 7
	blurEffect.Parent = Lighting
else
	blurEffect.Size = 7
end

-- 5. Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StaticScreenGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true -- Covers top bar/notch area
screenGui.ScreenInsets = Enum.ScreenInsets.None -- DISABLES SCREEN SAFE UI INSET (Edge-to-edge coverage)
screenGui.DisplayOrder = -5
screenGui.Enabled = true
screenGui.Parent = playerGui

-- 6. Full-Screen Pause Black Overlay (Smoothly fades in to turn screen black)
local pauseOverlay = Instance.new("Frame")
pauseOverlay.Name = "PauseOverlay"
pauseOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
pauseOverlay.BackgroundTransparency = 1 -- Starts fully transparent
pauseOverlay.Size = UDim2.new(1, 0, 1, 0)
pauseOverlay.Position = UDim2.new(0, 0, 0, 0)
pauseOverlay.BorderSizePixel = 0
pauseOverlay.ZIndex = 1
pauseOverlay.Parent = screenGui

-- 7. CanvasGroup Container (Handles 2-second PAUSE fade for all overlay elements)
local mainGroup = Instance.new("CanvasGroup")
mainGroup.Name = "MainGroup"
mainGroup.BackgroundTransparency = 1
mainGroup.Size = UDim2.new(1, 0, 1, 0)
mainGroup.Position = UDim2.new(0, 0, 0, 0)
mainGroup.GroupTransparency = 0 -- 0 = fully visible, 1 = fully invisible
mainGroup.ZIndex = 2
mainGroup.Parent = screenGui

-- 8. Outer Frame Container for Static
local containerFrame = Instance.new("Frame")
containerFrame.Name = "StaticContainer"
containerFrame.BackgroundTransparency = 1
containerFrame.Size = UDim2.new(1, 0, 1, 0)
containerFrame.Position = UDim2.new(0, 0, 0, 0)
containerFrame.ClipsDescendants = true
containerFrame.Parent = mainGroup

-- 9. Left Black Frame (Positioned at -0.85, 0, 0, 0)
local leftBorder = Instance.new("Frame")
leftBorder.Name = "LeftBorder"
leftBorder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
leftBorder.BackgroundTransparency = 0 -- Visible black frame
leftBorder.Size = UDim2.new(1, 0, 1, 0)
leftBorder.Position = UDim2.new(-0.85, 0, 0, 0)
leftBorder.BorderSizePixel = 0
leftBorder.Parent = mainGroup

-- Mode Action Text Image inside Top Left of Left Border
local modeTextImage = Instance.new("ImageLabel")
modeTextImage.Name = "ModeTextImage"
modeTextImage.BackgroundTransparency = 1
modeTextImage.Image = ASSET_IDS[tapeAction.Value] or ASSET_IDS.PLAY
modeTextImage.Size = UDim2.new(0.35, 0, 0.55, 0)
modeTextImage.Position = UDim2.new(0.95, 0, -0.05, 0)
modeTextImage.ScaleType = Enum.ScaleType.Fit
modeTextImage.Active = false
modeTextImage.Interactable = false
modeTextImage.Parent = leftBorder

-- 10. Right Black Frame (Positioned at 0.85, 0, 0, 0)
local rightBorder = Instance.new("Frame")
rightBorder.Name = "RightBorder"
rightBorder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
rightBorder.BackgroundTransparency = 0 -- Visible black frame
rightBorder.Size = UDim2.new(1, 0, 1, 0)
rightBorder.Position = UDim2.new(0.85, 0, 0, 0)
rightBorder.BorderSizePixel = 0
rightBorder.Parent = mainGroup

local timerTextLabel = Instance.new("TextLabel")
timerTextLabel.Name = "TimerTextLabel"
timerTextLabel.BackgroundTransparency = 1
timerTextLabel.FontFace = vcrFont
timerTextLabel.Text = "00:00:00"
timerTextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timerTextLabel.TextScaled = true
timerTextLabel.TextXAlignment = Enum.TextXAlignment.Left
timerTextLabel.TextYAlignment = Enum.TextYAlignment.Top
timerTextLabel.Size = UDim2.new(0.25, 0, 0.075, 0)
timerTextLabel.Position = UDim2.new(-0.225, 0, 0.182, 0)
timerTextLabel.Active = false
timerTextLabel.Interactable = false
timerTextLabel.Parent = rightBorder
-- 11. Create Tiled ImageLabel inside Frame
local staticImage = Instance.new("ImageLabel")
staticImage.Name = "TiledStaticImage"
staticImage.BackgroundTransparency = 1
staticImage.Image = STATIC_IMAGE_ID
staticImage.ImageTransparency = BASE_TRANSPARENCY
staticImage.ImageColor3 = Color3.fromRGB(255, 255, 255)

staticImage.Active = false
staticImage.Interactable = false

staticImage.ScaleType = Enum.ScaleType.Tile
staticImage.TileSize = UDim2.new(0, 256, 0, 256)

staticImage.Size = UDim2.new(10, 0, 10, 0)
staticImage.AnchorPoint = Vector2.new(0.5, 0.5)
staticImage.Parent = containerFrame

-- 12. Automatically Swap Text Image on TapeAction Change
tapeAction.Changed:Connect(function(newMode)
	if ASSET_IDS[newMode] then
		modeTextImage.Image = ASSET_IDS[newMode]
	end
end)

-- Helper function to format seconds into HH:MM:SS
local function formatTimestamp(seconds)
	local hrs = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", hrs, mins, secs)
end

-- Helper function to get closest entity distance
local function getClosestMonsterDistance()
	local character = localPlayer.Character
	if not character then return math.huge end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
	if not rootPart then return math.huge end
	
	local playerPos = rootPart.Position
	local minDistance = math.huge
	
	-- Search Workspace for any object named RushMoving, AmbushMoving, or DepthMoving
	for _, object in Workspace:GetDescendants() do
		if object.Name == "RushMoving" or object.Name == "AmbushMoving" or object.Name == "DepthMoving" then
			local objectPos = nil
			
			if object:IsA("Model") then
				objectPos = object:GetPivot().Position
			elseif object:IsA("BasePart") then
				objectPos = object.Position
			end
			
			if objectPos then
				local dist = (playerPos - objectPos).Magnitude
				if dist < minDistance then
					minDistance = dist
				end
			end
		end
	end
	
	return minDistance
end

-- 13. Animate Position, Rotation, TapeAction Mode, Timer, Screen Black Fade, and Proximity Transparency
RunService.RenderStepped:Connect(function(deltaTime)
	local mode = tapeAction.Value
	
	-- Timer Behavior
	if mode == "PLAY" or mode == "REPLAY" then
		tapeTimeSeconds = tapeTimeSeconds + deltaTime
	elseif mode == "REWIND" then
		tapeTimeSeconds = math.max(0, tapeTimeSeconds - (deltaTime * 5)) -- Rewinds 5x speed
	end
	-- PAUSE freezes tapeTimeSeconds
	
	timerTextLabel.Text = formatTimestamp(tapeTimeSeconds)

	-- Mode Handling: 2-second transitions for PAUSE mode
	if mode == "PAUSE" then
		-- Smoothly turn screen fully black over 2 seconds
		pauseOverlay.BackgroundTransparency = math.max(0, pauseOverlay.BackgroundTransparency - (deltaTime / 2))
		-- Smoothly fade out static noise & UI text over 2 seconds
		mainGroup.GroupTransparency = math.min(1, mainGroup.GroupTransparency + (deltaTime / 2))
	else
		-- Smoothly return screen back from black over 2 seconds
		pauseOverlay.BackgroundTransparency = math.min(1, pauseOverlay.BackgroundTransparency + (deltaTime / 2))
		-- Smoothly restore UI elements visibility over 2 seconds
		mainGroup.GroupTransparency = math.max(0, mainGroup.GroupTransparency - (deltaTime / 2))
	end
	
	-- Mode Handling: Static Image Transparency
	if mode == "REWIND" then
		staticImage.ImageTransparency = 0
	elseif mode == "PLAY" or mode == "REPLAY" then
		local targetTransparency = BASE_TRANSPARENCY
		local closestDist = getClosestMonsterDistance()
		
		if closestDist <= MAX_DETECTION_DIST then
			local alpha = 1 - math.clamp(closestDist / MAX_DETECTION_DIST, 0, 1)
			targetTransparency = BASE_TRANSPARENCY - alpha * (BASE_TRANSPARENCY - MIN_TRANSPARENCY)
		end
		
		local currentTransparency = staticImage.ImageTransparency
		staticImage.ImageTransparency = currentTransparency + (targetTransparency - currentTransparency) * math.clamp(deltaTime * FADE_SPEED, 0, 1)
	end

	-- Jitter Animation Loop
	timeAccumulator = timeAccumulator + deltaTime
	if timeAccumulator >= UPDATE_INTERVAL then
		timeAccumulator = timeAccumulator % UPDATE_INTERVAL
		
		staticImage.Rotation = random:NextNumber(-MAX_ROTATION, MAX_ROTATION)
		
		local scaleX = 0.5 + random:NextNumber(-0.5, 0.5)
		local scaleY = 0.5 + random:NextNumber(-0.5, 0.5)
		
		staticImage.Position = UDim2.new(scaleX, 0, scaleY, 0)
	end
end)
