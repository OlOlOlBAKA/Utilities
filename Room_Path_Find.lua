local PathfindingMovement = {}
PathfindingMovement.__index = PathfindingMovement

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local NodeObject = require(ReplicatedStorage:WaitForChild("NodeObject"))

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

-- Safely aligns Y height for multi-story / multi-floor rooms
local function alignToFloor(position: Vector3, heightOffset: number, currentRooms: Instance): Vector3
	local allCandidates = {}

	-- Collect all candidate floor parts across active rooms
	for _, room in ipairs(currentRooms:GetChildren()) do
		local partsFolder = room:FindFirstChild("Parts")
		local searchContainer = partsFolder or room

		for _, descendant in ipairs(searchContainer:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local lowerName = string.lower(descendant.Name)
				if lowerName == "floor" or string.find(lowerName, "floor") or string.find(lowerName, "base") or descendant.Size.Y <= 3 then
					table.insert(allCandidates, descendant)
				end
			end
		end
	end

	-- Filter floor targets down to parts nearby vertically (within 15 studs)
	local validFloorTargets = {}
	for _, part in ipairs(allCandidates) do
		local verticalDist = math.abs(part.Position.Y - position.Y)
		if verticalDist <= 15 then
			table.insert(validFloorTargets, part)
		end
	end

	-- Fallback if no nearby floors match vertical range criteria
	if #validFloorTargets == 0 then
		validFloorTargets = #allCandidates > 0 and allCandidates or currentRooms:GetChildren()
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = validFloorTargets

	-- Start raycast downward from target position
	local startPos = position + Vector3.new(0, 4, 0)
	local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -35, 0), raycastParams)

	if rayResult then
		return Vector3.new(position.X, rayResult.Position.Y + heightOffset, position.Z)
	end

	return position
end

local function computePathWaypoints(startPos: Vector3, endPos: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = 1,      -- Small radius to clear doorframes
		AgentHeight = 2.5,    -- Low height for ceiling clearance
		AgentCanJump = false,
		WaypointSpacing = 2,
		Costs = {
			Default = 1
		}
	})

	local success, err = pcall(function()
		path:ComputeAsync(startPos, endPos)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	else
		warn("[PathfindingMovement] Pathfinding status: " .. tostring(path.Status) .. " | Reason: " .. tostring(err))
		return {
			{ Position = startPos },
			{ Position = endPos }
		}
	end
end

-- Offsets target position 2.5 studs IN FRONT of the RoomEntrance to avoid doorframe collision boxes
local function getFrontOfEntrancePosition(roomFolder: Instance): Vector3?
	local roomEntrance = roomFolder:FindFirstChild("RoomEntrance", true)
	
	if roomEntrance then
		local cframe: CFrame?
		
		if roomEntrance:IsA("BasePart") then
			cframe = roomEntrance.CFrame
		elseif roomEntrance:IsA("Model") then
			cframe = roomEntrance.PrimaryPart and roomEntrance.PrimaryPart.CFrame or roomEntrance:GetPivot()
		end

		if cframe then
			return (cframe * CFrame.new(0, 0, -2.5)).Position
		end
	end

	-- Fallback to model pivot/position if RoomEntrance isn't found
	if roomFolder:IsA("Model") then
		return roomFolder.PrimaryPart and roomFolder.PrimaryPart.Position or roomFolder:GetPivot().Position
	elseif roomFolder:IsA("BasePart") then
		return roomFolder.Position
	end
	
	return nil
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

	local lastNode = nil
	local firstNode = nil
	local highestProcessedRoom = -1

	local function addRoomToPath(roomNum: number)
		local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
		if roomFolder then
			local entrancePos = getFrontOfEntrancePosition(roomFolder)
			if entrancePos then
				local newNode = NodeObject.new(entrancePos)

				if not firstNode then
					firstNode = newNode
				end

				if lastNode then
					lastNode:setNext(newNode)
				end

				lastNode = newNode
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
			if not child:FindFirstChild("RoomEntrance", true) then
				child:WaitForChild("RoomEntrance", 2)
			end
			addRoomToPath(roomNum)
		end
	end)

	if not firstNode then
		warn("PathfindingMovement: No valid rooms/nodes found.")
		roomAddedConnection:Disconnect()
		return
	end

	local currentNode = firstNode
	local initialPosition = alignToFloor(currentNode:getPosition(), heightOffset, currentRooms)

	if model:IsA("Model") then
		model:PivotTo(CFrame.new(initialPosition))
	elseif model:IsA("BasePart") then
		model.Position = initialPosition
	end

	if delayTime > 0 then
		task.wait(delayTime)
	end

	while currentNode do
		local nextNodes = currentNode:getAllNext()

		if #nextNodes == 0 then
			task.wait(0.3)
			nextNodes = currentNode:getAllNext()

			if #nextNodes == 0 then
				break
			end
		end

		local nextNode = nextNodes[1]
		local startPos = currentNode:getPosition()
		local endPos = nextNode:getPosition()

		local waypoints = computePathWaypoints(startPos, endPos)

		for i = 1, #waypoints do
			local rawTargetPos = waypoints[i].Position
			local targetPos = alignToFloor(rawTargetPos, heightOffset, currentRooms)

			local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
			local segmentDistance = (targetPos - currentPos).Magnitude

			if segmentDistance > 0.05 then
				local travelTime = segmentDistance / speed
				local targetCFrame = CFrame.lookAt(targetPos, targetPos + (targetPos - currentPos).Unit)
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

		currentNode = nextNode
	end

	roomAddedConnection:Disconnect()

	-- Stop all entity sounds when path finishes
	stopEntitySounds(model)

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

		model:Destroy()
	end
end

return PathfindingMovement
