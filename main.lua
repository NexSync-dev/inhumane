local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Civilians = game:GetService("Workspace"):WaitForChild("Civilians")
local SendToBlock = ReplicatedStorage.Remotes:WaitForChild("SendToBlock")

local function getBreathingStatus(model)
    local breath = model:FindFirstChild("BreathingNoise")
    if breath then
        if breath.Value == "Safe" then
            return "Safe"
        elseif breath.Value == "Critical" or breath.Value == "Zombie Breathing" then
            return "Bad"
        end
    end
    return ""
end

local function judge(model)
    local status = model:FindFirstChild("SymptomStatus")
    local bpm = model:FindFirstChild("BPM")
    local temp = model:FindFirstChild("Temp")
    local contaminated = model:FindFirstChild("HasContaminatedItems")
    local breath = getBreathingStatus(model)

    if status and status.Value == "Zombie" then
        return "Liquidation"
    end

    if contaminated and contaminated:IsA("BoolValue") and contaminated.Value == true then
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

-- Prevent double-processing
local processed = {}

local function process(model)
    if processed[model] then return end
    processed[model] = true

    local result = judge(model)
    SendToBlock:FireServer(result)
end

-- Initial run
for _, model in ipairs(Civilians:GetChildren()) do
    task.defer(function()
        process(model)
    end)
end

-- Handle new civilians
Civilians.ChildAdded:Connect(function(model)
    task.wait(0.2)
    process(model)
end)
