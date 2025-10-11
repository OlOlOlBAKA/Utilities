local CoreGui = game:GetService("CoreGui")

local Value = false

local function ManageLight(value)
   if value then
       local Light = Instance.new("PointLight")
       Light.Name = "pointoflight"
       Light.Brightness = 10
       Light.Range = 60
       Light.Parent = game.Players.LocalPlayer.Character.Head
   else
       if game.Players.LocalPlayer.Character.Head:FindFirstChild("pointoflight") then
         game.Players.LocalPlayer.Character.Head.pointoflight:Destroy()
      end
   end
end

if CoreGui:FindFirstChild("ScreenGui") then
CoreGui.ScreenGui:Destroy()
end

if not CoreGui:FindFirstChild("ScreenGui") then
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

-- Create TextButton
local button = Instance.new("TextButton")
button.Size = UDim2.new(0.1,0,0.2,0)
button.Position = UDim2.new(0.5, -100, 0.5, -25)
button.Text = "Toggle"
button.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.SourceSansBold
button.TextSize = 24
button.Parent = screenGui

button.Active = true
button.Draggable = true

button.MouseButton1Click:Connect(function()
    if Value then
        Value = false
    else
        Value = true
    end
    ManageLight(Value)
end)
end
