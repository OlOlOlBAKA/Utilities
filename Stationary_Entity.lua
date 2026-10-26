local httpSuccess, rawCode = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua")
end)

if httpSuccess and rawCode then
	local loadedFunc, err = loadstring(rawCode)
	if type(loadedFunc) == "function" then
		pcall(loadedFunc)
	else
		warn("PathfindingMovement: Failed to compile HTTP code ->", err)
	end
else
	warn("PathfindingMovement: Failed to fetch HTTP functions ->", rawCode)
end

--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer

local StationaryEntity = {}
StationaryEntity.__index = StationaryEntity

local CrucifixAssets = {
	Repentance = nil
}

task.spawn(function()
	local fetchFunc = (typeof(getgenv) == "function" and getgenv().LoadCustomInstance) or _G.LoadCustomInstance or (typeof(LoadCustomInstance) == "function" and LoadCustomInstance)
	if typeof(fetchFunc) == "function" then
		pcall(function()
			CrucifixAssets.Repentance = fetchFunc("https://github.com/RegularVynixu/DOORS-Entity-Spawner-V2/raw/main/Assets/Repentance.rbxm")
		end)
	end
end)

local CrucifixStorage = {
	CrucifixTypes = {
		["guiding"] = { Color = Color3.fromRGB(137, 207, 255) },
		["curious"] = { Color = Color3.fromRGB(255, 227, 137) }
	}
}

local function getRoomCenter(roomInstance: Instance): Vector3?
	if not roomInstance or not roomInstance:IsA("Model") then return nil end

	local partsFolder = roomInstance:FindFirstChild("Parts")
	local assetsFolder = roomInstance:FindFirstChild("Assets")
	local roomCF, roomSize = roomInstance:GetBoundingBox()

	-- Helper to check if an instance belongs to a sideroom, subroom, or stair steps
	local function isExcluded(inst: Instance): boolean
		local curr = inst
		while curr and curr ~= roomInstance do
			local nameLower = curr.Name:lower()
			if nameLower:find("sideroom") or nameLower:find("subroom") or nameLower:find("steps") or nameLower:find("stair") or nameLower:find("closet") or nameLower:find("secret") then
				return true
			end
			curr = curr.Parent
		end
		return false
	end

	local floors = {}
	local obstacles = {} -- Collects walls, pillars, AND furniture/assets

	local function scanFolder(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if isExcluded(child) then continue end
			local nameLower = child.Name:lower()

			if child:IsA("BasePart") then
				if nameLower == "floor" or nameLower:find("floor") then
					table.insert(floors, child)
				elseif child.CanCollide then
					table.insert(obstacles, child)
				end
			elseif child:IsA("Model") or child:IsA("Folder") then
				scanFolder(child)
			end
		end
	end

	-- Scan both Parts and Assets folders
	if partsFolder then scanFolder(partsFolder) end
	if assetsFolder then scanFolder(assetsFolder) end
	scanFolder(roomInstance) -- Fallback scan of the main room

	-- Determine true ground floor Y level
	local groundY = roomCF.Position.Y - (roomSize.Y / 2) + 3
	if #floors > 0 then
		local minY = math.huge
		for _, f in ipairs(floors) do
			local topY = f.Position.Y + (f.Size.Y / 2)
			if topY < minY then minY = topY end
		end
		if minY ~= math.huge then groundY = minY end
	end

	local spawnY = groundY + 2.5
	local bestPos = nil
	local maxMinDist = -1

	-- Grid scan across the room space to find the open center away from walls and furniture
	local step = 3
	for x = -roomSize.X / 2 + 4, roomSize.X / 2 - 4, step do
		for z = -roomSize.Z / 2 + 4, roomSize.Z / 2 - 4, step do
			local localPos = Vector3.new(x, 0, z)
			local worldPos = roomCF:PointToWorldSpace(localPos)
			local testPos = Vector3.new(worldPos.X, spawnY, worldPos.Z)

			-- Check distance and collision against all collected walls, pillars, and assets
			local isInsideObstacle = false
			local minDist = math.huge

			for _, obs in ipairs(obstacles) do
				local rel = obs.CFrame:PointToObjectSpace(testPos)
				local oSize = obs.Size
				if math.abs(rel.X) <= (oSize.X / 2 + 2) and math.abs(rel.Y) <= (oSize.Y / 2 + 3) and math.abs(rel.Z) <= (oSize.Z / 2 + 2) then
					isInsideObstacle = true
					break
				end

				local dist = (testPos - obs.Position).Magnitude
				if dist < minDist then minDist = dist end
			end

			if not isInsideObstacle then
				-- Verify ceiling clearance via raycast
				local rayParams = RaycastParams.new()
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				local excludeList = {}
				for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
					if p.Character then table.insert(excludeList, p.Character) end
				end
				rayParams.FilterDescendantsInstances = excludeList

				local ceilingHit = Workspace:Raycast(testPos, Vector3.new(0, 8, 0), rayParams)
				if not ceilingHit and minDist > maxMinDist then
					maxMinDist = minDist
					bestPos = testPos
				end
			end
		end
	end

	if bestPos then
		print("Got best one")
		return bestPos
	end

	-- Fallback to room center
	print("Failed")
	return Vector3.new(roomCF.Position.X, spawnY, roomCF.Position.Z)
end

local function defaultCheckCrucifix(character: Model): (boolean, Tool?)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local toolName = string.lower(child.Name)
			local isCrucifix = string.find(toolName, "crucifix") ~= nil 
				or child:GetAttribute("IsCrucifix") == true
				or CollectionService:HasTag(child, "Crucifix")
				or child:FindFirstChild("Crucifix") ~= nil
				
			if isCrucifix then
				return true, child
			end
		end
	end
	return false, nil
end

local function performCrucifixion(entityModel: Instance, character: Model, shakerInstance: any): boolean
	if not CrucifixAssets.Repentance then return false end

	local entityPivot = entityModel:IsA("Model") and entityModel:GetPivot() or entityModel.CFrame
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, entityModel }

	local rayResult = Workspace:Raycast(entityPivot.Position, Vector3.new(0, -1000, 0), rayParams)
	if not rayResult then return false end

	local repentance = CrucifixAssets.Repentance:Clone()
	local crucifix = repentance.Crucifix
	local handle = crucifix.Handle
	local pentagram = repentance.Pentagram
	local entityPart = repentance.Entity
	local sound = handle.Sound

	repentance:PivotTo(CFrame.new(rayResult.Position))
	crucifix:PivotTo(character:GetPivot())
	entityPart.CFrame = entityPivot
	repentance.Parent = Workspace
	sound:Play()

	local theShake = nil
	if shakerInstance and typeof(shakerInstance.StartShake) == "function" then
		theShake = shakerInstance:StartShake(5, 20, 2, Vector3.zero)
	end

	local function waitUntil(t: number)
		repeat RunService.RenderStepped:Wait() until sound.TimePosition >= t
	end

	local function fadeOut()
		for _, v in ipairs(pentagram:GetChildren()) do
			if v.Name == "BeamFlat" then
				task.delay(v:GetAttribute("Delay") or 0, function()
					TweenService:Create(v, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Brightness = 0 }):Play()
				end)
			elseif v.Name == "BeamChain" then
				TweenService:Create(v, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Brightness = 0 }):Play()
			elseif v.Name == "BeamGlow" then
				TweenService:Create(v, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Brightness = 0 }):Play()
			end
		end
		for _, v in ipairs(pentagram.Circle:GetChildren()) do
			if v:IsA("ParticleEmitter") then
				v.Enabled = false
			end
		end
	end

	local typeData = CrucifixStorage.CrucifixTypes["guiding"]
	local floorVal = ReplicatedStorage:FindFirstChild("GameData") and ReplicatedStorage.GameData:FindFirstChild("Floor")
	if floorVal and (floorVal.Value == "Hotel" or floorVal.Value == "Mines") then
		typeData = CrucifixStorage.CrucifixTypes["guiding"]
	else
		typeData = CrucifixStorage.CrucifixTypes["curious"]
	end
	
	local color = typeData.Color

	for _, v in ipairs(repentance:GetDescendants()) do
		if v:HasTag("GiveMeColor") or v.Name == "GiveMeColor" then
			if v:IsA("Light") or v:IsA("BasePart") then
				v.Color = color
			elseif v:IsA("ParticleEmitter") or v:IsA("Beam") then
				v.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, color),
					ColorSequenceKeypoint.new(1, color)
				})
			end
		end
	end

	task.spawn(function()
		while entityPart.Parent and entityModel and entityModel.Parent do
			if entityModel:IsA("Model") then
				entityModel:PivotTo(entityPart.CFrame)
			else
				entityModel.CFrame = entityPart.CFrame
			end
			RunService.RenderStepped:Wait()
		end
		if entityModel and entityModel.Parent then
			entityModel:Destroy()
		end
	end)

	handle.BodyPosition.Position = (character:GetPivot() * CFrame.new(1, 4, -6)).Position
	TweenService:Create(handle.BodyAngularVelocity, TweenInfo.new(4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), { AngularVelocity = Vector3.new(0, 40, 0) }):Play()

	task.delay(3, function()
		for _, shard in ipairs(handle.Shards:GetChildren()) do
			shard.CollisionGroup = "NoPlayer"
			shard.CanCollide = true
			if shard:FindFirstChild("Weld") then shard.Weld:Destroy() end
			shard.AssemblyAngularVelocity = Vector3.zero
		end
	end)

	TweenService:Create(entityPart, TweenInfo.new(3, Enum.EasingStyle.Elastic, Enum.EasingDirection.In), { CFrame = entityPart.CFrame + Vector3.new(0, 2, 0) }):Play()

	task.spawn(function()
		waitUntil(2.625)
		if pentagram:FindFirstChild("Base") and pentagram.Base:FindFirstChild("LightAttach") then
			TweenService:Create(pentagram.Base.LightAttach.LightBright, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 2.5, Range = 40 }):Play()
		end
		TweenService:Create(handle.Light, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 3.25, Range = 30 }):Play()

		task.wait(1.5)
		if pentagram:FindFirstChild("Base") and pentagram.Base:FindFirstChild("LightAttach") then
			TweenService:Create(pentagram.Base.LightAttach.LightBright, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 0, Range = 0 }):Play()
		end
		TweenService:Create(handle.Light, TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 0, Range = 0 }):Play()

		TweenService:Create(handle.Light, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut), { Brightness = 4, Range = 40 }):Play()
		if theShake and typeof(theShake.StartFadeOut) == "function" then theShake:StartFadeOut(3) end
		fadeOut()
		TweenService:Create(handle.BodyAngularVelocity, TweenInfo.new(3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { AngularVelocity = Vector3.zero }):Play()
	end)

	waitUntil(2.5)
	TweenService:Create(entityPart, TweenInfo.new(3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { CFrame = entityPart.CFrame - Vector3.new(0, 50, 0) }):Play()

	local soundTargets = {}
	if entityModel:IsA("Model") then
		soundTargets = entityModel:GetDescendants()
	elseif entityModel:IsA("Sound") then
		table.insert(soundTargets, entityModel)
	end

	for _, s in ipairs(soundTargets) do
		if s:IsA("Sound") and not s:GetAttribute("VolumeIgnore") then
			TweenService:Create(s, TweenInfo.new(3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Volume = 0 }):Play()
		end
	end

	waitUntil(6.75)

	TweenService:Create(handle.Glow, TweenInfo.new(1), { Size = handle.Glow.Size * 3, Transparency = 1 }):Play()
	if pentagram:FindFirstChild("Base") and pentagram.Base:FindFirstChild("LightAttach") then
		TweenService:Create(pentagram.Base.LightAttach.LightBright, TweenInfo.new(1), { Brightness = 0, Range = 0 }):Play()
	end
	TweenService:Create(handle.Light, TweenInfo.new(1), { Brightness = 0, Range = 0 }):Play()

	handle.ExplodeParticle:Emit(math.random(20, 30))
	if shakerInstance and typeof(shakerInstance.ShakeOnce) == "function" then 
		shakerInstance:ShakeOnce(7.5, 7.5, 0.25, 1.5) 
	end

	task.delay(5, repentance.Destroy, repentance)
	return true
end

function StationaryEntity.spawn(entityTemplate: Model, roomInstance: Instance, config: table?)
	config = config or {}
	local callbacks = config.callbacks or {}
	local spawnOffset = config.spawnOffset or Vector3.new(0, 0, 0)
	local crucifixRange = config.crucifixRange or 15
	local canBeCrucified = config.canBeCrucified ~= false
	local shakerInstance = config.shakerInstance
	local crucifixChecker = config.checkForEquippedCrucifix or defaultCheckCrucifix

	local centerPos = getRoomCenter(roomInstance)
	if not centerPos then
		warn("[StationaryEntity] Failed to find room center for:", roomInstance and roomInstance.Name or "nil")
		return nil
	end

	local entity = entityTemplate:Clone()
	entity.Parent = Workspace
	
	local spawnCFrame = CFrame.new(centerPos + spawnOffset)
	entity:PivotTo(spawnCFrame)

	local isHandled = false

	local actionsHandle = {}
	
	function actionsHandle.Destroy()
		if entity and entity.Parent then
			entity:Destroy()
		end
		isHandled = true
	end
	
	function actionsHandle.GetEntity()
		return entity
	end
	
	function actionsHandle.GetRoom()
		return roomInstance
	end

	function actionsHandle.SetCanBeCrucified(value: boolean)
		canBeCrucified = value
	end

	function actionsHandle.GetCanBeCrucified(): boolean
		return canBeCrucified
	end

	if type(callbacks.OnSpawned) == "function" then
		task.spawn(callbacks.OnSpawned, entity, roomInstance, actionsHandle)
	end

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if isHandled or not entity or not entity.Parent then
			if connection then connection:Disconnect() end
			return
		end

		local character = LocalPlayer.Character
		if not character or not character:FindFirstChild("HumanoidRootPart") then return end

		local hrp = character.HumanoidRootPart
		local distance = (hrp.Position - spawnCFrame.Position).Magnitude

		if distance <= crucifixRange and canBeCrucified then
			local hasCrucifix, tool = crucifixChecker(character)

			if hasCrucifix and tool then
				isHandled = true
				if connection then connection:Disconnect() end

				task.spawn(function()
					if tool:FindFirstChildWhichIsA("RemoteEvent") then
						if ReplicatedStorage:FindFirstChild("RemotesFolder") and ReplicatedStorage.RemotesFolder:FindFirstChild("DropItem") then
							ReplicatedStorage.RemotesFolder.DropItem:FireServer(tool)
						end
						task.wait()
						if Workspace:FindFirstChild("Drops") then
							local droppedDrop = Workspace.Drops:WaitForChild(tool.Name, 3)
							if droppedDrop then droppedDrop:Destroy() end
						end
					else
						tool:Destroy()
					end
				end)

				task.spawn(function()
					performCrucifixion(entity, character, shakerInstance)
					
					if type(callbacks.OnCrucifixion) == "function" then
						task.spawn(callbacks.OnCrucifixion, entity, character, actionsHandle)
					end
				end)

				return
			end
		end
	end)

	return actionsHandle
end

return StationaryEntity
