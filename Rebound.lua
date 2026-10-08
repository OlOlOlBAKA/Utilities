local ReSt = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
-- CREDIT TO REGULAR VYNIXU

loadstring(game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua"))()

local Main_Game = require(game.Players.LocalPlayer.PlayerGui.MainUI.Initiator.Main_Game)
local CamShaker = require(ReSt:WaitForChild("CameraShaker")

local ROOT = "https://github.com/RegularVynixu/DOORS-Entity-Spawner-V2/raw/main"

local function Shake()
    local Earthquake = LoadCustomInstance(ROOT.."/Assets/Earthquake.rbxm")
Earthquake.Parent = workspace
Earthquake.SoundEarthquake.Volume = 1.55
Earthquake.SoundEarthquake:Play()
local v5 = CollectionService:GetTagged("PartCeiling")
local v6 = {}
for _, v7 in v5 do
    local v8 = v7.Size.Magnitude * 0.7
    local v9 = math.clamp(v8, 0, 150)
    for _, v10 in pairs(Earthquake.Particles:GetChildren()) do
        local v11 = v10:Clone()
        v11.Parent = v7
        v11:Emit(v9 / 10)
        v11.Enabled = true
        table.insert(v6, v11)
    end
end
task.delay(4, function()
    for _, v12 in v6 do
        v12.Enabled = false
    end
end)
task.delay(6, function()
    Earthquake:Destroy()
end)
end

local isCrucified = false
local isPresent = false

task.wait(1)
local PathfindingMovement = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Room_Path_Find.lua"))()

local entityConfig = {
    Model = game:GetObjects("rbxassetid://77366392445371")[1],
    Speed = 60,
    HeightOffset = 5,
    FloorYOffset = -2,
    DelayTime = 4,
    SpawnOffsetRooms = 5,
    AttackType = "Front",

    HitboxRange = 50,
    RaycastHitbox = true,
    SphereRadius = 4,
    Damage = 100,

    LightFlicker = false,
    Duration = 1.5,
    LightBreak = false,

    Rebound = false,
    ReboundCount = 2,
    ReboundTime = 1.5,
    ReboundDelayTime = 1.0,

    EnableCameraShake = true,
    ShakeAmount = 5,
    ShakeRadius = 100,

    ShowPath = false,

    Callbacks = {
        OnSpawned = function(model, actions)
            isPresent = true
            Shake()
            CamShaker:ShakeOnce(15, 2, 3, 3)
            local ReboundColor = Instance.new("ColorCorrectionEffect", game.Lighting)
            game:GetService("Debris"):AddItem(ReboundColor, 24)
            ReboundColor.Name = "Warn"
            ReboundColor.TintColor = Color3.fromRGB(65, 138, 255)
            ReboundColor.Saturation = -0.7
            ReboundColor.Contrast = 0.2
            TS:Create(ReboundColor, TweenInfo.new(15), {TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0}):Play()

            task.spawn(function()
                task.wait(15)
                if ReboundColor then ReboundColor:Destroy() end
            end)
            model.Rebound_Cue2.Volume = 0.5
            model.Rebound_Cue:Play()
            model.Rebound_Cue2:Play()
            model.ReboundNew.Close.Volume = 0.75
            model.ReboundNew.Idle.Volume = 0.75
            model.ReboundNew.Sound.Volume = 4

            task.wait(3.5)
            model.Rebound_Cue.TimePosition = 0
            model.Rebound_Cue:Play()
        end,

        OnStartMoving = function(model, actions)
            for _, v in pairs(model.ReboundNew:GetChildren()) do
                if v:IsA("Sound") then
                    v:Play()
                end
            end
        end,

        OnStartRebounding = function(model, reboundCount, actions) end,
        OnEnterRoom = function(model, roomFolder, actions) end,
        OnEnterPlayerRoom = function(model, roomFolder, playerCharacter, actions) end,
        OnSeePlayer = function(model, playerCharacter, actions) end,
        OnKillPlayer = function(model, playerCharacter, actions) end,

        OnCrucifixion = function(model: Model | BasePart, actions)
            isCrucified = true
            isPresent = false
            model:SetAttribute("Crucified", true)
        end,

        OnDespawn = function(model, actions)
            isPresent = false
        end
    }
}

-- Initial Spawn
task.spawn(function()
    PathfindingMovement.MoveThroughRooms(entityConfig)
end)

-- Handle the 3 room progression rebounds
task.spawn(function()
    local reboundsLeft = 3
    local latestRoom = ReSt.GameData.LatestRoom

    while reboundsLeft > 0 do
        if isCrucified then
            print("Rebound got crucified, the spawn loop is ended")
            break
        end
        if latestRoom.Value == 49 or latestRoom.Value == 50 or latestRoom.Value == 99 or latestRoom.Value == 100 then
            print("break the loop, boss room")
            break
        end

        latestRoom.Changed:Wait()

        if isCrucified then
            print("Rebound got crucified during room wait, ending loop")
            break
        end

        if latestRoom.Value == 49 or latestRoom.Value == 50 or latestRoom.Value == 99 or latestRoom.Value == 100 then
            print("break the loop, boss room")
            break
        end

        if not isPresent then
            reboundsLeft = reboundsLeft - 1
            task.wait(2.5)

            local entityConfig2 = {
                Model = game:GetObjects("rbxassetid://77366392445371")[1],
                Speed = 60,
                HeightOffset = 5,
                FloorYOffset = -2,
                DelayTime = 0.75,
                SpawnOffsetRooms = 5,
                AttackType = "Front",

                HitboxRange = 50,
                RaycastHitbox = true,
                SphereRadius = 4,
                Damage = 100,

                LightFlicker = false,
                Duration = 1.5,
                LightBreak = false,

                Rebound = false,
                ReboundCount = 2,
                ReboundTime = 1.5,
                ReboundDelayTime = 1.0,

                EnableCameraShake = true,
                ShakeAmount = 5,
                ShakeRadius = 100,

                ShowPath = false,

                Callbacks = {
                    OnSpawned = function(model, actions)
                        isPresent = true
                        model.ReboundNew.Close.Volume = 0.75
                        model.ReboundNew.Idle.Volume = 0.75
                        model.ReboundNew.Sound.Volume = 4
                        model.Rebound_Cue.TimePosition = 0
                        model.Rebound_Cue:Play()
                    end,

                    OnStartMoving = function(model, actions)
                        for _, v in pairs(model.ReboundNew:GetChildren()) do
                            if v:IsA("Sound") then
                                v:Play()
                            end
                        end
                    end,

                    OnStartRebounding = function(model, reboundCount, actions) end,
                    OnEnterRoom = function(model, roomFolder, actions) end,
                    OnEnterPlayerRoom = function(model, roomFolder, playerCharacter, actions) end,
                    OnSeePlayer = function(model, playerCharacter, actions) end,
                    OnKillPlayer = function(model, playerCharacter, actions) end,

                    OnCrucifixion = function(model: Model | BasePart, actions)
                        isCrucified = true
                        isPresent = false
                        model:SetAttribute("Crucified", true)
                    end,

                    OnDespawn = function(model, actions)
                        isPresent = false
                    end
                }
            }

            PathfindingMovement.MoveThroughRooms(entityConfig2)
        else
            print("Another Rebound is present, will try next door")
        end
    end
end)
