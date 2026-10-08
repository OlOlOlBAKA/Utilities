--!nocheck
-- CREDIT AND INSPIRED BY REGULAR VYNIXU
-- \\ Safe Global Function Loading // --
local httpSuccess, rawCode = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua")
end)

if httpSuccess and rawCode then
	local loadedFunc, err = loadstring(rawCode)
	if type(loadedFunc) == "function" then
		pcall(loadedFunc)
	else
		warn("PathfindingMovement: Failed to compile HTTP code ->", err)
	end
else
	warn("PathfindingMovement: Failed to fetch HTTP functions ->", rawCode)
end

local PathfindingMovement = {}
PathfindingMovement.__index = PathfindingMovement

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- Module Requirements
local LocalPlayer = Players.LocalPlayer
local CameraShaker = nil

task.spawn(function()
	local csModule = ReplicatedStorage:WaitForChild("CameraShaker", 5)
	if csModule then
		local success, result = pcall(require, csModule)
		if success then
			CameraShaker = result
		else
			warn("PathfindingMovement: Failed to require CameraShaker ->", result)
		end
	end
end)

-- Safe Module_Events Integration
local Module_Events = nil
task.spawn(function()
	local modulesClient = ReplicatedStorage:WaitForChild("ModulesClient", 5)
	if modulesClient then
		local moduleEventsScript = modulesClient:WaitForChild("Module_Events", 5)
		if moduleEventsScript then
			local success, result = pcall(require, moduleEventsScript)
			if success then
				Module_Events = result
			else
				warn("PathfindingMovement: Failed to load Module_Events ->", result)
			end
		end
	end
end)

-- Replace CameraShaker require block with Main_Game require
local Main_Game = nil

task.spawn(function()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui", 5)
	if playerGui then
		local mainUI = playerGui:WaitForChild("MainUI", 5)
		if mainUI then
			local initiator = mainUI:WaitForChild("Initiator", 5)
			if initiator then
				local mainGameScript = initiator:WaitForChild("Main_Game", 5)
				if mainGameScript then
					local success, result = pcall(require, mainGameScript)
					if success then
						Main_Game = result
					else
						warn("PathfindingMovement: Failed to load Main_Game ->", result)
					end
				end
			end
		end
	end
end)


-- \\ Crucifixion Assets & Storage // --
local ROOT = "https://github.com/RegularVynixu/DOORS-Entity-Spawner-V2/raw/main"
local CrucifixAssets = {
	Repentance = nil
}

-- Spawned in background so failure here NEVER crashes module load
task.spawn(function()
	local fetchFunc = (typeof(getgenv) == "function" and getgenv().LoadCustomInstance) or _G.LoadCustomInstance or LoadCustomInstance
	if typeof(fetchFunc) == "function" then
		pcall(function()
			CrucifixAssets.Repentance = fetchFunc(ROOT .. "/Assets/Repentance.rbxm")
		end)
	end
end)

local CrucifixStorage = {
	CrucifixTypes = {
		["guiding"] = { Color = Color3.fromRGB(137, 207, 255) },
		["curious"] = { Color = Color3.fromRGB(255, 227, 137) }
	}
}

type MoveToConfig = {
	Speed: number?,
	ReachDistance: number?,
	HeightOffset: number?
}

type ActionsHandle = {
	Stop: () -> (),
	Resume: (resumeType: number?) -> (),
	SkipRoom: () -> (),
	SetSpeed: (newSpeed: number) -> (),
	MoveTo: (target: Vector3 | BasePart | Model, config: MoveToConfig?) -> (),
	Rebound: (roomOffset: number?, delayBefore: number?, delayAfter: number?) -> (),
	
	LightFlicker: (room: Instance | number, duration: number?, amount: number?) -> (),
	LightBreak: (room: Instance | number, amount: number?, speed: number?) -> (),
	ToggleLight: (room: Instance | number, state: boolean, ambientColor: Color3?) -> ()
}

type EventCallbacks = {
	OnSpawned: ((model: Model | BasePart, actions: ActionsHandle) -> ())?,
	OnStartMoving: ((model: Model | BasePart, actions: ActionsHandle) -> ())?,
	OnStartRebounding: ((model: Model | BasePart, reboundCount: number, actions: ActionsHandle) -> ())?,
	OnEnterRoom: ((model: Model | BasePart, roomFolder: Instance, actions: ActionsHandle) -> ())?,
	OnEnterPlayerRoom: ((model: Model | BasePart, roomFolder: Instance, playerCharacter: Model, actions: ActionsHandle) -> ())?,
	OnSeePlayer: ((model: Model | BasePart, playerCharacter: Model, actions: ActionsHandle) -> ())?,
	OnKillPlayer: ((model: Model | BasePart, playerCharacter: Model, actions: ActionsHandle) -> ())?,
	OnCrucifixion: ((model: Model | BasePart, actions: ActionsHandle) -> ())?,
	OnDespawn: ((model: Model | BasePart, actions: ActionsHandle) -> ())?
}

type MovementOptions = {
	Model: Model | BasePart,
	Speed: number?,
	HeightOffset: number?,
	FloorYOffset: number?,
	DelayTime: number?,
	SpawnOffsetRooms: number?,
	AttackType: ("Back" | "Front")?,
	
	HitboxRange: number?,
	RaycastHitbox: boolean?,
	SphereRadius: number?,
	Damage: number?,

	LightFlicker: boolean?,
	Duration: number?,
	LightBreak: boolean?,

	Callbacks: EventCallbacks?,
	ShowPath: boolean?,

	Rebound: boolean?,
	ReboundCount: number?,
	ReboundTime: number?,
	ReboundDelayTime: number?,

	EnableCameraShake: boolean?,
	ShakeValues: {number}?,
	ShakeRadius: number?
}

local function triggerLightFlicker(room: Instance | number, duration: number?, lightAmount: number?)
	if type(Module_Events) == "table" and type(Module_Events.flicker) == "function" then
		Module_Events.flicker(room, duration or 1, lightAmount or 100)
	end
end

local function triggerLightBreak(room: Instance | number, lightAmount: number?, breakSpeed: number?)
	if type(Module_Events) == "table" and type(Module_Events.shatter) == "function" then
		Module_Events.shatter(room, lightAmount or 100, breakSpeed or 60)
	end
end

local function triggerToggleLight(room: Instance | number, state: boolean, ambientColor: Color3?)
	local ambient = ambientColor or (state and Color3.fromRGB(67, 51, 56) or Color3.fromRGB(0, 0, 0))
	if type(Module_Events) == "table" and type(Module_Events.toggle) == "function" then
		Module_Events.toggle(room, state, ambient)
	end
end

local function disableCollision(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CanCollide = false
	end
	for _, child in ipairs(instance:GetDescendants()) do
		if child:IsA("BasePart") then
			child.CanCollide = false
		end
	end
end

local function stopEntitySounds(instance: Instance)
	if not instance then return end
	if instance:IsA("Sound") then
		instance:Stop()
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Sound") then
			descendant:Stop()
		end
	end
end

local function checkForEquippedCrucifix(character: Model): (boolean, Tool?)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local toolName = string.lower(child.Name)
			local isCrucifix = string.find(toolName, "crucifix") ~= nil 
				or child:GetAttribute("IsCrucifix") == true
				or CollectionService:HasTag(child, "Crucifix")
				or child:FindFirstChild("Crucifix") ~= nil
				
			if isCrucifix then
				return true, child
			end
		end
	end
	return false, nil
end

local function performCrucifixion(
	entityModel: Instance, 
	character: Model, 
	shakerInstance: any
)
	if not CrucifixAssets.Repentance then return false end

	local entityPivot = entityModel:IsA("Model") and entityModel:GetPivot() or entityModel.CFrame
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, entityModel }

	local rayResult = Workspace:Raycast(entityPivot.Position, Vector3.new(0, -1000, 0), rayParams)
	if not rayResult then return false end

	local repentance = CrucifixAssets.Repentance:Clone()
	local crucifix = repentance.Crucifix
	local handle = crucifix.Handle
	local pentagram = repentance.Pentagram
	local entityPart = repentance.Entity
	local sound = handle.Sound

	repentance:PivotTo(CFrame.new(rayResult.Position))
	crucifix:PivotTo(character:GetPivot())
	entityPart.CFrame = entityPivot
	repentance.Parent = Workspace
	sound:Play()

	local theShake = nil
	if shakerInstance and typeof(shakerInstance.StartShake) == "function" then
		theShake = shakerInstance:StartShake(5, 20, 2, Vector3.zero)
	end

	local function waitUntil(t: number)
		repeat RunService.RenderStepped:Wait() until sound.TimePosition >= t
	end

	local function fadeOut()
		for _, v in ipairs(pentagram:GetChildren()) do
			if v.Name == "BeamFlat" then
				task.delay(v:GetAttribute("Delay") or 0, function()
					TweenService:Create(v, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Brightness = 0 }):Play()
				end)
			elseif v.Name == "BeamChain" then
				TweenService:Create(v, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Brightness = 0 }):Play()
			end
		end
	end

	local typeData = CrucifixStorage.CrucifixTypes["guiding"]
	local color = typeData.Color

	for _, v in ipairs(repentance:GetDescendants()) do
		if v:HasTag("GiveMeColor") or v.Name == "GiveMeColor" then
			if v:IsA("Light") or v:IsA("BasePart") then
				v.Color = color
			elseif v:IsA("ParticleEmitter") or v:IsA("Beam") then
				v.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, color),
					ColorSequenceKeypoint.new(1, color)
				})
			end
		end
	end

	task.spawn(function()
		while entityPart.Parent and entityModel and entityModel.Parent do
			if entityModel:IsA("Model") then
				entityModel:PivotTo(entityPart.CFrame)
			else
				entityModel.CFrame = entityPart.CFrame
			end
			RunService.RenderStepped:Wait()
		end
		if entityModel and entityModel.Parent then
			entityModel:Destroy()
		end
	end)

	TweenService:Create(pentagram.Circle, TweenInfo.new(2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { CFrame = pentagram.Circle.CFrame - Vector3.new(0, 25, 0) }):Play()
	task.delay(2, pentagram.Circle.Destroy, pentagram.Circle)

	handle.BodyPosition.Position = (character:GetPivot() * CFrame.new(1, 4, -6)).Position
	TweenService:Create(handle.BodyAngularVelocity, TweenInfo.new(4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), { AngularVelocity = Vector3.new(0, 40, 0) }):Play()

	task.delay(3, function()
		for _, shard in ipairs(handle.Shards:GetChildren()) do
			shard.CollisionGroup = "NoPlayer"
			shard.CanCollide = true
			if shard:FindFirstChild("Weld") then shard.Weld:Destroy() end
			shard.AssemblyAngularVelocity = Vector3.zero
		end
	end)

	TweenService:Create(entityPart, TweenInfo.new(3, Enum.EasingStyle.Elastic, Enum.EasingDirection.In), { CFrame = entityPart.CFrame + Vector3.new(0, 2, 0) }):Play()

	task.spawn(function()
		waitUntil(2.625)
		TweenService:Create(pentagram.Base.LightAttach.LightBright, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 5, Range = 40 }):Play()
		TweenService:Create(handle.Light, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 11.25, Range = 30 }):Play()

		task.wait(1.5)
		TweenService:Create(pentagram.Base.LightAttach.LightBright, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 0, Range = 0 }):Play()
		TweenService:Create(handle.Light, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 0, Range = 0 }):Play()

		TweenService:Create(handle.Light, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 15, Range = 40 }):Play()
		if theShake and typeof(theShake.StartFadeOut) == "function" then theShake:StartFadeOut(3) end
		fadeOut()
		TweenService:Create(handle.BodyAngularVelocity, TweenInfo.new(3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { AngularVelocity = Vector3.zero }):Play()
	end)

	waitUntil(2.5)
	TweenService:Create(entityPart, TweenInfo.new(3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { CFrame = entityPart.CFrame - Vector3.new(0, 50, 0) }):Play()

	local soundTargets = entityModel:GetDescendants()
	if entityModel:IsA("Sound") then table.insert(soundTargets, entityModel) end

	for _, s in ipairs(soundTargets) do
		if s:IsA("Sound") and not s:GetAttribute("VolumeIgnore") then
			TweenService:Create(s, TweenInfo.new(3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Volume = 0 }):Play()
		end
	end

	waitUntil(6.75)

	TweenService:Create(handle.Glow, TweenInfo.new(1), { Size = handle.Glow.Size * 3, Transparency = 1 }):Play()
	TweenService:Create(pentagram.Base.LightAttach.LightBright, TweenInfo.new(1), { Brightness = 0, Range = 0 }):Play()
	TweenService:Create(handle.Light, TweenInfo.new(1), { Brightness = 0, Range = 0 }):Play()

	handle.ExplodeParticle:Emit(math.random(20, 30))
	if shakerInstance and typeof(shakerInstance.ShakeOnce) == "function" then 
		shakerInstance:ShakeOnce(7.5, 7.5, 0.25, 1.5) 
	end

	task.delay(5, repentance.Destroy, repentance)
	return true
end

-- Weak table cache to automatically GC deleted room references
local roomFloorCache = setmetatable({}, { __mode = "k" })

local function getRoomFloorParts(roomFolder: Instance): { BasePart }
	if roomFloorCache[roomFolder] then
		return roomFloorCache[roomFolder]
	end

	local floorParts = {}
	for _, descendant in ipairs(roomFolder:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local name = string.lower(descendant.Name)
			local isCeiling = string.find(name, "ceiling") or string.find(name, "roof") or string.find(name, "top")
			if not isCeiling then
				table.insert(floorParts, descendant)
			end
		end
	end

	roomFloorCache[roomFolder] = floorParts
	return floorParts
end

local function alignToFloorLevel(position: Vector3, roomFolder: Instance?, floorYOffset: number): Vector3
	local offsetVector = Vector3.new(0, floorYOffset, 0)
	if not roomFolder then return position + offsetVector end

	local floorParts = getRoomFloorParts(roomFolder)
	if #floorParts == 0 then return position + offsetVector end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = floorParts

	local startPos = Vector3.new(position.X, position.Y + 4, position.Z)
	local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -200, 0), raycastParams)

	if rayResult then
		return Vector3.new(position.X, rayResult.Position.Y, position.Z) + offsetVector
	end

	return position + offsetVector
end

local function renderDebugWaypoints(waypoints: {Vector3}): Folder
	local folder = Instance.new("Folder")
	folder.Name = "PathDebugVisuals"

	for i, pos in ipairs(waypoints) do
		local part = Instance.new("Part")
		part.Size = Vector3.new(1.2, 1.2, 1.2)
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(0, 255, 170)
		part.Transparency = 0.3
		part.Anchored = true
		part.CanCollide = false
		part.Position = pos
		part.Parent = folder

		if i > 1 then
			local prevPos = waypoints[i - 1]
			local dist = (pos - prevPos).Magnitude

			local line = Instance.new("Part")
			line.Size = Vector3.new(0.3, 0.3, dist)
			line.CFrame = CFrame.lookAt(prevPos:Lerp(pos, 0.5), pos)
			line.Material = Enum.Material.Neon
			line.Color = Color3.fromRGB(255, 170, 0)
			line.Transparency = 0.5
			line.Anchored = true
			line.CanCollide = false
			line.Parent = folder
		end
	end

	folder.Parent = Workspace
	return folder
end

local function checkLineOfSight(entityModel: Instance): (boolean, Model?)
	local character = LocalPlayer.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return false, nil end

	local entityPos = entityModel:IsA("Model") and entityModel:GetPivot().Position or entityModel.Position
	local playerPos = character.HumanoidRootPart.Position

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { entityModel, character }

	local direction = (playerPos - entityPos)
	local rayResult = Workspace:Raycast(entityPos, direction, raycastParams)

	if not rayResult then
		return true, character
	end

	return false, nil
end

local function checkAdvancedHitbox(
	entityModel: Instance, 
	character: Model, 
	lastEntityPosition: Vector3?, 
	sphereRadius: number
): boolean
	local currentEntityPos = entityModel:IsA("Model") and entityModel:GetPivot().Position or entityModel.Position

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { entityModel }

	if lastEntityPosition then
		local displacement = currentEntityPos - lastEntityPosition
		if displacement.Magnitude > 0.1 then
			local sphereResult = Workspace:Spherecast(lastEntityPosition, sphereRadius, displacement, raycastParams)
			if sphereResult and sphereResult.Instance:IsDescendantOf(character) then
				return true
			end
		end
	end

	local targetParts = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "Head" then
			table.insert(targetParts, child)
		end
	end

	for _, part in ipairs(targetParts) do
		local direction = (part.Position - currentEntityPos)
		local rayResult = Workspace:Raycast(currentEntityPos, direction, raycastParams)

		if rayResult and rayResult.Instance:IsDescendantOf(character) then
			return true
		end
	end

	return false
end

local function computePathWaypoints(startPos: Vector3, endPos: Vector3, heightOffset: number, floorYOffset: number, roomFolder: Instance?): {Vector3}
	local distance = (endPos - startPos).Magnitude
	if distance ~= distance or distance == 0 then return {} end

	local primaryPath = PathfindingService:CreatePath({
		AgentRadius = 1,
		AgentHeight = 2.5,
		AgentCanJump = false,
		WaypointSpacing = 3.5,
		Costs = { Default = 1 }
	})

	local success = pcall(function()
		primaryPath:ComputeAsync(startPos, endPos)
	end)

	local filteredWaypoints: {Vector3} = {}

	local function processWaypointCandidate(pos: Vector3)
		local distToStart = (pos - startPos).Magnitude
		local distToEnd = (pos - endPos).Magnitude
		if distToStart <= 10 or distToEnd <= 10 then return end

		local lastPos = filteredWaypoints[#filteredWaypoints]
		if lastPos then
			local distToLast = (pos - lastPos).Magnitude
			if distToLast < 10 then return end
		end

		local groundPos = alignToFloorLevel(pos, roomFolder, floorYOffset)
		table.insert(filteredWaypoints, groundPos + Vector3.new(0, heightOffset, 0))
	end

	if success and primaryPath.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(primaryPath:GetWaypoints()) do
			processWaypointCandidate(wp.Position)
		end
		return filteredWaypoints
	end

	local steps = math.max(2, math.ceil(distance / 10))
	for i = 1, steps do
		local alpha = i / steps
		local interpolated = startPos:Lerp(endPos, alpha)
		processWaypointCandidate(interpolated)
	end

	return filteredWaypoints
end

local function resolveTargetPosition(target: Vector3 | BasePart | Model): Vector3?
	if typeof(target) == "Vector3" then
		return target
	elseif typeof(target) == "Instance" then
		if target:IsA("BasePart") then
			return target.Position
		elseif target:IsA("Model") then
			return target:GetPivot().Position
		end
	end
	return nil
end

local function getRoomPositions(roomFolder: Instance, floorYOffset: number): (Vector3?, Vector3?, Vector3?, Vector3?)
	local roomEntrance = roomFolder:FindFirstChild("RoomEntrance", true)
	local roomExit = roomFolder:FindFirstChild("RoomExit", true) or roomEntrance

	local entFront, entBack, exitFront, exitBack

	if roomEntrance then
		local cf = roomEntrance:IsA("BasePart") and roomEntrance.CFrame or (roomEntrance:IsA("Model") and (roomEntrance.PrimaryPart and roomEntrance.PrimaryPart.CFrame or roomEntrance:GetPivot()))
		if cf then
			entFront = alignToFloorLevel((cf * CFrame.new(0, 0, 2.5)).Position, roomFolder, floorYOffset)
			entBack = alignToFloorLevel((cf * CFrame.new(0, 0, -2.5)).Position, roomFolder, floorYOffset)
		end
	end

	if roomExit then
		local cf = roomExit:IsA("BasePart") and roomExit.CFrame or (roomExit:IsA("Model") and (roomExit.PrimaryPart and roomExit.PrimaryPart.CFrame or roomExit:GetPivot()))
		if cf then
			exitFront = alignToFloorLevel((cf * CFrame.new(0, 0, 2.5)).Position, roomFolder, floorYOffset)
			exitBack = alignToFloorLevel((cf * CFrame.new(0, 0, -2.5)).Position, roomFolder, floorYOffset)
		end
	end

	return entFront, entBack, exitFront, exitBack
end

local function isRoomDistanceValid(roomFolder: Instance, entityModel: Instance, floorYOffset: number): boolean
	local _, entBack, exitFront = getRoomPositions(roomFolder, floorYOffset)
	if entBack and exitFront then
		local entityPos = entityModel:IsA("Model") and entityModel:GetPivot().Position or entityModel.Position
		return ((entityPos - entBack).Magnitude <= 1000) and ((exitFront - entityPos).Magnitude <= 1000)
	end
	return true
end

function PathfindingMovement.MoveThroughRooms(options: MovementOptions)
	local model = options.Model
	if not model then return end

	disableCollision(model)

	local callbacks = options.Callbacks or {}
	local speed = options.Speed or 60
	local heightOffset = options.HeightOffset or 2.5
	local floorYOffset = options.FloorYOffset or -3
	local delayTime = options.DelayTime or 0
	local showPath = options.ShowPath or false
	local attackType = options.AttackType or "Back"
	
	local hitboxRange = options.HitboxRange or 5
	local useRaycastHitbox = if options.RaycastHitbox ~= nil then options.RaycastHitbox else false
	local sphereRadius = options.SphereRadius or 3.5
	local damageAmount = options.Damage or 100

	local lightFlicker = if options.LightFlicker ~= nil then options.LightFlicker else false
	local duration = options.Duration or 1
	local lightBreak = if options.LightBreak ~= nil then options.LightBreak else false

	local spawnOffsetRooms = math.clamp(options.SpawnOffsetRooms or 10, 0, 15)

	local isRebound = options.Rebound or false
	local targetReboundCount = options.ReboundCount or 1
	local reboundTime = options.ReboundTime or 0
	local reboundDelayTime = options.ReboundDelayTime or 0

	local enableShake = if options.EnableCameraShake ~= nil then options.EnableCameraShake else true
	local shakeAmount = options.ShakeAmount or 1.5
	local shakeRadius = options.ShakeRadius or 120

	local isStopped = false
	local skipCurrentRoom = false
	local regenPathRequested = false
	local isMoveToActive = false
	local isBeingCrucified = false
	
	local reboundRequestedOffset: number? = nil
	local reboundRequestedDelayBefore: number = 0
	local reboundRequestedDelayAfter: number = 0

	local currentTween: Tween? = nil
	local executeMoveTo: ((target: Vector3 | BasePart | Model, config: MoveToConfig?) -> ())?

	local actionsHandle: ActionsHandle = {
		Stop = function()
			isStopped = true
			isMoveToActive = false
			if currentTween then currentTween:Cancel(); currentTween = nil end
		end,
		Resume = function(resumeType: number?)
			local mode = resumeType or 1
			isMoveToActive = false
			if mode == 2 then
				regenPathRequested = true
				if currentTween then currentTween:Cancel(); currentTween = nil end
			end
			isStopped = false
		end,
		SkipRoom = function()
			skipCurrentRoom = true
			isMoveToActive = false
			if currentTween then currentTween:Cancel(); currentTween = nil end
		end,
		SetSpeed = function(newSpeed: number)
			if type(newSpeed) == "number" and newSpeed > 0 then speed = newSpeed end
		end,
		MoveTo = function(target: Vector3 | BasePart | Model, config: MoveToConfig?)
			if executeMoveTo then executeMoveTo(target, config) end
		end,
		Rebound = function(roomOffset: number?, delayBefore: number?, delayAfter: number?)
			reboundRequestedOffset = roomOffset or 1
			reboundRequestedDelayBefore = delayBefore or 0
			reboundRequestedDelayAfter = delayAfter or 0
			skipCurrentRoom = true
			isMoveToActive = false
			if currentTween then currentTween:Cancel(); currentTween = nil end
		end,
		LightFlicker = function(room: Instance | number, durationAmount: number?, amount: number?)
			triggerLightFlicker(room, durationAmount or duration, amount)
		end,
		LightBreak = function(room: Instance | number, amount: number?, breakSpeed: number?)
			triggerLightBreak(room, amount, breakSpeed)
		end,
		ToggleLight = function(room: Instance | number, state: boolean, ambientColor: Color3?)
			triggerToggleLight(room, state, ambientColor)
		end
	}

	local isMoving = false
	local isMovementFinished = false
	local hasHitPlayerThisPass = false
	local lastEntityPosition: Vector3? = nil

		-- Vynixu Camera Shake Control Functions
	local shakeValues = options.ShakeValues or {1.5, 20, 0.1, 1} -- Magnitude, Roughness, FadeIn, FadeOut
	local shakeRadius = options.ShakeRadius or 100
    local renderConnection: RBXScriptConnection? = nil


	local function stopCameraShake(destroyShaker: boolean?)
		isMovementFinished = true
		if renderConnection then 
			renderConnection:Disconnect()
			renderConnection = nil 
		end
	end

	local function startCameraShake()
		if not RunService:IsClient() or not enableShake or renderConnection or not Main_Game or not Main_Game.camShaker then return end

		renderConnection = RunService.RenderStepped:Connect(function(dt)
			if isMovementFinished or not model or not model.Parent then
				stopCameraShake(true)
				return
			end

			if isMoving and not isStopped and not isBeingCrucified then
				local character = LocalPlayer.Character
				if character and character:FindFirstChild("HumanoidRootPart") then
					local hrpPos = character.HumanoidRootPart.Position
					local entityPos = model:IsA("Model") and model:GetPivot().Position or model.Position
					local distance = (hrpPos - entityPos).Magnitude

					-- 1. HITBOX & DAMAGE / CRUCIFIX CHECK
					if not isBeingCrucified and character:GetAttribute("Hiding") ~= true and distance <= (hitboxRange + (speed * dt)) and not hasHitPlayerThisPass then
						local canHit = true
						if useRaycastHitbox then
							canHit = checkAdvancedHitbox(model, character, lastEntityPosition, sphereRadius)
						end

						if canHit then
							local hasLoS = checkLineOfSight(model)
							if hasLoS then
								local hasCrucifix, tool = checkForEquippedCrucifix(character)
								if hasCrucifix and tool then
									isBeingCrucified = true
									isStopped = true
									if currentTween then currentTween:Cancel(); currentTween = nil end
									task.spawn(function()
										if tool:FindFirstChildWhichIsA("RemoteEvent") then
											ReplicatedStorage.RemotesFolder.DropItem:FireServer(tool)
											task.wait()
											if Workspace:FindFirstChild("Drops") then
												Workspace.Drops:WaitForChild(tool.Name, 3):Destroy()
											end
										else
											tool:Destroy()
										end
									end)
									
									stopCameraShake(false)

									if type(callbacks.OnCrucifixion) == "function" then
										task.spawn(callbacks.OnCrucifixion, model, actionsHandle)
									end

									task.spawn(function()
										-- Passes Main_Game.camShaker directly to crucifixion routine
										performCrucifixion(model, character, Main_Game.camShaker)
										isMovementFinished = true
									end)
									return
								else
									hasHitPlayerThisPass = true
									local humanoid = character:FindFirstChildOfClass("Humanoid")
									if humanoid then humanoid:TakeDamage(damageAmount) end

									if type(callbacks.OnKillPlayer) == "function" then
										task.spawn(callbacks.OnKillPlayer, model, character, actionsHandle)
									end
								end
							end
						end
					end

					lastEntityPosition = entityPos

					-- 2. LINE OF SIGHT CALLBACK
					if not isBeingCrucified and type(callbacks.OnSeePlayer) == "function" then
						local canSee, playerChar = checkLineOfSight(model)
						if canSee and playerChar then
							task.spawn(callbacks.OnSeePlayer, model, playerChar, actionsHandle)
						end
					end

					-- 3. VYNIXU DISTANCE-BASED CAMERA SHAKE
					if distance <= shakeRadius then
						local cloned = {}
						for i, v in ipairs(shakeValues) do
							cloned[i] = v
						end

						-- Scale Magnitude and Roughness based on proximity
						cloned[1] = shakeValues[1] / shakeRadius * (shakeRadius - distance) -- Magnitude
						cloned[2] = shakeValues[2] / shakeRadius * (shakeRadius - distance) -- Roughness

						Main_Game.camShaker:ShakeOnce(table.unpack(cloned))
					end
				end
			end
		end)
	end

	if model.Parent ~= Workspace then model.Parent = Workspace end

	local currentRooms = Workspace:WaitForChild("CurrentRooms", 10)
	local gameData = ReplicatedStorage:WaitForChild("GameData", 10)
	local latestRoomValue = gameData and gameData:WaitForChild("LatestRoom", 10)

	if not currentRooms or not latestRoomValue then
		stopCameraShake(true)
		return
	end

	local function resolveSpawnTarget(): (Instance?, number)
		local currentLatest = latestRoomValue.Value
		local targetNum = (attackType == "Front") and (currentLatest + spawnOffsetRooms) or math.max(0, currentLatest - spawnOffsetRooms)
		local foundRoom: Instance? = currentRooms:FindFirstChild(tostring(targetNum))

		if not foundRoom then
			local step = (attackType == "Front") and -1 or 1
			local searchLimit = (attackType == "Front") and 0 or currentLatest
			for i = targetNum, searchLimit, step do
				local candidate = currentRooms:FindFirstChild(tostring(i))
				if candidate then foundRoom = candidate; targetNum = i; break end
			end
		end

		return foundRoom, targetNum
	end

	local function applyPositionToRoom(targetRoom: Instance)
		local entFront, entBack, exitFront, exitBack = getRoomPositions(targetRoom, floorYOffset)
		local spawnPos = (attackType == "Front") and (exitBack or exitFront) or (entBack or entFront)

		if spawnPos then
			spawnPos = spawnPos + Vector3.new(0, heightOffset, 0)
			if model:IsA("Model") then
				model:PivotTo(CFrame.new(spawnPos))
			elseif model:IsA("BasePart") then
				model.Position = spawnPos
			end
		end
	end

	local initialRoom, initialTargetIndex = resolveSpawnTarget()
	if initialRoom then applyPositionToRoom(initialRoom) end

	if lightFlicker then
		local excludedRoomNum = latestRoomValue.Value + 1
		for _, room in ipairs(currentRooms:GetChildren()) do
			local roomNum = tonumber(room.Name)
			if roomNum and roomNum ~= excludedRoomNum then
				triggerLightFlicker(room, duration, 100)
			end
		end
	end

	if type(callbacks.OnSpawned) == "function" then
		task.spawn(callbacks.OnSpawned, model, actionsHandle)
	end

	if delayTime > 0 then isMoving = false; task.wait(delayTime) end

	if type(callbacks.OnStartMoving) == "function" then
		task.spawn(callbacks.OnStartMoving, model, actionsHandle)
	end

	local currentReboundState = 0
	local currentRoomIndex = initialTargetIndex

	local function moveDirectTo(targetPos: Vector3?, customSpeed: number?)
		if not targetPos or not model or not model.Parent or skipCurrentRoom or regenPathRequested then return end

		while (isStopped or isMoveToActive or isBeingCrucified) and not skipCurrentRoom and not regenPathRequested do
			task.wait(0.05)
		end
		if skipCurrentRoom or regenPathRequested or not model or not model.Parent or isBeingCrucified then return end

		local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
		local segmentDistance = (targetPos - currentPos).Magnitude

		if segmentDistance > 0.05 then
			if enableShake and not renderConnection then startCameraShake() end
			isMoving = true

			local moveSpeed = customSpeed or speed
			local travelTime = math.max(0.01, segmentDistance / moveSpeed)
			local direction = (targetPos - currentPos).Unit
			local targetCFrame = CFrame.lookAt(targetPos, targetPos + direction)
			local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)

			if model:IsA("BasePart") then
				currentTween = TweenService:Create(model, tweenInfo, { CFrame = targetCFrame })
				currentTween:Play()
				currentTween.Completed:Wait()
				currentTween = nil
			elseif model:IsA("Model") then
				local CFrameValue = Instance.new("CFrameValue")
				CFrameValue.Value = model:GetPivot()

				local connection = CFrameValue.Changed:Connect(function(newCFrame)
					if model and model.Parent then model:PivotTo(newCFrame) end
				end)

				currentTween = TweenService:Create(CFrameValue, tweenInfo, { Value = targetCFrame })
				currentTween:Play()
				currentTween.Completed:Wait()

				connection:Disconnect()
				CFrameValue:Destroy()
				currentTween = nil
			end

			isMoving = false
		end
	end

	executeMoveTo = function(target: Vector3 | BasePart | Model, config: MoveToConfig?)
		if currentTween then
			currentTween:Cancel()
			currentTween = nil
		end

		isMoveToActive = true
		isStopped = false

		local cfg = config or {}
		local moveSpeed = cfg.Speed or speed
		local reachDistance = cfg.ReachDistance or 2
		local customHeight = cfg.HeightOffset or heightOffset
		local lastTargetPos: Vector3? = nil

		while isMoveToActive and model and model.Parent and not skipCurrentRoom and not isBeingCrucified do
			local currentTargetPos = resolveTargetPosition(target)
			if not currentTargetPos then break end

			local entityPos = model:IsA("Model") and model:GetPivot().Position or model.Position
			if (currentTargetPos - entityPos).Magnitude <= reachDistance then break end

			if not lastTargetPos or (currentTargetPos - lastTargetPos).Magnitude > 2 then
				lastTargetPos = currentTargetPos
				local groundTargetPos = alignToFloorLevel(currentTargetPos, nil, floorYOffset) + Vector3.new(0, customHeight, 0)
				
				local dist = (groundTargetPos - entityPos).Magnitude
				if dist > reachDistance then
					local travelTime = math.max(0.01, dist / moveSpeed)
					local direction = (groundTargetPos - entityPos).Unit
					local targetCFrame = CFrame.lookAt(groundTargetPos, groundTargetPos + direction)
					local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)

					if model:IsA("BasePart") then
						currentTween = TweenService:Create(model, tweenInfo, { CFrame = targetCFrame })
						currentTween:Play()
						currentTween.Completed:Wait()
						currentTween = nil
					elseif model:IsA("Model") then
						local CFrameValue = Instance.new("CFrameValue")
						CFrameValue.Value = model:GetPivot()

						local connection = CFrameValue.Changed:Connect(function(newCFrame)
							if model and model.Parent then model:PivotTo(newCFrame) end
						end)

						currentTween = TweenService:Create(CFrameValue, tweenInfo, { Value = targetCFrame })
						currentTween:Play()
						currentTween.Completed:Wait()

						connection:Disconnect()
						CFrameValue:Destroy()
						currentTween = nil
					end
				end
			end
			task.wait(0.05)
		end

		isMoveToActive = false
		regenPathRequested = true
	end

	local function moveAlongWaypoints(startPos: Vector3, endPos: Vector3, roomFolder: Instance?, startNode: Vector3?, endNode: Vector3?)
		local heightVector = Vector3.new(0, heightOffset, 0)
		local fullPathVisuals: Folder?

		local currentStartPos = startPos
		local waypoints = computePathWaypoints(currentStartPos, endPos, heightOffset, floorYOffset, roomFolder)
		
		if showPath then
			local allNodes = {}
			if startNode then table.insert(allNodes, startNode + heightVector) end
			for _, wp in ipairs(waypoints) do table.insert(allNodes, wp) end
			if endNode then table.insert(allNodes, endNode + heightVector) end
			fullPathVisuals = renderDebugWaypoints(allNodes)
		end

		if startNode and not skipCurrentRoom and not regenPathRequested and not isBeingCrucified then
			moveDirectTo(startNode + heightVector)
		end

		local idx = 1
		while idx <= #waypoints do
			if skipCurrentRoom or isBeingCrucified then break end

			while isMoveToActive or isBeingCrucified do
				task.wait(0.05)
				regenPathRequested = true
				if isBeingCrucified then break end
			end

			if isBeingCrucified then break end

			if regenPathRequested then
				regenPathRequested = false
				if fullPathVisuals then fullPathVisuals:Destroy() end

				local currentEntityPos = model:IsA("Model") and model:GetPivot().Position or model.Position
				waypoints = computePathWaypoints(currentEntityPos, endPos, heightOffset, floorYOffset, roomFolder)
				idx = 1

				if showPath then
					local allNodes = {}
					for _, wp in ipairs(waypoints) do table.insert(allNodes, wp) end
					if endNode then table.insert(allNodes, endNode + heightVector) end
					fullPathVisuals = renderDebugWaypoints(allNodes)
				end
			end

			if waypoints[idx] then moveDirectTo(waypoints[idx]) end
			idx += 1
		end

		if endNode and not skipCurrentRoom and not isBeingCrucified then moveDirectTo(endNode + heightVector) end
		if fullPathVisuals then fullPathVisuals:Destroy() end
	end

	local function triggerRoomEvents(roomFolder: Instance)
		local roomNum = tonumber(roomFolder.Name)
		local excludedRoomNum = latestRoomValue.Value + 1

		if lightBreak and roomNum ~= excludedRoomNum then
			triggerLightBreak(roomFolder, 100, 60)
		end

		if type(callbacks.OnEnterRoom) == "function" then
			task.spawn(callbacks.OnEnterRoom, model, roomFolder, actionsHandle)
		end

		if type(callbacks.OnEnterPlayerRoom) == "function" then
			local playerRoomNum = LocalPlayer:GetAttribute("CurrentRoom")
			if playerRoomNum and tostring(playerRoomNum) == roomFolder.Name then
				task.spawn(callbacks.OnEnterPlayerRoom, model, roomFolder, LocalPlayer.Character, actionsHandle)
			end
		end
	end

	local function processActionRebound(requestedOffset: number, delayBefore: number, delayAfter: number)
		reboundRequestedOffset = nil
		if delayBefore > 0 then isMoving = false; task.wait(delayBefore) end

		local targetRoomIndex = math.clamp(currentRoomIndex - requestedOffset, 0, latestRoomValue.Value + spawnOffsetRooms)

		if requestedOffset == 0 then
			local roomFolder = currentRooms:FindFirstChild(tostring(currentRoomIndex))
			if roomFolder then
				local _, entBack = getRoomPositions(roomFolder, floorYOffset)
				if entBack then
					local currentEntityPos = model:IsA("Model") and model:GetPivot().Position or model.Position
					moveAlongWaypoints(currentEntityPos, entBack, roomFolder, nil, entBack)
				end
			end
		else
			while model and model.Parent and currentRoomIndex >= targetRoomIndex and not isBeingCrucified do
				skipCurrentRoom = false
				local roomFolder = currentRooms:FindFirstChild(tostring(currentRoomIndex))
				if roomFolder then
					local _, entBack, exitFront = getRoomPositions(roomFolder, floorYOffset)
					if exitFront and entBack then
						moveAlongWaypoints(exitFront, entBack, roomFolder, exitFront, entBack)
					end
				end
				if currentRoomIndex == targetRoomIndex or isBeingCrucified then break end
				currentRoomIndex -= 1
				task.wait()
			end
		end

		if delayAfter > 0 then isMoving = false; task.wait(delayAfter) end
	end

	local function runForwardPass()
		while model and model.Parent and not isBeingCrucified do
			skipCurrentRoom = false
			regenPathRequested = false

			local dynamicTargetEndRoom = math.min(currentRoomIndex + spawnOffsetRooms, latestRoomValue.Value + 1)
			if currentRoomIndex > dynamicTargetEndRoom then break end

			local roomFolder = currentRooms:FindFirstChild(tostring(currentRoomIndex))
			if roomFolder then
				if isRoomDistanceValid(roomFolder, model, floorYOffset) then
					triggerRoomEvents(roomFolder)
					
					if reboundRequestedOffset ~= nil then
						processActionRebound(reboundRequestedOffset, reboundRequestedDelayBefore, reboundRequestedDelayAfter)
					elseif not skipCurrentRoom then
						local _, entBack, exitFront = getRoomPositions(roomFolder, floorYOffset)
						if entBack and exitFront then
							moveAlongWaypoints(entBack, exitFront, roomFolder, entBack, exitFront)
						else
							task.wait()
						end
					end
				end
			else
				task.wait()
			end

			currentRoomIndex += 1
		end
	end

	local function runBackwardPass()
		while model and model.Parent and not isBeingCrucified do
			skipCurrentRoom = false
			regenPathRequested = false

			local dynamicTargetMinRoom = math.max(0, latestRoomValue.Value - spawnOffsetRooms)
			if currentRoomIndex < dynamicTargetMinRoom then currentRoomIndex = dynamicTargetMinRoom; break end

			local roomFolder = currentRooms:FindFirstChild(tostring(currentRoomIndex))
			if roomFolder then
				if isRoomDistanceValid(roomFolder, model, floorYOffset) then
					triggerRoomEvents(roomFolder)

					if reboundRequestedOffset ~= nil then
						processActionRebound(reboundRequestedOffset, reboundRequestedDelayBefore, reboundRequestedDelayAfter)
					elseif not skipCurrentRoom then
						local _, entBack, exitFront = getRoomPositions(roomFolder, floorYOffset)
						if exitFront and entBack then
							moveAlongWaypoints(exitFront, entBack, roomFolder, exitFront, entBack)
						else
							task.wait()
						end
					end
				end
			else
				task.wait()
			end

			if currentRoomIndex == dynamicTargetMinRoom then break end
			currentRoomIndex -= 1
		end
	end

	while model and model.Parent and not isBeingCrucified do
		hasHitPlayerThisPass = false
		lastEntityPosition = nil

		local isForwardStep = (currentReboundState % 2 == 0)
		if attackType == "Front" then isForwardStep = not isForwardStep end

		if isForwardStep then runForwardPass() else runBackwardPass() end

		if isRebound and currentReboundState < targetReboundCount and not isBeingCrucified then
			isMoving = false
			currentReboundState += 1

			if type(callbacks.OnStartRebounding) == "function" then
				task.spawn(callbacks.OnStartRebounding, model, currentReboundState, actionsHandle)
			end

			if currentReboundState % 2 == 1 then
				if reboundTime > 0 then task.wait(reboundTime) end
			else
				if reboundDelayTime > 0 then task.wait(reboundDelayTime) end
			end
		else
			break
		end
	end

	-- Despawn / Crucifixion Cleanup
	if isBeingCrucified then
		while isBeingCrucified and model and model.Parent do
			task.wait(0.1)
		end
	end

	if type(callbacks.OnDespawn) == "function" then
		task.spawn(callbacks.OnDespawn, model, actionsHandle)
	end

	if model and model.Parent then
		local startCFrame = model:IsA("Model") and model:GetPivot() or model.CFrame
		local fallTargetCFrame = startCFrame - Vector3.new(0, 300, 0)
		local fallTime = math.max(0.5, 300 / (speed * 1.5))
		local fallTweenInfo = TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		if model:IsA("BasePart") then
			local fallTween = TweenService:Create(model, fallTweenInfo, { CFrame = fallTargetCFrame })
			fallTween:Play()
			fallTween.Completed:Wait()
		elseif model:IsA("Model") then
			local CFrameValue = Instance.new("CFrameValue")
			CFrameValue.Value = startCFrame

			local connection = CFrameValue.Changed:Connect(function(newCFrame)
				if model and model.Parent then model:PivotTo(newCFrame) end
			end)

			local fallTween = TweenService:Create(CFrameValue, fallTweenInfo, { Value = fallTargetCFrame })
			fallTween:Play()
			fallTween.Completed:Wait()
			
			stopCameraShake(true)
			connection:Disconnect()
			CFrameValue:Destroy()
		end

		stopEntitySounds(model)
		task.wait(1)
		if model and model.Parent then model:Destroy() end
	end
end

return PathfindingMovement
