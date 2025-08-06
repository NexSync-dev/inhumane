local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Get the required services and folders
local Civilians = Workspace:WaitForChild("Civilians")
local SendToBlockRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SendToBlock")

-- Track which models we've already processed
local processedModels = {}

-- Detection functions from ESP script
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

-- Comprehensive status detection function
local function determineActualStatus(model)
    -- First check SymptomStatus if it exists
    local symptomStatus = model:FindFirstChild("SymptomStatus")
    if symptomStatus then
        local status = symptomStatus.Value
        if status == "Zombie" then
            return "Infected"
        elseif status == "Safe" then
            return "Safe"
        elseif status == "Quarantine" then
            -- For quarantine, do additional checks to see if they should really be liquidated
            local bpm = model:FindFirstChild("BPM")
            local temp = model:FindFirstChild("Temp")
            local breathingVal, breathingColor = getBreathingStatus(model)
            local contamValue = model:FindFirstChild("HasContaminatedItems")
            
            local bpmVal = bpm and tonumber(bpm.Value) or 0
            local tempVal = temp and tonumber(temp.Value) or 0
            
            -- Check for critical conditions that warrant liquidation
            local isCritical = false
            
            -- Critical BPM (too high)
            if bpmVal > 140 then
                isCritical = true
            end
            
            -- Critical temperature
            if tempVal > 104 then
                isCritical = true
            end
            
            -- Critical breathing
            if breathingVal == "Bad" then
                isCritical = true
            end
            
            -- Has contaminated items
            if contamValue and contamValue:IsA("BoolValue") and contamValue.Value then
                isCritical = true
            end
            
            if isCritical then
                return "Infected" -- Send to liquidation
            else
                return "Quarantine" -- Keep in quarantine
            end
        end
    end
    
    -- Fallback: Check individual components if SymptomStatus doesn't exist
    local bpm = model:FindFirstChild("BPM")
    local temp = model:FindFirstChild("Temp")
    local breathingVal, breathingColor = getBreathingStatus(model)
    local contamValue = model:FindFirstChild("HasContaminatedItems")
    
    local bpmVal = bpm and tonumber(bpm.Value) or 0
    local tempVal = temp and tonumber(temp.Value) or 0
    
    -- Determine status based on vital signs
    local isCritical = false
    local hasSymptoms = false
    
    -- Critical conditions (liquidation)
    if bpmVal > 140 or tempVal > 104 or breathingVal == "Bad" then
        isCritical = true
    end
    
    -- Has contaminated items (liquidation)
    if contamValue and contamValue:IsA("BoolValue") and contamValue.Value then
        isCritical = true
    end
    
    -- Mild symptoms (quarantine)
    if (bpmVal > 90 and bpmVal <= 140) or (tempVal >= 100 and tempVal <= 104) then
        hasSymptoms = true
    end
    
    if isCritical then
        return "Infected"
    elseif hasSymptoms then
        return "Quarantine"
    else
        return "Safe"
    end
end

-- Auto-judge function for the first person in line
local function judgeFirstPerson()
    -- Get the first civilian in the folder
    local firstCivilian = Civilians:GetChildren()[1]
    
    if not firstCivilian or not firstCivilian:IsA("Model") then
        return
    end
    
    local humanoid = firstCivilian:FindFirstChildWhichIsA("Humanoid")
    local status = firstCivilian:FindFirstChild("SymptomStatus")
    local root = firstCivilian:FindFirstChild("HumanoidRootPart")
    
    if not (humanoid and status and root) then 
        return 
    end
    
    -- Check if this person was already judged
    if processedModels[firstCivilian] then
        return
    end
    
    pcall(function()
        local currentStatus = status.Value
        
        -- Debug: Print what we're actually reading
        print("DEBUG: " .. firstCivilian.Name .. " has status: '" .. tostring(currentStatus) .. "'")
        
        if currentStatus == "Zombie" then
            -- Send infected to Liquidation
            local args = {
                [1] = "Liquidation"
            }
            SendToBlockRemote:FireServer(unpack(args))
            print("Judged " .. firstCivilian.Name .. " -> Liquidation (Infected)")
            
        elseif currentStatus == "Safe" then
            -- Send safe to Survivor
            local args = {
                [1] = "Survivor"
            }
            SendToBlockRemote:FireServer(unpack(args))
            print("Judged " .. firstCivilian.Name .. " -> Survivor (Safe)")
            
        elseif currentStatus == "Quarantine" then
            -- Send quarantine to Quarantine
            local args = {
                [1] = "Quarantine"
            }
            SendToBlockRemote:FireServer(unpack(args))
            print("Judged " .. firstCivilian.Name .. " -> Quarantine")
        else
            -- Debug: Show what unrecognized status we got
            print("WARNING: Unrecognized status '" .. tostring(currentStatus) .. "' for " .. firstCivilian.Name)
        end
        
        -- Mark as processed
        processedModels[firstCivilian] = true
    end)
end

-- Continuous monitoring loop to judge the first person
task.spawn(function()
    while true do
        judgeFirstPerson()
        task.wait(1) -- Check every second for new first person
    end
end)

-- Clean up processed models when they're removed
Civilians.ChildRemoved:Connect(function(child)
    if processedModels[child] then
        processedModels[child] = nil
    end
end)

print("Auto-Judge Script Loaded!")
print("Safe -> Survivor")
print("Quarantine -> Quarantine") 
print("Infected -> Liquidation")
