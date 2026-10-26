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

-- Helper function to verify if a LootHolder's parent matches allowed locations and dynamic rules
local function isValidLocation(holder: BasePart, allowedLocations: {string}?, isDynamic: boolean): boolean
	if not allowedLocations or #allowedLocations == 0 then
		return true
	end

	local current = holder.Parent
	while current and current ~= Workspace and current ~= game.ReplicatedStorage do
		local name = current.Name
		for _, allowed in ipairs(allowedLocations) do
			if name == allowed or name:find(allowed) then
				-- If it's a DrawerContainer, ChestBox, or ChestBoxLocked found via initial GetDescendants (not dynamic), block it
				if (allowed == "DrawerContainer" or allowed == "ChestBox" or allowed == "ChestBoxLocked") and not isDynamic then
					return false
				end
				return true
			end
		end
		current = current.Parent
	end
	return false
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

	local allowedLocations = config.AllowedLocations
	local offset = config.Offset or Vector3.new(0, 0.2, 0)
	local rotOffset = config.RotationOffset or Vector3.new(0, 0, 0)
	local promptSettings = config.Prompt or {}
	local callbacks = config.callbacks or {}
	local spawnChance = config.SpawnChance or 100

	local processedHolders = {}
	local spawnedItems = {}
	local hasSpawned = false
	
	local connection: RBXScriptConnection? = nil
	local ancestryConnection: RBXScriptConnection? = nil
	local destroyingConnection: RBXScriptConnection? = nil

	local cleanup: () -> void

	cleanup = function()
		if connection then connection:Disconnect(); connection = nil end
		if ancestryConnection then ancestryConnection:Disconnect(); ancestryConnection = nil end
		if destroyingConnection then destroyingConnection:Disconnect(); destroyingConnection = nil end

		table.clear(processedHolders)
		table.clear(spawnedItems)
	end

	local function processHolder(holder: BasePart, isDynamic: boolean)
		if hasSpawned then return end
		if processedHolders[holder] then return end
		
		-- Prevent spawning if this specific LootHolder was already used
		if holder:GetAttribute("IsUsed") == true then
			return
		end
		
		if not isValidLocation(holder, allowedLocations, isDynamic) then
			return
		end

		processedHolders[holder] = true

		if math.random(1, 100) > spawnChance then
			return
		end

		-- Mark this specific LootHolder location as used
		holder:SetAttribute("IsUsed", true)

		hasSpawned = true
		if connection then
			connection:Disconnect()
			connection = nil
		end

		itemModel.Parent = holder.Parent or Workspace
		table.insert(spawnedItems, itemModel)

		local finalCFrame = holder.CFrame + offset
		local rotationCFrame = CFrame.Angles(
			math.rad(rotOffset.X),
			math.rad(rotOffset.Y),
			math.rad(rotOffset.Z)
		)

		if itemModel:IsA("Model") then
			itemModel:PivotTo(finalCFrame * rotationCFrame)
		elseif itemModel:IsA("BasePart") then
			itemModel.CFrame = finalCFrame * rotationCFrame
		end

		local targetPart = nil
		if itemModel:IsA("Model") then
			targetPart = itemModel.PrimaryPart or itemModel:FindFirstChildWhichIsA("BasePart", true)
		elseif itemModel:IsA("BasePart") then
			targetPart = itemModel
		end

		-- Weld the item to the LootHolder for smooth movement
		if targetPart and targetPart:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = targetPart
			weld.Part1 = holder
			weld.Parent = targetPart
		end

		local actionsHandle = {}
		
		function actionsHandle.Destroy()
			if itemModel and itemModel.Parent then
				itemModel:Destroy()
			end
			cleanup()
		end
		
		function actionsHandle.GetItem()
			return itemModel
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
					task.spawn(callbacks.OnTriggered, player, itemModel, actionsHandle)
				else
					prompt:Destroy()
					actionsHandle.Destroy()
				end
			end)
		end

		if type(callbacks.OnSpawned) == "function" then
			task.spawn(callbacks.OnSpawned, itemModel, roomInstance, actionsHandle)
		end
	end

	-- 1. Scan pre-existing LootHolders instantly (isDynamic = false)
	for _, desc in ipairs(roomInstance:GetDescendants()) do
		if not hasSpawned and desc.Name == "LootHolder" and desc:IsA("BasePart") then
			processHolder(desc, false)
		end
	end

	-- 2. Listen for dynamic LootHolders created at runtime (isDynamic = true)
	if not hasSpawned then
		connection = roomInstance.DescendantAdded:Connect(function(desc)
			if not hasSpawned and desc.Name == "LootHolder" and desc:IsA("BasePart") then
				processHolder(desc, true)
			end
		end)
	end

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
