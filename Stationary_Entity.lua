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

	local designatedCenter = roomInstance:FindFirstChild("Center") or roomInstance:FindFirstChild("RoomCenter") or roomInstance:FindFirstChild("Node")
	if designatedCenter and designatedCenter:IsA("BasePart") then
		return designatedCenter.Position
	end

	local floorParts = {}
	local partsFolder = roomInstance:FindFirstChild("Parts")
	if partsFolder then
		local floorInst = partsFolder:FindFirstChild("Floor")
		if floorInst then
			if floorInst:IsA("BasePart") then
				table.insert(floorParts, floorInst)
			elseif floorInst:IsA("Model") or floorInst:IsA("Folder") then
				for _, desc in ipairs(floorInst:GetDescendants()) do
					if desc:IsA("BasePart") then table.insert(floorParts, desc) end
				end
			end
		end
		for _, desc in ipairs(partsFolder:GetDescendants()) do
			if desc.Name == "Floor" and desc:IsA("BasePart") and not table.find(floorParts, desc) then
				table.insert(floorParts, desc)
			end
		end
	end

	if #floorParts == 0 then
		for _, desc in ipairs(roomInstance:GetDescendants()) do
			if desc.Name == "Floor" and desc:IsA("BasePart") then
				table.insert(floorParts, desc)
			end
		end
	end

	local cframe, size = roomInstance:GetBoundingBox()
	local bestPos = Vector3.new(cframe.Position.X, cframe.Position.Y - (size.Y / 2), cframe.Position.Z)

	if #floorParts > 0 then
		local minY = math.huge
		for _, part in ipairs(floorParts) do
			local topY = part.Position.Y + (part.Size.Y / 2)
			if topY < minY then
				minY = topY
			end
		end

		local groundFloors = {}
		for _, part in ipairs(floorParts) do
			local topY = part.Position.Y + (part.Size.Y / 2)
			if math.abs(topY - minY) <= 3 then
				table.insert(groundFloors, part)
			end
		end

		local closestFloor = groundFloors[1]
		local minDst = math.huge
		local centerXZ = Vector3.new(cframe.Position.X, 0, cframe.Position.Z)

		for _, part in ipairs(groundFloors) do
			local pXZ = Vector3.new(part.Position.X, 0, part.Position.Z)
			local dst = (pXZ - centerXZ).Magnitude
			if dst < minDst then
				minDst = dst
				closestFloor = part
			end
		end

		if closestFloor then
			local pCF, pSize = closestFloor.CFrame, closestFloor.Size
			bestPos = Vector3.new(pCF.Position.X, pCF.Position.Y + (pSize.Y / 2), pCF.Position.Z)
		end
	else
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { roomInstance }
		local rayResult = Workspace:Raycast(Vector3.new(cframe.Position.X, cframe.Position.Y + (size.Y / 2), cframe.Position.Z), Vector3.new(0, -size.Y * 2, 0), raycastParams)
		if rayResult then
			bestPos = rayResult.Position
		end
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { roomInstance }

	local checkSize = Vector3.new(3, 4, 3)
	local finalPos = bestPos

	local function isClear(pos: Vector3): boolean
		local parts = Workspace:GetPartBoundsInBox(CFrame.new(pos + Vector3.new(0, 2, 0)), checkSize, overlapParams)
		for _, p in ipairs(parts) do
			local isFloor = false
			for _, fp in ipairs(floorParts) do
				if p == fp or p:IsDescendantOf(fp) then
					isFloor = true
					break
				end
			end
			if not isFloor then return false end
		end
		return true
	end

	if not isClear(finalPos) then
		local found = false
		for _, radius in ipairs({ 3, 6, 9, 12 }) do
			for _, angle in ipairs({ 0, 45, 90, 135, 180, 225, 270, 315 }) do
				local rad = math.rad(angle)
				local testPos = bestPos + Vector3.new(math.cos(rad) * radius, 0, math.sin(rad) * radius)
				if isClear(testPos) then
					finalPos = testPos
					found = true
					break
				end
			end
			if found then break end
		end
	end

	return finalPos
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
							local droppedDrop = Workspace.Drops:FindFirstChild(tool.Name)
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
