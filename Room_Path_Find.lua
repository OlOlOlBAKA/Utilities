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
	SpawnOffsetRooms: number?
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

-- Gets stable ground height by raycasting down specifically for large main floor parts
local function getStableFloorY(position: Vector3, roomFolder: Instance?): number
	local candidates = {}

	if roomFolder then
		local partsFolder = roomFolder:FindFirstChild("Parts")
		local searchContainer = partsFolder or roomFolder

		for _, descendant in ipairs(searchContainer:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local name = string.lower(descendant.Name)
				-- Only target primary floor geometry (ignore small props, steps, or thresholds)
				if (name == "floor" or string.find(name, "basefloor") or string.find(name, "mainfloor")) and descendant.Size.X > 4 and descendant.Size.Z > 4 then
					table.insert(candidates, descendant)
				end
			end
		end
	end

	-- Fallback raycast params if specific floor parts aren't tagged
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	if #candidates > 0 then
		raycastParams.FilterDescendantsInstances = candidates
	else
		raycastParams.FilterDescendantsInstances = Workspace:GetChildren()
	end

	local startPos = Vector3.new(position.X, position.Y + 10, position.Z)
	local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -50, 0), raycastParams)

	if rayResult then
		return rayResult.Position.Y
	end

	return position.Y
end

-- Computes sub-waypoints between start and end positions
local function computePathWaypoints(startPos: Vector3, endPos: Vector3): {Vector3}
	local primaryPath = PathfindingService:CreatePath({
		AgentRadius = 1,
		AgentHeight = 2.5,
		AgentCanJump = false,
		WaypointSpacing = 2,
		Costs = { Default = 1 }
	})

	local success, _ = pcall(function()
		primaryPath:ComputeAsync(startPos, endPos)
	end)

	local rawWaypoints = {}
	if success and primaryPath.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(primaryPath:GetWaypoints()) do
			table.insert(rawWaypoints, wp.Position)
		end
		return rawWaypoints
	end

	-- Fallback linear interpolation points
	local distance = (endPos - startPos).Magnitude
	local steps = math.max(2, math.ceil(distance / 4))

	for i = 1, steps do
		local alpha = i / steps
		table.insert(rawWaypoints, startPos:Lerp(endPos, alpha))
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

	local globalWaypointQueue: {Vector3} = {}
	local highestProcessedRoom = -1
	local lastTargetPos: Vector3? = nil

	local function addRoomToPath(roomNum: number)
		local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
		if roomFolder then
			local frontPos, backPos = getEntrancePositions(roomFolder)
			
			if frontPos and backPos then
				-- Calculate floor Y level once per room segment for perfect stability
				local roomFloorY = getStableFloorY(frontPos, roomFolder) + heightOffset
				
				local stableFront = Vector3.new(frontPos.X, roomFloorY, frontPos.Z)
				local stableBack = Vector3.new(backPos.X, roomFloorY, backPos.Z)

				if lastTargetPos then
					local subPoints = computePathWaypoints(lastTargetPos, stableFront)
					for _, pt in ipairs(subPoints) do
						table.insert(globalWaypointQueue, Vector3.new(pt.X, roomFloorY, pt.Z))
					end
				else
					table.insert(globalWaypointQueue, stableFront)
				end

				table.insert(globalWaypointQueue, stableBack)
				lastTargetPos = stableBack
				highestProcessedRoom = roomNum
			end
		end
	end

	for roomNum = targetSpawnNumber, latestRoomValue.Value + 1 do
		addRoomToPath(roomNum)
	end

	local roomAddedConnection = currentRooms.ChildAdded:Connect(function(child)
		local roomNum = tonumber(child.Name)
		if roomNum and roomNum > highestProcessedRoom then
			if not (child:FindFirstChild("RoomEntrance", true) or child:FindFirstChild("RoomExit", true)) then
				task.wait(0.1)
			end
			addRoomToPath(roomNum)
		end
	end)

	if #globalWaypointQueue == 0 then
		warn("PathfindingMovement: No valid rooms/waypoints found.")
		roomAddedConnection:Disconnect()
		return
	end

	local initialPosition = globalWaypointQueue[1]
	if model:IsA("Model") then
		model:PivotTo(CFrame.new(initialPosition))
	elseif model:IsA("BasePart") then
		model.Position = initialPosition
	end

	if delayTime > 0 then
		task.wait(delayTime)
	end

	-- Smooth continuous execution loop
	local queueIndex = 2
	local active = true

	while active do
		if queueIndex > #globalWaypointQueue then
			task.wait(0.05)
			if queueIndex > #globalWaypointQueue then
				active = false
				break
			end
		end

		local targetPos = globalWaypointQueue[queueIndex]
		local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
		
		-- Flatten movement direction so orientation stays horizontal
		local flatCurrentPos = Vector3.new(currentPos.X, targetPos.Y, currentPos.Z)
		local segmentDistance = (targetPos - flatCurrentPos).Magnitude

		if segmentDistance > 0.05 then
			local travelTime = segmentDistance / speed
			local lookTarget = targetPos + (targetPos - flatCurrentPos).Unit
			local targetCFrame = CFrame.lookAt(targetPos, Vector3.new(lookTarget.X, targetPos.Y, lookTarget.Z))
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

		queueIndex += 1
	end

	roomAddedConnection:Disconnect()

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

		-- Stop entity sounds AFTER falling 300 studs
		stopEntitySounds(model)

		model:Destroy()
	end
end

return PathfindingMovement
