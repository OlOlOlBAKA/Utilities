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

-- Helper function with strict holder name validation & ancestry matching
local function getLocationConfig(holder: BasePart, locationsConfig: {[string]: any}?): (boolean, Vector3?, Vector3?, string?, Instance?)
	if not locationsConfig then
		return true, nil, nil, nil, nil
	end

	local holderNameLower = holder.Name:lower()
	local matchedType = nil
	local matchedConfig = nil
	local containerModel = nil

	-- Walk up ancestry from holder.Parent
	local current = holder.Parent
	while current and current ~= Workspace and current ~= game.ReplicatedStorage do
		local nameLower = current.Name:lower()

		if nameLower:find("table") and locationsConfig["table"] then
			-- Tables use LootHolder or Holder
			if holderNameLower == "lootholder" then
				matchedType = "table"
				matchedConfig = locationsConfig["table"]
				containerModel = current
				break
			end
		elseif nameLower:find("drawer") and locationsConfig["drawer"] then
			-- Drawers explicitly use LootHolder
			if holderNameLower == "lootholder" then
				matchedType = "drawer"
				matchedConfig = locationsConfig["drawer"]
				containerModel = current
				break
			end
		elseif nameLower:find("chest") and locationsConfig["chest"] then
			-- Chests explicitly use LootHolder
			if holderNameLower == "lootholder" then
				matchedType = "chest"
				matchedConfig = locationsConfig["chest"]
				containerModel = current
				break
			end
		elseif (nameLower:find("wall") or nameLower:find("holder")) and locationsConfig["wall"] then
			-- Walls explicitly use Holder
			if holderNameLower == "holder" then
				matchedType = "wall"
				matchedConfig = locationsConfig["wall"]
				containerModel = current
				break
			end
		end

		current = current.Parent
	end

	-- Fallback for explicit wall holder parts
	if not matchedType and holderNameLower == "holder" and locationsConfig["wall"] then
		matchedType = "wall"
		matchedConfig = locationsConfig["wall"]
		containerModel = holder.Parent
	end

	if not matchedConfig or type(matchedConfig) ~= "table" then
		return false, nil, nil, nil, nil
	end

	if matchedConfig.Enabled == false then
		return false, nil, nil, nil, nil
	end

	return true, matchedConfig.Offset, matchedConfig.RotationOffset, matchedType, containerModel
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
	local staticSpawned = false -- Enforces 1 item max per room for tables/walls
	
	local activeConnections = {}
	local ancestryConnection: RBXScriptConnection? = nil
	local destroyingConnection: RBXScriptConnection? = nil

	local cleanup: () -> void

	cleanup = function()
		for _, conn in ipairs(activeConnections) do
			conn:Disconnect()
		end
		table.clear(activeConnections)

		if ancestryConnection then ancestryConnection:Disconnect(); ancestryConnection = nil end
		if destroyingConnection then destroyingConnection:Disconnect(); destroyingConnection = nil end
		table.clear(processedHolders)
	end

	local function processHolder(holder: BasePart, isDynamic: boolean)
		if processedHolders[holder] then return end
		
		if holder:GetAttribute("IsUsed") == true then
			return
		end
		
		local isValid, locOffset, locRotOffset, matchedType, _ = getLocationConfig(holder, locationsConfig)
		if not isValid then
			return
		end

		processedHolders[holder] = true

		if math.random(1, 100) > spawnChance then
			return
		end

		-- For tables and walls, ensure only 1 spawns per room statically on load
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

	-- Scan all holders in the room on load
	for _, desc in ipairs(roomInstance:GetDescendants()) do
		if desc:IsA("BasePart") and (desc.Name == "LootHolder" or desc.Name == "Holder") then
			local isValid, _, _, matchedType, containerModel = getLocationConfig(desc, locationsConfig)
			if isValid then
				if matchedType == "table" or matchedType == "wall" then
					-- Tables and walls spawn immediately on room load
					processHolder(desc, false)
				elseif (matchedType == "drawer" or matchedType == "chest") and containerModel then
					-- Drawers and chests wait until the player opens them at runtime
					local function hookContainerOpening()
						local function triggerOpen()
							processHolder(desc, true)
						end

						-- Listen to opening attributes or ProximityPrompts inside the container model
						if containerModel:GetAttribute("Opened") == true or containerModel:GetAttribute("Open") == true then
							triggerOpen()
						else
							table.insert(activeConnections, containerModel:GetAttributeChangedSignal("Opened"):Connect(triggerOpen))
							table.insert(activeConnections, containerModel:GetAttributeChangedSignal("Open"):Connect(triggerOpen))

							for _, prompt in ipairs(containerModel:GetDescendants()) do
								if prompt:IsA("ProximityPrompt") then
									table.insert(activeConnections, prompt.Triggered:Connect(triggerOpen))
								end
							end
							table.insert(activeConnections, containerModel.DescendantAdded:Connect(function(child)
								if child:IsA("ProximityPrompt") then
									table.insert(activeConnections, child.Triggered:Connect(triggerOpen))
								end
							end))
						end
					end

					hookContainerOpening()
				end
			end
		end
	end

	-- Room recycling and cleanup hooks
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
