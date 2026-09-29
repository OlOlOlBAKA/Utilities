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

local function alignToFloorLevel(position: Vector3, roomFolder: Instance?): Vector3
	if not roomFolder then return position end

	local floorParts = getRoomFloorParts(roomFolder)
	if #floorParts == 0 then return position end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = floorParts

	local startPos = Vector3.new(position.X, position.Y + 4, position.Z)
	local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -30, 0), raycastParams)

	if rayResult then
		return Vector3.new(position.X, rayResult.Position.Y, position.Z)
	end

	return position
end

-- Computes path sub-waypoints on demand (HeightOffset strictly applied ONLY to path nodes)
local function computePathWaypoints(startPos: Vector3, endPos: Vector3, heightOffset: number, roomFolder: Instance?): {Vector3}
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

	local rawWaypoints = {}
	if success and primaryPath.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(primaryPath:GetWaypoints()) do
			local groundPos = alignToFloorLevel(wp.Position, roomFolder)
			table.insert(rawWaypoints, groundPos + Vector3.new(0, heightOffset, 0))
		end
		return rawWaypoints
	end

	-- Fallback linear path
	local distance = (endPos - startPos).Magnitude
	local steps = math.max(2, math.ceil(distance / 5))

	for i = 1, steps do
		local alpha = i / steps
		local interpolated = startPos:Lerp(endPos, alpha)
		local groundPos = alignToFloorLevel(interpolated, roomFolder)
		table.insert(rawWaypoints, groundPos + Vector3.new(0, heightOffset, 0))
	end

	return rawWaypoints
end

-- Get Door Positions without HeightOffset
local function getRoomPositions(roomFolder: Instance): (Vector3?, Vector3?, Vector3?, Vector3?)
	local roomEntrance = roomFolder:FindFirstChild("RoomEntrance", true)
	local roomExit = roomFolder:FindFirstChild("RoomExit", true) or roomEntrance

	local entFront, entBack, exitFront, exitBack

	if roomEntrance then
		local cf = roomEntrance:IsA("BasePart") and roomEntrance.CFrame or (roomEntrance:IsA("Model") and (roomEntrance.PrimaryPart and roomEntrance.PrimaryPart.CFrame or roomEntrance:GetPivot()))
		if cf then
			entFront = alignToFloorLevel((cf * CFrame.new(0, 0, 2.5)).Position, roomFolder)
			entBack = alignToFloorLevel((cf * CFrame.new(0, 0, -2.5)).Position, roomFolder)
		end
	end

	if roomExit then
		local cf = roomExit:IsA("BasePart") and roomExit.CFrame or (roomExit:IsA("Model") and (roomExit.PrimaryPart and roomExit.PrimaryPart.CFrame or roomExit:GetPivot()))
		if cf then
			exitFront = alignToFloorLevel((cf * CFrame.new(0, 0, 2.5)).Position, roomFolder)
			exitBack = alignToFloorLevel((cf * CFrame.new(0, 0, -2.5)).Position, roomFolder)
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
	local endRoomNumber = latestRoomNumber + 1

	-- Helper to move smooth to target
	local function moveDirectTo(targetPos: Vector3)
		if not model or not model.Parent then return end
		
		local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
		local segmentDistance = (targetPos - currentPos).Magnitude

		if segmentDistance > 0.05 then
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
		end
	end

	-- Move through a series of sub-nodes on demand
	local function moveAlongWaypoints(startPos: Vector3, endPos: Vector3, roomFolder: Instance?)
		local waypoints = computePathWaypoints(startPos, endPos, heightOffset, roomFolder)
		for _, nodePos in ipairs(waypoints) do
			moveDirectTo(nodePos)
		end
	end

	-- Setup spawn position
	local spawnRoom = currentRooms:FindFirstChild(tostring(targetSpawnNumber))
	if spawnRoom then
		local entFront = getRoomPositions(spawnRoom)
		if entFront then
			if model:IsA("Model") then
				model:PivotTo(CFrame.new(entFront))
			elseif model:IsA("BasePart") then
				model.Position = entFront
			end
		end
	end

	if delayTime > 0 then
		task.wait(delayTime)
	end

	local currentReboundState = 0

	-- Main On-Demand Loop
	while model and model.Parent do
		endRoomNumber = latestRoomValue.Value + 1

		if currentReboundState % 2 == 0 then
			-- Forward Pass
			for roomNum = targetSpawnNumber, endRoomNumber do
				local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
				if roomFolder then
					local entFront, entBack, exitFront = getRoomPositions(roomFolder)
					local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position

					if entFront then
						moveAlongWaypoints(currentPos, entFront, roomFolder)
					end
					if entBack then
						currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
						moveAlongWaypoints(currentPos, entBack, roomFolder)
					end

					if roomNum == endRoomNumber and exitFront then
						currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
						moveAlongWaypoints(currentPos, exitFront, roomFolder)
					end
				end
				--task.wait() -- Prevents frame spikes during room iteration
			end
		else
			-- Backward Pass (Rebound)
			for roomNum = endRoomNumber, targetSpawnNumber, -1 do
				local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
				if roomFolder then
					local entFront, entBack, exitFront, exitBack = getRoomPositions(roomFolder)
					local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
					if entBack then 
						moveAlongWaypoints(currentPos, entBack, roomFolder) 
					end
					if entFront then
						currentPos = entFront.Position
						-- moveAlongWaypoints(currentPos, entFront, roomFolder) 
					end
				end
				-- task.wait() -- Prevents frame spikes during room iteration
			end
		end

		-- Check for Rebound trigger
		if isRebound and currentReboundState < targetReboundCount then
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
	
	-- Clean cache when done
	table.clear(roomFloorCache)
end

return PathfindingMovement
