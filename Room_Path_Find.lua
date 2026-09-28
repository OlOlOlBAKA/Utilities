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
	ReboundTime: number?,
	ReboundDelayTime: number?
}

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

-- Strictly samples ground level while ignoring ceilings, roofs, and overhead structures
local function alignToFloorLevel(position: Vector3, heightOffset: number): Vector3
	local currentRooms = Workspace:FindFirstChild("CurrentRooms")
	if not currentRooms then
		return position + Vector3.new(0, heightOffset, 0)
	end

	-- Collect valid floor candidates, ignoring ceilings and roofs
	local validFloorTargets = {}
	for _, room in ipairs(currentRooms:GetChildren()) do
		for _, descendant in ipairs(room:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local name = string.lower(descendant.Name)
				local isCeiling = string.find(name, "ceiling") or string.find(name, "roof") or string.find(name, "top")
				if not isCeiling then
					table.insert(validFloorTargets, descendant)
				end
			end
		end
	end

	if #validFloorTargets == 0 then
		return position + Vector3.new(0, heightOffset, 0)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = validFloorTargets

	-- Raycast down starting close to position height (below ceiling level)
	local startPos = Vector3.new(position.X, position.Y + 4, position.Z)
	local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -30, 0), raycastParams)

	if rayResult then
		return Vector3.new(position.X, rayResult.Position.Y + heightOffset, position.Z)
	end

	return position + Vector3.new(0, heightOffset, 0)
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
		table.insert(rawWaypoints, alignToFloorLevel(interpolated, heightOffset))
	end

	return rawWaypoints
end

-- Gets Entrance (Front/Back) and Exit (Front/Back) positions for exact room bounds
local function getRoomPositions(roomFolder: Instance, heightOffset: number): (Vector3?, Vector3?, Vector3?, Vector3?)
	local roomEntrance = roomFolder:FindFirstChild("RoomEntrance", true)
	local roomExit = roomFolder:FindFirstChild("RoomExit", true) or roomEntrance

	local entFront, entBack, exitFront, exitBack

	if roomEntrance then
		local cf = roomEntrance:IsA("BasePart") and roomEntrance.CFrame or (roomEntrance:IsA("Model") and (roomEntrance.PrimaryPart and roomEntrance.PrimaryPart.CFrame or roomEntrance:GetPivot()))
		if cf then
			entFront = alignToFloorLevel((cf * CFrame.new(0, 0, 2.5)).Position, heightOffset)
			entBack = alignToFloorLevel((cf * CFrame.new(0, 0, -2.5)).Position, heightOffset)
		end
	end

	if roomExit then
		local cf = roomExit:IsA("BasePart") and roomExit.CFrame or (roomExit:IsA("Model") and (roomExit.PrimaryPart and roomExit.PrimaryPart.CFrame or roomExit:GetPivot()))
		if cf then
			exitFront = alignToFloorLevel((cf * CFrame.new(0, 0, 2.5)).Position, heightOffset)
			exitBack = alignToFloorLevel((cf * CFrame.new(0, 0, -2.5)).Position, heightOffset)
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
	local delayTime = options.DelayTime or 0
	
	local rawOffset = options.SpawnOffsetRooms or 10
	local spawnOffsetRooms = math.clamp(rawOffset, 0, 15)

	-- Rebound Settings
	local isRebound = options.Rebound or false
	local targetReboundCount = options.ReboundCount or 1
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

	local function appendMoveTarget(rawPos: Vector3)
		if lastTargetPos then
			local subPoints = computePathWaypoints(lastTargetPos, rawPos, 0)
			for _, pt in ipairs(subPoints) do
				table.insert(globalQueue, { Type = "MOVE", Position = pt })
			end
		else
			table.insert(globalQueue, { Type = "MOVE", Position = rawPos })
		end
		lastTargetPos = rawPos
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
				local entFront, entBack, exitFront, exitBack = getRoomPositions(roomFolder, heightOffset)
				
				if roomNum == endNum and exitFront then
					if entFront then appendMoveTarget(entFront) end
					if entBack then appendMoveTarget(entBack) end
					appendMoveTarget(exitFront)
				else
					if entFront and entBack then
						appendMoveTarget(entFront)
						appendMoveTarget(entBack)
					end
				end
			end
		end
	end

	-- Backward Path Construction
	local function buildBackwardPath(startNum: number, endNum: number)
		for roomNum = startNum, endNum, -1 do
			local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
			if roomFolder then
				local entFront, entBack, exitFront, exitBack = getRoomPositions(roomFolder, heightOffset)
				
				if exitFront and exitBack then
					appendMoveTarget(exitFront)
					appendMoveTarget(exitBack)
				end
				if entBack and entFront then
					appendMoveTarget(entBack)
					appendMoveTarget(entFront)
				end
			end
		end
	end

	local currentReboundState = 0
	local endRoomNumber = latestRoomValue.Value + 1

	-- Initial sweep (Rebound 0)
	buildForwardPath(targetSpawnNumber, endRoomNumber)

	-- Dynamically append newly opened rooms
	local roomAddedConnection
	roomAddedConnection = currentRooms.ChildAdded:Connect(function(child)
		local roomNum = tonumber(child.Name)
		if roomNum and roomNum > endRoomNumber then
			endRoomNumber = roomNum
			if currentReboundState % 2 == 0 then
				local entFront, entBack, exitFront = getRoomPositions(child, heightOffset)
				if entFront then appendMoveTarget(entFront) end
				if entBack then appendMoveTarget(entBack) end
				if exitFront then appendMoveTarget(exitFront) end
			end
		end
	end)

	if #globalQueue == 0 then
		warn("PathfindingMovement: No valid waypoints generated.")
		if roomAddedConnection then roomAddedConnection:Disconnect() end
		return
	end

	-- Position Entity at Spawn Point
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

	-- Execution Loop
	local queueIndex = 2
	local active = true

	while active do
		if queueIndex > #globalQueue then
			if isRebound and currentReboundState < targetReboundCount then
				currentReboundState += 1
				
				if currentReboundState % 2 == 1 then
					appendWait(reboundTime)
					buildBackwardPath(endRoomNumber, targetSpawnNumber)
				else
					appendWait(reboundDelayTime)
					buildForwardPath(targetSpawnNumber, endRoomNumber)
				end
			else
				active = false
				break
			end
		end

		local node = globalQueue[queueIndex]

		if node and node.Type == "WAIT" then
			task.wait(node.WaitDuration or 0)
		elseif node and node.Type == "MOVE" and node.Position then
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

	if roomAddedConnection then
		roomAddedConnection:Disconnect()
	end

	-- Despawn Gravity Fall
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

		stopEntitySounds(model)
		model:Destroy()
	end
end

return PathfindingMovement
