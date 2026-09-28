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
	HeightOffset: number?
}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function alignToFloor(position: Vector3, heightOffset: number): Vector3
	local rayResult = Workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), raycastParams)
	if rayResult then
		return rayResult.Position + Vector3.new(0, heightOffset, 0)
	end
	return position
end

local function visualizePathSegment(p1: Vector3, p2: Vector3)
	local visualizerFolder = Workspace:FindFirstChild("PathfindingVisualizer")
	if not visualizerFolder then
		visualizerFolder = Instance.new("Folder")
		visualizerFolder.Name = "PathfindingVisualizer"
		visualizerFolder.Parent = Workspace
	end

	local distance = (p2 - p1).Magnitude
	if distance < 0.1 then return end

	local linePart = Instance.new("Part")
	linePart.Size = Vector3.new(0.3, 0.3, distance)
	linePart.Material = Enum.Material.Neon
	linePart.Color = Color3.fromRGB(0, 255, 255)
	linePart.Transparency = 0.3
	linePart.CanCollide = false
	linePart.Anchored = true
	linePart.CFrame = CFrame.new((p1 + p2) / 2, p2)
	linePart.Name = "PathfindingLine"
	linePart.Parent = visualizerFolder
end

local function computePathWaypoints(startPos: Vector3, endPos: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
		Costs = { Default = 1 }
	})

	local success = pcall(function()
		path:ComputeAsync(startPos, endPos)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		for i = 1, #waypoints - 1 do
			visualizePathSegment(waypoints[i].Position, waypoints[i + 1].Position)
		end
		return waypoints
	else
		visualizePathSegment(startPos, endPos)
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

	local speed = options.Speed or 60
	local heightOffset = options.HeightOffset or 2.5

	local currentRooms = Workspace:WaitForChild("CurrentRooms", 10)
	local gameData = ReplicatedStorage:WaitForChild("GameData", 10)
	local latestRoomValue = gameData and gameData:WaitForChild("LatestRoom", 10)

	if not currentRooms or not latestRoomValue then
		warn("PathfindingMovement: CurrentRooms or GameData.LatestRoom missing!")
		return
	end

	raycastParams.FilterDescendantsInstances = { model }

	local latestRoomNumber = latestRoomValue.Value
	local targetSpawnNumber = math.max(0, latestRoomNumber - 10)

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

	-- Build initial node path
	for roomNum = targetSpawnNumber, latestRoomValue.Value + 1 do
		addRoomToPath(roomNum)
	end

	-- Dynamically append rooms as new ones generate
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

	-- Teleport model to start position
	local currentNode = firstNode
	local initialPosition = alignToFloor(currentNode:getPosition(), heightOffset)

	if model:IsA("Model") then
		model:PivotTo(CFrame.new(initialPosition))
	elseif model:IsA("BasePart") then
		model.Position = initialPosition
	end

	-- Travel node by node
	while currentNode do
		if currentNode.visualizeNode then
			currentNode:visualizeNode()
		end

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
			local targetPos = alignToFloor(rawTargetPos, heightOffset)

			local currentPos = model:IsA("Model") and model:GetPivot().Position or model.Position
			local segmentDistance = (targetPos - currentPos).Magnitude

			if segmentDistance > 0.1 then
				local travelTime = segmentDistance / speed
				local targetCFrame = CFrame.lookAt(targetPos, targetPos + (targetPos - currentPos))
				local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)

				if model:IsA("BasePart") then
					local tween = TweenService:Create(model, tweenInfo, { CFrame = targetCFrame })
					tween:Play()
					tween.Completed:Wait()
				elseif model:IsA("Model") then
					local CFrameValue = Instance.new("CFrameValue")
					CFrameValue.Value = model:GetPivot()

					local connection = CFrameValue.Changed:Connect(function(newCFrame)
						model:PivotTo(newCFrame)
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
end

return PathfindingMovement
