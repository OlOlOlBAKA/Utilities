--!strict
local Workspace = game:GetService("Workspace")

local ItemSpawner = {}
ItemSpawner.__index = ItemSpawner

-- Helper function to verify if a LootHolder's parent/ancestor matches the allowed list
local function isValidLocation(holder: BasePart, allowedLocations: {string}?): boolean
	if not allowedLocations or #allowedLocations == 0 then
		return true -- If left empty, allow all locations by default
	end

	local current = holder.Parent
	while current and current ~= Workspace and current ~= game.ReplicatedStorage do
		local name = current.Name
		for _, allowed in ipairs(allowedLocations) do
			if name == allowed or name:find(allowed) then
				return true
			end
		end
		current = current.Parent
	end
	return false
end

function ItemSpawner.spawn(itemTemplate: Instance, roomInstance: Instance, config: table?)
	config = config or {}
	if not itemTemplate then
		warn("[ItemSpawner] Failed to spawn: No item template provided.")
		return nil
	end
	if not roomInstance or not roomInstance:IsA("Model") then
		warn("[ItemSpawner] Failed to spawn: Invalid room instance provided.")
		return nil
	end

	local allowedLocations = config.AllowedLocations
	local offset = config.Offset or Vector3.new(0, 0.2, 0)
	local rotOffset = config.RotationOffset or Vector3.new(0, 0, 0)
	local promptSettings = config.Prompt or {}
	local callbacks = config.callbacks or {}
	local spawnChance = config.SpawnChance or 100

	-- Track processed holders for safe cleanup
	local processedHolders = {}
	local spawnedItems = {}
	
	local connection: RBXScriptConnection? = nil
	local ancestryConnection: RBXScriptConnection? = nil
	local destroyingConnection: RBXScriptConnection? = nil

	local cleanup: () -> void

	local function processHolder(holder: BasePart)
		if processedHolders[holder] then return end
		
		-- Check if the LootHolder is inside an allowed container (Table, DrawerContainer, etc.)
		if not isValidLocation(holder, allowedLocations) then
			return
		end

		processedHolders[holder] = true

		if math.random(1, 100) > spawnChance then
			return
		end

		local model = itemTemplate:Clone()
		model.Parent = holder.Parent or Workspace
		table.insert(spawnedItems, model)

		local finalCFrame = holder.CFrame + offset
		local rotationCFrame = CFrame.Angles(
			math.rad(rotOffset.X),
			math.rad(rotOffset.Y),
			math.rad(rotOffset.Z)
		)

		if model:IsA("Model") then
			model:PivotTo(finalCFrame * rotationCFrame)
		elseif model:IsA("BasePart") then
			model.CFrame = finalCFrame * rotationCFrame
		end

		local targetPart = model
		if model:IsA("Model") then
			targetPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		end

		local actionsHandle = {}
		
		function actionsHandle.Destroy()
			if model and model.Parent then
				model:Destroy()
			end
		end
		
		function actionsHandle.GetItem()
			return model
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
			prompt.Parent = targetPart

			prompt.Triggered:Connect(function(player)
				if type(callbacks.OnTriggered) == "function" then
					task.spawn(callbacks.OnTriggered, player, model, actionsHandle)
				else
					prompt:Destroy()
					actionsHandle.Destroy()
				end
			end)
		end

		if type(callbacks.OnSpawned) == "function" then
			task.spawn(callbacks.OnSpawned, model, roomInstance, actionsHandle)
		end
	end

	-- Full cleanup routine to prevent memory leaks over 20+ room cycles
	cleanup = function()
		if connection then connection:Disconnect(); connection = nil end
		if ancestryConnection then ancestryConnection:Disconnect(); ancestryConnection = nil end
		if destroyingConnection then destroyingConnection:Disconnect(); destroyingConnection = nil end

		table.clear(processedHolders)
		table.clear(spawnedItems)
	end

	-- 1. Scan pre-existing LootHolders instantly (e.g., items already on tables)
	for _, desc in ipairs(roomInstance:GetDescendants()) do
		if desc.Name == "LootHolder" and desc:IsA("BasePart") then
			processHolder(desc)
		end
	end

	-- 2. Listen for dynamic LootHolders (e.g., when a drawer is opened)
	connection = roomInstance.DescendantAdded:Connect(function(desc)
		if desc.Name == "LootHolder" and desc:IsA("BasePart") then
			processHolder(desc)
		end
	end)

	-- 3. Garbage collection hooks for when old rooms are deleted or recycled
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
