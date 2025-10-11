-- Cleaned-up version of the decompiled Luau script for better readability.
-- This script handles the intro sequence, camera effects, and game state for a Roblox game, likely related to a horror or narrative-driven experience.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local TweenModule = require(ReplicatedStorage:WaitForChild("SmartTweenModule"))
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local Parent = script.Parent
local IntroText = Parent:WaitForChild("IntroText")
local IntroCover = Parent:WaitForChild("IntroCover")
local ToggleRemote = LocalPlayer.PlayerGui:WaitForChild("CameraModalGUI"):WaitForChild("ToggleHelper"):WaitForChild("ToggleRemote")
local Master = SoundService:WaitForChild("Master")
local GameSounds = Master:WaitForChild("GameSounds")
local WorldMusic = Master:WaitForChild("MusicChannels"):WaitForChild("WorldMusic")
local MainMusic = Master:WaitForChild("MusicChannels"):WaitForChild("MainMusic")
local GhostLighting = Lighting:WaitForChild("GhostLighting")

-- Check if the player is on a touch-enabled device (mobile).
local TouchEnabled = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Initialize audio settings if the player can enter the game.
local CanEnterGame = LocalPlayer:GetAttribute("CanEnterGame") or false
if CanEnterGame then
    GhostLighting.Enabled = false
    MainMusic.Volume = MainMusic:GetAttribute("IntendedVolume") or 1
    WorldMusic.Volume = WorldMusic:GetAttribute("IntendedVolume") or 1
    GameSounds.Volume = GameSounds:GetAttribute("IntendedVolume") or 1
    GameSounds:WaitForChild("DeathMuffle").Enabled = false
    GameSounds:WaitForChild("DeathReverb").Enabled = false
    WorldMusic:WaitForChild("DeathMuffle").Enabled = false
    WorldMusic:WaitForChild("DeathReverb").Enabled = false
end

-- Function to display text character by character with optional sound effects.
local function AddText(text, playSound)
    local currentText = ""
    local skip = false
    local inputConnection

    -- Handle input to skip text animation.
    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA or input.UserInputType == Enum.UserInputType.Touch then
            inputConnection:Disconnect()
            skip = true
        end
    end)

    -- Disable text scaling initially.
    if IntroText.TextScaled then
        IntroText.TextScaled = false
    end

    -- Display text character by character.
    for i = 1, string.len(text) do
        IntroText.Text = currentText .. string.sub(text, 1, i)
        if playSound then
            coroutine.wrap(function()
                local sound = Instance.new("Sound")
                sound.SoundId = "rbxassetid://156286438"
                sound.PlaybackSpeed = math.random(85, 111) / 100
                sound.Volume = 0.222
                sound.Parent = script
                sound:Play()
                sound.Ended:Wait()
                sound:Destroy()
            end)()
        end
        if not IntroText.TextFits then
            IntroText.TextScaled = true
        end
        if not skip or i % 20 == 0 then
            wait()
        end
    end

    pcall(function()
        inputConnection:Disconnect()
    end)
    currentText = currentText .. text
    return currentText
end

-- Function to display text and wait for user input to proceed.
local function TextFunctionCall(text, playSound)
    local currentText = AddText(text, playSound)
    IntroText.Text = currentText .. " ↓"
    local proceed = false
    local inputConnection

    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if (input.KeyCode == Enum.KeyCode.Return and not gameProcessed) or input.KeyCode == Enum.KeyCode.ButtonA or input.UserInputType == Enum.UserInputType.Touch then
            if UserInputService:GetFocusedTextBox() == nil then
                inputConnection:Disconnect()
                proceed = true
            end
        end
    end)

    repeat
        wait()
    until proceed
    IntroText.Text = currentText
    return currentText
end

-- Function to find a jumpscare GUI in the parent.
local function FindEntityJumpscareGUI()
    for _ = 1, 10 do
        for _, child in pairs(Parent:GetChildren()) do
            if string.find(string.lower(tostring(child)), "jumpscare") and child:IsA("Frame") then
                return child
            end
        end
        wait(0.1)
    end
    return nil
end

-- Function to toggle admin interference UI visibility.
local function OnAdminInterferenceToggled(value)
    Parent:WaitForChild("CamFrame"):WaitForChild("Frame"):WaitForChild("AdminInterference").Visible = value
end

-- Function to toggle camera power effects.
local function ToggleCameraPower(enabled)
    OnAdminInterferenceToggled(ReplicatedStorage:WaitForChild("AdminInterference").Value)
    if enabled then
        script:WaitForChild("Use"):Play()
        script:WaitForChild("Idle"):Play()
        IntroCover.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TweenModule:Tween(IntroCover, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1
        })
    else
        script:WaitForChild("Idle"):Stop()
        script:WaitForChild("Disable"):Play()
        IntroCover.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        IntroCover.BackgroundTransparency = 0
    end
end

-- Randomize static effect position periodically.
local staticTimer = 0
local staticConnection = RunService.RenderStepped:Connect(function(deltaTime)
    staticTimer = staticTimer + deltaTime
    if staticTimer >= 0.2 then
        staticTimer = 0
        Parent.Static1.Position = UDim2.fromScale(math.random(0, 100) / 100, math.random(0, 100) / 100)
    end
end)

-- Hide static effect if camcorder is disabled.
if LocalPlayer:WaitForChild("RFFClientSettings"):GetAttribute("DisableCamcorder") then
    Parent:WaitForChild("Static1").ImageTransparency = 1
end

-- Initialize UI visibility.
IntroCover.Visible = true
IntroText.Visible = true
Parent.Enabled = true

-- Show developer branch notification for specific place ID.
local CamFrame = Parent.CamFrame.Frame
CamFrame.DevBranchNotif.Visible = game.PlaceId == 124800589535312

-- Display initial control instructions based on input device.
local currentText = ""
if TouchEnabled then
    currentText = TextFunctionCall(
        "On mobile platforms, character movement controls can be changed in the Roblox settings menu. Pick whichever style you're most comfortable with.\n\n" ..
        "MOBILE CONTROLS:\n" ..
        "Tap anywhere on the screen to use items/tools in your hand.\n" ..
        "Tap on objects to interact with them.\n" ..
        "With a flashlight equipped, tap the battery icon to replace batteries.\n" ..
        "Tap the run button to toggle between sprinting/walking.\n" ..
        "To advance or speed up text, tap anywhere on the screen.\n\n" ..
        "Advance text to begin"
    )
else
    currentText = TextFunctionCall(
        "PC CONTROLS:\n" ..
        "Use WASD to move around by default.\n" ..
        "Use the mouse to look around and use items/tools.\n" ..
        "Character movement controls can be further changed in the Roblox settings menu.\n\n" ..
        "E = Interact\n" ..
        "R = Replace Flashlight Batteries\n" ..
        "I = Open Inventory\n" ..
        "V = Lock/Unlock Mouse\n" ..
        "L.SHIFT = Sprint\n" ..
        "Enter = Advance/Speed Up Text\n\n" ..
        "Advance text to begin"
    )
end

-- Display intro narrative.
currentText = ""
TextFunctionCall(
    "The following footage was recovered by the Federal Bureau of Investigation from an office building within [REDACTED], United States during a police investigation of the property prompted by reports of several disappearances in the area."
)
currentText = ""

-- Display player-specific intro text based on input device.
if TouchEnabled then
    TextFunctionCall("\n\nSUBJECT: " .. LocalPlayer.DisplayName .. "\nBACKGROUND: Unknown\nSTATUS: To be determined\n\n[ Tap anywhere to play recording ]")
elseif UserInputService.GamepadEnabled then
    TextFunctionCall("\n\nSUBJECT: " .. LocalPlayer.DisplayName .. "\nBACKGROUND: Unknown\nSTATUS: To be determined\n\n[ Press A/B to play recording ]")
else
    TextFunctionCall("\n\nSUBJECT: " .. LocalPlayer.DisplayName .. "\nBACKGROUND: Unknown\nSTATUS: To be determined\n\n[ Press ENTER to play recording ]")
end

-- Reset text and hide intro UI.
currentText = ""
IntroText.Text = ""
IntroText.Visible = false

-- Ensure player's character and humanoid are loaded.
if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end
local Humanoid = LocalPlayer.Character:WaitForChild("Humanoid")
if CurrentCamera.CameraSubject ~= Humanoid then
    CurrentCamera.CameraSubject = Humanoid
end

-- Request game start from server.
if not CanEnterGame then
    ReplicatedStorage:WaitForChild("GameStartRemotes"):WaitForChild("RequestStartGame"):InvokeServer(1)
else
    ReplicatedStorage:WaitForChild("GameStartRemotes"):WaitForChild("RequestStartGame"):InvokeServer(2)
end

-- Enable camera and disable most core GUI elements.
ToggleRemote:Invoke(true)
ToggleCameraPower(true)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)

-- Handle player death.
local deathConnection
deathConnection = Humanoid.Died:Connect(function()
    deathConnection:Disconnect()
    local jumpscareGUI = FindEntityJumpscareGUI()
    LocalPlayer:SetAttribute("SuppressActionDeathMessage", true)
    script.Idle:Pause()

    -- Wait for jumpscare to finish.
    while jumpscareGUI and jumpscareGUI.Visible do
        wait()
    end
    script.Idle:Resume()
    LocalPlayer:SetAttribute("SuppressActionDeathMessage", false)

    -- Trigger death effects.
    coroutine.wrap(function()
        ToggleRemote:Invoke(false)
    end)()
    MainMusic.Volume = 0
    WorldMusic.Volume = 0
    GameSounds.Volume = 0
    GameSounds:WaitForChild("DeathMuffle").Enabled = true
    GameSounds:WaitForChild("DeathReverb").Enabled = true
    WorldMusic:WaitForChild("DeathMuffle").Enabled = true
    WorldMusic:WaitForChild("DeathReverb").Enabled = true
    script.Death:Play()
    Parent.CamFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    Parent.CamFrame.BackgroundTransparency = 0
    TweenModule:Tween(Parent.CamFrame, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        BackgroundColor3 = Color3.fromRGB(85, 0, 0)
    })
    TweenModule:Tween(Parent.Static1, TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
        ImageTransparency = 0
    })
    TweenModule:Tween(script.Idle, TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
        Volume = 5
    })
    wait(7)
    ToggleCameraPower(false)
    staticConnection:Disconnect()
    wait(2)

    -- Display death screen and narrative.
    local success = LocalPlayer.PlayerGui:WaitForChild("DeathScreen"):WaitForChild("Display"):Invoke()
    IntroText.Visible = true
    if not success then
        TextFunctionCall("SUBJECT: " .. LocalPlayer.DisplayName .. "\nSTATUS: Unknown\n\nAutopsy of the subject reveals the cause of death to be total and sudden failure of the circulatory and nervous systems by unknown means.")
        TextFunctionCall(" Attempted inspection of video footage has not yielded conclusive results. It has, however, revealed the subject was attacked by unknown entities residing within the building.")
        TextFunctionCall(" The building has been quarantined and designated as the \"Rooms Anomaly\" by the federal government. A further investigation is pending approval.")
    end
end)

-- Handle game end event.
local gameEnded = false
ReplicatedStorage:WaitForChild("GameEndRemotes"):WaitForChild("EndGame").OnClientInvoke = function(ending)
    if gameEnded then
        return false
    end
    gameEnded = true
    ending = ending or 1

    coroutine.resume(coroutine.create(function()
        deathConnection:Disconnect()
        script.Idle:Stop()
        script.Disable:Play()
        staticConnection:Disconnect()
        IntroCover.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        IntroCover.BackgroundTransparency = 0
        wait(2)
        IntroText.Visible = true

        if ending == 1 then
            TextFunctionCall("SUBJECT: " .. LocalPlayer.DisplayName .. "\nSTATUS: Unknown\n\nRecovered video footage ended after the subject reached an exit from the Rooms Anomaly at location A-1000.")
            TextFunctionCall(" All attempts to locate the owner of the footage have failed so far. A reward for information regarding the suspect has been offered to the public, with no results in the last " .. LocalPlayer.AccountAge .. " days.")
            TextFunctionCall(" Unlike most recovered video tapes from the Rooms Anomaly, this tape appears to have golden trimmings. The significance of this is unknown.")
            TextFunctionCall("\n\nAdditional Note: It appears the tape holding the footage exceeds the storage capacity of a conventional VHS tape by a length of ██ hours. How this is possible is unknown. Further investigation is currently pending approval.")
            if TouchEnabled then
                currentText = ""
                TextFunctionCall("\n\n[ END RECORDING ]\nEnding 1 of 5\nTap anywhere to return to the lobby.")
            else
                TextFunctionCall("\n\n[ END RECORDING ]\nEnding 1 of 5\nPress ENTER to return to the lobby.")
            end
        else
            TextFunctionCall("Unknown ending received. This may be a mistake or the result of a script error.")
            if TouchEnabled then
                currentText = ""
                TextFunctionCall("\n\n[ END RECORDING ]\nEnding ?? of 5\nTap anywhere to return to the lobby.")
            else
                TextFunctionCall("\n\n[ END RECORDING ]\nEnding ?? of 5\nPress ENTER to return to the lobby.")
            end
        end
        TeleportService:Teleport(13757888451, LocalPlayer)
        LocalPlayer:Kick("You won the game! (Ending " .. tostring(ending) .. " of 5) Returning to lobby...")
    end))
    return true
end

-- Connect admin interference toggle.
ReplicatedStorage:WaitForChild("AdminInterference").Changed:Connect(OnAdminInterferenceToggled)
