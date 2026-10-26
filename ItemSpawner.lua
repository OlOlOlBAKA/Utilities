local httpSuccess, rawCode = pcall(function()
	return game:HttpGet("https://raw.githubusercontent.com/RegularVynixu/Utilities/main/Functions.lua")
end)

if httpSuccess and rawCode then
	local loadedFunc, err = loadstring(rawCode)
	if type(loadedFunc) == "function" then
		pcall(loadedFunc)
	else
		warn("Item spawner: Failed to compile HTTP code ->", err)
	end
else
	warn("Item spawner: Failed to fetch HTTP functions ->", rawCode)
end--!strict
local Workspace = game:GetService("Workspace")

local ItemSpawner = {}
ItemSpawner.__index = ItemSpawner

local function getLocationConfig(holder: BasePart, locationsConfig: {[string]: any}?, isDynamic: boolean): (boolean, Vector3?, Vector3?)
	if not locationsConfig then
		return true, nil, nil
	end

	for locName, locConfig in pairs(locationsConfig) do
		if type(locConfig) == "table" and locConfig.Enabled ~= false then
			local locKeyLower = locName:lower()
			
			local current = holder
			while current and current ~= Workspace and current ~= game.ReplicatedStorage do
				local nameLower = current.Name:lower()
				
				local isMatch = nameLower:find(locKeyLower) or ((locKeyLower:find("wall") or locKeyLower:find("holder")) and holder.Name == "Holder")
				
				if isMatch then
					if (locKeyLower:find("drawer") or locKeyLower:find("chest")) and not isDynamic then
						return false, nil, nil
					end
					
					return true, locConfig.Offset, locConfig.RotationOffset
				end
				
				current = current.Parent
			end
		end
	end
	
	return false, nil, nil
end

function ItemSpawner.spawn(itemModel: Instance, roomInstance: Instance, config: table?)
	config = config or {}
	if not itemModel then
		warn("[ItemSpawner] Failed to spawn: No item model provided.")
		return nil
	end
	if not roomInstance or not roomInstance:IsA("Model") then
		warn("[ItemSpawner] Failed to spawn: Invalid room instance provided.")
		return nil
	end

	if itemModel:IsA("Tool") then
		local extracted = itemModel:FindFirstChildWhichIsA("Model") or itemModel:FindFirstChildWhichIsA("BasePart")
		if not extracted then
			extracted = itemModel:FindFirstChild("Handle")
		end
		
		if extracted and extracted:IsA("Instance") then
			extracted.Parent = nil
			itemModel:Destroy()
			itemModel = extracted
		else
			warn("[ItemSpawner] Tool provided but no valid Model or BasePart found inside it.")
			return nil
		end
	end

	local locationsConfig = config.Locations
	local defaultOffset = config.Offset or Vector3.new(0, 0.2, 0)
	local defaultRotOffset = config.RotationOffset or Vector3.new(0, 0, 0)
	local promptSettings = config.Prompt or {}
	local callbacks = config.callbacks or {}
	local spawnChance = config.SpawnChance or 100

	local processedHolders = {}
	
	local connection: RBXScriptConnection? = nil
	local ancestryConnection: RBXScriptConnection? = nil
	local destroyingConnection: RBXScriptConnection? = nil

	local cleanup: () -> void

	cleanup = function()
		if connection then connection:Disconnect(); connection = nil end
		if ancestryConnection then ancestryConnection:Disconnect(); ancestryConnection = nil end
		if destroyingConnection then destroyingConnection:Disconnect(); destroyingConnection = nil end
		table.clear(processedHolders)
	end

	local function processHolder(holder: BasePart, isDynamic: boolean)
		if processedHolders[holder] then return end
		
		if holder:GetAttribute("IsUsed") == true then
			return
		end
		
		local isValid, locOffset, locRotOffset = getLocationConfig(holder, locationsConfig, isDynamic)
		if not isValid then
			return
		end

		processedHolders[holder] = true

		if math.random(1, 100) > spawnChance then
			return
		end

		-- Mark this holder as used so it never spawns twice
		holder:SetAttribute("IsUsed", true)

		-- Clone the item instance if spawning multiple across containers
		local spawnedItem = itemModel:Clone()
		spawnedItem.Parent = holder.Parent or Workspace

		local finalOffset = locOffset or defaultOffset
		local finalRotOffset = locRotOffset or defaultRotOffset

		-- FIX: Local space CFrame multiplication so offsets respect the furniture's rotation
		local rotationCFrame = CFrame.Angles(
			math.rad(finalRotOffset.X),
			math.rad(finalRotOffset.Y),
			math.rad(finalRotOffset.Z)
		)
		local finalCFrame = holder.CFrame * CFrame.new(finalOffset) * rotationCFrame

		if spawnedItem:IsA("Model") then
			spawnedItem:PivotTo(finalCFrame)
		elseif spawnedItem:IsA("BasePart") then
			spawnedItem.CFrame = finalCFrame
		end

		local targetPart = nil
		if spawnedItem:IsA("Model") then
			targetPart = spawnedItem.PrimaryPart or spawnedItem:FindFirstChildWhichIsA("BasePart", true)
		elseif spawnedItem:IsA("BasePart") then
			targetPart = spawnedItem
		end

		if targetPart and targetPart:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = targetPart
			weld.Part1 = holder
			weld.Parent = targetPart
		end

		local actionsHandle = {}
		
		function actionsHandle.Destroy()
			if spawnedItem and spawnedItem.Parent then
				spawnedItem:Destroy()
			end
		end
		
		function actionsHandle.GetItem()
			return spawnedItem
		end

		function actionsHandle.GetRoom()
			return roomInstance
		end

		function actionsHandle.GetHolder()
			return holder
		end

		if targetPart and targetPart:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.HoldDuration = promptSettings.HoldDuration or 0
			prompt.MaxActivationDistance = promptSettings.MaxActivationDistance or 6
			prompt.RequiresLineOfSight = promptSettings.RequiresLineOfSight ~= false
			prompt.KeyboardKeyCode = promptSettings.KeyboardKeyCode or Enum.KeyCode.E
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt.Parent = targetPart

			prompt.Triggered:Connect(function(player)
				if type(callbacks.OnTriggered) == "function" then
					task.spawn(callbacks.OnTriggered, player, spawnedItem, actionsHandle)
				else
					prompt:Destroy()
					actionsHandle.Destroy()
				end
			end)
		end

		if type(callbacks.OnSpawned) == "function" then
			task.spawn(callbacks.OnSpawned, spawnedItem, roomInstance, actionsHandle)
		end
	end

	-- 1. Scan pre-existing LootHolders instantly
	for _, desc in ipairs(roomInstance:GetDescendants()) do
		if (desc.Name == "LootHolder" or desc.Name == "Holder") and desc:IsA("BasePart") then
			processHolder(desc, false)
		end
	end

	-- 2. Listen for dynamic LootHolders/Holders created at runtime (e.g., opened drawers/chests)
	connection = roomInstance.DescendantAdded:Connect(function(desc)
		if (desc.Name == "LootHolder" or desc.Name == "Holder") and desc:IsA("BasePart") then
			processHolder(desc, true)
		end
	end)

	-- 3. Room recycling and cleanup hooks
	ancestryConnection = roomInstance.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cleanup()
		end
	end)

	destroyingConnection = roomInstance.Destroying:Connect(function()
		cleanup()
	end)

	local roomHandle = {}
	function roomHandle.Destroy()
		cleanup()
	end

	return roomHandle
end

return ItemSpawner
