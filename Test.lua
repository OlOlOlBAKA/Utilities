local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Main_Game = require(Players.LocalPlayer.PlayerGui.MainUI.Initiator.Main_Game)

-- Anti-re-run protection
if _G.HardcoreModeRunning then
    Main_Game.caption("Hardcore Mode is already running!", true, 3)
    return
end

if ReplicatedStorage.GameData.LatestRoom.Value > 0 then
    Main_Game.caption("You must run the script at door 0", true, 3)
    return
end

_G.HardcoreModeRunning = true

--------------------------------------------------------------------------------
-- CONFIGURATION & GLOBAL SETTINGS
--------------------------------------------------------------------------------
local GLOBAL_IGNORE_MAX_ROOMS = false

local success, floorVal = pcall(function()
    return ReplicatedStorage.GameData.Floor.Value
end)
if success and floorVal == "Archives" or success and floorVal == "Rooms" then
    GLOBAL_IGNORE_MAX_ROOMS = true
    print("Its Archives/Rooms Floor")
end

-- Fetch DOORS actual game seed
local function getGameSeed()
    local gameData = ReplicatedStorage:FindFirstChild("GameData")
    if gameData then
        local seedObj = gameData:FindFirstChild("GameSeedInitial")
        if seedObj and seedObj.Value then
            print(seedObj.Value)
            return tonumber(seedObj.Value)
        end
    end

    -- Fallback to JobId seeding
    local jobId = game.JobId
    if not jobId or jobId == "" then 
        jobId = "HARDCORE_TEST_SEED_123"
    end
    
    local seed = 0
    for i = 1, #jobId do
        seed = seed + string.byte(jobId, i)
    end
    return seed
end

local MASTER_SEED = getGameSeed()
print("[Hardcore Mode] Master Seed initialized:", MASTER_SEED)

local safeRoomStreak = 0

_G.CrucifyDepth = false
_G.SurviveDepth = false

-- Track which specific entities are currently running to prevent duplicate spawns
local activeEntities = {
    ["A-120"] = false,
    ["Depth"] = false,
    ["Rebound"] = false,
    ["Blink"] = false,
}

-- Track room numbers when entities complete despawning to enforce cooldowns
local entityLastDespawnRoom = {
    ["A-120"] = -999,
    ["Depth"] = -999,
    ["Rebound"] = -999,
    ["Blink"] = -999,
}

-- Prevents the same room number from running the spawn logic multiple times
local lastProcessedRoom = -1

local GLOBAL_BLACKLIST_ROOMS = {50, 100}

local ENTITY_TABLE = {
    {
        Name = "A-120",     
        Weight = 0.25, 
        MinRoom = 12, 
        MaxRoom = 95, 
        CanSpawnInDark = true,
        CooldownRooms = 2,
        IgnoreHidingSpots = false,
        IgnoreMaxRoom = false,
        OnlyInNoHidingSpotRoom = false,
        BlacklistedEntities = {"Rebound"}
    },
    {
        Name = "Depth",    
        Weight = 1,  
        MinRoom = 5,  
        MaxRoom = 89, 
        CanSpawnInDark = false,
        CooldownRooms = 2,
        IgnoreHidingSpots = false,
        IgnoreMaxRoom = false,
        OnlyInNoHidingSpotRoom = false,
        BlacklistedEntities = {}
    },
    {
        Name = "Rebound",  
        Weight = 0.5,  
        MinRoom = 10, 
        MaxRoom = 94, 
        CanSpawnInDark = true,
        CooldownRooms = 2,
        IgnoreHidingSpots = false,
        IgnoreMaxRoom = false,
        OnlyInNoHidingSpotRoom = false,
        BlacklistedEntities = {"A-120"}
    },
    {
        Name = "Blink",  
        Weight = 1,  
        MinRoom = 7, 
        MaxRoom = 89, 
        CanSpawnInDark = true,
        CooldownRooms = 2,
        IgnoreHidingSpots = false,
        IgnoreMaxRoom = false,
        OnlyInNoHidingSpotRoom = true,
        BlacklistedEntities = {}
    }
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

local function countHidingSpots(roomModel)
    local count = 0
    local assets = roomModel:FindFirstChild("Assets")
    
    if assets then
        for _, child in ipairs(assets:GetChildren()) do
            if child:FindFirstChild("HiddenPlayer") then
                count = count + 1
            end
        end
    end
    
    return count
end

local function isRoomBlacklisted(roomNumber)
    -- Dynamic room-range blacklists (49-55, 99-105, 149-155, etc.)
    local mod = roomNumber % 50
    if mod >= 49 or mod <= 5 then
        return true
    end

    for _, blacklistedRoom in ipairs(GLOBAL_BLACKLIST_ROOMS) do
        if roomNumber == blacklistedRoom then
            return true
        end
    end
    return false
end

local function selectWeightedEntity(availableEntities, rng)
    local totalWeight = 0
    for _, entity in ipairs(availableEntities) do
        totalWeight = totalWeight + entity.Weight
    end

    local randomWeight = rng:NextNumber(0, totalWeight)
    local currentWeight = 0

    for _, entity in ipairs(availableEntities) do
        currentWeight = currentWeight + entity.Weight
        if randomWeight <= currentWeight then
            return entity
        end
    end

    return availableEntities[1]
end

local function registerDespawn(entityName)
    activeEntities[entityName] = false
    local currentRoom = ReplicatedStorage.GameData.LatestRoom.Value
    entityLastDespawnRoom[entityName] = currentRoom
    print(string.format("[Hardcore Mode] %s despawned/unlocked at Room %d. Cooldown active.", entityName, currentRoom))
end

local function spawnEntity(entityName, roomNumber)
    if activeEntities[entityName] or workspace:FindFirstChild(entityName) then 
        warn(entityName .. " is present right now cannot spawn")
        return 
    end

    -- Lock active state immediately
    activeEntities[entityName] = true

    -- 1. Run entity script via loadstring
    task.spawn(function()
        if entityName == "A-120" then
            loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/A-120.lua"))()
        elseif entityName == "Depth" then
            loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Depth.lua"))()
        elseif entityName == "Rebound" then
            loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Rebound.lua"))()
        elseif entityName == "Blink" then
            loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Blink.lua"))()
        end
    end)

    -- 2. Handle Despawns & Lifecycle Tracking
    if entityName == "Rebound" then
        task.spawn(function()
            local isFinalPass = false

            while activeEntities["Rebound"] do
                task.wait(0.1)
                local entityModel = workspace:WaitForChild("Rebound", 10)

                if workspace:FindFirstChild("SeekMovingNewClone") or workspace:FindFirstChild("HonchoRig") then
                    print("Rebound loop break, chasing session")
                    registerDespawn("Rebound")
                    break
                end

                local mod = roomNumber % 50
                if mod >= 49 or mod <= 5 then
                    print("blacklisted room, despawned")
                    registerDespawn("Rebound")
                    break
                end
                    
                if entityModel then
                    local isCrucified = false

                    if entityModel:GetAttribute("LastRebound") == true then
                        isFinalPass = true
                    end

                    local attrConn
                    attrConn = entityModel:GetAttributeChangedSignal("LastRebound"):Connect(function()
                        if entityModel:GetAttribute("LastRebound") == true then
                            isFinalPass = true
                        end
                    end)

                    local crucifyConn
                    crucifyConn = entityModel:GetAttributeChangedSignal("Crucified"):Connect(function()
                        if entityModel:GetAttribute("Crucified") == true then
                            isCrucified = true
                        end
                    end)

                    while entityModel and entityModel.Parent == workspace do
                        if entityModel:GetAttribute("Crucified") == true then
                            isCrucified = true
                            break
                        end
                        task.wait(0.1)
                    end

                    if attrConn then attrConn:Disconnect() end
                    if crucifyConn then crucifyConn:Disconnect() end

                    if isCrucified then
                        print("[Hardcore Mode] Rebound was Crucified! Ending session.")
                        registerDespawn("Rebound")
                        break
                    elseif isFinalPass then
                        print("[Hardcore Mode] Final Rebound pass despawned. Unlocking spawn.")
                        registerDespawn("Rebound")
                        break
                    end
                end
            end
        end)
    else
        -- Standard single-despawn entities (A-120, Depth, Blink)
        task.spawn(function()
            local entityModel = workspace:WaitForChild(entityName, 15)
            
            if entityModel then
                local childRemovedConn
                local attrConn

                local function cleanupAndUnlock()
                    if childRemovedConn then childRemovedConn:Disconnect() end
                    if attrConn then attrConn:Disconnect() end
                    registerDespawn(entityName)
                end

                childRemovedConn = workspace.ChildRemoved:Connect(function(child)
                    if child == entityModel then
                        cleanupAndUnlock()
                    end
                end)

                attrConn = entityModel:GetAttributeChangedSignal("Crucified"):Connect(function()
                    if entityModel:GetAttribute("Crucified") == true then
                        print(string.format("[Hardcore Mode] %s was Crucified! Unlocking spawn.", entityName))
                        cleanupAndUnlock()
                    end
                end)

                if entityModel:GetAttribute("Crucified") == true then
                    cleanupAndUnlock()
                end
            else
                registerDespawn(entityName)
            end
        end)
    end
end

local function handleHardcoreRoom(roomNumber)
    if lastProcessedRoom == roomNumber then return end
    lastProcessedRoom = roomNumber

    -- Check if Seek is currently active in Workspace
    if workspace:FindFirstChild("SeekMovingNewClone") or workspace:FindFirstChild("HonchoRig") then
        print(string.format("[Hardcore Mode] Room %d skipped (Seek chase or Honcho mail room in workspace)", roomNumber))
        safeRoomStreak = safeRoomStreak + 1
        return
    end

    local roomSeed = MASTER_SEED + roomNumber
    print(string.format("[Hardcore Mode] Processing Room %d | Room Seed: %d", roomNumber, roomSeed))

    local rng = Random.new(roomSeed)

    -- item spawner
    loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Crucifix.lua"))()

    if isRoomBlacklisted(roomNumber) then
        print(string.format("[Hardcore Mode] Room %d is blacklisted", roomNumber))
        safeRoomStreak = safeRoomStreak + 1
        return
    end

    local isDarkRoom = false
    local totalHidingSpots = 0

    local currentRoomsFolder = workspace:FindFirstChild("CurrentRooms")
    if currentRoomsFolder then
        local currentRoomModel = currentRoomsFolder:FindFirstChild(tostring(roomNumber))
        if currentRoomModel then
            if currentRoomModel:GetAttribute("IsDark") == true then
                isDarkRoom = true
            end
            
            totalHidingSpots = countHidingSpots(currentRoomModel)
        end
    end

    local playerCount = #Players:GetPlayers()

    local baseSpawnChance = math.clamp(15 + (roomNumber * 0.8), 15, 35)
    local spawnRoll = rng:NextNumber(1, 100)

    if roomNumber > 2 and spawnRoll <= baseSpawnChance then
        local eligibleEntities = {}
        for _, entity in ipairs(ENTITY_TABLE) do
            local minRoomReq = roomNumber >= entity.MinRoom
            
            local bypassMaxRoom = GLOBAL_IGNORE_MAX_ROOMS or entity.IgnoreMaxRoom
            local maxRoomReq = bypassMaxRoom or (not entity.MaxRoom) or (roomNumber <= entity.MaxRoom)
            
            local darkReq = (not isDarkRoom) or entity.CanSpawnInDark
            local notAlreadyActive = not activeEntities[entity.Name]
            
            local blacklistPassed = true
            if entity.BlacklistedEntities then
                for _, blacklistedName in ipairs(entity.BlacklistedEntities) do
                    if activeEntities[blacklistedName] == true or workspace:FindFirstChild(blacklistedName) then
                        blacklistPassed = false
                        break
                    end
                end
            end

            local lastDespawn = entityLastDespawnRoom[entity.Name]
            local cooldownPassed = (roomNumber - lastDespawn) > entity.CooldownRooms

            -- OnlyInNoHidingSpotRoom validation:
            -- If entity requires a no-hiding-spot room, totalHidingSpots must be 0.
            local noHidingSpotReq = true
            if entity.OnlyInNoHidingSpotRoom then
                noHidingSpotReq = (totalHidingSpots == 0)
            end

            -- Hiding spot validation (standard check for entities that require spots):
            local hidingSpotCheckPassed = entity.IgnoreHidingSpots
            if not hidingSpotCheckPassed then
                if playerCount > 1 and floorVal == "Archives" or playerCount > 1 and floorVal == "Rooms" then
                    hidingSpotCheckPassed = (totalHidingSpots >= 1)
                else
                    hidingSpotCheckPassed = (totalHidingSpots >= playerCount)
                end
            end

            if minRoomReq and maxRoomReq and darkReq and notAlreadyActive and blacklistPassed and cooldownPassed and noHidingSpotReq and hidingSpotCheckPassed then
                table.insert(eligibleEntities, entity)
            end
        end

        if #eligibleEntities > 0 then
            safeRoomStreak = 0
            local chosenEntity = selectWeightedEntity(eligibleEntities, rng)

            spawnEntity(chosenEntity.Name, roomNumber)
        else
            safeRoomStreak = safeRoomStreak + 1
        end
    else
        safeRoomStreak = safeRoomStreak + 1
    end
end

local gameData = ReplicatedStorage:WaitForChild("GameData", 10)

if gameData and gameData:FindFirstChild("LatestRoom") then
    local latestRoom = gameData.LatestRoom
    
    Main_Game.caption("The Hardcore Mode script is now running, Have fun LOL STILL IN BETA TESTING", true, 3)
    
    latestRoom.Changed:Connect(function(newRoomNumber)
        task.wait(0.15)
        handleHardcoreRoom(newRoomNumber)
    end)

    if latestRoom.Value > 0 then
        handleHardcoreRoom(latestRoom.Value)
    end
end
