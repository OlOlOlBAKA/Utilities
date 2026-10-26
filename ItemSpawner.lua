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
end
--!strict
local Workspace = game:GetService("Workspace")

local ItemSpawner = {}
ItemSpawner.__index = ItemSpawner

-- Helper function with strict ancestry matching for Table, Drawer, Chest, and Wall
local function getLocationConfig(holder: BasePart, locationsConfig: {[string]: any}?, isDynamic: boolean): (boolean, Vector3?, Vector3?, string?)
	if not locationsConfig then
		return true, nil, nil, nil
	end

	local matchedType = nil
	local matchedConfig = nil

	local current = holder
	while current and current ~= Workspace and current ~= game.ReplicatedStorage do
		local nameLower = current.Name:lower()

		if nameLower:find("table") and locationsConfig["table"] then
			matchedType = "table"
			matchedConfig = locationsConfig["table"]
			break
		elseif nameLower:find("drawer") and locationsConfig["drawer"] then
			matchedType = "drawer"
			matchedConfig = locationsConfig["drawer"]
			break
		elseif nameLower:find("chest") and locationsConfig["chest"] then
			matchedType = "chest"
			matchedConfig = locationsConfig["chest"]
			break
		elseif (nameLower:find("wall") or nameLower:find("holder")) and locationsConfig["wall"] then
			matchedType = "wall"
			matchedConfig = locationsConfig["wall"]
			break
		end

		current = current.Parent
	end

	-- Fallback for explicit wall holders named "Holder"
	if not matchedType and holder.Name == "Holder" and locationsConfig["wall"] then
		matchedType = "wall"
		matchedConfig = locationsConfig["wall"]
	end

	if not matchedConfig or type(matchedConfig) ~= "table" then
		return false, nil, nil, nil
	end

	if matchedConfig.Enabled == false then
		return false, nil, nil, nil
	end

	-- Block pre-existing drawers and chests found during the initial static scan
	if (matchedType == "drawer" or matchedType == "chest") and not isDynamic then
		return false, nil, nil, nil
	end

	return true, matchedConfig.Offset, matchedConfig.RotationOffset, matchedType
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

	-- If a Tool is passed, extract the inner Model or BasePart and destroy the tool wrapper
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
	local staticSpawned = false -- Ensures tables/walls only spawn 1 item max per room
	
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
		
		local isValid, locOffset, locRotOffset, matchedType = getLocationConfig(holder, locationsConfig, isDynamic)
		if not isValid then
			return
		end

		processedHolders[holder] = true

		if math.random(1, 100) > spawnChance then
			return
		end

		-- If it's a static location (table/wall), ensure only 1 spawns per room
		if not isDynamic then
			if staticSpawned then return end
			staticSpawned = true
		end

		holder:SetAttribute("IsUsed", true)

		local spawnedItem = itemModel:Clone()
		spawnedItem.Parent = holder.Parent or Workspace

		local finalOffset = locOffset or defaultOffset
		local finalRotOffset = locRotOffset or defaultRotOffset

		-- Local space CFrame multiplication to properly respect furniture rotation
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

		-- Weld the item to the holder for smooth movement/locking
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
			cleanup()
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

		-- Create ProximityPrompt
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

	-- 1. Scan pre-existing tables and walls instantly on room load (isDynamic = false)
	for _, desc in ipairs(roomInstance:GetDescendants()) do
		if (desc.Name == "LootHolder" or desc.Name == "Holder") and desc:IsA("BasePart") then
			local isValid, _, _, matchedType = getLocationConfig(desc, locationsConfig, false)
			if isValid and (matchedType == "table" or matchedType == "wall") then
				processHolder(desc, false)
			end
		end
	end

	-- 2. Listen for dynamic drawers and chests created at runtime when opened (isDynamic = true)
	connection = roomInstance.DescendantAdded:Connect(function(desc)
		if (desc.Name == "LootHolder" or desc.Name == "Holder") and desc:IsA("BasePart") then
			local isValid, _, _, matchedType = getLocationConfig(desc, locationsConfig, true)
			if isValid and (matchedType == "drawer" or matchedType == "chest") then
				processHolder(desc, true)
			end
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
