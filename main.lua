local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

task.spawn(function()

	while true do		pcall(function()

			local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

			local humanoid = char:FindFirstChildWhichIsA("Humanoid")

			if humanoid then

				humanoid.WalkSpeed = 28

			end

		end)

		task.wait(0.1)

	end

end)

local ProxPromptCache = {}

local function setupPrompt(prompt)

	if not prompt:IsA("ProximityPrompt") or ProxPromptCache[prompt] then return end

	ProxPromptCache[prompt] = true

	prompt.HoldDuration = 0

	local function autoFire()

		pcall(function()

			local part = prompt.Parent

			if not (part and part:IsA("BasePart") and prompt.Enabled) then return end

			local name = part.Name:lower()

			local action = prompt.ActionText

			if name == "head" or name == "torso" or name == "pour" then

				prompt:InputHoldBegin()

				prompt:InputHoldEnd()

			elseif action == "Examine" then

				prompt:InputHoldBegin()

				prompt:InputHoldEnd()

				task.wait(0.3)

			end

		end)

	end

	RunService.Heartbeat:Connect(function()

		if prompt.Parent and prompt.Enabled then

			autoFire()

		end

	end)

	prompt.AncestryChanged:Connect(function(_, parent)

		if not parent then

			ProxPromptCache[prompt] = nil

		end

	end)

end

task.spawn(function()

	while true do

		for _, prompt in ipairs(Workspace:GetDescendants()) do

			if prompt:IsA("ProximityPrompt") and not ProxPromptCache[prompt] then

				setupPrompt(prompt)

			end

		end

		task.wait(1)

	end

end)

local generatorFillRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GeneratorFill")

RunService.Heartbeat:Connect(function()

	pcall(function()

		generatorFillRemote:FireServer(true)

	end)

end)

local Civilians = Workspace:WaitForChild("Civilians")

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

local function updateESP(model, status)

	local root = model:FindFirstChild("HumanoidRootPart")

	if not root then return end

	local gui = model:FindFirstChild("StatusESP")

	if not gui then

		gui = Instance.new("BillboardGui")

		gui.Name = "StatusESP"

		gui.Adornee = root

		gui.AlwaysOnTop = true

		gui.Size = UDim2.new(0, 60, 0, 48)

		gui.StudsOffset = Vector3.new(0, 3, 0)

		gui.Parent = model

		local nameText = Instance.new("TextLabel")

		nameText.Name = "Name"

		nameText.Size = UDim2.new(1, 0, 0, 12)

		nameText.Position = UDim2.new(0, 0, 0, 3.1)

		nameText.BackgroundTransparency = 1

		nameText.Font = Enum.Font.SourceSans

		nameText.TextSize = 12

		nameText.Text = model.Name

		nameText.TextColor3 = Color3.fromRGB(180,180,180)

		nameText.TextYAlignment = Enum.TextYAlignment.Center

		nameText.TextStrokeTransparency = 1

		nameText.Parent = gui

		local label = Instance.new("TextLabel")

		label.Name = "Label"

		label.Size = UDim2.new(1, 0, 0, 16)

		label.Position = UDim2.new(0, 0, 0, 14)

		label.BackgroundTransparency = 1

		label.Font = Enum.Font.Gotham

		label.TextSize = 13

		label.TextStrokeTransparency = 0.5

		label.TextYAlignment = Enum.TextYAlignment.Center

		label.Parent = gui

		local info = Instance.new("TextLabel")

		info.Name = "Info"

		info.Size = UDim2.new(1, 0, 0, 20)

		info.Position = UDim2.new(0, 0, 0, 30)

		info.BackgroundTransparency = 1

		info.Font = Enum.Font.SourceSans

		info.TextScaled = true

		info.TextStrokeTransparency = 1

		info.RichText = true

		info.TextColor3 = Color3.fromRGB(150,150,150)

		info.TextYAlignment = Enum.TextYAlignment.Center

		info.Parent = gui

	end

	local label = gui:FindFirstChild("Label")

	local info = gui:FindFirstChild("Info")

	if not label or not info then return end

	if status == "Zombie" then

		label.Text = "Infected"

		label.TextColor3 = Color3.fromRGB(255, 0, 0)

		info.Text = ""

	elseif status == "Safe" then

		label.Text = "Safe"

		label.TextColor3 = Color3.fromRGB(0, 255, 0)

		info.Text = ""

	elseif status == "Quarantine" then

		label.Text = "Quarantine"

		label.TextColor3 = Color3.fromRGB(255, 255, 0)

		local bpm = model:FindFirstChild("BPM")

		local temp = model:FindFirstChild("Temp")

		local breathingVal, breathingColor = getBreathingStatus(model)

		local bpmVal = bpm and bpm.Value or "0"

		local tempVal = temp and temp.Value or "0"

		local bpmColor = getColor(bpmVal, 90, 140, 999)

		local tempColor = getTempColor(tempVal)

		local contaminationText = "No contaminated items"

		local contaminationColor = Color3.fromRGB(0, 255, 0)

		local contamValue = model:FindFirstChild("HasContaminatedItems")

		if contamValue and contamValue:IsA("BoolValue") and contamValue.Value then

			contaminationText = "Has contaminated items"

			contaminationColor = Color3.fromRGB(255, 0, 0)

		end

		info.Text = string.format(

			'<p align="center"><font color="#FFFFFF">BPM: </font><font color="#%02X%02X%02X">%s</font>  <font color="#FFFFFF">Temp: </font><font color="#%02X%02X%02X">%s</font><br/><font color="#FFFFFF">Breathing: </font><font color="#%02X%02X%02X">%s</font><br/><font color="#%02X%02X%02X">%s</font></p>',

			bpmColor.R*255, bpmColor.G*255, bpmColor.B*255, tostring(bpmVal),

			tempColor.R*255, tempColor.G*255, tempColor.B*255, tostring(tempVal),

			breathingColor.R*255, breathingColor.G*255, breathingColor.B*255, breathingVal,

			contaminationColor.R*255, contaminationColor.G*255, contaminationColor.B*255, contaminationText

		)

	else

		if gui then gui:Destroy() end

	end

end

local trackedModels = {}

local function handleModel(model)

	if not model:IsA("Model") then return end

	if trackedModels[model] then return end

	local humanoid = model:FindFirstChildWhichIsA("Humanoid")

	local status = model:FindFirstChild("SymptomStatus")

	local root = model:FindFirstChild("HumanoidRootPart")

	if not (humanoid and status and root) then return end

	trackedModels[model] = true

	updateESP(model, status.Value)

	local connStatus

	connStatus = status:GetPropertyChangedSignal("Value"):Connect(function()

		updateESP(model, status.Value)

	end)

	local connDied

	connDied = humanoid.Died:Connect(function()

		local esp = model:FindFirstChild("StatusESP")

		if esp then esp:Destroy() end

		connStatus:Disconnect()

		connDied:Disconnect()

		trackedModels[model] = nil

	end)

end

for _, model in ipairs(Civilians:GetChildren()) do

	handleModel(model)

end

local ZombiesFolder = Workspace:WaitForChild("Zombies")

local function createHealthBar(humanoid, head)

	local billboard = Instance.new("BillboardGui")

	billboard.Name = "HealthBar"

	billboard.Adornee = head

	billboard.Size = UDim2.new(4, 0, 0.5, 0)

	billboard.StudsOffset = Vector3.new(0, 1.5, 0)

	billboard.AlwaysOnTop = true

	billboard.Parent = head

	local background = Instance.new("Frame")

	background.Size = UDim2.new(1, 0, 1, 0)

	background.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

	background.BorderSizePixel = 0

	background.Parent = billboard

	local healthBar = Instance.new("Frame")

	healthBar.Size = UDim2.new(1, 0, 1, 0)

	healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)

	healthBar.BorderSizePixel = 0

	healthBar.Parent = background

	local function updateHealth()

		local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)

		healthBar:TweenSize(UDim2.new(healthPercent, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)

		if healthPercent > 0.5 then

			healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)

		elseif healthPercent > 0.2 then

			healthBar.BackgroundColor3 = Color3.fromRGB(255, 165, 0)

		else

			healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)

		end

	end

	local healthConn = humanoid:GetPropertyChangedSignal("Health"):Connect(updateHealth)

	updateHealth()

	humanoid.Died:Connect(function()

		healthConn:Disconnect()

		if billboard then billboard:Destroy() end

	end)

	local removalConn

	removalConn = humanoid.Parent.AncestryChanged:Connect(function(_, parent)

		if not parent then

			healthConn:Disconnect()

			removalConn:Disconnect()

			if billboard then billboard:Destroy() end

		end

	end)

end

local trackedZombies = {}

local function handleZombie(zombie)

	if trackedZombies[zombie] then return end

	if not zombie:IsA("Model") then return end

	local humanoid = zombie:FindFirstChildWhichIsA("Humanoid")

	local head = zombie:FindFirstChild("Head")

	if humanoid and head then

		trackedZombies[zombie] = true

		createHealthBar(humanoid, head)

	end

end

for _, zombie in ipairs(ZombiesFolder:GetChildren()) do

	handleZombie(zombie)

end

ZombiesFolder.ChildAdded:Connect(function(child)

	task.wait(0.1)

	handleZombie(child)

end)
