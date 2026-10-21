-- ==========================================
-- 1. จัดการ UI และป้องกันการรันซ้ำด้วย Return
-- ==========================================
local CoreGui = game:GetService("CoreGui")

if CoreGui:FindFirstChild("AutoFishToggleUI") then
    -- หากมี UI อยู่แล้ว ให้คืนค่า (return) ออกไปเลย ไม่สร้างซ้ำและไม่ทำลายของเก่า
    return
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFishToggleUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 140, 0, 45)
toggleButton.Position = UDim2.new(0.05, 0, 0.15, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
toggleButton.BorderColor3 = Color3.fromRGB(60, 60, 60)
toggleButton.BorderSizePixel = 2
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 14
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Text = "Auto Fish: OFF"
toggleButton.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = toggleButton

-- ==========================================
-- 2. ค้นหา Actor และเตรียมสั่งรันสคริปต์
-- ==========================================
local actor

for _, v in ipairs(get_actors()) do
    if v.Name == "ClientHandlers" then
        actor = v
        break
    end
end

assert(actor, "ClientHandlers actor not found")

-- ==========================================
-- 3. ระบบกดปุ่มเปิด-ปิดการทำงาน
-- ==========================================
local isRunning = false

toggleButton.MouseButton1Click:Connect(function()
    isRunning = not isRunning

    if isRunning then
        toggleButton.Text = "Auto Fish: ON"
        toggleButton.BackgroundColor3 = Color3.fromRGB(40, 160, 80)

        -- สั่งรันสคริปต์ตกปลาทั้งหมดเข้าไปใน Actor
        task.spawn(function()
            run_on_actor(actor, [==[
                local Players = game:GetService("Players")
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                local ReplicatedFirst = game:GetService("ReplicatedFirst")
                local HttpService = game:GetService("HttpService")
                local VirtualUser = game:GetService("VirtualUser")

                local player = Players.LocalPlayer

                local config = {
                    autoSell = true,
                    sellTriggerRemaining = 5,

                    arriveDistance = 5,
                    repathInterval = 0.18,
                    moveTimeout = 60,
                    startTimeout = 10,
                    resultHoldTime = 1.25,
                    betweenCasts = 0.5,
                    stuckTime = 1
                }

                local SimplePath = loadstring(game:HttpGet(
                    "https://raw.githubusercontent.com/ahmicy/simplepath/main/src/SimplePath.lua"
                ))()

                local Fishing = require(
                    ReplicatedStorage.Packets:WaitForChild("Fishing")
                )

                local Utility = require(
                    ReplicatedStorage.Modules:WaitForChild("Utility")
                )

                local replica = Utility.Replica.WaitForReplica(player)

                local fishingClient = ReplicatedFirst
                    .ClientHandlers
                    :WaitForChild("FishingClient")

                local FishUI = require(
                    fishingClient:WaitForChild("FishUI")
                )

                local FishingShopUI = require(
                    ReplicatedStorage.Modules.UI:WaitForChild("FishingShopUI")
                )

                local fishingPoints = workspace
                    .Map
                    .Miscs
                    :WaitForChild("FishingPoints")

                local fishShop = workspace
                    .Map
                    .Miscs
                    :WaitForChild("FishShop")

                local shopPrompt = fishShop
                    .NPC
                    :WaitForChild("ProximityPrompt")

                local sessionKey = "__OvernightAutoFish"
                local session = HttpService:GenerateGUID(false)

                player:SetAttribute(sessionKey, session)

                local function running()
                    return player:GetAttribute(sessionKey) == session
                end

                player.Idled:Connect(function()
                    if not running() then
                        return
                    end

                    pcall(function()
                        VirtualUser:CaptureController()
                        VirtualUser:ClickButton2(Vector2.new())
                    end)
                end)

                local function getCharacter()
                    local character = player.Character or player.CharacterAdded:Wait()
                    local humanoid = character:WaitForChild("Humanoid")
                    local root = character:WaitForChild("HumanoidRootPart")

                    character.PrimaryPart = root

                    return character, humanoid, root
                end

                local path
                local pathCharacter

                local function getPath()
                    local character, humanoid, root = getCharacter()

                    if pathCharacter ~= character then
                        if path then
                            pcall(function()
                                path:Destroy()
                            end)
                        end

                        pathCharacter = character

                        path = SimplePath.new(
                            character,
                            {
                                AgentRadius = 2,
                                AgentHeight = 5,
                                AgentCanJump = true,
                                AgentCanClimb = true,
                                WaypointSpacing = 4
                            },
                            {
                                TIME_VARIANCE = 0.07,
                                COMPARISON_CHECKS = 2,
                                JUMP_WHEN_STUCK = true
                            }
                        )

                        path.Error:Connect(function(errorType)
                            if errorType == SimplePath.ErrorType.AgentStuck then
                                humanoid.Jump = true
                                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                            end
                        end)

                        path.Blocked:Connect(function()
                            humanoid.Jump = true
                            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end)
                    end

                    return path, character, humanoid, root
                end

                local function stopPath(currentPath)
                    if currentPath and currentPath.Status == SimplePath.StatusType.Active then
                        pcall(function()
                            currentPath:Stop()
                        end)
                    end
                end

                local function walkTo(goal, distance, invalid)
                    local currentPath, character, humanoid, root = getPath()

                    local started = os.clock()
                    local lastPosition = root.Position
                    local stuckFor = 0

                    while running() do
                        if player.Character ~= character or not root.Parent then
                            return false, "respawn"
                        end

                        if invalid and invalid() then
                            stopPath(currentPath)
                            return false, "invalid"
                        end

                        if (root.Position - goal).Magnitude <= distance then
                            stopPath(currentPath)
                            return true
                        end

                        if os.clock() - started >= config.moveTimeout then
                            stopPath(currentPath)
                            return false, "timeout"
                        end

                        local ok = pcall(function()
                            currentPath:Run(goal)
                        end)

                        if not ok then
                            humanoid.Jump = true
                            task.wait(0.35)
                        else
                            task.wait(config.repathInterval)
                        end

                        local moved = (root.Position - lastPosition).Magnitude

                        if moved < 0.12 then
                            stuckFor += config.repathInterval
                        else
                            stuckFor = 0
                        end

                        if stuckFor >= config.stuckTime then
                            humanoid.Jump = true
                            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

                            task.wait(0.15)

                            pcall(function()
                                currentPath:Run(goal)
                            end)

                            stuckFor = 0
                        end

                        lastPosition = root.Position
                    end

                    return false, "stopped"
                end

                local function waitUntil(callback, timeout, rate)
                    local deadline = os.clock() + timeout

                    repeat
                        if callback() then
                            return true
                        end

                        task.wait(rate or 0.05)
                    until not running() or os.clock() >= deadline

                    return callback()
                end

                local function inventoryCount()
                    local count = 0

                    for _ in replica.Data.FishInventory do
                        count += 1
                    end

                    return count, replica.Data.FishInventorySize
                end

                local function getNearestSpot()
                    local _, _, root = getCharacter()

                    local closest
                    local closestDistance = math.huge

                    for _, spot in ipairs(fishingPoints:GetChildren()) do
                        if spot:IsA("Model")
                            and spot:GetAttribute("spotId")
                            and not spot:GetAttribute("occupied") then

                            local distance = (
                                root.Position - spot:GetPivot().Position
                            ).Magnitude

                            if distance < closestDistance then
                                closest = spot
                                closestDistance = distance
                            end
                        end
                    end

                    return closest, closestDistance
                end

                local function getShopPosition()
                    local npc = fishShop.NPC

                    if npc:IsA("BasePart") then
                        return npc.Position
                    end

                    return npc:GetPivot().Position
                end

                local function sellFish(uid)
                    if not replica.Data.FishInventory[uid] then
                        return true
                    end

                    FishingShopUI.Store.SelectedFishUID = uid
                    FishingShopUI.Store.SellButton.Callback()

                    local confirm = FishingShopUI.Store.sellConfirmFrame

                    if not waitUntil(function()
                        return confirm:IsOpened()
                    end, 10) then
                        return false
                    end

                    confirm.OnSelected:Fire(true)

                    return waitUntil(function()
                        return replica.Data.FishInventory[uid] == nil
                    end, 10, 0.1)
                end

                local function autoSell()
                    print("[auto fish] heading to fish shop")

                    local reached, reason = walkTo(getShopPosition(), 7)

                    if not reached then
                        warn("[auto fish] couldn't reach fish shop:", reason)
                        return false
                    end

                    fireproximityprompt(shopPrompt)

                    task.delay(5, function()
                        FishingShopUI.Window.Visible = true
                    end)
                    
                    if not waitUntil(function()
                        return FishingShopUI.Window.Visible
                    end, 15) then
                        warn("[auto fish] shop didn't open")
                        return false
                    end

                    FishingShopUI.Store.IsBuyPage = false

                    local fishToSell = {}

                    for uid in replica.Data.FishInventory do
                        table.insert(fishToSell, uid)
                    end

                    local sold = 0

                    for _, uid in ipairs(fishToSell) do
                        if not running() then
                            break
                        end

                        if sellFish(uid) then
                            sold += 1
                        else
                            warn("[auto fish] failed to sell", uid)
                            task.wait(0.5)
                        end

                        task.wait(0.1)
                    end

                    FishingShopUI.Window.Visible = false

                    local current, capacity = inventoryCount()

                    print(
                        "[auto fish] sold",
                        sold,
                        "fish | storage",
                        current .. "/" .. capacity
                    )

                    return current < capacity
                end

                local catches = 0
                local failures = 0

                print("[auto fish] started")

                while running() do
                    local count, capacity = inventoryCount()

                    if config.autoSell
                        and count >= capacity - config.sellTriggerRemaining then

                        autoSell()

                        count, capacity = inventoryCount()
                    end

                    if count >= capacity then
                        warn("[auto fish] inventory full")
                        task.wait(5)
                        continue
                    end

                    if FishUI.isResultMode then
                        FishUI.isResultMode = false
                        task.wait(0.25)
                    end

                    local spot, distance = getNearestSpot()

                    if not spot then
                        warn("[auto fish] no free fishing spots")
                        task.wait(2)
                        continue
                    end

                    local goal = spot:GetPivot().Position

                    if distance > config.arriveDistance then
                        print(
                            "[auto fish] walking",
                            math.floor(distance),
                            "studs"
                        )

                        local reached = walkTo(
                            goal,
                            config.arriveDistance,
                            function()
                                return not spot.Parent
                                    or spot:GetAttribute("occupied")
                            end
                        )

                        if not reached then
                            task.wait(0.5)
                            continue
                        end
                    end

                    local _, _, root = getCharacter()

                    waitUntil(function()
                        return FishUI.visible
                    end, 3)

                    if not FishUI.visible
                        or spot:GetAttribute("occupied")
                        or (root.Position - goal).Magnitude > 10 then

                        task.wait(0.5)
                        continue
                    end

                    print(
                        "[auto fish] casting at",
                        spot:GetAttribute("locationName") or spot.Name
                    )

                    Fishing.start.send(spot:GetAttribute("spotId"))

                    if not waitUntil(function()
                        return FishUI.isFishing
                    end, config.startTimeout) then

                        warn("[auto fish] fishing start timed out")
                        task.wait(1)
                        continue
                    end

                    while running() and FishUI.isFishing do
                        if FishUI.isMinigameMode and FishUI.isMinigameStarted then
                            local middle = math.clamp(
                                (FishUI.successPosition or 0.5)
                                + (FishUI.successWidth or 0.1) / 2,
                                0,
                                1
                            )

                            FishUI.fishProgress = middle
                            FishUI.catchProgress = 100
                        end

                        task.wait(0.03)
                    end

                    if not running() then
                        break
                    end

                    waitUntil(function()
                        return FishUI.isResultMode
                    end, 5)

                    if FishUI.isResultMode then
                        if FishUI.rewardType == "Fish" then
                            catches += 1

                            print(
                                "[auto fish] caught",
                                FishUI.rewardName,
                                "| total",
                                catches
                            )
                        else
                            failures += 1

                            warn(
                                "[auto fish]",
                                FishUI.rewardType,
                                "| failures",
                                failures
                            )
                        end

                        task.wait(config.resultHoldTime)
                        FishUI.isResultMode = false
                    end

                    waitUntil(function()
                        return not FishUI.isMinigameMode
                    end, 3)

                    task.wait(config.betweenCasts)
                end

                if path then
                    pcall(function()
                        path:Destroy()
                    end)
                end

                print(
                    "[auto fish] stopped | caught",
                    catches,
                    "| failures",
                    failures
                )
            ]==])
        end)
    else
        toggleButton.Text = "Auto Fish: OFF"
        toggleButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)

        -- สั่งหยุดการทำงานโดยเปลี่ยนค่า Attribute
        pcall(function()
            run_on_actor(actor, [==[
                local sessionKey = "__OvernightAutoFish"
                game:GetService("Players").LocalPlayer:SetAttribute(sessionKey, "Stopped")
            ]==])
        end)
    end
end)
