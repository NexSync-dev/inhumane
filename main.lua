local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SendToBlock = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SendToBlock")
local Civilians = Workspace:WaitForChild("Civilians")

local function getBreathingStatus(model)
	local breath = model:FindFirstChild("BreathingNoise")
	if breath then
		local val = breath.Value
		if val == "Safe" then return "Safe"
		elseif val == "Critical" or val == "Zombie Breathing" then return "Bad" end
	end
	return ""
end

local function getClassification(model)
	local status = model:FindFirstChild("SymptomStatus")
	local bpm = model:FindFirstChild("BPM")
	local temp = model:FindFirstChild("Temp")
	local contam = model:FindFirstChild("HasContaminatedItems")
	local breath = getBreathingStatus(model)

	-- Priority: Infected → Liquidation → Quarantine → Safe
	if status and status.Value == "Zombie" then
		return "Liquidation"
	end

	if contam and contam:IsA("BoolValue") and contam.Value then
		return "Liquidation"
	end

	if bpm and temp then
		local bpmVal = tonumber(bpm.Value)
		local tempVal = tonumber(temp.Value)

		if bpmVal and (bpmVal < 90 or bpmVal > 140) then
			return "Quarantine"
		end
		if tempVal and tempVal >= 100 then
			return "Quarantine"
		end
	end

	if breath == "Bad" then
		return "Quarantine"
	end

	return "Survivor"
end

local alreadyProcessed = {}

local function process(model)
	if alreadyProcessed[model] then return end
	alreadyProcessed[model] = true

	local classification = getClassification(model)
	SendToBlock:FireServer(classification)
end

-- Handle current civilians
for _, model in ipairs(Civilians:GetChildren()) do
	task.defer(function()
		process(model)
	end)
end

-- Handle future civilians
Civilians.ChildAdded:Connect(function(model)
	task.wait(0.2)
	process(model)
end)
