local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Civilians = Workspace:WaitForChild("Civilians")
local sendToBlock = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SendToBlock")

local trackedModels = {}

-- Determine infection status based on sensor values (ESP logic)
local function determineStatus(model)
	local breathing = (model:FindFirstChild("BreathingNoise") or {}).Value
	local contaminated = (model:FindFirstChild("HasContaminatedItems") or {}).Value == true
	local bpm = tonumber((model:FindFirstChild("BPM") or {}).Value) or 0
	local temp = tonumber((model:FindFirstChild("Temp") or {}).Value) or 0

	-- 🔴 Liquidation conditions
	if breathing == "Zombie Breathing" or breathing == "Critical" then
		return "Zombie"
	end
	if contaminated then
		return "Zombie"
	end

	-- 🟡 Quarantine conditions
	if bpm >= 140 or temp >= 100 then
		return "Quarantine"
	end

	-- 🟢 Safe
	return "Safe"
end

-- Fire correct RemoteEvent
local function autoJudge(model)
	local category = determineStatus(model)

	if category == "Zombie" then
		sendToBlock:FireServer("Liquidation")
	elseif category == "Quarantine" then
		sendToBlock:FireServer("Quarantine")
	elseif category == "Safe" then
		sendToBlock:FireServer("Survivor")
	end
end

-- Handle individual model
local function handleModel(model)
	if not model:IsA("Model") or trackedModels[model] then return end

	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end

	trackedModels[model] = true
	autoJudge(model)

	local connections = {}

	local function track(obj)
		if obj then
			local conn = obj:GetPropertyChangedSignal("Value"):Connect(function()
				autoJudge(model)
			end)
			table.insert(connections, conn)
		end
	end

	for _, name in ipairs({ "BreathingNoise", "HasContaminatedItems", "BPM", "Temp" }) do
		track(model:FindFirstChild(name))
	end

	humanoid.Died:Connect(function()
		for _, conn in ipairs(connections) do conn:Disconnect() end
		trackedModels[model] = nil
	end)
end

-- Handle existing civilians
for _, model in ipairs(Civilians:GetChildren()) do
	handleModel(model)
end

-- Handle new civilians
Civilians.ChildAdded:Connect(function(child)
	task.wait(0.1)
	handleModel(child)
end)
