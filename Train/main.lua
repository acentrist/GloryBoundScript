loadstring(game:HttpGet("https://raw.githubusercontent.com/krissisis898-dev/Roblox-/refs/heads/main/Roblox%20Anti%20AFK-Script%20(updatet)", true))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

if getgenv().GloryBoundCleanup then
	getgenv().GloryBoundCleanup()
end

local oldGui = LocalPlayer.PlayerGui:FindFirstChild("GloryBoundAutoFarm")
if oldGui then oldGui:Destroy() end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TrainRepRemote = Remotes:WaitForChild("TrainRep")
local TrainStopRemote = Remotes:WaitForChild("TrainStop")
local RebirthRemote = Remotes:WaitForChild("Rebirth")

local function loadShared(path)
	local node = ReplicatedStorage:WaitForChild("Shared", 20)
	for name in string.gmatch(path, "[^%.]+") do
		node = node and node:WaitForChild(name, 10)
	end
	if not node then return nil end
	local ok, result = pcall(require, node)
	if ok then return result end
	return nil
end

local Config = loadShared("Config")

local EQUIPMENT_MODE = "1.5x"
local REP_INTERVAL = 0.33
local REBIRTH_STOP_DELAY = 0.3
local REBIRTH_RETRY_DELAY = 3
local REBIRTH_CONFIRM_TIMEOUT = 3
local NEW_CAP_READY_STABLE_SECONDS = 1

local enabled = false
local lastRepTime = 0
local isRebirthing = false
local isStartingTraining = false
local rebirthNeedsClear = false
local rebirthPreviousCap = nil
local newCapReadySince = nil
local statusText = "Idle"

local connections = {}
local function connect(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(connections, conn)
	return conn
end

local function num(value, default)
	local n = tonumber(value)
	if n == nil or n ~= n then
		return default
	end
	return n
end

local function parseDisplayNumber(value)
	local numberPart, suffix = string.match(value or "", "^%s*([%d,%.]+)%s*([%a]*)%s*$")
	if not numberPart then return nil end
	local multipliers = { [""] = 1, k = 1e3, m = 1e6, b = 1e9, t = 1e12,
		qa = 1e15, qi = 1e18, sx = 1e21, sp = 1e24, oc = 1e27, no = 1e30, dc = 1e33 }
	local multiplier = multipliers[string.lower(suffix)]
	local n = tonumber((string.gsub(numberPart, ",", "")))
	if not multiplier or not n then return nil end
	return n * multiplier
end

local function getState()
	local function readText(path)
		local node = LocalPlayer:FindFirstChild("PlayerGui")
		for _, name in ipairs(path) do
			node = node and node:FindFirstChild(name)
		end
		if node and (node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox")) then
			return node.Text
		end
		return ""
	end

	local rebirthText = readText({"LobbyHUD", "Root", "LobbyHUD", "LeftColumn", "Chips", "Rebirth", "Row", "Text"})
	local trainingStatus = readText({"Training", "Root", "TrainingPanel", "Card", "Body", "Info", "Status"})
	local strengthText = readText({"LobbyHUD", "Root", "LobbyHUD", "LeftColumn", "Chips", "Strength", "Row", "Text"})
	local currentStrength, strengthCap
	local currentText, capText = string.match(strengthText, "^%s*(.-)%s*/%s*(.-)%s*$")
	if currentText and capText then
		currentStrength = parseDisplayNumber(currentText)
		strengthCap = parseDisplayNumber(capText)
	end

	local readyText = string.lower(rebirthText .. " " .. trainingStatus)
	local uiSaysReady = string.find(readyText, "rebirth ready", 1, true) ~= nil
	local readyAttribute = LocalPlayer:GetAttribute("RebirthReady")
	local strengthKnown = currentStrength ~= nil and strengthCap ~= nil
	local rebirthReady
	local readySource
	local readyKnown = true
	if type(readyAttribute) == "boolean" then
		rebirthReady = readyAttribute
		readySource = "RebirthReady attribute"
	elseif rebirthText ~= "" then
		rebirthReady = string.match(string.lower(rebirthText), "^%s*rebirth%s+ready%s*$") ~= nil
		readySource = "Rebirth HUD"
	elseif trainingStatus ~= "" then
		rebirthReady = uiSaysReady
		readySource = "Training HUD"
	else
		rebirthReady = false
		readyKnown = false
		readySource = "Unavailable"
	end
	if strengthKnown and currentStrength < strengthCap then
		rebirthReady = false
	end

	return {
		Rebirth = num(LocalPlayer:GetAttribute("Rebirth"), 0),
		Level = num(LocalPlayer:GetAttribute("Level"), 0),
		Strength = num(currentStrength, 0),
		StrengthCap = num(strengthCap, math.huge),
		StrengthKnown = strengthKnown,
		ReadyKnown = readyKnown,
		RebirthReady = rebirthReady,
	}
end

local function getRoot()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function fireAction(name, remote)
	remote:FireServer()
end

local function isTraining()
	local training = LocalPlayer:GetAttribute("Training")
	return training ~= nil and training ~= ""
end

local function stopTraining()
	if isTraining() then
		fireAction("TrainStop", TrainStopRemote)
	end
end

local function maxRebirth()
	local n = Config and Config.Rebirth and tonumber(Config.Rebirth.MaxRebirth)
	return n or math.huge
end

local function rebirthStatus(state)
	local rebirth = math.floor(num(state.Rebirth, 0))
	if rebirth >= maxRebirth() then
		return false, "Max"
	end

	if state.RebirthReady == true then
		return true, "Ready"
	end

	return false, "Strength"
end

local function findMachine()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then return nil end
	local gym = lobby:FindFirstChild("Gym")
	if not gym then return nil end
	local barbells = gym:FindFirstChild("Barbells")
	if not barbells then return nil end

	local root = getRoot()
	local best, bestDist = nil, math.huge

	for _, b in ipairs(barbells:GetChildren()) do
		local boost = b:GetAttribute("Boost")
		local occupant = b:GetAttribute("Occupant")
		local prompt = b:FindFirstChild("TrainPrompt", true)

		local matchesMode
		if EQUIPMENT_MODE == "1.5x" then
			matchesMode = boost and boost >= 1.5
		else
			matchesMode = not boost or boost < 1.5
		end

		if matchesMode and prompt
			and (occupant == 0 or occupant == LocalPlayer.UserId) then
			local part = b:FindFirstChildWhichIsA("BasePart", true)
			if part and root then
				local dist = (root.Position - part.Position).Magnitude
				if dist < bestDist then
					bestDist = dist
					best = {model = b, prompt = prompt, part = part}
				end
			end
		end
	end

	return best
end

local function startTraining()
	if isStartingTraining then return false end
	isStartingTraining = true

	local machine = findMachine()
	if not machine then
		statusText = "No available " .. EQUIPMENT_MODE .. " machine"
		isStartingTraining = false
		return false
	end

	local root = getRoot()
	if not root then
		statusText = "Waiting for character..."
		isStartingTraining = false
		return false
	end

	statusText = "Moving to " .. machine.model.Name .. "..."
	root.CFrame = CFrame.new(machine.part.Position + Vector3.new(0, 3, 0))
	task.wait(0.5)

	fireproximityprompt(machine.prompt)
	task.wait(1)

	isStartingTraining = false

	if isTraining() then
		statusText = "Training at " .. machine.model.Name
		return true
	end

	statusText = "Failed to start - retrying"
	return false
end

local function skipRebirthCutscene()
	local controllers = LocalPlayer.PlayerScripts:FindFirstChild("Controllers")
	if not controllers then return end
	local cutscene = controllers:FindFirstChild("RebirthCutscene")
	if not cutscene then return end
	local ok, mod = pcall(require, cutscene)
	if ok and type(mod) == "table" and mod.isPlaying and mod.isPlaying() then
		pcall(mod.stop)
	end
end

local function getShrinePosition()
	local lobby = workspace:FindFirstChild("Lobby")
	local stations = lobby and lobby:FindFirstChild("Stations")
	local shrine = stations and stations:FindFirstChild("RebirthShrine")
	if not shrine then return nil end

	local bestPrompt, bestScore = nil, 0
	for _, d in ipairs(shrine:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			local score = 1
			if d:GetAttribute("Opens") == "Rebirth" then
				score = 3
			elseif d.Name == "OpenPrompt" then
				score = 2
			end
			if score > bestScore then
				bestScore = score
				bestPrompt = d
			end
		end
	end

	local parent = bestPrompt and bestPrompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	end

	local part = shrine:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position
end

local function doRebirth()
	if isRebirthing then return end
	isRebirthing = true

	local beforeState = getState()
	local before = math.floor(num(beforeState.Rebirth, 0))
	local beforeCap = beforeState.StrengthKnown and beforeState.StrengthCap or nil

	statusText = "Stopping training..."
	stopTraining()
	task.wait(REBIRTH_STOP_DELAY)

	local root = getRoot()
	local position = getShrinePosition()

	if root and position then
		statusText = "Moving to shrine..."
		root.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
		task.wait(0.5)

		statusText = "Rebirthing..."
		fireAction("Rebirth", RebirthRemote)

		local deadline = os.clock() + REBIRTH_CONFIRM_TIMEOUT
		while os.clock() < deadline and math.floor(num(getState().Rebirth, 0)) <= before do
			task.wait(0.1)
		end
		task.wait(0.3)
		skipRebirthCutscene()
	else
		statusText = "RebirthShrine not found"
	end

	task.wait(0.5)

	if math.floor(num(getState().Rebirth, 0)) > before then
		rebirthNeedsClear = true
		rebirthPreviousCap = beforeCap
		newCapReadySince = nil
		statusText = "Rebirth done - resuming"
	else
		statusText = "Rebirth failed - will retry"
		task.wait(REBIRTH_RETRY_DELAY)
	end

	isRebirthing = false
end

local function create(class, properties, parent)
	local instance = Instance.new(class)
	for name, value in pairs(properties) do instance[name] = value end
	instance.Parent = parent
	return instance
end

local gui = create("ScreenGui", {
	Name = "GloryBoundAutoFarm", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, LocalPlayer:WaitForChild("PlayerGui"))
local main = create("Frame", {
	Name = "Panel", Size = UDim2.fromOffset(250, 80),
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 1,
	BorderColor3 = Color3.fromRGB(75, 75, 75),
}, gui)
local titleBar = create("Frame", {
	Name = "Header", Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0,
}, main)
create("TextLabel", {
	Name = "Title", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
	BackgroundTransparency = 1, Text = "AUTO TRAIN & AUTO REBIRTH", TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(240, 240, 240), Font = Enum.Font.SourceSansBold, TextSize = 16,
}, titleBar)
local toggleBtn = create("TextButton", {
	Name = "Toggle_Train", Position = UDim2.fromOffset(8, 42), Size = UDim2.new(1, -16, 0, 30),
	BackgroundColor3 = Color3.fromRGB(40, 40, 40), BorderSizePixel = 0,
	Text = "  Auto Train & Rebirth", TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(235, 235, 235), Font = Enum.Font.SourceSans, TextSize = 16,
	AutoButtonColor = false,
}, main)
local toggleStatus = create("TextLabel", {
	Name = "Status_Train", Position = UDim2.new(1, -49, 0, 0), Size = UDim2.fromOffset(42, 30),
	BackgroundTransparency = 1, Text = "OFF", TextColor3 = Color3.fromRGB(180, 180, 180),
	Font = Enum.Font.SourceSansBold, TextSize = 15,
}, toggleBtn)
local function setEnabled(value)
	enabled = value
	toggleStatus.Text = value and "ON" or "OFF"
	toggleStatus.TextColor3 = value and Color3.fromRGB(130, 215, 150) or Color3.fromRGB(180, 180, 180)
	if not value then
		stopTraining()
		statusText = "Idle"
	end
end
connect(toggleBtn.MouseButton1Click, function()
	setEnabled(not enabled)
end)

local drag
local function inside(element, position)
	local origin, size = element.AbsolutePosition, element.AbsoluteSize
	return position.X >= origin.X and position.Y >= origin.Y
		and position.X < origin.X + size.X and position.Y < origin.Y + size.Y
end
connect(UserInputService.InputBegan, function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if not inside(titleBar, input.Position) then return end
	local origin = main.AbsolutePosition
	drag = {input = input, touch = input.UserInputType == Enum.UserInputType.Touch,
		startX = input.Position.X, startY = input.Position.Y, panelX = origin.X, panelY = origin.Y}
	main.AnchorPoint = Vector2.new(0, 0)
	main.Position = UDim2.fromOffset(origin.X, origin.Y)
end)
connect(UserInputService.InputChanged, function(input)
	if not drag then return end
	if drag.touch then
		if input ~= drag.input then return end
	elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	local x = drag.panelX + input.Position.X - drag.startX
	local y = drag.panelY + input.Position.Y - drag.startY
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
	if viewport then
		x = math.clamp(x, 0, math.max(0, viewport.X - main.AbsoluteSize.X))
		y = math.clamp(y, 0, math.max(0, viewport.Y - main.AbsoluteSize.Y))
	end
	main.Position = UDim2.fromOffset(x, y)
end)
connect(UserInputService.InputEnded, function(input)
	if drag and ((drag.touch and input == drag.input)
		or (not drag.touch and input.UserInputType == Enum.UserInputType.MouseButton1)) then drag = nil end
end)
connect(UserInputService.WindowFocusReleased, function() drag = nil end)

task.spawn(function()
	while gui.Parent do
		if enabled and not isRebirthing and not isStartingTraining then
			local ok, state = pcall(getState)
			if ok and state then
				local zone = LocalPlayer:GetAttribute("Zone")
				local lobbyStatus = LocalPlayer:GetAttribute("LobbyStatus")
				if zone == "Arena" or lobbyStatus == "Arena" then
					statusText = "In Arena - paused"
				else
					local ready = rebirthStatus(state)
					if rebirthNeedsClear then
						if not ready and state.ReadyKnown then
							rebirthNeedsClear = false
							newCapReadySince = nil
						elseif ready and rebirthPreviousCap and state.StrengthKnown
							and state.StrengthCap > rebirthPreviousCap and state.Strength >= state.StrengthCap then
							newCapReadySince = newCapReadySince or os.clock()
							if os.clock() - newCapReadySince >= NEW_CAP_READY_STABLE_SECONDS then
								rebirthNeedsClear = false
								newCapReadySince = nil
							else
								ready = false
							end
						else
							newCapReadySince = nil
							ready = false
						end
					end

					if ready then
						doRebirth()
					elseif not isTraining() then
						startTraining()
					else
						local now = os.clock()
						if now - lastRepTime >= REP_INTERVAL then
							TrainRepRemote:FireServer(1)
							lastRepTime = now
						end
						statusText = "Training..."
					end
				end
			end
		end
		task.wait(0.1)
	end
end)

connect(LocalPlayer.Idled, function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

getgenv().GloryBoundCleanup = function()
	enabled = false
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	if gui.Parent then gui:Destroy() end
end
