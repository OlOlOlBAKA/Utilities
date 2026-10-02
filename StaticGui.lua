-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = localPlayer:WaitForChild("PlayerGui")
local random = Random.new()

if playerGui:FindFirstChild("StaticScreenGui") then return end

-- 1. Configuration Settings
local BASE_TRANSPARENCY = 0.9 -- Default max transparency (faint/idle)
local MIN_TRANSPARENCY = 0.5  -- Min transparency when monster is on top of player (heavy static)
local MAX_DETECTION_DIST = 200 -- Distance in studs where static starts ramping up
local FADE_SPEED = 3 -- Speed multiplier for smooth transparency transition

local MAX_ROTATION = 90
local UPDATE_INTERVAL = 0.03
local timeAccumulator = 0

-- 2. Create Static Blur Effect in Lighting (Permanent Size 7)
local blurEffect = Lighting:FindFirstChild("StaticBlurEffect")
if not blurEffect then
	blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "StaticBlurEffect"
	blurEffect.Size = 7
	blurEffect.Parent = Lighting
else
	blurEffect.Size = 7
end

-- 3. Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StaticScreenGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true -- Covers top bar/notch area
screenGui.ScreenInsets = Enum.ScreenInsets.None -- DISABLES SCREEN SAFE UI INSET (Edge-to-edge coverage)
screenGui.DisplayOrder = -5
screenGui.Enabled = true
screenGui.Parent = playerGui

-- 4. Outer Frame Container for Static
local containerFrame = Instance.new("Frame")
containerFrame.Name = "StaticContainer"
containerFrame.BackgroundTransparency = 1
containerFrame.Size = UDim2.new(1, 0, 1, 0)
containerFrame.Position = UDim2.new(0, 0, 0, 0)
containerFrame.ClipsDescendants = true
containerFrame.Parent = screenGui

-- 5. Left Black Frame (Positioned at -0.85, 0, 0, 0)
local leftBorder = Instance.new("Frame")
leftBorder.Name = "LeftBorder"
leftBorder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
leftBorder.BackgroundTransparency = 0 -- Visible black frame
leftBorder.Size = UDim2.new(1, 0, 1, 0)
leftBorder.Position = UDim2.new(-0.9, 0, 0, 0)
leftBorder.BorderSizePixel = 0
leftBorder.Parent = screenGui

-- 6. Right Black Frame (Positioned at 0.85, 0, 0, 0)
local rightBorder = Instance.new("Frame")
rightBorder.Name = "RightBorder"
rightBorder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
rightBorder.BackgroundTransparency = 0 -- Visible black frame
rightBorder.Size = UDim2.new(1, 0, 1, 0)
rightBorder.Position = UDim2.new(0.9, 0, 0, 0)
rightBorder.BorderSizePixel = 0
rightBorder.Parent = screenGui

-- 7. Create Tiled ImageLabel inside Frame
local staticImage = Instance.new("ImageLabel")
staticImage.Name = "TiledStaticImage"
staticImage.BackgroundTransparency = 1
staticImage.Image = "rbxassetid://9470965"
staticImage.ImageTransparency = BASE_TRANSPARENCY
staticImage.ImageColor3 = Color3.fromRGB(255, 255, 255)

staticImage.Active = false
staticImage.Interactable = false

staticImage.ScaleType = Enum.ScaleType.Tile
staticImage.TileSize = UDim2.new(0, 256, 0, 256)

staticImage.Size = UDim2.new(10, 0, 10, 0)
staticImage.AnchorPoint = Vector2.new(0.5, 0.5)
staticImage.Parent = containerFrame

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
		if object.Name == "RushMoving" or object.Name == "AmbushMoving" or object.Name == "DepthMoving" or object.Name == "Rebound" or object.Name == "A120" or object.Name == "A-120" then
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

-- 8. Animate Position, Rotation, and Smooth Proximity Transparency
RunService.RenderStepped:Connect(function(deltaTime)
	local targetTransparency = BASE_TRANSPARENCY
	local closestDist = getClosestMonsterDistance()
	
	if closestDist <= MAX_DETECTION_DIST then
		local alpha = 1 - math.clamp(closestDist / MAX_DETECTION_DIST, 0, 1)
		targetTransparency = BASE_TRANSPARENCY - alpha * (BASE_TRANSPARENCY - MIN_TRANSPARENCY)
	end
	
	-- Smoothly transition transparency
	local currentTransparency = staticImage.ImageTransparency
	staticImage.ImageTransparency = currentTransparency + (targetTransparency - currentTransparency) * math.clamp(deltaTime * FADE_SPEED, 0, 1)

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
