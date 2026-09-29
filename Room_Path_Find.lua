local PathfindingMovement = {}
PathfindingMovement.__index = PathfindingMovement

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- CameraShaker Integration
local CameraShaker = require(ReplicatedStorage:WaitForChild("CameraShaker"))
local LocalPlayer = Players.LocalPlayer

type EventCallbacks = {
	OnSpawned: ((model: Model | BasePart) -> ())?,
	OnStartMoving: ((model: Model | BasePart) -> ())?,
	OnStartRebounding: ((model: Model | BasePart, reboundCount: number) -> ())?,
	OnEnterRoom: ((model: Model | BasePart, roomFolder: Instance) -> ())?,
	OnEnterPlayerRoom: ((model: Model | BasePart, roomFolder: Instance) -> ())?,
	OnSeePlayer: ((model: Model | BasePart, playerCharacter: Model) -> ())?,
	OnKillPlayer: ((model: Model | BasePart, playerCharacter: Model) -> ())?,
	OnDespawn: ((model: Model | BasePart) -> ())?
}

type MovementOptions = {
	Model: Model | BasePart,
	Speed: number?,
	HeightOffset: number?,
	FloorYOffset: number?, -- Offset applied to floor level (default: -3)
	DelayTime: number?,
	SpawnOffsetRooms: number?,
	AttackType: ("Back" | "Front")?, -- "Back" = Spawns behind & rushes forward | "Front" = Spawns ahead & rushes back
	
	-- Combat & Hitbox Options
	HitboxRange: number?,   -- Distance in studs to trigger hit/kill (default: 5)
	RaycastHitbox: boolean?, -- Require clean raycast/spherecast connection to hit player
	SphereRadius: number?,  -- Thickness radius of the spherecast (default: 3.5)
	Damage: number?,        -- Damage applied to player (default: 100)

	-- Custom Event Callbacks
	Callbacks: EventCallbacks?,

	-- Debug / Visualization Options
	ShowPath: boolean?, -- Visualize generated waypoints

	-- Rebound System Options
	Rebound: boolean?,
	ReboundCount: number?,
	ReboundTime: number?,
	ReboundDelayTime: number?,

	-- Camera Shake Options
	EnableCameraShake: boolean?,
	ShakeAmount: number?, -- Base magnitude multiplier (default: 1.5)
	ShakeRadius: number?   -- Distance in studs to feel shake (default: 120)
}

-- Disable CanCollide on all parts of the entity
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

-- Stops all playing audio tracks attached to the entity
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

-- Fast Raycast-based Floor Alignment with Instance Caching
local roomFloorCache: { [Instance]: { BasePart } } = {}

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
	local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -30, 0), raycastParams)

	if rayResult then
		return Vector3.new(position.X, rayResult.Position.Y, position.Z) + offsetVector
	end

	return position + offsetVector
end

-- Visualizes waypoints as small neon spheres in Workspace
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

-- Line of Sight check to local player
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

-- High-Speed Swept Spherecast + Every Body Part LoS Check (Excludes Head)
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

	-- 1. Swept Spherecast Trajectory (Prevents tunneling between frames)
	if lastEntityPosition then
		local displacement = currentEntityPos - lastEntityPosition
		if displacement.Magnitude > 0.1 then
			local sphereResult = Workspace:Spherecast(lastEntityPosition, sphereRadius, displacement, raycastParams)
			if sphereResult and sphereResult.Instance:IsDescendantOf(character) then
				return true
			end
		end
	end

	-- 2. Check Line of Sight to every character BasePart EXCEPT Head
	local targetParts = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "Head" then
			table.insert(targetParts, child)
		end
	end

	for _, part in ipairs(targetParts) do
		local direction = (part.Position - currentEntityPos)
		local rayResult = Workspace:Raycast(currentEntityPos, direction, raycastParams)

		-- Hit registers if ray connects directly to body part or character model
		if rayResult and rayResult.Instance:IsDescendantOf(character) then
			return true
		end
	end

	return false
end

-- Computes path sub-waypoints and filters nodes near doors or prior waypoints
local function computePathWaypoints(startPos: Vector3, endPos: Vector3, heightOffset: number, floorYOffset: number, roomFolder: Instance?): {Vector3}
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
		if distToStart <= 10 or distToEnd <= 10 then
			return
		end

		local lastPos = filteredWaypoints[#filteredWaypoints]
		if lastPos then
			local distToLast = (pos - lastPos).Magnitude
			if distToLast < 10 then
				return
			end
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

	local distance = (endPos - startPos).Magnitude
	local steps = math.max(2, math.ceil(distance / 10))

	for i = 1, steps do
		local alpha = i / steps
		local interpolated = startPos:Lerp(endPos, alpha)
		processWaypointCandidate(interpolated)
	end

	return filteredWaypoints
end

-- Retrieves dynamic room entrance and exit locations
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

-- Helper: Validates whether a room's entrance and exit distance is within the 200 stud limit
local function isRoomDistanceValid(roomFolder: Instance, floorYOffset: number): boolean
	local _, entBack, exitFront = getRoomPositions(roomFolder, floorYOffset)
	if entBack and exitFront then
		return (exitFront - entBack).Magnitude <= 200
	end
	return true
end

function PathfindingMovement.MoveThroughRooms(options: MovementOptions)
	local model = options.Model
	if not model then
		warn("PathfindingMovement: Model is missing.")
		return
	end

	disableCollision(model)

	local callbacks = options.Callbacks or {}
	local speed = options.Speed or 60
	local heightOffset = options.HeightOffset or 2.5
	local floorYOffset = options.FloorYOffset or -3
	local delayTime = options.DelayTime or 0
	local showPath = options.ShowPath or false
	local attackType = options.AttackType or "Back" -- "Back" or "Front"
	
	-- Hitbox & Combat Options
	local hitboxRange = options.HitboxRange or 5
	local useRaycastHitbox = if options.RaycastHitbox ~= nil then options.RaycastHitbox else false
	local sphereRadius = options.SphereRadius or 3.5
	local damageAmount = options.Damage or 100

	local rawOffset = options.SpawnOffsetRooms or 10
	local spawnOffsetRooms = math.clamp(rawOffset, 0, 15)

	-- Rebound Settings
	local isRebound = options.Rebound or false
	local targetReboundCount = options.ReboundCount or 1
	local reboundTime = options.ReboundTime or 0
	local reboundDelayTime = options.ReboundDelayTime or 0

	-- Camera Shake Settings
	local enableShake = if options.EnableCameraShake ~= nil then options.EnableCameraShake else true
	local shakeAmount = options.ShakeAmount or 1.5
	local shakeRadius = options.ShakeRadius or 120

	-- Movement State Flags
	local isMoving = false
	local isMovementFinished = false
	local hasHitPlayerThisPass = false

	-- Entity Velocity/Position Tracking
	local lastEntityPosition: Vector3? = nil

	-- Setup Cleanup & Lifecycle Handles for Isolated Local Shake
	local renderConnection: RBXScriptConnection?
	local shakerInstance: any?
	local sustainedShake: any?

	local function startCameraShake()
		if not RunService:IsClient() or not enableShake or renderConnection then return end

		shakerInstance = CameraShaker.new(Enum.RenderPriority.Camera.Value + 10, function(shakeCFrame)
			local camera = Workspace.CurrentCamera
			if camera and camera.CameraSubject then
				camera.CFrame = camera.CFrame * shakeCFrame
			end
		end)
		shakerInstance:Start()

		renderConnection = RunService.RenderStepped:Connect(function(dt)
			if shakerInstance then
				shakerInstance:Update(dt)
			end

			if isMovementFinished or not model or not model.Parent then
				if sustainedShake then 
					sustainedShake:StartFadeOut(0.2) 
					sustainedShake = nil
				end
				if renderConnection then
					renderConnection:Disconnect()
					renderConnection = nil
				end
				task.delay(0.2, function()
					if shakerInstance then
						shakerInstance:Stop()
						shakerInstance = nil
					end
				end)
				return
			end

			if isMoving then
				local character = LocalPlayer.Character
				if character and character:FindFirstChild("HumanoidRootPart") then
					local hrpPos = character.HumanoidRootPart.Position
					local entityPos = model:IsA("Model") and model:GetPivot().Position or model.Position
					local distance = (hrpPos - entityPos).Magnitude

					-- Check if player is hiding
					local isHiding = character:GetAttribute("Hiding") == true

					-- Hitbox & Damage Check (Ignored if player is hiding)
					if not isHiding and distance <= (hitboxRange + (speed * dt)) and not hasHitPlayerThisPass then
						local canHit = true
						if useRaycastHitbox then
							canHit = checkAdvancedHitbox(model, character, lastEntityPosition, sphereRadius)
						end

						if canHit then
							hasHitPlayerThisPass = true
							
							local humanoid = character:FindFirstChildOfClass("Humanoid")
							if humanoid then
								humanoid:TakeDamage(damageAmount)
							end

							if callbacks.OnKillPlayer then
								task.spawn(callbacks.OnKillPlayer, model, character)
							end
						end
					end

					-- Save position for trajectory spherecasting on next frame
					lastEntityPosition = entityPos

					-- Check Line of Sight
					if callbacks.OnSeePlayer then
						local canSee, playerChar = checkLineOfSight(model)
						if canSee and playerChar then
							task.spawn(callbacks.OnSeePlayer, model, playerChar)
						end
					end

					if distance <= shakeRadius then
						if not sustainedShake then
							local rawShakeInstance = CameraShaker.CameraShakeInstance.new(shakeAmount, 6, 0.2, 0.3)
							rawShakeInstance.PositionInfluence = Vector3.new(0.15, 0.15, 0.15)
							rawShakeInstance.RotationInfluence = Vector3.new(0.8, 0.8, 0.8)
							sustainedShake = shakerInstance:ShakeSustain(rawShakeInstance)
						end

						local distanceRatio = 1 - (distance / shakeRadius)
						local targetMagnitude = shakeAmount * (distanceRatio ^ 2)

						sustainedShake.Magnitude = math.clamp(
							sustainedShake.Magnitude + (targetMagnitude - sustainedShake.Magnitude) * math.clamp(dt * 8, 0, 1),
							0,
							shakeAmount
						)
					else
						if sustainedShake then
							sustainedShake:StartFadeOut(0.3)
							sustainedShake = nil
						end
					end
				end
			else
				if sustainedShake then
					sustainedShake:StartFadeOut(0.3)
					sustainedShake = nil
				end
			end
		end)
	end

	local function stopCameraShake()
		isMovementFinished = true
		if sustainedShake then
			sustainedShake:StartFadeOut(0.2)
			sustainedShake = nil
		end
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		if shakerInstance then
			task.delay(0.2, function()
				if shakerInstance then
					shakerInstance:Stop()
					shakerInstance = nil
				end
			end)
		end
	end

	if model.Parent ~= Workspace then
		model.Parent = Workspace
	end

	local currentRooms = Workspace:WaitForChild("CurrentRooms", 10)
	local gameData = ReplicatedStorage:WaitForChild("GameData", 10)
	local latestRoomValue = gameData and gameData:WaitForChild("LatestRoom", 10)

	if not currentRooms or not latestRoomValue then
		warn("PathfindingMovement: CurrentRooms or GameData.LatestRoom missing!")
		stopCameraShake()
		return
	end

	local latestRoomNumber = latestRoomValue.Value
	local initialSpawnNumber = 0

	if attackType == "Front" then
		-- Spawns ahead of player
		initialSpawnNumber = latestRoomNumber + 1 + spawnOffsetRooms
	else
		-- Spawns behind player (default "Back")
		initialSpawnNumber = math.max(0, latestRoomNumber - spawnOffsetRooms)
	end

	-- Move entity directly to target point
	local function moveDirectTo(targetPos: Vector3?)
		if not targetPos or not model or not model.Parent then return end
		
		local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
		local segmentDistance = (targetPos - currentPos).Magnitude

		if segmentDistance > 0.001 then
			if enableShake and not renderConnection then
				startCameraShake()
			end

			isMoving = true

			local travelTime = segmentDistance / speed
			local direction = (targetPos - currentPos).Unit
			local targetCFrame = CFrame.lookAt(targetPos, targetPos + direction)
			local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)

			if model:IsA("BasePart") then
				local tween = TweenService:Create(model, tweenInfo, { CFrame = targetCFrame })
				tween:Play()
				tween.Completed:Wait()
			elseif model:IsA("Model") then
				local CFrameValue = Instance.new("CFrameValue")
				CFrameValue.Value = model:GetPivot()

				local connection = CFrameValue.Changed:Connect(function(newCFrame)
					if model and model.Parent then
						model:PivotTo(newCFrame)
					end
				end)

				local tween = TweenService:Create(CFrameValue, tweenInfo, { Value = targetCFrame })
				tween:Play()
				tween.Completed:Wait()

				connection:Disconnect()
				CFrameValue:Destroy()
			end

			isMoving = false
		end
	end

	-- Sequence motion along calculated nodes
	local function moveAlongWaypoints(startPos: Vector3, endPos: Vector3, roomFolder: Instance?, startNode: Vector3?, endNode: Vector3?)
		local heightVector = Vector3.new(0, heightOffset, 0)
		local fullPathVisuals: Folder?

		local waypoints = computePathWaypoints(startPos, endPos, heightOffset, floorYOffset, roomFolder)
		
		if showPath then
			local allNodes = {}
			if startNode then table.insert(allNodes, startNode + heightVector) end
			for _, wp in ipairs(waypoints) do table.insert(allNodes, wp) end
			if endNode then table.insert(allNodes, endNode + heightVector) end

			fullPathVisuals = renderDebugWaypoints(allNodes)
		end

		if startNode then
			moveDirectTo(startNode + heightVector)
		end

		for _, nodePos in ipairs(waypoints) do
			moveDirectTo(nodePos)
		end

		if endNode then
			moveDirectTo(endNode + heightVector)
		end

		if fullPathVisuals then
			fullPathVisuals:Destroy()
		end
	end

	-- Trigger Room Callbacks
	local function triggerRoomEvents(roomFolder: Instance)
		if callbacks.OnEnterRoom then
			task.spawn(callbacks.OnEnterRoom, model, roomFolder)
		end

		if callbacks.OnEnterPlayerRoom then
			local playerRoomNum = LocalPlayer:GetAttribute("CurrentRoom")
			if playerRoomNum and tostring(playerRoomNum) == roomFolder.Name then
				task.spawn(callbacks.OnEnterPlayerRoom, model, roomFolder)
			end
		end
	end

	-- Entity spawn setup
	local targetSpawnNumber = initialSpawnNumber
	local actualSpawnRoom: Instance? = nil

	if attackType == "Front" then
		-- Find valid spawn room searching backward from target front spawn
		while targetSpawnNumber >= 0 do
			local candidateRoom = currentRooms:FindFirstChild(tostring(targetSpawnNumber))
			if candidateRoom then
				if isRoomDistanceValid(candidateRoom, floorYOffset) then
					actualSpawnRoom = candidateRoom
					break
				else
					warn(string.format("PathfindingMovement: Cannot spawn in Room %s (>200 studs). Trying previous room.", candidateRoom.Name))
				end
			end
			targetSpawnNumber -= 1
		end
	else
		-- Find valid spawn room searching forward from target back spawn
		while targetSpawnNumber <= latestRoomNumber + 1 do
			local candidateRoom = currentRooms:FindFirstChild(tostring(targetSpawnNumber))
			if candidateRoom then
				if isRoomDistanceValid(candidateRoom, floorYOffset) then
					actualSpawnRoom = candidateRoom
					break
				else
					warn(string.format("PathfindingMovement: Cannot spawn in Room %s (>200 studs). Trying next room.", candidateRoom.Name))
				end
			end
			targetSpawnNumber += 1
		end
	end

	if actualSpawnRoom then
		local entFront, _, _, exitBack = getRoomPositions(actualSpawnRoom, floorYOffset)
		local spawnPos = (attackType == "Front" and exitBack or entFront)
		if spawnPos then
			spawnPos = spawnPos + Vector3.new(0, heightOffset, 0)
			if model:IsA("Model") then
				model:PivotTo(CFrame.new(spawnPos))
			elseif model:IsA("BasePart") then
				model.Position = spawnPos
			end
		end
	end

	-- Callback: OnSpawned
	if callbacks.OnSpawned then
		task.spawn(callbacks.OnSpawned, model)
	end

	if delayTime > 0 then
		isMoving = false
		task.wait(delayTime)
	end

	-- Callback: OnStartMoving
	if callbacks.OnStartMoving then
		task.spawn(callbacks.OnStartMoving, model)
	end

	local currentReboundState = 0

	-- Forward motion helper (Back -> Front)
	local function runForwardPass()
		local currentRoomIndex = targetSpawnNumber
		while model and model.Parent do
			local targetEndRoom = latestRoomValue.Value + 1
			if currentRoomIndex > targetEndRoom then break end

			local roomFolder = currentRooms:FindFirstChild(tostring(currentRoomIndex))
			if roomFolder then
				if isRoomDistanceValid(roomFolder, floorYOffset) then
					triggerRoomEvents(roomFolder)
					local _, entBack, exitFront = getRoomPositions(roomFolder, floorYOffset)
					if entBack and exitFront then
						moveAlongWaypoints(entBack, exitFront, roomFolder, entBack, exitFront)
					end
				else
					warn(string.format("PathfindingMovement: Room %s skipped (>200 studs).", roomFolder.Name))
				end
			end

			currentRoomIndex += 1
			if currentRoomIndex > targetEndRoom then
				local updatedEndRoom = latestRoomValue.Value + 1
				if updatedEndRoom > targetEndRoom then
					targetEndRoom = updatedEndRoom
				end
			end
		end
	end

	-- Backward motion helper (Front -> Back)
	local function runBackwardPass()
		local startRoomNum = math.max(targetSpawnNumber, latestRoomValue.Value + 1)
		for roomNum = startRoomNum, 0, -1 do
			if not (model and model.Parent) then break end
			local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
			if roomFolder then
				if isRoomDistanceValid(roomFolder, floorYOffset) then
					triggerRoomEvents(roomFolder)
					local _, entBack, exitFront = getRoomPositions(roomFolder, floorYOffset)
					if exitFront and entBack then
						moveAlongWaypoints(exitFront, entBack, roomFolder, exitFront, entBack)
					end
				else
					warn(string.format("PathfindingMovement: Room %s skipped (>200 studs).", roomFolder.Name))
				end
			end
		end
	end

	-- Navigation processing loop
	while model and model.Parent do
		hasHitPlayerThisPass = false
		lastEntityPosition = nil

		local isForwardStep = (currentReboundState % 2 == 0)
		if attackType == "Front" then
			isForwardStep = not isForwardStep -- Invert motion sequence for Front spawns
		end

		if isForwardStep then
			runForwardPass()
		else
			runBackwardPass()
		end

		-- Evaluate rebound parameters
		if isRebound and currentReboundState < targetReboundCount then
			isMoving = false
			currentReboundState += 1

			-- Callback: OnStartRebounding
			if callbacks.OnStartRebounding then
				task.spawn(callbacks.OnStartRebounding, model, currentReboundState)
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

	-- Callback: OnDespawn
	if callbacks.OnDespawn then
		task.spawn(callbacks.OnDespawn, model)
	end

	-- Gravity Fall Despawn logic
	if model and model.Parent then
		local startCFrame = model:IsA("Model") and model:GetPivot() or model.CFrame
		local fallTargetCFrame = startCFrame - Vector3.new(0, 300, 0)
		local fallTime = math.max(0.5, 300 / (speed * 1.5))
		
		local fallTweenInfo = TweenInfo.new(
			fallTime, 
			Enum.EasingStyle.Quad, 
			Enum.EasingDirection.In
		)

		if model:IsA("BasePart") then
			local fallTween = TweenService:Create(model, fallTweenInfo, { CFrame = fallTargetCFrame })
			fallTween:Play()
			fallTween.Completed:Wait()
		elseif model:IsA("Model") then
			local CFrameValue = Instance.new("CFrameValue")
			CFrameValue.Value = startCFrame

			local connection = CFrameValue.Changed:Connect(function(newCFrame)
				if model and model.Parent then
					model:PivotTo(newCFrame)
				end
			end)

			local fallTween = TweenService:Create(CFrameValue, fallTweenInfo, { Value = fallTargetCFrame })
			fallTween:Play()
			fallTween.Completed:Wait()
			
			stopCameraShake()
			connection:Disconnect()
			CFrameValue:Destroy()
		end

		stopEntitySounds(model)
		task.wait(1)
		model:Destroy()
	end
	
	table.clear(roomFloorCache)
end

return PathfindingMovement
