local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Civilians = Workspace:WaitForChild("Civilians")
local sendToBlock = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SendToBlock")

local trackedModels = {}

-- Color logic reused from your ESP (for reference)
local function getColor(value, low, mid, high)
	value = tonumber(value)
	if not value then return Color3.fromRGB(150,150,150) end
	if value < low then return Color3.fromRGB(0,255,0)
	elseif value <= mid then return Color3.fromRGB(255,165,0)
	else return Color3.fromRGB(255,0,0) end
end

local function getTempColor(temp)
	temp = tonumber(temp)
	if not temp then return Color3.fromRGB(150,150,150) end
	if temp > 104 then return Color3.fromRGB(255,0,0)
	elseif temp >= 100 then return Color3.fromRGB(255,165,0)
	else return Color3.fromRGB(0,255,0) end
end

local function getBreathingStatus(model)
	local breath = model:FindFirstChild("BreathingNoise")
	if breath then
		local val = breath.Value
		if val == "Safe" then
			return "Safe", Color3.fromRGB(0,255,0)
		elseif val == "Critical" or val == "Zombie Breathing" then
			return "Bad", Color3.fromRGB(255,0,0)
		end
	end
	return "", Color3.fromRGB(150,150,150)
end

-- Exact logic used by your ESP to categorize the model
local function determineStatus(model)
	local status = model:FindFirstChild("SymptomStatus")
	if status and status.Value == "Zombie" then
		return "Zombie"
	elseif status and status.Value == "Safe" then
		return "Safe"
	end

	-- Quarantine logic based on extra sensors
	local bpm = tonumber((model:FindFirstChild("BPM") or {}).Value) or 0
	local temp = tonumber((model:FindFirstChild("Temp") or {}).Value) or 0
	local breathingStatus, _ = getBreathingStatus(model)
	local contaminated = (model:FindFirstChild("HasContaminatedItems") or {}).Value == true

	if breathingStatus == "Bad" then return "Zombie" end
	if contaminated then return "Quarantine" end
	if bpm >= 140 or temp >= 100 then return "Quarantine" end

	return "Safe"
end

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

local function handleModel(model)
	if not model:IsA("Model") then return end
	if trackedModels[model] then return end

	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end

	trackedModels[model] = true

	autoJudge(model)

	local signals = {}
	local function track(obj)
		if obj then
			local conn = obj:GetPropertyChangedSignal("Value"):Connect(function()
				autoJudge(model)
			end)
			table.insert(signals, conn)
		end
	end

	for _, name in ipairs({ "SymptomStatus", "HasContaminatedItems", "BPM", "Temp", "BreathingNoise" }) do
		track(model:FindFirstChild(name))
	end

	humanoid.Died:Connect(function()
		for _, conn in ipairs(signals) do conn:Disconnect() end
		trackedModels[model] = nil
	end)
end

-- Track all existing civilians
for _, model in ipairs(Civilians:GetChildren()) do
	handleModel(model)
end

-- Track new civilians
Civilians.ChildAdded:Connect(function(child)
	task.wait(0.1)
	handleModel(child)
end)
