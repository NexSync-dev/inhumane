local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
		if val == "Safe" then return "Safe", Color3.fromRGB(0,255,0)
		elseif val == "Critical" or val == "Zombie Breathing" then return "Bad", Color3.fromRGB(255,0,0) end
	end
	return "", Color3.fromRGB(150,150,150)
end

-- Function to determine final status and send to appropriate location
local function determineAndSendStatus(model)
	local status = model:FindFirstChild("SymptomStatus")
	if not status then return end
	
	local currentStatus = status.Value
	
	-- If already determined as Zombie, send to liquidation
	if currentStatus == "Zombie" then
		print("Sending " .. model.Name .. " to Liquidation (Infected)")
		liquidationRemote:FireServer(model)
		return
	end
	
	-- If already determined as Safe, send to survivor
	if currentStatus == "Safe" then
		print("Sending " .. model.Name .. " to Survivor (Safe)")
		survivorRemote:FireServer(model)
		return
	end
	
	-- For Quarantine status, check detailed metrics to make final decision
	if currentStatus == "Quarantine" then
		local bpm = model:FindFirstChild("BPM")
		local temp = model:FindFirstChild("Temp")
		local breathingVal, _ = getBreathingStatus(model)
		local contamValue = model:FindFirstChild("HasContaminatedItems")
		
		local bpmVal = bpm and tonumber(bpm.Value) or 0
		local tempVal = temp and tonumber(temp.Value) or 0
		local hasContaminatedItems = contamValue and contamValue:IsA("BoolValue") and contamValue.Value
		
		-- Decision logic based on health metrics
		local isInfected = false
		local isSafe = false
		
		-- Check BPM (dangerous if > 140 or < 90)
		if bpmVal > 140 or bpmVal < 90 then
			isInfected = true
		end
		
		-- Check temperature (dangerous if > 104)
		if tempVal > 104 then
			isInfected = true
		end
		
		-- Check breathing (dangerous if not "Safe")
		if breathingVal ~= "Safe" then
			isInfected = true
		end
		
		-- Check contaminated items
		if hasContaminatedItems then
			isInfected = true
		end
		
		-- If temperature is normal (<= 100) and no other dangerous signs, consider safe
		if tempVal <= 100 and breathingVal == "Safe" and not hasContaminatedItems and bpmVal >= 90 and bpmVal <= 140 then
			isSafe = true
		end
		
		-- Make final decision
		if isInfected then
			print("Sending " .. model.Name .. " to Liquidation (Quarantine -> Infected)")
			liquidationRemote:FireServer(model)
		elseif isSafe then
			print("Sending " .. model.Name .. " to Survivor (Quarantine -> Safe)")
			survivorRemote:FireServer(model)
		else
			-- Keep in quarantine if uncertain
			print("Keeping " .. model.Name .. " in Quarantine (uncertain status)")
			quarantineRemote:FireServer(model)
		end
	end
end

-- Track models and monitor their status changes
local trackedModels = {}

local function handleModel(model)
	if not model:IsA("Model") then return end
	if trackedModels[model] then return end
	
	local humanoid = model:FindFirstChildWhichIsA("Humanoid")
	local status = model:FindFirstChild("SymptomStatus")
	local root = model:FindFirstChild("HumanoidRootPart")
	
	if not (humanoid and status and root) then return end
	
	trackedModels[model] = true
	
	-- Initial status check
	determineAndSendStatus(model)
	
	-- Monitor status changes
	local connStatus
	connStatus = status:GetPropertyChangedSignal("Value"):Connect(function()
		determineAndSendStatus(model)
	end)
	
	-- Clean up when character dies
	local connDied
	connDied = humanoid.Died:Connect(function()
		connStatus:Disconnect()
		connDied:Disconnect()
		trackedModels[model] = nil
	end)
end

-- Process existing civilians
for _, model in ipairs(Civilians:GetChildren()) do
	handleModel(model)
end

-- Monitor for new civilians
Civilians.ChildAdded:Connect(function(child)
	task.wait(0.1)
	handleModel(child)
end)

print("Auto-sort script loaded! Monitoring civilians and automatically sending them to appropriate locations.") 
