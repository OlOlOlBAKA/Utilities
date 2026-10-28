-- LocalScript: Noise Complete Execution Script (Final Optimized)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==========================================
-- 1. LOAD UTILITIES & CUSTOM INSTANCES
-- ==========================================
loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"))()

local newScript = LoadCustomInstance("https://github.com/OlOlOlBAKA/Utilities/raw/main/NoiseTV_Module.rbxm")
local newF = workspace:FindFirstChild("NoiseTV")
if not newF then
    newF = Instance.new("Folder")
    newF.Name = "NoiseTV"
    newF.Parent = workspace
end

for _,v in ipairs(newScript:GetChildren()) do
    v.Parent = newF
end

local noiseModel = LoadCustomInstance("https://github.com/OlOlOlBAKA/Utilities/raw/main/NoiseModel.rbxm")
local tapeZeroColors = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/TapeZeroColor.lua"))()
local tvStandModel = LoadCustomInstance("https://github.com/OlOlOlBAKA/Utilities/raw/main/TV_Stand.rbxm")

local noiseReplication = newF:WaitForChild("NoiseReplication", 5)
if not noiseReplication then
    noiseReplication = Instance.new("Folder")
    noiseReplication.Name = "NoiseReplication"
    noiseReplication.Parent = newF
end

local MainGame = require(LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("MainUI"):WaitForChild("Initiator"):WaitForChild("Main_Game"))

-- ==========================================
-- 2. SETUP CLIENT CONTROLLER & NOISE MODULE
-- ==========================================
local clientController = {
    cam = Camera,
    char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait(),
    fovtarget = Camera.FieldOfView,
    
    shakerel = function(position, magnitude, roughness, fadeInTime, fadeOutTime)
        if MainGame and MainGame.camShaker then
            MainGame.camShaker:ShakeOnce(magnitude, roughness, fadeInTime or 0.1, fadeOutTime or 1.2)
        end
    end,
    
    animateCharacter = function(char, animObj, startCF, endCF, ...)
        if char and char:FindFirstChildOfClass("Humanoid") then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
            if animObj then
                local track = animator:LoadAnimation(animObj)
                track:Play()
            end
        end
    end
}

LocalPlayer.CharacterAdded:Connect(function(newChar)
    clientController.char = newChar
end)

local noiseModuleFunction = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/NoiseModule.lua"))()

local noiseVisuals = nil

-- 1. Check for Compilation / Syntax Errors
local compiledFunction, syntaxError = noiseModuleFunction(clientController, newF)
if not compiledFunction then
	warn("[Item Spawner Syntax Error]: The downloaded code has syntax issues ->", syntaxError)
	return
end

-- 2. Check for Runtime/Execution Errors during initialization
local runSuccess, runError = pcall(function()
	ItemSpawner = compiledFunction()
end)

if not runSuccess then
	warn("[Item Spawner Initialization Error]: The script ran but crashed immediately ->", runError)
	return
elseif type(noiseVisuals) ~= "table" then
	warn("[Item Spawner Content Error]: The script executed successfully, but did not return a valid module table! It returned type:", type(noiseVisuals))
	return
end

print("✅ Noise Module Systems Loaded Successfully!")

-- ==========================================
-- 3. SPAWN TV & TRIGGER NOISE FUNCTION
-- ==========================================
local function startNoiseEvent()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    
    -- เสกทีวีวางไว้หน้าผู้เล่นระยะ 5 Studs
    local tvClone = tvStandModel:Clone()
    local tvSpawnCF = hrp.CFrame * CFrame.new(0, 0, -5) * CFrame.Angles(0, math.rad(180), 0)
    tvClone:PivotTo(tvSpawnCF)
    tvClone.Parent = Workspace

    task.wait(0.1)
    
    -- ค้นหาตำแหน่งเริ่มต้นจาก NoiseAttach หรือ PrimaryPart/Base ของทีวี
    local noiseAttach = tvClone:FindFirstChild("NoiseAttach", true)
    local exactTvCFrame = noiseAttach and noiseAttach.WorldCFrame or (tvClone.PrimaryPart and tvClone.PrimaryPart.CFrame or tvSpawnCF)

    -- สร้าง Folder สั่ง Replication
    local noiseFolder = Instance.new("Folder")
    noiseFolder.Name = "Noise_" .. LocalPlayer.Name .. "_" .. tick()

    noiseFolder:SetAttribute("TargetUserId", LocalPlayer.UserId)
    noiseFolder:SetAttribute("State", "Emerging")
    noiseFolder:SetAttribute("Crawling", false)
    noiseFolder:SetAttribute("Enraged", false)

    local tvVal = Instance.new("ObjectValue")
    tvVal.Name = "TV"
    tvVal.Value = tvClone
    tvVal.Parent = noiseFolder

    local victimVal = Instance.new("ObjectValue")
    victimVal.Name = "Victim"
    victimVal.Value = char
    victimVal.Parent = noiseFolder

    local targetCF = Instance.new("CFrameValue")
    targetCF.Name = "TargetCF"
    targetCF.Value = exactTvCFrame
    targetCF.Parent = noiseFolder

    noiseFolder.Parent = noiseReplication
    print("📺 TV Spawned & Noise Triggered Successfully!")

    -- ลูป AI & Pathfinding (เริ่มทำงานทันทีหลังประกาศตัว)
    task.spawn(function()
        local pathQueue = {} 
        local lastRecordedPos = hrp.Position
        local baseSpeed = 13  -- ความเร็วปกติ 13 Studs/s
        local ffSpeed = 18    -- ความเร็ว Fast Forward 18 Studs/s
        local isFastForwarding = false

        while noiseFolder and noiseFolder.Parent do
            local dt = task.wait(0.03)
            local playerChar = LocalPlayer.Character
            local playerHrp = playerChar and playerChar:FindFirstChild("HumanoidRootPart")

            if playerHrp then
                local currentNoisePos = targetCF.Value.Position
                local currentPlayerPos = playerHrp.Position
                
                local distanceToPlayer = (currentPlayerPos - currentNoisePos).Magnitude
                local playerMovedDist = (currentPlayerPos - lastRecordedPos).Magnitude
                local isPlayerMoving = playerMovedDist > 0.05

                -- บันทึกรอยเท้าเมื่อผู้เล่นเคลื่อนที่
                if isPlayerMoving then
                    lastRecordedPos = currentPlayerPos
                    table.insert(pathQueue, playerHrp.CFrame)
                end

                -- เช็คเงื่อนไขโหมด Fast Forward (> 50 Studs เข้าโหมด / <= 10 Studs ออกจากโหมด)
                if distanceToPlayer > 50 then
                    isFastForwarding = true
                elseif distanceToPlayer <= 10 then
                    isFastForwarding = false
                end

                local currentActiveSpeed = isFastForwarding and ffSpeed or baseSpeed

                -- อัปเดตสถานะ (State) ของ Noise ส่งให้ Module ทราบ
                if noiseFolder:GetAttribute("State") ~= "Emerging" then
                    if isFastForwarding then
                        noiseFolder:SetAttribute("State", "FastForward")
                    elseif isPlayerMoving then
                        noiseFolder:SetAttribute("State", "Walking")
                    else
                        noiseFolder:SetAttribute("State", "Paused")
                    end
                end

                -- ควบคุมการเคลื่อนที่ตามคิวรอยเท้า (เดินตามรอยผู้เล่นเสมอ แม้กระทั่งตอน Fast Forward)
                if #pathQueue > 0 then
                    local nextNodeCF = pathQueue[1]
                    local moveDir = (nextNodeCF.Position - currentNoisePos)

                    if moveDir.Magnitude < 1.5 then
                        table.remove(pathQueue, 1)
                    else
                        local stepPos = currentNoisePos + moveDir.Unit * (currentActiveSpeed * dt)
                        targetCF.Value = CFrame.lookAt(stepPos, Vector3.new(nextNodeCF.Position.X, stepPos.Y, nextNodeCF.Position.Z))
                    end
                elseif isFastForwarding then
                    local moveDir = (currentPlayerPos - currentNoisePos)
                    if moveDir.Magnitude > 0.1 then
                        local stepPos = currentNoisePos + moveDir.Unit * (currentActiveSpeed * dt)
                        targetCF.Value = CFrame.lookAt(stepPos, Vector3.new(currentPlayerPos.X, stepPos.Y, currentPlayerPos.Z))
                    end
                end
            end
        end
    end)
end

task.wait(1)
startNoiseEvent()
