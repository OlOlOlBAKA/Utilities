local Players = game:GetService("Players")

local function modifyPart(descendant)
	if not descendant:IsA("BasePart") then return end
	
	-- Check if the part belongs to a model with a Humanoid (characters, NPCs, etc.)
	local model = descendant:FindFirstAncestorWhichIsA("Model")
	local hasHumanoid = model and model:FindFirstChildOfClass("Humanoid")
	
	-- Enable UsePartColor for Unions, MeshParts, and standard Parts
	if descendant:IsA("UnionOperation") or descendant:IsA("MeshPart") or descendant:IsA("Part") then
		pcall(function()
			descendant.UsePartColor = true
		end)
	end
	
	-- Apply colors based on whether it's a humanoid/character or a regular part
	if hasHumanoid then
		descendant.Color = Color3.fromRGB(0, 0, 0)
		descendant.Material = Enum.Material.CorrodedMetal
	else
		descendant.Color = Color3.fromRGB(130, 130, 130)
		descendant.Material = Enum.Material.CorrodedMetal
	end
end

-- Process parts already loaded in the workspace
for _, descendant in ipairs(workspace:GetDescendants()) do
	modifyPart(descendant)
end

-- Listen for any new objects added to the workspace
workspace.DescendantAdded:Connect(modifyPart)
