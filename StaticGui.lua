-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = localPlayer:WaitForChild("PlayerGui")
local random = Random.new()

if playerGui:FindFirstChild("StaticScreenGui") then return end

loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"))()

-- 1. Configuration Settings
local BASE_TRANSPARENCY = 0.95 -- Default max transparency (faint/idle)
local MIN_TRANSPARENCY = 0.6  -- Min transparency when monster is on top of player (heavy static)
local MAX_DETECTION_DIST = 150 -- Distance in studs where static starts ramping up
local FADE_SPEED = 3 -- Speed multiplier for smooth proximity transparency transition

local MAX_ROTATION = 90
local UPDATE_INTERVAL = 0.03
local timeAccumulator = 0

local STATIC_IMAGE_ID = "rbxassetid://9470965"

local root = "https://github.com/OlOlOlBAKA/Utilities/raw/main"

-- Image Asset IDs for each TapeAction state (Replace with your own asset IDs)
local ASSET_IDS = {
	PLAY = LoadCustomInstance(root.."/Play.PNG"),
	REPLAY = LoadCustomInstance(root.."/Replay.PNG"),
	REWIND = LoadCustomInstance(root.."/Rewind.PNG"),
	PAUSE = LoadCustomInstance(root.."/Pause.PNG")
}

-- 2. Preload Images
task.spawn(function()
	local assetsToPreload = { STATIC_IMAGE_ID }
	for _, id in pairs(ASSET_IDS) do
		if type(id) == "string" then
			table.insert(assetsToPreload, id)
		end
	end
	
	-- Asynchronously preloads textures into memory
	pcall(function()
		ContentProvider:PreloadAsync(assetsToPreload)
	end)
end)

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

-- 6. CanvasGroup Container (Handles 2-second PAUSE fade for all elements)
local mainGroup = Instance.new("CanvasGroup")
mainGroup.Name = "MainGroup"
mainGroup.BackgroundTransparency = 1
mainGroup.Size = UDim2.new(1, 0, 1, 0)
mainGroup.Position = UDim2.new(0, 0, 0, 0)
mainGroup.GroupTransparency = 0 -- 0 = fully visible, 1 = fully invisible
mainGroup.Parent = screenGui

-- 7. Outer Frame Container for Static
local containerFrame = Instance.new("Frame")
containerFrame.Name = "StaticContainer"
containerFrame.BackgroundTransparency = 1
containerFrame.Size = UDim2.new(1, 0, 1, 0)
containerFrame.Position = UDim2.new(0, 0, 0, 0)
containerFrame.ClipsDescendants = true
containerFrame.Parent = mainGroup

-- 8. Left Black Frame (Positioned at -0.85, 0, 0, 0)
local leftBorder = Instance.new("Frame")
leftBorder.Name = "LeftBorder"
leftBorder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
leftBorder.BackgroundTransparency = 0 -- Visible black frame
leftBorder.Size = UDim2.new(1, 0, 1, 0)
leftBorder.Position = UDim2.new(-0.8, 0, 0, 0)
leftBorder.BorderSizePixel = 0
leftBorder.Parent = mainGroup

-- Mode Action Text Image inside Top Left of Left Border
local modeTextImage = Instance.new("ImageLabel")
modeTextImage.Name = "ModeTextImage"
modeTextImage.BackgroundTransparency = 1
modeTextImage.Image = ASSET_IDS[tapeAction.Value] or ASSET_IDS.PLAY
modeTextImage.Size = UDim2.new(0.2, 0, 0.4, 0)
modeTextImage.Position = UDim2.new(0.85, 0, 0.05, 0)
modeTextImage.ScaleType = Enum.ScaleType.Fit
modeTextImage.Active = false
modeTextImage.Interactable = false
modeTextImage.Parent = leftBorder

-- 9. Right Black Frame (Positioned at 0.85, 0, 0, 0)
local rightBorder = Instance.new("Frame")
rightBorder.Name = "RightBorder"
rightBorder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
rightBorder.BackgroundTransparency = 0 -- Visible black frame
rightBorder.Size = UDim2.new(1, 0, 1, 0)
rightBorder.Position = UDim2.new(0.8, 0, 0, 0)
rightBorder.BorderSizePixel = 0
rightBorder.Parent = mainGroup

-- 10. Create Tiled ImageLabel inside Frame
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

-- 11. Automatically Swap Text Image on TapeAction Change
tapeAction.Changed:Connect(function(newMode)
	if ASSET_IDS[newMode] then
		modeTextImage.Image = ASSET_IDS[newMode]
	end
end)

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

-- 12. Animate Position, Rotation, TapeAction Mode, and Smooth Proximity Transparency
RunService.RenderStepped:Connect(function(deltaTime)
	local mode = tapeAction.Value
	
	-- Mode Handling: Group Fading for PAUSE mode (2 seconds)
	if mode == "PAUSE" then
		mainGroup.GroupTransparency = math.min(1, mainGroup.GroupTransparency + (deltaTime / 2))
	else
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
