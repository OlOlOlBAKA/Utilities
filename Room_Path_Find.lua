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

-- Strictly aligns ONLY vertical Y height, with multi-level failsafes for floor detection
local function alignToFloor(position: Vector3, heightOffset: number, currentRooms: Instance): Vector3
	local floorTargets = {}

	for _, room in ipairs(currentRooms:GetChildren()) do
		local partsFolder = room:FindFirstChild("Parts")
		local searchContainer = partsFolder or room

		-- Primary search: Exact name "Floor"
		for _, descendant in ipairs(searchContainer:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name == "Floor" then
				table.insert(floorTargets, descendant)
			end
		end

		-- Secondary failsafe: Search for common floor keywords (case-insensitive)
		if #floorTargets == 0 then
			for _, descendant in ipairs(searchContainer:GetDescendants()) do
				if descendant:IsA("BasePart") then
					local lowerName = string.lower(descendant.Name)
					if string.find(lowerName, "floor") or string.find(lowerName, "base") or string.find(lowerName, "ground") then
						table.insert(floorTargets, descendant)
					end
				end
			end
		end

		-- Tertiary failsafe: Find thin, horizontal ground parts (Size.Y <= 3)
		if #floorTargets == 0 then
			for _, descendant in ipairs(searchContainer:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Size.Y <= 3 then
					table.insert(floorTargets, descendant)
				end
			end
		end
	end

	-- Ultimate fallback: Include all room instances if no individual floor parts were detected
	if #floorTargets == 0 then
		for _, room in ipairs(currentRooms:GetChildren()) do
			table.insert(floorTargets, room)
		end
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = floorTargets

	-- Start raycast downward from target position
	local startPos = position + Vector3.new(0, 3, 0)
	local rayResult = Workspace:Raycast(startPos, Vector3.new(0, -30, 0), raycastParams)

	if rayResult then
		-- Keep original X and Z, adjust ONLY vertical Y height
		return Vector3.new(position.X, rayResult.Position.Y + heightOffset, position.Z)
	end

	return position
end

local function computePathWaypoints(startPos: Vector3, endPos: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = 1,      -- Keeps entity safe from doorframes
		AgentHeight = 2.5,    -- Very low clearance for doorways and low ceilings
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

local function getRoomEntrancePosition(roomFolder: Instance): Vector3?
	local roomEntrance = roomFolder:FindFirstChild("RoomEntrance", true)
	if roomEntrance then
		if roomEntrance:IsA("BasePart") then
			return roomEntrance.Position
		elseif roomEntrance:IsA("Model") then
			return roomEntrance.PrimaryPart and roomEntrance.PrimaryPart.Position or roomEntrance:GetPivot().Position
		end
	end

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
			local entrancePos = getRoomEntrancePosition(roomFolder)
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
