--// ClickerGui – Roblox Native Draggable + VirtualUser
--// LocalScript → StarterGui

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

-- Create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClickerGui_RobloxDrag"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.Parent = CoreGui  -- Use player:WaitForChild("PlayerGui") for live games

-------------------------------------------------
-- CONFIG
-------------------------------------------------
local TOGGLE_SIZE = UDim2.new(0, 140, 0, 50)
local TOGGLE_POS  = UDim2.new(0, 15, 0, 15)

local DOT_SIZE    = UDim2.new(0, 60, 0, 60)
local DOT_COLOR_ON  = Color3.fromRGB(0, 170, 255)   -- clicking
local DOT_COLOR_OFF = Color3.fromRGB(200, 200, 200) -- draggable

local CLICK_INTERVAL = 0.05
-------------------------------------------------

-- Toggle Button
local toggle = Instance.new("TextButton")
toggle.Size = TOGGLE_SIZE
toggle.Position = TOGGLE_POS
toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
toggle.BorderSizePixel = 0
toggle.Text = "Clicker: OFF"
toggle.TextColor3 = Color3.new(1,1,1)
toggle.Font = Enum.Font.SourceSansBold
toggle.TextSize = 20
toggle.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 12)
toggleCorner.Parent = toggle

-- Click Dot
local dot = Instance.new("Frame")
dot.Size = DOT_SIZE
dot.BackgroundColor3 = DOT_COLOR_OFF
dot.Visible = false
dot.Name = "ClickDot"
dot.Draggable = false  -- Controlled by us
dot.Active = true      -- Required for Draggable
dot.Parent = screenGui

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot

-- Drag glow (feedback when dragging)
local dragGlow = Instance.new("UIStroke")
dragGlow.Color = Color3.fromRGB(255, 255, 255)
dragGlow.Thickness = 4
dragGlow.Transparency = 1
dragGlow.Parent = dot

-------------------------------------------------
-- State
-------------------------------------------------
local isEnabled = false  -- true = clicking
local clickConn = nil

-------------------------------------------------
-- VirtualUser Click
-------------------------------------------------
local function fireClick()
	if not dot.Visible then return end
	local center = dot.AbsolutePosition + dot.AbsoluteSize/2
	VirtualUser:ClickButton1(Vector2.new(center.X, center.Y))
end

local function startClicking()
	if clickConn then return end
	clickConn = RunService.Heartbeat:Connect(function()
		if isEnabled and dot.Visible then
			fireClick()
			task.wait(CLICK_INTERVAL)
		end
	end)
end

local function stopClicking()
	if clickConn then clickConn:Disconnect() clickConn = nil end
end

-------------------------------------------------
-- Enable / Disable Clicker
-------------------------------------------------
local function setEnabled(on)
	isEnabled = on

	if on then
		-- CLICKER ON
		toggle.Text = "Clicker: ON"
		toggle.BackgroundColor3 = Color3.fromRGB(0, 140, 0)
		dot.BackgroundColor3 = DOT_COLOR_ON
		dot.Visible = true
		dot.Draggable = false  -- DISABLE DRAG
		dragGlow.Transparency = 1

		-- Center if first time
		if dot.Position == UDim2.new() then
			dot.Position = UDim2.new(0.5, -DOT_SIZE.X.Offset/2, 0.5, -DOT_SIZE.Y.Offset/2)
		end

		startClicking()
	else
		-- CLICKER OFF
		toggle.Text = "Clicker: OFF"
		toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		dot.BackgroundColor3 = DOT_COLOR_OFF
		dot.Draggable = true   -- ENABLE DRAG
		stopClicking()
		dot.Visible = true
	end
end

-- Toggle
toggle.MouseButton1Click:Connect(function()
	setEnabled(not isEnabled)
end)

-------------------------------------------------
-- Native Drag Feedback (Glow when dragging)
-------------------------------------------------
dot.MouseEnter:Connect(function()
	if dot.Draggable then
		TweenService:Create(dragGlow, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
	end
end)

dot.MouseLeave:Connect(function()
	if dot.Draggable then
		TweenService:Create(dragGlow, TweenInfo.new(0.2), {Transparency = 1}):Play()
	end
end)

-- Mobile touch feedback
dot.TouchTap:Connect(function() end) -- No action
dot.InputBegan:Connect(function(input)
	if dot.Draggable and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
		TweenService:Create(dragGlow, TweenInfo.new(0.1), {Transparency = 0}):Play()
	end
end)

dot.InputEnded:Connect(function(input)
	if dot.Draggable and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
		TweenService:Create(dragGlow, TweenInfo.new(0.2), {Transparency = 1}):Play()
	end
end)

-------------------------------------------------
-- Toggle Hover Feedback
-------------------------------------------------
toggle.MouseEnter:Connect(function()
	if not isEnabled then
		TweenService:Create(toggle, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(70,70,70)}):Play()
	end
end)
toggle.MouseLeave:Connect(function()
	if not isEnabled then
		TweenService:Create(toggle, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40,40,40)}):Play()
	end
end)

-- Start OFF (draggable)
setEnabled(false)
