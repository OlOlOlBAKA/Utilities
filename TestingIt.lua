local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StationaryEntity = loadstring(game:HttpGet("https://raw.githubusercontent.com/OlOlOlBAKA/Utilities/refs/heads/main/Stationary_Entity.lua"))()

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer.PlayerGui
local mainUI = playerGui:WaitForChild("MainUI")
local initiator = mainUI:WaitForChild("Initiator")
local Main_Game = require(initiator:WaitForChild("Main_Game"))

local character = localPlayer.Character

local currentRooms = workspace:WaitForChild("CurrentRooms")
local GameData = ReplicatedStorage:WaitForChild("GameData")
local LatestRoom = GameData:WaitForChild("LatestRoom")

local spawnRoom = currentRooms:WaitForChild(tostring(LatestRoom.Value))

local function isInSightAndMoving(origin: Vector3, maxDistance: number, ignoreList: {Instance}?): boolean
	maxDistance = maxDistance or 80
	ignoreList = ignoreList or {}

	local character = localPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	if humanoid.MoveDirection.Magnitude <= 0 then return false end

	local hrp = character.HumanoidRootPart
	if (hrp.Position - origin).Magnitude > maxDistance + 10 then
		return false
	end

	for _, partName in ipairs({"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerLeg", "RightLowerLeg"}) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local direction = part.Position - origin
			local distance = direction.Magnitude

			if distance <= maxDistance then
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude

				local filter = {character}
				for _, ignored in ipairs(ignoreList) do
					table.insert(filter, ignored)
				end
				raycastParams.FilterDescendantsInstances = filter

				local rayResult = Workspace:Raycast(origin, direction.Unit * distance, raycastParams)
				if not rayResult or rayResult.Instance:IsDescendantOf(character) then
					return true
				end
			end
		end
	end

	return false
end

local function setState(model: Model, openEye: boolean)
	local part = model:FindFirstChild("Main")
	if not part then return end
	if openEye == true then
		part.Blink:Play()
		part.BlinkForeshadow:Play()
		task.wait(0.2)
		part.Attachment.Open.Enabled = true
		task.wait(0.2)
		part.Attachment.Closed.Enabled = false
		task.wait(0.1)
		canKill = true
	else
		part.Blink:Play()
		part.BlinkForeshadow:Play()
		task.wait(0.2)
		part.Attachment.Closed.Enabled = true
		task.wait(0.2)
		part.Attachment.Open.Enabled = false
		task.wait(0.1)
		canKill = false
	end
end

local r = Random.new()

local entityConfig = {
	spawnOffset = Vector3.new(0, 6, 0),
	crucifixRange = 85,
	canBeCrucified = false,
	shakerInstance = Main_Game.camShaker,

	callbacks = {
		OnSpawned = function(entity: Model, room: Model, handle: table)
			-- handle.Destroy()                      -> Instantly destroys the entity and stops its loop.
			-- handle.GetEntity()                    -> Returns the spawned entity model instance.
			-- handle.GetRoom()                      -> Returns the room model instance.
			-- handle.SetCanBeCrucified(bool)        -> Dynamically toggle crucifix immunity.
			-- handle.GetCanBeCrucified() -> boolean -> Check current crucifix vulnerability.
			local model = handle.GetEntity()
			model.Main.Attachment.Closed.Rate = 80
			model.Main.Attachment.Open.Rate = 80
			model.Main.Attachment.Sparkles.Enabled = true
			task.wait(1)
			model.Main.Spawn:Play()
			model.Main.Attachment.Closed.Enabled = true
			task.spawn(function()
				while model and model.Parent do
					task.wait(
				end
			end)
			task.spawn(function()
				while model and model.Parent do
					task.wait(0.5)
					local char = localPlayer.Character
					local humanoid = char:FindFirstChild("Humanoid")
					if humanoid.Health > 0 and canKill then
					    if isInSightAndMoving(model:GetPivot().Position, 80, {model}) the
							humanoid.Health = 0
					    end
					end
				end
			end)
			LatestRoom.Changed:Wait()
			handle.Destroy()
		end,

		OnCrucifixion = function(entity: Model, character: Model, handle: table)
		end
	}
}

StationaryEntity.spawn(LoadCustomInstance("https://github.com/OlOlOlBAKA/Utilities/raw/main/LatestBlink.rbxm"), spawnRoom, entityConfig)
