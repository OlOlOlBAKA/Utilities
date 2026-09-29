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

type MovementOptions = {
	Model: Model | BasePart,
	Speed: number?,
	HeightOffset: number?,
	FloorYOffset: number?, -- Offset applied to floor level (default: -3)
	DelayTime: number?,
	SpawnOffsetRooms: number?,
	
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

		-- Draw connecting line to previous waypoint
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

-- Computes path sub-waypoints and filters nodes near doors (<10 studs) or near prior waypoints (<10 studs)
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
		-- 1. Door clearance threshold check (10-stud radius)
		local distToStart = (pos - startPos).Magnitude
		local distToEnd = (pos - endPos).Magnitude
		if distToStart <= 10 or distToEnd <= 10 then
			return
		end

		-- 2. Waypoint density threshold check (10-stud spacing filter)
		local lastPos = filteredWaypoints[#filteredWaypoints]
		if lastPos then
			local distToLast = (pos - lastPos).Magnitude
			if distToLast < 10 then
				return
			end
		end

		-- Ground align with vertical offset floor adjustments
		local groundPos = alignToFloorLevel(pos, roomFolder, floorYOffset)
		table.insert(filteredWaypoints, groundPos + Vector3.new(0, heightOffset, 0))
	end

	if success and primaryPath.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(primaryPath:GetWaypoints()) do
			processWaypointCandidate(wp.Position)
		end
		return filteredWaypoints
	end

	-- Fallback linear path generator
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

function PathfindingMovement.MoveThroughRooms(options: MovementOptions)
	local model = options.Model
	if not model then
		warn("PathfindingMovement: Model is missing.")
		return
	end

	disableCollision(model)

	local speed = options.Speed or 60
	local heightOffset = options.HeightOffset or 2.5
	local floorYOffset = options.FloorYOffset or -3
	local delayTime = options.DelayTime or 0
	local showPath = options.ShowPath or false
	
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

	-- Setup Cleanup & Lifecycle Handles for Isolated Local Shake
	local renderConnection: RBXScriptConnection?
	local shakerInstance: any?
	local sustainedShake: any?

	local function startCameraShake()
		-- Ensure execution ONLY runs locally on the Client
		if not RunService:IsClient() or not enableShake or renderConnection then return end

		-- Isolated CameraShaker Instance bound cleanly without interfering with main camera
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

			-- Cleanup when entity is destroyed or movement ends
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

			-- Distance check to conditionally enable shake ONLY within shakeRadius
			if isMoving then
				local character = LocalPlayer.Character
				if character and character:FindFirstChild("HumanoidRootPart") then
					local hrpPos = character.HumanoidRootPart.Position
					local entityPos = model:IsA("Model") and model:GetPivot().Position or model.Position
					local distance = (hrpPos - entityPos).Magnitude

					if distance <= shakeRadius then
						-- Instantiate shake only when player enters radius
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
						-- Fade out and clear shake when outside radius
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
	local targetSpawnNumber = math.max(0, latestRoomNumber - spawnOffsetRooms)
	local endRoomNumber = latestRoomNumber + 1

	-- Move entity directly to target point
	local function moveDirectTo(targetPos: Vector3?)
		if not targetPos or not model or not model.Parent then return end
		
		local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
		local segmentDistance = (targetPos - currentPos).Magnitude

		if segmentDistance > 0.001 then
			-- Initialize local proximity listener on first movement segment
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

		-- Calculate waypoints
		local waypoints = computePathWaypoints(startPos, endPos, heightOffset, floorYOffset, roomFolder)
		
		-- Optional Visual Path Render
		if showPath then
			local allNodes = {}
			if startNode then table.insert(allNodes, startNode + heightVector) end
			for _, wp in ipairs(waypoints) do table.insert(allNodes, wp) end
			if endNode then table.insert(allNodes, endNode + heightVector) end

			fullPathVisuals = renderDebugWaypoints(allNodes)
		end

		-- 1. Start door node move
		if startNode then
			moveDirectTo(startNode + heightVector)
		end

		-- 2. Waypoint traversal
		for _, nodePos in ipairs(waypoints) do
			moveDirectTo(nodePos)
		end

		-- 3. Exit door node move
		if endNode then
			moveDirectTo(endNode + heightVector)
		end

		-- Cleanup path visualization markers after segment completion
		if fullPathVisuals then
			fullPathVisuals:Destroy()
		end
	end

	-- Entity spawn setup
	local spawnRoom = currentRooms:FindFirstChild(tostring(targetSpawnNumber))
	if spawnRoom then
		local entFront = getRoomPositions(spawnRoom, floorYOffset)
		if entFront then
			local spawnPos = entFront + Vector3.new(0, heightOffset, 0)
			if model:IsA("Model") then
				model:PivotTo(CFrame.new(spawnPos))
			elseif model:IsA("BasePart") then
				model.Position = spawnPos
			end
		end
	end

	if delayTime > 0 then
		isMoving = false
		task.wait(delayTime)
	end

	local currentReboundState = 0

	-- Navigation processing loop
	while model and model.Parent do
		endRoomNumber = latestRoomValue.Value + 1

		if currentReboundState % 2 == 0 then
			-- Forward direction pass
			for roomNum = targetSpawnNumber, endRoomNumber do
				local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
				if roomFolder then
					local _, entBack, exitFront = getRoomPositions(roomFolder, floorYOffset)

					if entBack and exitFront then
						moveAlongWaypoints(entBack, exitFront, roomFolder, entBack, exitFront)
					end
				end
			end
		else
			-- Rebound direction pass
			for roomNum = endRoomNumber, targetSpawnNumber, -1 do
				local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
				if roomFolder then
					local _, entBack, exitFront = getRoomPositions(roomFolder, floorYOffset)

					if exitFront and entBack then
						moveAlongWaypoints(exitFront, entBack, roomFolder, exitFront, entBack)
					end
				end
			end
		end

		-- Evaluate rebound parameters
		if isRebound and currentReboundState < targetReboundCount then
			isMoving = false
			currentReboundState += 1
			if currentReboundState % 2 == 1 then
				if reboundTime > 0 then task.wait(reboundTime) end
			else
				if reboundDelayTime > 0 then task.wait(reboundDelayTime) end
			end
		else
			break
		end
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
