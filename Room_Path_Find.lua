local PathfindingMovement = {}
PathfindingMovement.__index = PathfindingMovement

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")

local PathModule = require(ReplicatedStorage:WaitForChild("ModulesShared"):WaitForChild("Path"))

type MovementOptions = {
	Model: Model | BasePart,
	Speed: number?,
	HeightOffset: number?,
	DelayTime: number?,
	SpawnOffsetRooms: number?,
	
	Rebound: boolean?,
	ReboundCount: number?,
	ReboundTime: number?,
	ReboundDelayTime: number?
}

-- Disable Collisions on entity parts
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

-- Stop sounds on despawn
local function stopEntitySounds(instance: Instance)
	if not instance then return end
	if instance:IsA("Sound") then instance:Stop() end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Sound") then descendant:Stop() end
	end
end

-- Searches for any folder matching path/node keywords
local function findNodesContainer(roomFolder: Instance): Instance?
	for _, child in ipairs(roomFolder:GetChildren()) do
		local name = string.lower(child.Name)
		if string.match(name, "path") or string.match(name, "node") or string.match(name, "waypoint") or string.match(name, "point") then
			return child
		end
	end
	return nil
end

-- Extract vector positions from the node/path container
local function getRoomNodes(roomFolder: Instance): {Vector3}
	local nodes = {}
	local nodesContainer = findNodesContainer(roomFolder)

	if nodesContainer then
		local children = nodesContainer:GetChildren()
		
		table.sort(children, function(a, b)
			local numA = tonumber(string.match(a.Name, "%d+"))
			local numB = tonumber(string.match(b.Name, "%d+"))
			if numA and numB then
				return numA < numB
			end
			return a.Name < b.Name
		end)

		for _, node in ipairs(children) do
			if node:IsA("BasePart") then
				table.insert(nodes, node.Position)
			elseif node:IsA("Attachment") then
				table.insert(nodes, node.WorldPosition)
			end
		end
	end

	return nodes
end

-- Raycasts from Ceiling to Floor to check if objects in "Parts" folder block the room
local function generateSmartPath(startPos: Vector3, targetPos: Vector3, model: Instance, currentRoom: Instance): {Vector3}
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local ceilingPart = currentRoom:FindFirstChild("Ceiling", true)
	local floorPart = currentRoom:FindFirstChild("Floor", true)
	local partsFolder = currentRoom:FindFirstChild("Parts")

	local excludedInstances = { model }
	if ceilingPart then table.insert(excludedInstances, ceilingPart) end
	if floorPart then table.insert(excludedInstances, floorPart) end

	raycastParams.FilterDescendantsInstances = excludedInstances

	-- 1. Direct Horizontal Line-of-Sight Check
	local directDirection = (targetPos - startPos)
	local wallHit = Workspace:Raycast(startPos, directDirection, raycastParams)

	-- 2. Vertical Ceiling-to-Floor Check for objects in "Parts" folder
	local isPartsFolderBlocked = false

	if ceilingPart and floorPart and ceilingPart:IsA("BasePart") and floorPart:IsA("BasePart") then
		local topPos = ceilingPart.Position
		local bottomPos = floorPart.Position
		local rayDirection = bottomPos - topPos

		local verticalHit = Workspace:Raycast(topPos, rayDirection, raycastParams)

		if verticalHit and verticalHit.Instance then
			if partsFolder and verticalHit.Instance:IsDescendantOf(partsFolder) then
				isPartsFolderBlocked = true
			end
		end
	end

	-- Clear path: No horizontal wall collision AND no "Parts" folder obstacle vertically
	if not wallHit and not isPartsFolderBlocked then
		return { startPos, targetPos }
	end

	-- 3. PathfindingService Fallback
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4
	})

	local success, _ = pcall(function()
		path:ComputeAsync(startPos, targetPos)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local vectorSequence = {}
		for _, wp in ipairs(waypoints) do
			table.insert(vectorSequence, wp.Position)
		end
		return vectorSequence
	end

	return { startPos, wallHit and wallHit.Position or targetPos }
end

-- Build full sequence across target room numbers
local function buildSequenceForRooms(currentRooms: Instance, startRoom: number, endRoom: number, reverse: boolean): {Vector3}
	local fullSequence = {}

	if not reverse then
		for roomNum = startRoom, endRoom do
			local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
			if roomFolder then
				local roomNodes = getRoomNodes(roomFolder)
				for _, pos in ipairs(roomNodes) do
					table.insert(fullSequence, pos)
				end
			end
		end
	else
		for roomNum = endRoom, startRoom, -1 do
			local roomFolder = currentRooms:FindFirstChild(tostring(roomNum))
			if roomFolder then
				local roomNodes = getRoomNodes(roomFolder)
				for i = #roomNodes, 1, -1 do
					table.insert(fullSequence, roomNodes[i])
				end
			end
		end
	end

	return fullSequence
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

	local runner = PathModule.new()
	runner.WalkSpeed = speed

	local spawnSequence = buildSequenceForRooms(currentRooms, targetSpawnNumber, targetSpawnNumber, false)
	if #spawnSequence > 0 then
		local startPos = spawnSequence[1] + Vector3.new(0, heightOffset, 0)
		if model:IsA("Model") then
			model:PivotTo(CFrame.new(startPos))
		elseif model:IsA("BasePart") then
			model.Position = startPos
		end
	end

	if delayTime > 0 then
		task.wait(delayTime)
	end

	local currentReboundState = 0

	runner.stepCallback = function(_, p1, p2, currentPos, _, _)
		if not model or not model.Parent then return end

		local finalPos = currentPos + Vector3.new(0, heightOffset, 0)
		local lookTarget = p2 + Vector3.new(0, heightOffset, 0)

		local targetCFrame
		if (lookTarget - finalPos).Magnitude > 0.01 then
			targetCFrame = CFrame.lookAt(finalPos, lookTarget)
		else
			targetCFrame = CFrame.new(finalPos)
		end

		if model:IsA("Model") then
			model:PivotTo(targetCFrame)
		elseif model:IsA("BasePart") then
			model.CFrame = targetCFrame
		end
	end

	while model and model.Parent do
		local endRoomNumber = latestRoomValue.Value + 1
		local isReverse = (currentReboundState % 2 == 1)

		local sequence = buildSequenceForRooms(currentRooms, targetSpawnNumber, endRoomNumber, isReverse)

		if #sequence < 2 then
			local targetRoom = currentRooms:FindFirstChild(tostring(endRoomNumber)) or currentRooms:FindFirstChild(tostring(latestRoomValue.Value))
			if targetRoom then
				local startPos = model:IsA("Model") and model:GetPivot().Position or model.Position
				local targetPos = targetRoom:GetPivot().Position
				sequence = generateSmartPath(startPos, targetPos, model, targetRoom)
			else
				break
			end
		end

		runner:setSequence(sequence)
		runner:Play()

		local finished = false
		local heartbeatConnection
		heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
			if not model or not model.Parent or runner.Finished then
				finished = true
				if heartbeatConnection then heartbeatConnection:Disconnect() end
				return
			end

			runner:Step(dt)

			if runner.magProg >= runner.totalMag then
				finished = true
				runner:Pause()
				if heartbeatConnection then heartbeatConnection:Disconnect() end
			end
		end)

		repeat task.wait() until finished or not model or not model.Parent

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
