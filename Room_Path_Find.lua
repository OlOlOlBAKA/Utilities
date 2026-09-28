local PathfindingMovement = {}
PathfindingMovement.__index = PathfindingMovement

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

type MovementOptions = {
	Model: Model | BasePart,
	Speed: number?,
	HeightOffset: number?,
	DelayTime: number?,
	SpawnOffsetRooms: number?,
	
	-- Rebound System Options
	Rebound: boolean?,
	ReboundCount: number?,
	ReboundTime: number?,      -- Delay at the end before heading back
	ReboundDelayTime: number?  -- Delay at the start/origin before starting return sweep
}

-- Types for global waypoint queue items
type ActionType = "MOVE" | "WAIT"

type WaypointNode = {
	Type: ActionType,
	Position: Vector3?,
	WaitDuration: number?
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

-- Fallback floor alignment only used if pathfinding fails
local function getFallbackFloorY(position: Vector3, heightOffset: number): Vector3
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = {Workspace:FindFirstChild("CurrentRooms") or Workspace}

	local startPos = Vector3.new(position.X, position.Y + 10, position.Z)
	local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -50, 0), raycastParams)

	if rayResult then
		return Vector3.new(position.X, rayResult.Position.Y + heightOffset, position.Z)
	end

	return position
end

-- Computes sub-waypoints preserving 3D stair / height transitions
local function computePathWaypoints(startPos: Vector3, endPos: Vector3, heightOffset: number): {Vector3}
	local primaryPath = PathfindingService:CreatePath({
		AgentRadius = 1,
		AgentHeight = 2.5,
		AgentCanJump = false,
		WaypointSpacing = 2.5,
		Costs = { Default = 1 }
	})

	local success, _ = pcall(function()
		primaryPath:ComputeAsync(startPos, endPos)
	end)

	local rawWaypoints = {}
	if success and primaryPath.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(primaryPath:GetWaypoints()) do
			table.insert(rawWaypoints, wp.Position + Vector3.new(0, heightOffset, 0))
		end
		return rawWaypoints
	end

	-- Fallback linear interpolation points if pathfinding fails
	local distance = (endPos - startPos).Magnitude
	local steps = math.max(2, math.ceil(distance / 4))

	for i = 1, steps do
		local alpha = i / steps
		local interpolated = startPos:Lerp(endPos, alpha)
		table.insert(rawWaypoints, getFallbackFloorY(interpolated, heightOffset))
	end

	return rawWaypoints
end

-- Gets Front (+2.5 studs) and Behind (-2.5 studs) positions for doorway navigation
local function getEntrancePositions(roomFolder: Instance): (Vector3?, Vector3?)
	local roomEntrance = roomFolder:FindFirstChild("RoomEntrance", true) or roomFolder:FindFirstChild("RoomExit", true)
	
	if roomEntrance then
		local cframe: CFrame?
		
		if roomEntrance:IsA("BasePart") then
			cframe = roomEntrance.CFrame
		elseif roomEntrance:IsA("Model") then
			cframe = roomEntrance.PrimaryPart and roomEntrance.PrimaryPart.CFrame or roomEntrance:GetPivot()
		end

		if cframe then
			local frontPos = (cframe * CFrame.new(0, 0, 2.5)).Position
			local backPos = (cframe * CFrame.new(0, 0, -2.5)).Position
			return frontPos, backPos
		end
	end

	local fallbackPos: Vector3?
	if roomFolder:IsA("Model") then
		fallbackPos = roomFolder.PrimaryPart and roomFolder.PrimaryPart.Position or roomFolder:GetPivot().Position
	elseif roomFolder:IsA("BasePart") then
		fallbackPos = roomFolder.Position
	end
	
	return fallbackPos, fallbackPos
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
	local delayTime = options.DelayTime or 0
	
	local rawOffset = options.SpawnOffsetRooms or 10
	local spawnOffsetRooms = math.clamp(rawOffset, 0, 15)

	-- Rebound Settings
	local isRebound = options.Rebound or false
	local maxRebounds = options.ReboundCount or 1
	local reboundTime = options.ReboundTime or 0
	local reboundDelayTime = options.ReboundDelayTime or 0

	if model.Parent ~= Workspace then
		model.Parent = Workspace
	end

	local currentRooms = Workspace:WaitForChild("CurrentRooms", 10)
	local gameData = ReplicatedStorage:WaitForChild("GameData", 10)
	local latestRoomValue = gameData and gameData:WaitForChild("LatestRoom", 10)

	if not currentRooms or not latestRoomValue then
		warn("PathfindingMovement: CurrentRooms or GameData.LatestRoom missing!")
		return
	end

	local latestRoomNumber = latestRoomValue.Value
	local targetSpawnNumber = math.max(0, latestRoomNumber - spawnOffsetRooms)

	local globalQueue: {WaypointNode} = {}
	local lastTargetPos: Vector3? = nil
	local currentReboundCount = 0

	local function appendMoveTarget(rawPos: Vector3)
		local targetWithHeight = rawPos + Vector3.new(0, heightOffset, 0)
		if lastTargetPos then
			local subPoints = computePathWaypoints(lastTargetPos, rawPos, heightOffset)
			for _, pt in ipairs(subPoints) do
				table.insert(globalQueue, { Type = "MOVE", Position = pt })
			end
		else
			table.insert(globalQueue, { Type = "MOVE", Position = targetWithHeight })
		end
		lastTargetPos = targetWithHeight
	end

	local function appendWait(duration: number)
		if duration > 0 then
			table.insert(globalQueue, { Type = "WAIT", WaitDuration = duration })
		end
	end

	-- Forward Path Construction
	local function buildForwardPath(startNum: number, endNum: number)
		for roomNum = startNum, endNum do
			local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
			if roomFolder then
				local frontPos, backPos = getEntrancePositions(roomFolder)
				if frontPos and backPos then
					appendMoveTarget(frontPos)
					appendMoveTarget(backPos)
				end
			end
		end
	end

	-- Backward Path Construction (Rebound)
	local function buildBackwardPath(startNum: number, endNum: number)
		for roomNum = startNum, endNum, -1 do
			local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
			if roomFolder then
				local frontPos, backPos = getEntrancePositions(roomFolder)
				if frontPos and backPos then
					appendMoveTarget(backPos)
					appendMoveTarget(frontPos)
				end
			end
		end
	end

	-- Build initial sweep
	local endRoomNumber = latestRoomValue.Value + 1
	buildForwardPath(targetSpawnNumber, endRoomNumber)

	if isRebound then
		while currentReboundCount < maxRebounds do
			currentReboundCount += 1
			
			-- Pause at RoomExit of latest room before going back
			appendWait(reboundTime)
			
			-- Sweep backwards to earliest room entrance
			buildBackwardPath(endRoomNumber, targetSpawnNumber)
			
			-- Pause at earliest room entrance before sweeping forward again (if multi-rebound)
			if currentReboundCount < maxRebounds then
				appendWait(reboundDelayTime)
				buildForwardPath(targetSpawnNumber, endRoomNumber)
			end
		end
	end

	if #globalQueue == 0 then
		warn("PathfindingMovement: No valid waypoints generated.")
		return
	end

	-- Position Entity at Initial Spawn Point
	local initialNode = globalQueue[1]
	if initialNode and initialNode.Position then
		if model:IsA("Model") then
			model:PivotTo(CFrame.new(initialNode.Position))
		elseif model:IsA("BasePart") then
			model.Position = initialNode.Position
		end
	end

	if delayTime > 0 then
		task.wait(delayTime)
	end

	-- Execute Queue Sequence
	local queueIndex = 2
	local active = true

	while active do
		if queueIndex > #globalQueue then
			active = false
			break
		end

		local node = globalQueue[queueIndex]

		if node.Type == "WAIT" then
			task.wait(node.WaitDuration or 0)
		elseif node.Type == "MOVE" and node.Position then
			local targetPos = node.Position
			local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
			local segmentDistance = (targetPos - currentPos).Magnitude

			if segmentDistance > 0.05 then
				local travelTime = segmentDistance / speed
				local direction = (targetPos - currentPos).Unit
				local lookTarget = targetPos + direction
				local targetCFrame = CFrame.lookAt(targetPos, lookTarget)
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
			end
		end

		queueIndex += 1
	end

	-- Gravity fall sequence before despawning
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

			connection:Disconnect()
			CFrameValue:Destroy()
		end

		-- Stop entity audio tracks
		stopEntitySounds(model)

		model:Destroy()
	end
end

return PathfindingMovement
