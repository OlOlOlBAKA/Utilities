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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemSpawner = {}
ItemSpawner.__index = ItemSpawner

-- Helper function using model-based keyword checks & strict part name enforcement
local function getLocationConfig(holder: BasePart, locationsConfig: {[string]: any}?, isDynamic: boolean): (boolean, Vector3?, Vector3?, string?)
	if not locationsConfig then
		return true, nil, nil, nil
	end

	local holderNameLower = holder.Name:lower()
	local matchedType = nil
	local matchedConfig = nil

	-- Walk up ancestry to find the model containing the keyword
	local current = holder.Parent
	while current and current ~= Workspace and current ~= game.ReplicatedStorage do
		local nameLower = current.Name:lower()

		if nameLower:find("onthewall") then
			if holderNameLower == "holder" then
				matchedType = "onthewall"
				matchedConfig = locationsConfig["onthewall"] or locationsConfig["wall"]
				break
			else
				-- Reject if an onthewall model's part is not named "holder"
				return false, nil, nil, nil
			end
		elseif nameLower:find("table") then
			if holderNameLower == "lootholder" then
				matchedType = "table"
				matchedConfig = locationsConfig["table"]
				break
			else
				-- Strictly reject any table part named "Holder"
				return false, nil, nil, nil
			end
		elseif nameLower:find("drawer") or nameLower:find("rolltop") then
			if holderNameLower == "lootholder" then
				matchedType = "drawer"
				matchedConfig = locationsConfig["drawer"]
				break
			else
				return false, nil, nil, nil
			end
		elseif nameLower:find("chestbox") or nameLower:find("chest") then
			if holderNameLower == "lootholder" then
				matchedType = "chestbox"
				matchedConfig = locationsConfig["chestbox"] or locationsConfig["chest"]
				break
			else
				return false, nil, nil, nil
			end
		end

		current = current.Parent
	end

	-- Fallback for standalone wall holder parts

	if not matchedConfig or type(matchedConfig) ~= "table" or matchedConfig.Enabled == false then
		return false, nil, nil, nil
	end

	-- Enforce scan separation rules:
	-- Drawers & chestboxes must ONLY be processed dynamically at runtime via DescendantAdded
	if (matchedType == "drawer" or matchedType == "chestbox" or matchedType == "chest") and not isDynamic then
		return false, nil, nil, nil
	end

	-- Tables & onthewall must ONLY be processed statically on room load via GetDescendants
	if (matchedType == "table" or matchedType == "onthewall" or matchedType == "wall") and isDynamic then
		return false, nil, nil, nil
	end

	return true, matchedConfig.Offset, matchedConfig.RotationOffset, matchedType
end

function ItemSpawner.spawn(itemModel: Instance, roomInstance: Instance, config: table?, SeedNumber: Number)
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
	local spawnChance = config.SpawnChance or 10
	local MaxChance = config.MaxChance or 100

	local rngNumber = Random.new(SeedNumber)

	local processedHolders = {}
	local staticSpawned = false -- Enforces 1 static item max per room for tables/walls
	
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

	local function processHolder(holder: BasePart, isDynamic: boolean, rngResult: Number)
		if processedHolders[holder] then return end
		
		if holder:GetAttribute("IsUsed") == true then
			return
		end
		
		local isValid, locOffset, locRotOffset, _ = getLocationConfig(holder, locationsConfig, isDynamic)
		if not isValid then
			return
		end

		processedHolders[holder] = true

		if not rngResult then rngResult = rngNumber:NextInteger(spawnChance, MaxChance) end

		print(rngResult)
		
		if rngResult > spawnChance then
			holder:SetAttribute("IsUsed", true) -- Mark as searched/empty so it doesn't re-roll
			return
		end

		-- For static items (tables and onthewall), ensure only 1 spawns per room on load
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
			cleanup()
		end

		if type(callbacks.OnSpawned) == "function" then
			task.spawn(callbacks.OnSpawned, spawnedItem, roomInstance, actionsHandle)
		end
	end

	-- 1. Static Scan: Process pre-existing tables and onthewall on room load using GetDescendants
	for _, desc in ipairs(roomInstance:GetDescendants()) do
		local room = ReplicatedStorage.GameData.LatestRoom
		if roomInstance.Name ~= tostring(room.Value) and roomInstance.Name ~= tostring(room.Value - 1) then
			print("not current room") 
			cleanup() 
			return 
		end
		if desc:IsA("BasePart") then
			local rngResult = rngNumber:NextInteger(spawnChance, MaxChance)
			
			processHolder(desc, false, rngResult)
		end
	end

	-- 2. Dynamic Scan: Listen for drawer and chestbox loot holders added at runtime via DescendantAdded
	connection = roomInstance.DescendantAdded:Connect(function(desc)
		local room = ReplicatedStorage.GameData.LatestRoom
		if roomInstance.Name ~= tostring(room.Value) and roomInstance.Name ~= tostring(room.Value - 1) then
			print("not current room") 
			cleanup() 
			return 
		end
		if desc:IsA("BasePart") then
			local rngResult = rngNumber:NextInteger(spawnChance, MaxChance)

			processHolder(desc, true, rngResult)
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
