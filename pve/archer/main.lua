loadstring(game:HttpGet("https://raw.githubusercontent.com/krissisis898-dev/Roblox-/refs/heads/main/Roblox%20Anti%20AFK-Script%20(updatet)", true))()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = ReplicatedStorage:WaitForChild("GameState")

local controls = {attack = true, revive = true, retry = true, dash = true,
	ability = true, movement = true, boon = true, freecam = true, cursor = false}
local controlListeners = {}
local function onControlChanged(callback)
	table.insert(controlListeners, callback)
end
local function setControl(name, value)
	if controls[name] == value then return end
	controls[name] = value
	for _, callback in ipairs(controlListeners) do
		local ok, err = pcall(callback, name, value)
		if not ok then warn("[Controls] " .. tostring(err)) end
	end
end

-- Retry starts enabled, as indicated by the control panel.
task.spawn(function()
	local leaveMatch = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LeaveMatch")
	local sent = false
	local function checkRetry()
		if GameState:GetAttribute("Phase") ~= "Ending" then sent = false; return end
		if GameState:GetAttribute("NightmareGate") == "open" then return end
		if sent or not controls.retry then return end
		sent = true
		leaveMatch:FireServer("retry")
	end
	GameState:GetAttributeChangedSignal("Phase"):Connect(checkRetry)
	GameState:GetAttributeChangedSignal("NightmareGate"):Connect(checkRetry)
	onControlChanged(function(name, enabled)
		if name == "retry" and enabled then checkRetry() end
	end)
	checkRetry()
end)


task.spawn(function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
if not playerGui then return end

local previous = playerGui:FindFirstChild("ControlPanelMock")
if previous then previous:Destroy() end

local function create(class, properties, parent)
	local instance = Instance.new(class)
	for name, value in pairs(properties) do instance[name] = value end
	instance.Parent = parent
	return instance
end

local screen = create("ScreenGui", {
	Name = "ControlPanelMock", ResetOnSpawn = false, IgnoreGuiInset = true,
	DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local panel = create("Frame", {
	Name = "Panel", Size = UDim2.fromOffset(250, 319),
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(32, 32, 32), BorderSizePixel = 1,
	BorderColor3 = Color3.fromRGB(75, 75, 75),
}, screen)
local header = create("Frame", {
	Name = "Header", Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = Color3.fromRGB(45, 45, 45), BorderSizePixel = 0,
}, panel)
create("TextLabel", {
	Name = "Title", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
	BackgroundTransparency = 1, Text = "CONTROLS", TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(240, 240, 240), Font = Enum.Font.SourceSansBold, TextSize = 16,
}, header)

local items = {
	{id = "attack", name = "Attack", key = Enum.KeyCode.One, number = "1"},
	{id = "revive", name = "Revive", key = Enum.KeyCode.Two, number = "2"},
	{id = "retry", name = "Retry", key = Enum.KeyCode.Three, number = "3"},
	{id = "dash", name = "Dash", key = Enum.KeyCode.Four, number = "4"},
	{id = "ability", name = "Ability", key = Enum.KeyCode.Five, number = "5"},
	{id = "movement", name = "Movement", key = Enum.KeyCode.Six, number = "6"},
	{id = "boon", name = "Boon", key = Enum.KeyCode.Seven, number = "7"},
	{id = "freecam", name = "Freecam", key = Enum.KeyCode.Eight, number = "8"},
}
local rowsByKey, connections = {}, {}
local function refresh(row)
	row.status.Text = row.enabled and "ON" or "OFF"
	row.status.TextColor3 = row.enabled and Color3.fromRGB(130, 215, 150) or Color3.fromRGB(180, 180, 180)
end
local function toggle(row)
	row.enabled = not row.enabled
	setControl(row.id, row.enabled)
	refresh(row)
end
for index, item in ipairs(items) do
	local button = create("TextButton", {
		Name = "Toggle_" .. item.id, Position = UDim2.fromOffset(8, 42 + (index - 1) * 34),
		Size = UDim2.new(1, -16, 0, 30), BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BorderSizePixel = 0, Text = "  " .. item.number .. "    " .. item.name,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(235, 235, 235),
		Font = Enum.Font.SourceSans, TextSize = 16, AutoButtonColor = false,
	}, panel)
	local status = create("TextLabel", {
		Name = "Status_" .. item.id, Position = UDim2.new(1, -49, 0, 0), Size = UDim2.fromOffset(42, 30),
		BackgroundTransparency = 1, Font = Enum.Font.SourceSansBold, TextSize = 15,
	}, button)
	local row = {id = item.id, enabled = controls[item.id], status = status}
	rowsByKey[item.key] = row
	button.MouseButton1Click:Connect(function() toggle(row) end)
	refresh(row)
end

local drag
local function inside(gui, position)
	local origin, size = gui.AbsolutePosition, gui.AbsoluteSize
	return position.X >= origin.X and position.Y >= origin.Y
		and position.X < origin.X + size.X and position.Y < origin.Y + size.Y
end
table.insert(connections, UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			setControl("cursor", true); return
		end
		local row = rowsByKey[input.KeyCode]
		if row then toggle(row) end
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if not inside(header, input.Position) then return end
	local origin = panel.AbsolutePosition
	drag = {input = input, touch = input.UserInputType == Enum.UserInputType.Touch,
		startX = input.Position.X, startY = input.Position.Y, panelX = origin.X, panelY = origin.Y}
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.fromOffset(origin.X, origin.Y)
end))
table.insert(connections, UserInputService.InputChanged:Connect(function(input)
	if not drag then return end
	if drag.touch then
		if input ~= drag.input then return end
	elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local x = drag.panelX + input.Position.X - drag.startX
	local y = drag.panelY + input.Position.Y - drag.startY
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
	if viewport then
		x = math.clamp(x, 0, math.max(0, viewport.X - panel.AbsoluteSize.X))
		y = math.clamp(y, 0, math.max(0, viewport.Y - panel.AbsoluteSize.Y))
	end
	panel.Position = UDim2.fromOffset(x, y)
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then setControl("cursor", false) end
	if drag and ((drag.touch and input == drag.input)
		or (not drag.touch and input.UserInputType == Enum.UserInputType.MouseButton1)) then drag = nil end
end))
table.insert(connections, UserInputService.WindowFocusReleased:Connect(function() drag = nil; setControl("cursor", false) end))
screen.Destroying:Connect(function()
	drag = nil
	setControl("cursor", false)
	for _, connection in ipairs(connections) do connection:Disconnect() end
end)

end)
task.spawn(function()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")

local player = Players.LocalPlayer
local enemiesFolder = workspace:WaitForChild("ActiveEnemies")
local floor = workspace:WaitForChild("Arena")
	:WaitForChild("Core")
	:WaitForChild("Floor")

-- Tunable policy, not claimed server limits. Distances/times of live prompts take precedence.
local policy = {
    tpwalkRatio = 0.0, -- Additional fraction of Humanoid.WalkSpeed; 0 disables it.
    maxMovementStep = 0.05, -- discard lag catch-up; do not bank displacement
    arrivalTolerance = 0.35,
    reviveRangeMargin = 1, -- stay inside the prompt's original activation range
    reviveRetry = 0.15,
    holdAckTimeout = 0.4, -- local input acknowledgement, not a shorter revive duration
    serverGrace = 0.4,
    hazardMargin = 2,
    hazardGrace = 0.2,
    stableScoreMargin = 1.5, -- small score changes alone should not reverse a safe plan
    walkSmoothTime = 0.06, -- ordinary movement only; hazard and dash paths bypass it
}
local edgeMargin = 8
local wallMargin = 8
local updateInterval = 0.05
local candidateCount = 24
local predictionTimes = {0.1, 0.35, 0.7, 1.1}
local candidateDirections, objectiveDirections = {}, {}
for i = 0, candidateCount - 1 do
	local angle = i / candidateCount * math.pi * 2
	table.insert(candidateDirections, Vector3.new(math.cos(angle), 0, math.sin(angle)))
end
for i = 0, 15 do
	local angle = i / 16 * math.pi * 2
	table.insert(objectiveDirections, Vector3.new(math.cos(angle), 0, math.sin(angle)))
end
local wallProbeDirections = {
	Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
}


local enemies = {}
local enemyParts = {}
local playerParts = {}
local playerConnections = {}
local threats = {}

local character
local humanoid
local root
local attachment
local orientation
local originalAutoRotate

local escapeTarget
local lastDirection
local attackModel
local attackRoot

local elapsed = updateInterval
local wasMoving = false

local activeCamera
local originalCameraType
local originalMouseBehavior

local obstacleParams = RaycastParams.new()
obstacleParams.FilterType = Enum.RaycastFilterType.Exclude
obstacleParams.RespectCanCollide = true

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.RespectCanCollide = true
sightParams.IgnoreWater = true

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = {floor}

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Shared observations and controls for the existing movement loop.
local bot = {
	debug = false,
	dash = {busyUntil = 0, retryAt = 0, chainUntil = 0, attemptAt = 0},
	eye = {},
	unknownMarks = {},
}


local challenge = {live = false, round = -1}
local completedRound = -1
local tagged = {Purse = {}, ChallengeChariot = {}, VolleyMark = {}, BossMark = {}}
local volleyEvents = {}
local hazards = {}
local selectedPurse
local currentObjective
-- Auto-revive state is shared by movement, attacks, and cleanup.
local revive = {prompt = nil, target = nil, startedAt = 0, retryAt = 0, seeking = false}
local endRevive
local route = {version = 0, requestedAt = -math.huge}
local supportedChallenges = {
	Slaughter = true, Horde = true, Champion = true, Chariot = true,
	Volley = true, Treasure = true, Eye = true, Rivals = true,
}

local function invalidateRoute()
	route.version += 1
	route.key = nil
	route.goal = nil
	route.nodes = nil
	route.index = nil
end

local function clearChallenge()
	challenge = {live = false, round = -1}
	bot.eye = {}
	selectedPurse = nil
	currentObjective = nil
	invalidateRoute()
	elapsed = updateInterval
end

local function objectPosition(instance)
	if not instance:IsDescendantOf(workspace) then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function addVolley(position, radius, impactAt, expiresAt)
	for _, hazard in ipairs(volleyEvents) do
		if flat(hazard.position - position).Magnitude < 1
			and math.abs(hazard.impactAt - impactAt) < 0.6 then
			hazard.expiresAt = math.max(hazard.expiresAt, expiresAt)
			hazard.radius = math.max(hazard.radius, radius)
			return
		end
	end
	table.insert(volleyEvents, {
		position = position, radius = radius, kind = "volley",
		impactAt = impactAt, expiresAt = expiresAt,
	})
end

-- ChallengeWorldFx accepts both server clock and DistributedGameTime timestamps.
function bot.volleyImpactAt(value)
	local time = tonumber(value)
	if not time or time ~= time or math.abs(time) == math.huge then return nil end
	local now = workspace:GetServerTimeNow()
	if time < 100000000 and now > 100000000 then
		return now + time - workspace.DistributedGameTime
	end
	return time
end

local function handleChallenge(payload)
	if type(payload) ~= "table" then
		return
	end
	local event = payload.type
	local round = tonumber(payload.round)
	if event == "matchStart" or event == "arenaWaiting" then
		if event == "matchStart" then bot.matchEnded = false end
		completedRound = -1
		table.clear(volleyEvents)
		clearChallenge()
		return
	end
	if event == "matchEnd" or event == "matchComplete" then
		if bot.releaseAbility then bot.releaseAbility() end
		if bot.releaseDashKey then bot.releaseDashKey() end
		revive.locked = nil
		bot.matchEnded = true
		if bot.onMatchEnd then bot.onMatchEnd() end
		if endRevive then endRevive(false) end
		revive.seeking = false
		bot.dash.chainUntil = 0
		clearChallenge()
		return
	end
	if event == "intermission" then
		if round and round < challenge.round then
			return
		end
		completedRound = math.max(completedRound, challenge.round, (round or 0) - 1)
		clearChallenge()
		return
	end
	if event == "challengeComplete" or event == "roundCleared" then
		completedRound = math.max(completedRound, round or challenge.round)
		if not round or round >= challenge.round then
			clearChallenge()
		end
		return
	end
	if event == "challengeFx" then
		if payload.kind == "volley" then
			local impactAt = bot.volleyImpactAt(payload.impactAt or payload.at)
			local rings = type(payload.rings) == "table" and payload.rings
				or type(payload.marks) == "table" and payload.marks
				or type(payload.points) == "table" and payload.points
			if impactAt and impactAt >= workspace:GetServerTimeNow() - 0.1 and rings then
				for _, item in ipairs(rings) do
					local position = typeof(item) == "Vector3" and item or type(item) == "table" and item.pos
					local radius = type(item) == "table" and tonumber(item.radius) or tonumber(payload.radius)
					if typeof(position) == "Vector3" then
						addVolley(position, math.clamp(radius or tonumber(payload.radius) or 9, 1, 40), impactAt, impactAt + 2.5)
					end
				end
				elapsed = updateInterval
			end
		end
		return
	end
	if event ~= "roundStart" and event ~= "challenge" and event ~= "challengeProgress" then
		return
	end
	local id = payload.id or payload.challenge
	if not supportedChallenges[id] or not round
		or round <= completedRound or round < challenge.round then
		return
	end
	if challenge.id ~= id or challenge.round ~= round then
		clearChallenge()
		challenge.id = id
		challenge.round = round
	end
	challenge.live = true
	if typeof(payload.pos) == "Vector3" then
		challenge.position = payload.pos
	end
	if type(payload.radius) == "number" then
		challenge.radius = payload.radius
	end
	if type(payload.endsAt) == "number" then
		challenge.endsAt = payload.endsAt
	end
	if type(payload.telegraph) == "number" then
		challenge.telegraph = payload.telegraph
	end
	elapsed = updateInterval
end

-- Recover the current objective when this script starts during an active round.
function bot.syncChallenge()
	local phase = GameState:GetAttribute("RoundPhase")
	local id = GameState:GetAttribute("Challenge")
	local round = tonumber(GameState:GetAttribute("Round"))
	if GameState:GetAttribute("ObjectiveActive") ~= true
		or (phase ~= "Combat" and phase ~= "Overtime")
		or not supportedChallenges[id] or not round or round <= completedRound then return end
	if not challenge.live or challenge.id ~= id or round > challenge.round then
		handleChallenge({type = "challenge", id = id, round = round,
			pos = GameState:GetAttribute("ObjectivePos"), endsAt = GameState:GetAttribute("ObjectiveEnd")})
	end
end

local function trackTagged(tag, instance, existing)
	if tagged[tag][instance] then
		return
	end
	tagged[tag][instance] = {
		position = objectPosition(instance),
		radius = tonumber(instance:GetAttribute("Radius")) or (tag == "VolleyMark" and 9 or challenge.radius) or 9,
		impactAt = bot.volleyImpactAt(instance:GetAttribute("ImpactAt"))
			or workspace:GetServerTimeNow() + (existing and 0 or challenge.telegraph or 1.5),
	}
	elapsed = updateInterval
end

for tag in pairs(tagged) do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		trackTagged(tag, instance, false)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		local record = tagged[tag][instance]
		if tag == "VolleyMark" and record and record.position then
			local now = workspace:GetServerTimeNow()
			if record.impactAt <= now + 0.3 and record.impactAt + 2.5 >= now then
				addVolley(record.position, record.radius, record.impactAt, record.impactAt + 2.5)
			end
		end
		tagged[tag][instance] = nil
		if selectedPurse == instance then
			selectedPurse = nil
		end
		elapsed = updateInterval
	end)
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		trackTagged(tag, instance, true)
	end
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MatchEvent")
	.OnClientEvent:Connect(handleChallenge)

function bot.collectBossMarks(result, now)
	for mark in pairs(tagged.BossMark) do
		if mark:IsA("BasePart") and mark:IsDescendantOf(workspace) and mark:GetAttribute("Dry") ~= true then
			local kind = mark:GetAttribute("Kind")
			local impactAt = tonumber(mark:GetAttribute("ImpactAt"))
			local struck = mark:GetAttribute("Struck") ~= nil
			local hazard = {position = mark.Position, impactAt = impactAt or now,
				expiresAt = (impactAt or now) + 0.5, kind = kind}
			if kind == "circle" or kind == "puddle" or kind == "rift" or kind == "star" then
				hazard.radius = tonumber(mark:GetAttribute("Radius"))
				if kind == "puddle" and struck then hazard.expiresAt = now + 0.2 end
			elseif kind == "strip" or kind == "lance" then
				local direction = mark:GetAttribute("Dir")
				if typeof(direction) == "Vector3" and flat(direction).Magnitude > 0.001 then
					direction = flat(direction).Unit
					local length = tonumber(mark:GetAttribute("Length")) or (kind == "strip" and 40 or 60)
					local width = tonumber(mark:GetAttribute("Width")) or (kind == "strip" and 5 or 6)
					length = math.clamp(length, kind == "strip" and 2 or 4, kind == "strip" and 160 or 260)
					width = math.clamp(width, kind == "strip" and 1 or 2, 20)
					hazard.start = flat(mark.Position) - direction * (kind == "lance" and length / 2 or 0)
					hazard.finish = hazard.start + direction * length
					hazard.radius = width / 2
				end
			elseif kind ~= nil and kind ~= "dust" and not bot.unknownMarks[tostring(kind)] then
				bot.unknownMarks[tostring(kind)] = true
				bot.trace("Unknown BossMark kind: " .. tostring(kind))
			end
			if hazard.radius and hazard.radius > 0 and hazard.expiresAt >= now then
				table.insert(result, hazard)
			end
		end
	end
end


local function collectHazards()
	local now = workspace:GetServerTimeNow()
	local result = {}
	for i = #volleyEvents, 1, -1 do
		local hazard = volleyEvents[i]
		if now > hazard.expiresAt then
			table.remove(volleyEvents, i)
		else
			table.insert(result, hazard)
		end
	end
	for instance, record in pairs(tagged.VolleyMark) do
		local position = objectPosition(instance)
		if position and math.abs(position.Y - floor.Position.Y) < 30 then
			record.position = position
			record.radius = tonumber(instance:GetAttribute("Radius")) or record.radius
			local actualImpact = bot.volleyImpactAt(instance:GetAttribute("ImpactAt"))
			if actualImpact then record.impactAt = actualImpact end
			local matched = false
			for _, hazard in ipairs(result) do
				if flat(hazard.position - position).Magnitude < 1
					and math.abs(hazard.impactAt - record.impactAt) < 0.6 then
					matched = true
					break
				end
			end
			if not matched and (not actualImpact or record.impactAt + 2.5 >= now) then
				table.insert(result, {
					position = position, radius = record.radius, kind = "volley",
					impactAt = record.impactAt,
					expiresAt = actualImpact and record.impactAt + 2.5 or math.max(now + 0.1, record.impactAt + 2.5),
				})
			end
		end
	end
	bot.collectBossMarks(result, now)
	return result
end

function bot.playerCameraSubject()
	local currentCharacter = player.Character
	local state = player:GetAttribute("CombatState")
	if not currentCharacter or not currentCharacter.Parent or player:GetAttribute("Zone") ~= "Arena"
		or (state ~= "Alive" and state ~= "Downed") or player:GetAttribute("Spectating") == true
		or player:GetAttribute("Cinematic") == true or currentCharacter:GetAttribute("Cinematic") == true then return nil end
	return currentCharacter:FindFirstChildOfClass("Humanoid")
end

function bot.ensureCameraFollow()
	local camera = workspace.CurrentCamera
	local subject = bot.playerCameraSubject()
	if camera and subject and camera.CameraType == Enum.CameraType.Custom and camera.CameraSubject ~= subject then
		camera.CameraSubject = subject
	end
end

local function restoreCamera(relinquish)
	local currentCharacter = player.Character
	local gameOwnsCamera = relinquish or player:GetAttribute("Cinematic") == true
		or player:GetAttribute("Spectating") == true
		or (currentCharacter and currentCharacter:GetAttribute("Cinematic") == true)
	if not gameOwnsCamera then
		if activeCamera and originalCameraType and activeCamera.CameraType == Enum.CameraType.Scriptable then
			activeCamera.CameraType = originalCameraType
		end
		if activeCamera and originalMouseBehavior and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = originalMouseBehavior
		end
	end
	activeCamera = nil
	originalCameraType = nil
	originalMouseBehavior = nil
	if not gameOwnsCamera then bot.ensureCameraFollow() end
end

local function removeEnemyLinks(entry)
	for playerPart, constraint in pairs(entry.links) do
		constraint:Destroy()
		entry.links[playerPart] = nil
	end
end

local function linkParts(playerPart, enemyPart, entry)
	if not character or not playerPart.Parent or not enemyPart.Parent then
		return
	end

	if entry.links[playerPart] then
		return
	end

	local constraint = Instance.new("NoCollisionConstraint")
	constraint.Part0 = playerPart
	constraint.Part1 = enemyPart
	constraint.Parent = character

	entry.links[playerPart] = constraint
end

local function refreshEnemyPart(enemyPart)
	local entry = enemyParts[enemyPart]

	if not entry then
		return
	end

	if not enemyPart.CanCollide then
		removeEnemyLinks(entry)
		return
	end

	for playerPart in pairs(playerParts) do
		linkParts(playerPart, enemyPart, entry)
	end
end

local function registerEnemyPart(enemyPart, record)
	if not enemyPart:IsA("BasePart") then return end
	local existing = enemyParts[enemyPart]
	if existing then
		record.parts[enemyPart] = true
		existing.owners[record] = true
		return
	end
	local entry = {links = {}, restoreCanCollide = enemyPart.CanCollide, changed = false, owners = {[record] = true}}
	enemyParts[enemyPart] = entry
	record.parts[enemyPart] = true
	if enemyPart.Name == "HumanoidRootPart" then elapsed = updateInterval end
	local function enforce()
		if enemyPart.CanCollide then
			entry.restoreCanCollide = true
			local ok = pcall(function() enemyPart.CanCollide = false end)
			if ok and not enemyPart.CanCollide then entry.changed = true end
		end
		-- Retain the prior per-character constraints as a fallback if the property cannot be set.
		refreshEnemyPart(enemyPart)
	end
	entry.connection = enemyPart:GetPropertyChangedSignal("CanCollide"):Connect(enforce)
	enforce()
end

local function unregisterEnemyPart(enemyPart, record)
	local entry = enemyParts[enemyPart]
	if not entry then return end
	if record then
		entry.owners[record] = nil
		if next(entry.owners) then return end
	end
	if entry.connection then entry.connection:Disconnect() end
	removeEnemyLinks(entry)
	enemyParts[enemyPart] = nil
	if entry.changed and enemyPart.Parent and not enemyPart.CanCollide then
		pcall(function() enemyPart.CanCollide = entry.restoreCanCollide end)
	end
end

local function trackEnemy(enemy, source)
	if not enemy:IsA("Model") then return end
	source = source or "folder"
	if source == "tag" and (Players:GetPlayerFromCharacter(enemy)
		or (CollectionService:HasTag(enemy, "Bot") and not enemy:IsDescendantOf(enemiesFolder))) then return end
	local existing = enemies[enemy]
	if existing then existing.sources[source] = true; return end
	local record = {parts = {}, connections = {}, sources = {[source] = true}}
	enemies[enemy] = record
	table.insert(record.connections, enemy.DescendantAdded:Connect(function(instance)
		registerEnemyPart(instance, record)
	end))
	table.insert(record.connections, enemy.DescendantRemoving:Connect(function(instance)
		if record.parts[instance] then
			record.parts[instance] = nil
			unregisterEnemyPart(instance, record)
		end
	end))
	for _, instance in ipairs(enemy:GetDescendants()) do registerEnemyPart(instance, record) end
end

local function untrackEnemy(enemy, source)
	local record = enemies[enemy]
	if not record then return end
	record.sources[source or "folder"] = nil
	if next(record.sources) then return end
	for _, connection in ipairs(record.connections) do connection:Disconnect() end
	for enemyPart in pairs(record.parts) do unregisterEnemyPart(enemyPart, record) end
	enemies[enemy] = nil
end


local function refreshObstacleFilter()
	local excluded = {enemiesFolder}
	if character then table.insert(excluded, character) end
	obstacleParams.FilterDescendantsInstances = excluded
end

local function registerPlayerPart(playerPart)
	if not playerPart:IsA("BasePart") or playerParts[playerPart] then
		return
	end

	playerParts[playerPart] = true

	for enemyPart, entry in pairs(enemyParts) do
		if enemyPart.CanCollide then
			linkParts(playerPart, enemyPart, entry)
		end
	end
end

local function unregisterPlayerPart(playerPart)
	if not playerParts[playerPart] then
		return
	end

	for _, entry in pairs(enemyParts) do
		local constraint = entry.links[playerPart]

		if constraint then
			constraint:Destroy()
			entry.links[playerPart] = nil
		end
	end

	playerParts[playerPart] = nil
end

local function cleanupPlayerParts()
	for _, connection in ipairs(playerConnections) do
		connection:Disconnect()
	end

	table.clear(playerConnections)

	for _, entry in pairs(enemyParts) do
		removeEnemyLinks(entry)
	end

	table.clear(playerParts)
end

enemiesFolder.ChildAdded:Connect(function(enemy)
	trackEnemy(enemy)
	elapsed = updateInterval
end)
enemiesFolder.ChildRemoved:Connect(untrackEnemy)

for _, child in ipairs(enemiesFolder:GetChildren()) do
	trackEnemy(child, "folder")
end
CollectionService:GetInstanceAddedSignal("Enemy"):Connect(function(enemy) trackEnemy(enemy, "tag") end)
CollectionService:GetInstanceRemovedSignal("Enemy"):Connect(function(enemy) untrackEnemy(enemy, "tag") end)
for _, enemy in ipairs(CollectionService:GetTagged("Enemy")) do trackEnemy(enemy, "tag") end

local function cleanup()
	if humanoid then pcall(function() humanoid:Move(Vector3.zero, false) end) end
	if bot.releaseBow then bot.releaseBow("cleanup") end
	if bot.releaseAbility then bot.releaseAbility() end
	if bot.releaseDashKey then bot.releaseDashKey() end
	revive.locked, revive.selected, revive.arrived = nil, nil, false
	if endRevive then
		endRevive(false)
	end
	bot.dash.busyUntil, bot.dash.chainUntil = 0, 0
	bot.dash.prepareUntil, bot.dash.prepareRetryAt = nil, nil
	bot.bossIntent = nil
	bot.retreatRound, bot.retreat, bot.lowReviveRetreat = nil, false, false
	bot.preleapAim, bot.ringSafeRegion, bot.ringConstrained = nil, nil, false
	bot.breaths, bot.breathRetreat, bot.lionZones, bot.lionRetreat = {}, false, {}, false
	bot.attackZones, bot.attackRetreat, bot.unknownAttackCount, bot.phobetorComboCount = {}, false, 0, 0
	bot.volleyHoldUntil, bot.nextUrgentPlan, bot.escapeCache = nil, nil, nil
	bot.attackStates = setmetatable({}, {__mode = "k"})
	revive.seeking = false
	invalidateRoute()
	currentObjective = nil
	restoreCamera()
	cleanupPlayerParts()

	if humanoid and humanoid.Parent and originalAutoRotate ~= nil then
		humanoid.AutoRotate = originalAutoRotate
	end

	if orientation then
		orientation:Destroy()
	end

	if attachment then
		attachment:Destroy()
	end

	character = nil
	humanoid = nil
	root = nil
	attachment = nil
	orientation = nil
	originalAutoRotate = nil

	escapeTarget = nil
	lastDirection = nil
	bot.stablePlanValid, bot.stablePlanEnemy, bot.stablePlanObjectiveKind, bot.stablePlanObjectiveKey = false, nil, nil, nil
	bot.walkSmoothDirection, bot.walkSmoothAt, bot.walkLastOutput, bot.movementEmergency = nil, nil, nil, false
	attackModel = nil
	attackRoot = nil
	wasMoving = false
	threats = {}
end

bot.onMatchEnd = function()
	cleanup()
end

local function setup(newCharacter, newHumanoid, newRoot)
	cleanup()

	character = newCharacter
	humanoid = newHumanoid
	root = newRoot
	originalAutoRotate = humanoid.AutoRotate

	refreshObstacleFilter()

	attachment = Instance.new("Attachment")
	attachment.Name = "EscapeFacingAttachment"
	attachment.Parent = root

	orientation = Instance.new("AlignOrientation")
	orientation.Name = "EscapeFacing"
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.MaxTorque = math.huge
	orientation.Responsiveness = 40
	orientation.Enabled = false
	orientation.Parent = root

	table.insert(playerConnections, character.DescendantAdded:Connect(registerPlayerPart))
	table.insert(playerConnections, character.DescendantRemoving:Connect(unregisterPlayerPart))

	for _, instance in ipairs(character:GetDescendants()) do
		registerPlayerPart(instance)
	end

	elapsed = updateInterval
end

local function getArena()
	local cf = floor.CFrame
	local size = floor.Size

	local xVertical = math.abs(cf.RightVector.Y)
	local yVertical = math.abs(cf.UpVector.Y)
	local zVertical = math.abs(cf.LookVector.Y)

	local diameter

	if xVertical >= yVertical and xVertical >= zVertical then
		diameter = math.min(size.Y, size.Z)
	elseif yVertical >= zVertical then
		diameter = math.min(size.X, size.Z)
	else
		diameter = math.min(size.X, size.Y)
	end

	return flat(floor.Position), math.max(1, diameter / 2 - edgeMargin)
end

local function clampToArena(position, center, radius)
	local offset = position - center

	if offset.Magnitude > radius then
		return center + offset.Unit * radius
	end

	return position
end

local function hasFloor(position)
	local origin = Vector3.new(
		position.X,
		root.Position.Y + 8,
		position.Z
	)

	return workspace:Raycast(
		origin,
		Vector3.new(0, -40, 0),
		floorParams
	) ~= nil
end

local function wallClearance(position)
	local origin = Vector3.new(position.X, root.Position.Y, position.Z)
	local minimum = wallMargin

	for _, direction in ipairs(wallProbeDirections) do
		local hit = workspace:Raycast(
			origin,
			direction * wallMargin,
			obstacleParams
		)

		if hit then
			minimum = math.min(minimum, hit.Distance)
		end
	end

	return minimum
end

local function isAlive(enemy)
	if enemy:GetAttribute("AIState") == "Dead" then
		return false
	end

	local healthAttribute = enemy:GetAttribute("Health")

	if type(healthAttribute) == "number" and healthAttribute <= 0 then
		return false
	end

	local enemyHumanoid = enemy:FindFirstChildWhichIsA("Humanoid", true)

	if enemyHumanoid and enemyHumanoid.Health <= 0 then
		return false
	end

	return true
end

local function getAimPosition(enemy, enemyRoot)
	local torso = enemy:FindFirstChild("Torso")
		or enemy:FindFirstChild("UpperTorso")

	if torso and torso:IsA("BasePart") then
		return torso.Position
	end

	return enemyRoot.Position + Vector3.new(0, 0.5, 0)
end

local function getCameraPosition(aimPosition)
	local horizontal = flat(aimPosition - root.Position)

	if horizontal.Magnitude < 0.01 then
		horizontal = flat(root.CFrame.LookVector)
	end

	if horizontal.Magnitude < 0.01 then
		horizontal = Vector3.new(0, 0, -1)
	end

	return root.Position
		- horizontal.Unit * 16
		+ Vector3.new(0, 8, 0)
end

local function hasLineOfSight(enemy, enemyRoot)
	if not character or not root
		or enemy.Parent ~= enemiesFolder
		or not enemyRoot:IsDescendantOf(enemy)
		or not isAlive(enemy) then

		return false
	end

	local aimPosition = getAimPosition(enemy, enemyRoot)
	local horizontal = flat(aimPosition - root.Position)

	if horizontal.Magnitude < 0.01 then
		horizontal = flat(root.CFrame.LookVector)
	end

	if horizontal.Magnitude < 0.01 then
		horizontal = Vector3.new(0, 0, -1)
	end

	local shotOrigin = root.Position
		+ Vector3.new(0, 1.3, 0)
		+ horizontal.Unit

	local cameraPosition = getCameraPosition(aimPosition)
	local cameraOffset = aimPosition - cameraPosition

	if cameraOffset.Magnitude < 0.01 then
		return false
	end

	local cameraDirection = cameraOffset.Unit
	local projection = math.max(
		0,
		(root.Position - cameraPosition):Dot(cameraDirection)
	)

	local cameraRayOrigin = cameraPosition + cameraDirection * projection

	sightParams.FilterDescendantsInstances = {character, enemy}

	local shotBlock = workspace:Raycast(
		shotOrigin,
		aimPosition - shotOrigin,
		sightParams
	)

	if shotBlock then
		return false
	end

	local cameraBlock = workspace:Raycast(
		cameraRayOrigin,
		aimPosition - cameraRayOrigin,
		sightParams
	)

	return cameraBlock == nil
end

local function collectThreats()
	local result = {}

	for enemy in pairs(enemies) do
		if enemy.Parent ~= enemiesFolder or not isAlive(enemy) then
			continue
		end

		local enemyRoot = enemy:FindFirstChild("HumanoidRootPart", true)

		if not enemyRoot or not enemyRoot:IsA("BasePart") then
			continue
		end

		local velocity = flat(enemyRoot.AssemblyLinearVelocity)

		if velocity.Magnitude > 160 then
			velocity = velocity.Unit * 160
		end

		table.insert(result, {
			model = enemy,
			root = enemyRoot,
			velocity = velocity,
		})
	end

	return result
end

local function threatImminent(playerVelocity)
	local position = flat(root.Position)

	for _, threat in ipairs(threats) do
		if not threat.root:IsDescendantOf(enemiesFolder) then
			continue
		end

		local offset = flat(threat.root.Position) - position

		if offset.Magnitude > 75 then
			continue
		end

		local windup = threat.model:GetAttribute("AIState") == "Windup"
		if windup and offset.Magnitude <= 18 then return true end
		local velocity = flat(threat.root.AssemblyLinearVelocity) - playerVelocity
		local speedSquared = velocity:Dot(velocity)
		if speedSquared >= 1 and offset:Dot(velocity) < 0 then
			local closestTime = math.clamp(-offset:Dot(velocity) / speedSquared, 0, 1.2)
			if (offset + velocity * closestTime).Magnitude <= 15 then return true end
		end
	end

	return false
end

local function validObjectivePosition(position)
	return position and math.abs(position.Y - floor.Position.Y) < 30
end

function bot.trace(message)
	if bot.debug then print("[AutoBot] " .. message) end
end

function bot.isThief(model)
	local value = model:GetAttribute("Thief")
	return value == true or (type(value) == "number" and value > 0) or bot.isCarrier(model)
end

function bot.isCarrier(model)
	if model:GetAttribute("Carrying") == true then return true end
	local identity = tostring(model:GetAttribute("EnemyUid") or model.Name)
	for purse in pairs(tagged.Purse) do
		local claim = purse:GetAttribute("Claim")
		if purse:GetAttribute("State") == "carried" and claim ~= nil and tostring(claim) == identity then
			return true
		end
	end
	return false
end

function bot.parseEyePath(raw)
	if type(raw) ~= "string" or raw == "" then return nil end
	local points = {}
	local function add(x, z)
		x, z = tonumber(x), tonumber(z)
		if x and z and x == x and z == z and math.abs(x) < 1e6 and math.abs(z) < 1e6 then
			table.insert(points, Vector3.new(x, 0, z))
		end
	end
	local http = game:GetService("HttpService")
	local ok, decoded = pcall(function() return http:JSONDecode(raw) end)
	if ok and type(decoded) == "table" then
		local entries = type(decoded.points) == "table" and decoded.points or decoded
		for _, item in ipairs(entries) do
			if type(item) == "table" then
				if item.x ~= nil or item.X ~= nil then
					add(item.x or item.X, item.z or item.Z)
				else
					add(item[1], item[3] or item[2])
				end
			end
		end
	end
	if #points < 2 then
		table.clear(points)
		for chunk in string.gmatch(raw, "[^;|]+") do
			local nums = {}
			for n in string.gmatch(chunk, "[-+]?%d*%.?%d+") do table.insert(nums, tonumber(n)) end
			if #nums >= 2 then add(nums[1], nums[3] or nums[2]) end
		end
	end
	if #points < 2 then return nil end
	if (points[1] - points[#points]).Magnitude > 0.5 then table.insert(points, points[1]) end
	local lengths, total = {}, 0
	for i = 1, #points - 1 do
		lengths[i] = (points[i + 1] - points[i]).Magnitude
		total += lengths[i]
	end
	return total > 1 and {points = points, lengths = lengths, total = total} or nil
end

function bot.pathPosition(path, distance)
	local remaining = distance % path.total
	for i, length in ipairs(path.lengths) do
		if remaining <= length or i == #path.lengths then
			local alpha = length > 0.0001 and math.clamp(remaining / length, 0, 1) or 0
			return path.points[i]:Lerp(path.points[i + 1], alpha)
		end
		remaining -= length
	end
	return path.points[#path.points]
end

function bot.eyePosition(fallback)
	local state = ReplicatedStorage:FindFirstChild("GameState")
	local actual = state and state:GetAttribute("ObjectivePos")
	if typeof(actual) ~= "Vector3" or actual.Magnitude < 0.1 or not validObjectivePosition(actual) then
		return fallback
	end
	local raw = state:GetAttribute("EyePath")
	if raw ~= bot.eye.raw then
		bot.eye.raw, bot.eye.path = raw, bot.parseEyePath(raw)
	end
	local start = tonumber(state:GetAttribute("EyeStart"))
	local speed = tonumber(state:GetAttribute("EyeSpeed"))
	local now = workspace:GetServerTimeNow()
	if start and speed and speed > 0 and bot.eye.path then
		if start < 1e8 and now > 1e8 then start = now + start - workspace.DistributedGameTime end
		local traveled = math.max(0, now - start) * speed
		local predicted = bot.pathPosition(bot.eye.path, traveled)
		-- Match the game's own fallback when the path disagrees with ObjectivePos.
		if (predicted - flat(actual)).Magnitude <= 6 then
			local ahead = bot.pathPosition(bot.eye.path, traveled + speed * 0.5)
			return Vector3.new(ahead.X, actual.Y, ahead.Z)
		end
	end
	return actual
end

function bot.nearestThief()
	local best, bestDistance, bestVisible, bestCarrier
	for _, threat in ipairs(threats) do
		local model, part = threat.model, threat.root
		if model.Parent == enemiesFolder and part:IsDescendantOf(model) and isAlive(model) and bot.isThief(model) then
			local distance = flat(part.Position - root.Position).Magnitude
			local carrier = bot.isCarrier(model)
			if not bestDistance or (carrier and not bestCarrier) or (carrier == bestCarrier and distance < bestDistance) then
				best, bestDistance = threat, distance
				bestCarrier = carrier
				bestVisible = hasLineOfSight(model, part)
			end
		end
	end
	return best, bestDistance, bestVisible
end

function bot.updateRetreat()
	if not humanoid or humanoid.MaxHealth <= 0 then return false end
	local previous = bot.retreat == true
	local fraction = humanoid.Health / humanoid.MaxHealth
	if fraction <= 0.30 then bot.retreat = true
	elseif fraction >= 0.50 then bot.retreat = false end
	return previous ~= (bot.retreat == true)
end

local function getObjective()
	if bot.retreat then return nil end
	if not challenge.live then
		return nil
	end
	if challenge.endsAt and workspace:GetServerTimeNow() > challenge.endsAt + 1 then
		clearChallenge()
		return nil
	end
	if challenge.id == "Treasure" then
		local bestInstance
		local bestPosition
		local bestDistance = math.huge
		for instance in pairs(tagged.Purse) do
			local state = instance:GetAttribute("State")
			local position = objectPosition(instance)
			if validObjectivePosition(position) and (state == "sand" or state == nil) then
				local distance = flat(position - root.Position).Magnitude
				if instance == selectedPurse then
					distance -= 4
				end
				if distance < bestDistance then
					bestDistance = distance
					bestInstance = instance
					bestPosition = position
				end
			end
		end
		selectedPurse = bestInstance
		local thief, thiefDistance, thiefVisible = bot.nearestThief()
		-- Shoot a visible thief while collecting; pursue a closer blocked thief.
		if thief and not thiefVisible and (not bestPosition or thiefDistance < bestDistance) then
			return {kind = "Thief", key = thief.model, position = flat(thief.root.Position), radius = 3}
		end
		if bestPosition then
			return {kind = "Treasure", key = bestInstance, position = flat(bestPosition), radius = 2}
		end
		if thief and not thiefVisible then
			return {kind = "Thief", key = thief.model, position = flat(thief.root.Position), radius = 3}
		end
	elseif challenge.id == "Chariot" then
		local position = challenge.position
		local radius = challenge.radius or 13
		local bestDistance = math.huge
		for instance in pairs(tagged.ChallengeChariot) do
			local candidate = objectPosition(instance)
			local progress = instance:GetAttribute("Progress")
			if validObjectivePosition(candidate) and (type(progress) ~= "number" or progress < 1) then
				local distance = flat(candidate - root.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					position = candidate
					radius = tonumber(instance:GetAttribute("PushRadius")) or radius
				end
			end
		end
		if validObjectivePosition(position) then
			return {kind = "Chariot", key = "Chariot", position = flat(position), radius = math.max(2, radius - 3)}
		end
	elseif challenge.id == "Eye" then
		local position = bot.eyePosition(challenge.position)
		if validObjectivePosition(position) then
			return {kind = "Eye", key = "Eye", position = flat(position), radius = math.max(2, (challenge.radius or 13) - 3)}
		end
	end
	return nil
end

local function directTravel(position, target)
	local offset = flat(target - position)
	if offset.Magnitude < 0.1 then
		return true
	end
	return workspace:Blockcast(
		CFrame.new(position), Vector3.new(2.5, 2, 2.5), offset, obstacleParams
	) == nil
end

local function navigationTarget(objective)
	local position = flat(root.Position)
	local destination = objective.position
	if objective.kind ~= "Treasure" then
		local offset = position - destination
		if offset.Magnitude <= objective.radius then
			return nil
		end
		if offset.Magnitude > 0.1 then
			destination += offset.Unit * objective.radius * 0.65
		end
	end
	local worldDestination = Vector3.new(destination.X, root.Position.Y, destination.Z)
	if directTravel(root.Position, worldDestination) then
		return destination
	end
	if route.key ~= objective.key or not route.goal or flat(route.goal - destination).Magnitude > 7 then
		invalidateRoute()
		route.key = objective.key
		route.goal = destination
	end
	local now = os.clock()
	if not route.pending and now - route.requestedAt >= 0.8 then
		route.pending = true
		route.requestedAt = now
		local version = route.version
		local routeRoot = root
		local start = root.Position
		local destinationSnapshot = worldDestination
		task.spawn(function()
			local path
			local ok, nodes = pcall(function()
				path = PathfindingService:CreatePath({
					AgentRadius = 2.5, AgentHeight = 5,
					AgentCanJump = false, AgentCanClimb = false,
					WaypointSpacing = 5,
				})
				path:ComputeAsync(start, destinationSnapshot)
				if path.Status == Enum.PathStatus.Success then
					return path:GetWaypoints()
				end
				return nil
			end)
			if path then
				path:Destroy()
			end
			route.pending = false
			if root == routeRoot and route.version == version and ok and nodes and #nodes > 1 then
				route.nodes = nodes
				route.index = 2
				elapsed = updateInterval
			end
		end)
	end
	if route.nodes then
		while route.index <= #route.nodes and flat(route.nodes[route.index].Position - position).Magnitude < 3 do
			route.index += 1
		end
		if route.index <= #route.nodes then
			for index = math.min(#route.nodes, route.index + 4), route.index, -1 do
				local point = route.nodes[index].Position
				local target = Vector3.new(point.X, root.Position.Y, point.Z)
				if directTravel(root.Position, target) then
					route.index = index
					return flat(point)
				end
			end
		end
	end
	return destination
end

local function segmentDistance(point, start, finish)
	local delta = finish - start
	local lengthSquared = delta:Dot(delta)
	if lengthSquared < 0.001 then
		return (point - start).Magnitude
	end
	local fraction = math.clamp((point - start):Dot(delta) / lengthSquared, 0, 1)
	return (point - start - delta * fraction).Magnitude
end

-- Base creature ranges are not
-- claims about the server hitbox of a scaled boss. Keep a radial safety margin.
bot.breathRanges = {fire_breath = 22, cacus_breath = 24, hydra_spit = 48, arc_beam = 26}
bot.breathSeen = setmetatable({}, {__mode = "k"})

function bot.collectBreaths()
	local result = {}
	for _, threat in ipairs(threats) do
		local model, enemyRoot = threat.model, threat.root
		local state, attack = model:GetAttribute("AIState"), model:GetAttribute("AttackKind")
		if state ~= "Windup" and state ~= "Attack" then
			bot.breathSeen[model] = nil
			continue
		end
		if bot.breathRanges[attack] then
			bot.breathSeen[model] = attack
		elseif state == "Attack" and (attack == nil or attack == "") then
			attack = bot.breathSeen[model]
		else
			bot.breathSeen[model] = nil
			continue
		end
		local range = bot.breathRanges[attack]
		if not range or not enemyRoot or not enemyRoot:IsDescendantOf(model) then continue end
		local mouth = model:FindFirstChild("Mouth2", true) or model:FindFirstChild("Mouth", true)
		local reachOffset
		if mouth and mouth:IsA("Attachment") then
			reachOffset = flat(mouth.WorldPosition - enemyRoot.Position).Magnitude
		else
			-- Fallback only when mouth data is unavailable; not a measured hitbox.
			reachOffset = math.max(enemyRoot.Size.X, enemyRoot.Size.Z) * 0.5
		end
		table.insert(result, {model = model, position = flat(enemyRoot.Position),
			radius = range + reachOffset + 4, kind = attack, state = state})
	end
	return result
end

function bot.inBreathDanger(position, breaths)
	for _, breath in ipairs(breaths) do
		if (position - breath.position).Magnitude < breath.radius then return true end
	end
	return false
end

function bot.breathPenalty(start, finish, breaths)
	local penalty = 0
	for _, breath in ipairs(breaths) do
		local from = (start - breath.position).Magnitude
		local to = (finish - breath.position).Magnitude
		if from < breath.radius then
			-- Demand outward movement rather than letting central bias dominate.
			if to <= from + 0.01 then penalty += 100000 end
			penalty += math.max(0, breath.radius - to) * 1000
		elseif segmentDistance(breath.position, start, finish) < breath.radius then
			penalty += 100000
		end
	end
	return penalty
end


-- War Lion's short pounce and maul are different from its long charge.
-- These base ranges use a conservative radial margin.
bot.lionAttackRanges = {pounce = 14, maul = 6.5}
bot.lionAttackSeen = setmetatable({}, {__mode = "k"})
function bot.collectLionZones()
	local result = {}
	for _, threat in ipairs(threats) do
		local model, part = threat.model, threat.root
		local state, attack = model:GetAttribute("AIState"), model:GetAttribute("AttackKind")
		if model:GetAttribute("CreatureId") ~= "war_lion" or (state ~= "Windup" and state ~= "Attack") then
			bot.lionAttackSeen[model] = nil
			continue
		end
		if bot.lionAttackRanges[attack] then
			bot.lionAttackSeen[model] = attack
		elseif state == "Attack" and (attack == nil or attack == "") then
			attack = bot.lionAttackSeen[model]
		else
			bot.lionAttackSeen[model] = nil
			continue
		end
		local range = bot.lionAttackRanges[attack]
		if not range or not part or not part:IsDescendantOf(model) then continue end
		local halfWidth = math.max(part.Size.X, part.Size.Z) * 0.5
		table.insert(result, {model = model, position = flat(part.Position),
			radius = range + halfWidth + 4, kind = attack, state = state})
	end
	return result
end


-- Attack shapes are keyed by creature and attack ID.
-- The geometry below is conservative, not a claim about the server hitbox.
bot.attackCatalog = {
 ["undead_legionary"] = {
  ["slash"] = {kind = "melee", range = 5.5, arc = 90.0, windup = 0.55, cooldown = 1.5},
  ["shield_bash"] = {kind = "melee", range = 4.5, arc = 70.0, windup = 0.45, cooldown = 4.5},
 },
 ["undead_raider"] = {
  ["twin_slash"] = {kind = "melee", range = 5.0, arc = 80.0, windup = 0.3, cooldown = 0.85},
  ["dash_stab"] = {kind = "lunge", range = 11.0, minRange = 5.0, distance = 10.0, speed = 42.0, width = 3.0, windup = 0.5, cooldown = 4.0},
 },
 ["undead_brute"] = {
  ["cleave"] = {kind = "melee", range = 7.0, arc = 120.0, windup = 0.85, cooldown = 2.4},
  ["ground_slam"] = {kind = "slam", range = 8.0, radius = 9.0, windup = 1.2, cooldown = 6.0},
 },
 ["war_dog"] = {
  ["bite"] = {kind = "melee", range = 4.5, arc = 70.0, windup = 0.28, cooldown = 1.1},
  ["lunge_bite"] = {kind = "lunge", range = 12.0, minRange = 5.0, distance = 12.0, speed = 46.0, width = 3.0, windup = 0.45, cooldown = 3.5},
 },
 ["war_lion"] = {
  ["maul"] = {kind = "melee", range = 6.5, arc = 100.0, windup = 0.6, cooldown = 1.8},
  ["pounce"] = {kind = "lunge", range = 14.0, minRange = 6.0, distance = 14.0, speed = 50.0, width = 4.0, windup = 0.7, cooldown = 5.0},
  ["charge"] = {kind = "charge", range = 34.0, minRange = 12.0, distance = 34.0, speed = 48.0, width = 5.0, windup = 0.9, cooldown = 7.0},
 },
 ["cerberus"] = {
  ["triple_bite"] = {kind = "melee", range = 9.0, arc = 120.0, windup = 0.7, cooldown = 1.6},
  ["fire_breath"] = {kind = "breath", range = 22.0, minRange = 4.0, arc = 45.0, windup = 1.1, duration = 1.5, cooldown = 7.0},
  ["stomp"] = {kind = "slam", range = 10.0, radius = 12.0, windup = 1.0, cooldown = 8.0},
 },
 ["undead_archer"] = {
  ["bone_arrow"] = {kind = "projectile", range = 34.0, minRange = 8.0, speed = 62.0, windup = 0.85, cooldown = 2.4},
  ["stab"] = {kind = "melee", range = 4.5, arc = 70.0, windup = 0.35, cooldown = 1.2},
 },
 ["armored_boar"] = {
  ["gore"] = {kind = "melee", range = 5.0, arc = 80.0, windup = 0.5, cooldown = 1.8},
  ["tusk_charge"] = {kind = "charge", range = 26.0, minRange = 10.0, distance = 32.0, speed = 44.0, width = 4.0, windup = 0.95, cooldown = 6.0},
 },
 ["minotaur"] = {
  ["labrys_cleave"] = {kind = "melee", range = 10.0, arc = 150.0, windup = 0.8, cooldown = 2.2},
  ["labrys_quake"] = {kind = "slam", range = 9.0, radius = 11.0, windup = 1.15, cooldown = 7.0},
  ["bull_rush"] = {kind = "charge", range = 40.0, minRange = 12.0, distance = 42.0, speed = 52.0, width = 6.0, windup = 1.0, cooldown = 7.0},
  ["horn_toss"] = {kind = "lunge", range = 10.0, minRange = 4.0, distance = 8.0, speed = 40.0, width = 4.0, windup = 0.55, cooldown = 5.0},
 },
 ["talos"] = {
  ["bronze_fist"] = {kind = "melee", range = 9.0, arc = 110.0, windup = 0.9, cooldown = 2.4},
  ["boulder_hurl"] = {kind = "slam", range = 24.0, minRange = 11.0, offset = 18.0, radius = 7.0, windup = 1.45, cooldown = 6.0},
  ["colossus_stomp"] = {kind = "slam", range = 10.0, radius = 13.0, windup = 1.2, cooldown = 8.0},
 },
 ["cyborg_lion"] = {
  ["claw"] = {kind = "melee", range = 6.5, arc = 100.0, windup = 0.55, cooldown = 1.6},
  ["overdrive_charge"] = {kind = "charge", range = 40.0, minRange = 12.0, distance = 40.0, speed = 60.0, width = 5.0, windup = 0.8, cooldown = 6.0},
  ["arc_beam"] = {kind = "breath", range = 26.0, minRange = 5.0, arc = 20.0, windup = 1.0, duration = 1.2, cooldown = 8.0},
 },
 ["bronze_automaton"] = {
  ["piston_fist"] = {kind = "melee", range = 6.5, arc = 90.0, windup = 0.8, cooldown = 2.2},
  ["overheat_slam"] = {kind = "slam", range = 7.0, radius = 10.0, windup = 1.3, cooldown = 7.0},
 },
 ["rival_murmillo"] = {
  ["gladius_jab"] = {kind = "melee", range = 6.5, arc = 80.0, windup = 0.5, cooldown = 1.4},
  ["shield_bash"] = {kind = "melee", range = 5.5, arc = 70.0, windup = 0.55, cooldown = 5.0},
  ["scutum_rush"] = {kind = "charge", range = 24.0, minRange = 9.0, distance = 22.0, speed = 40.0, width = 5.0, windup = 1.0, cooldown = 7.0},
 },
 ["rival_retiarius"] = {
  ["trident_lunge"] = {kind = "lunge", range = 14.0, minRange = 5.0, distance = 12.0, speed = 46.0, width = 3.0, windup = 0.6, cooldown = 3.5},
  ["tide_sweep"] = {kind = "melee", range = 9.5, arc = 170.0, windup = 0.75, cooldown = 5.0},
  ["net_cast"] = {kind = "projectile", range = 26.0, minRange = 8.0, speed = 38.0, windup = 0.9, cooldown = 7.0},
 },
 ["rival_bestiarius"] = {
  ["club_cleave"] = {kind = "melee", range = 8.0, arc = 130.0, windup = 0.8, cooldown = 2.2},
  ["lions_leap"] = {kind = "lunge", range = 16.0, minRange = 7.0, distance = 14.0, speed = 48.0, width = 4.0, windup = 0.85, cooldown = 6.0},
  ["earthbreaker"] = {kind = "slam", range = 8.0, radius = 11.0, windup = 1.3, cooldown = 9.0},
 },
 ["rival_scissor"] = {
  ["crescent_cut"] = {kind = "melee", range = 8.0, arc = 150.0, windup = 0.7, cooldown = 2.0},
  ["carver_lunge"] = {kind = "lunge", range = 15.0, minRange = 5.0, distance = 14.0, speed = 52.0, width = 3.0, windup = 0.65, cooldown = 4.5},
  ["half_moon"] = {kind = "slam", range = 9.0, offset = 4.5, radius = 5.0, windup = 1.1, cooldown = 8.0},
 },
 ["trial_cacus"] = {
  ["cacus_club"] = {kind = "slam", range = 11.0, radius = 14.0, windup = 1.25, cooldown = 4.0},
  ["cacus_breath"] = {kind = "breath", range = 24.0, minRange = 4.0, arc = 60.0, windup = 1.2, duration = 2.0, cooldown = 12.0},
  ["cacus_rush"] = {kind = "charge", range = 150.0, minRange = 999.0, distance = 150.0, speed = 48.0, width = 9.0, windup = 1.5, cooldown = 14.0},
 },
 ["trial_glaucus"] = {
  ["glaucus_sweep"] = {kind = "melee", range = 17.0, arc = 180.0, windup = 1.2, cooldown = 4.5},
  ["glaucus_lunge"] = {kind = "lunge", range = 28.0, minRange = 8.0, distance = 24.0, speed = 50.0, width = 6.0, windup = 1.2, cooldown = 5.5},
 },
 ["trial_lycaon"] = {
  ["lycaon_claw"] = {kind = "melee", range = 11.0, arc = 120.0, windup = 0.6, cooldown = 1.8},
  ["lycaon_lunge"] = {kind = "lunge", range = 30.0, minRange = 10.0, distance = 26.0, speed = 56.0, width = 7.0, windup = 0.75, cooldown = 6.0},
 },
 ["trial_janus"] = {
  ["janus_cleave_front"] = {kind = "melee", range = 30.0, minRange = 999.0, arc = 140.0, windup = 1.4, cooldown = 4.0},
  ["janus_slam"] = {kind = "slam", range = 14.0, minRange = 999.0, radius = 12.0, windup = 1.3, cooldown = 6.0},
 },
 ["trial_imp"] = {
  ["imp_claw"] = {kind = "melee", range = 5.0, arc = 80.0, windup = 0.35, cooldown = 1.0},
  ["imp_dash"] = {kind = "lunge", range = 11.0, minRange = 5.0, distance = 10.0, speed = 42.0, width = 3.0, windup = 0.5, cooldown = 4.0},
 },
 ["trial_sailor"] = {
  ["sailor_slash"] = {kind = "melee", range = 5.5, arc = 90.0, windup = 0.55, cooldown = 1.5},
  ["sailor_bash"] = {kind = "melee", range = 4.5, arc = 70.0, windup = 0.45, cooldown = 4.5},
 },
 ["trial_direwolf"] = {
  ["wolf_bite"] = {kind = "melee", range = 5.0, arc = 70.0, windup = 0.35, cooldown = 1.2},
  ["wolf_pounce"] = {kind = "lunge", range = 13.0, minRange = 5.0, distance = 12.0, speed = 46.0, width = 3.0, windup = 0.5, cooldown = 4.0},
 },
 ["trial_gatekeeper"] = {
  ["keeper_jab"] = {kind = "melee", range = 6.5, arc = 80.0, windup = 0.55, cooldown = 1.6},
  ["keeper_bash"] = {kind = "melee", range = 5.5, arc = 70.0, windup = 0.55, cooldown = 5.0},
 },
 ["raid_hydra"] = {
  ["hydra_bite"] = {kind = "melee", range = 16.0, arc = 150.0, windup = 0.8, cooldown = 1.8},
  ["hydra_spit"] = {kind = "breath", range = 48.0, windup = 1.25, duration = 0.5, cooldown = 11.0},
  ["hydra_tail"] = {kind = "slam", range = 20.0, radius = 1.0, windup = 1.0, cooldown = 9.0},
 },
 ["phobetor"] = {
  ["reaping_sweep"] = {kind = "melee", range = 10.0, arc = 200.0, windup = 0.9, cooldown = 3.0},
  ["sickle_hurl"] = {kind = "slam", range = 30.0, minRange = 10.0, offset = 16.0, radius = 6.0, windup = 1.1, cooldown = 7.0},
 },
}
-- Only these observed/catalogued basic attacks are shield candidates.
-- Other known attack IDs use the existing special-attack avoidance geometry.
bot.basicGuardAttacks = {
 undead_legionary = "slash", undead_raider = "twin_slash", undead_brute = "cleave",
 war_dog = "bite", war_lion = "maul", cerberus = "triple_bite", undead_archer = "bone_arrow",
 armored_boar = "gore", minotaur = "labrys_cleave", talos = "bronze_fist",
 cyborg_lion = "claw", bronze_automaton = "piston_fist", rival_murmillo = "gladius_jab",
 rival_bestiarius = "club_cleave", rival_scissor = "crescent_cut", trial_glaucus = "glaucus_sweep",
 trial_lycaon = "lycaon_claw", trial_janus = "janus_cleave_front", trial_imp = "imp_claw",
 trial_sailor = "sailor_slash", trial_direwolf = "wolf_bite", trial_gatekeeper = "keeper_jab",
 raid_hydra = "hydra_bite",
}
function bot.basicGuardAttack(creature, attack)
	return bot.basicGuardAttacks[creature] == attack
end
function bot.specialAttackZone(zone)
	return zone.special == true or (zone.special == nil and zone.kind ~= "melee")
end
bot.attackSeen = setmetatable({}, {__mode = "k"})

function bot.collectAttackZones()
	local result, unknown = {}, 0
	for _, threat in ipairs(threats) do
		local model, part = threat.model, threat.root
		local creature = model:GetAttribute("CreatureId")
		local state, attack = model:GetAttribute("AIState"), model:GetAttribute("AttackKind")
		if state ~= "Windup" and state ~= "Attack" and state ~= "Charge" then
			bot.attackSeen[model] = nil
			continue
		end
		local creatureDef = type(creature) == "string" and bot.attackCatalog[creature] or nil
		local definition = creatureDef and type(attack) == "string" and creatureDef[attack] or nil
		if definition then
			bot.attackSeen[model] = attack
		elseif (state == "Attack" or state == "Charge") and (attack == nil or attack == "") then
			attack = bot.attackSeen[model]
			definition = creatureDef and attack and creatureDef[attack] or nil
		else
			bot.attackSeen[model] = nil
		end
		if not definition then
			if attack and attack ~= "" then unknown += 1 end
			continue
		end
		if not part or not part:IsDescendantOf(model) then continue end
		local kind = definition.kind
		-- Existing specialized handlers handle breath and the lion's short attacks.
		if kind == "breath" or (creature == "war_lion" and (attack == "maul" or attack == "pounce")) then continue end
		local base, reach = flat(part.Position), math.max(part.Size.X, part.Size.Z) * 0.5
		local zone = {model = model, position = base, kind = kind, attack = attack, creature = creature, state = state,
			special = not bot.basicGuardAttack(creature, attack)}
		if kind == "melee" and zone.special and type(definition.arc) == "number" and definition.arc > 0
			and definition.arc < 310 and flat(part.CFrame.LookVector).Magnitude > 0.01 then
			zone.shape, zone.forward = "cone", flat(part.CFrame.LookVector).Unit
			zone.radius = math.max(definition.range or 0, definition.distance or 0, definition.radius or 0) + reach + 3
			zone.halfAngle = math.rad(math.min(179, definition.arc * 0.5 + 25))
		elseif kind == "lunge" and type(definition.width) == "number" and definition.width > 0
			and type(definition.distance) == "number" and definition.distance > 0
			and flat(part.CFrame.LookVector).Magnitude > 0.01 then
			local forward = flat(part.CFrame.LookVector).Unit
			local length = definition.distance + reach
			zone.shape, zone.start, zone.finish = "lane", base, base + forward * length
			-- Reserve lateral room for rotation and replication delay.
			zone.radius = definition.width * 0.5 + reach + 3 + length * 0.26
		elseif kind == "melee" or kind == "lunge" or kind == "slam" then
			-- The client renders slam circles around the attacker. This can differ from server-targeted attacks.
			-- Enclose the client telegraph offset without assuming its server hitbox or lock.
			local offset = type(definition.offset) == "number" and math.abs(definition.offset) or 0
			local extent = math.max(definition.range or 0, definition.distance or 0, (definition.radius or 0) + offset)
			if extent <= 0 then unknown += 1; continue end
			zone.shape, zone.radius = "circle", extent + reach + 3
		elseif kind == "charge" or kind == "projectile" then
			local forward = flat(part.CFrame.LookVector)
			local length = definition.distance or definition.range
			if forward.Magnitude < 0.001 or not length or length <= 0 then unknown += 1; continue end
			zone.shape, zone.start = "lane", base
			zone.finish = base + forward.Unit * (length + reach)
			-- A missing projectile width has no verified server value; use a marked estimate.
			zone.radius = (definition.width or 4) * 0.5 + reach + 2
			zone.estimatedWidth = definition.width == nil
		else
			unknown += 1
			continue
		end
		-- Movement candidates are at most 45 studs long. Farther zones cannot
		-- intersect this decision and need not be scored against every candidate.
		if bot.attackZoneDepth(zone, flat(root.Position)) >= -45 then table.insert(result, zone) end
	end

	-- The client animator publishes MechKind and impact times for these poses.
	-- Combo radius 7 and spin 12 come from ConfigPhobetorS1; use a broad
	-- short-range circle until the server hitboxes and tracking are observed.
	local comboCount, now = 0, workspace:GetServerTimeNow()
	for _, threat in ipairs(threats) do
		local model, part = threat.model, threat.root
		if model:GetAttribute("CreatureId") ~= "phobetor" or not part or not part:IsDescendantOf(model) then continue end
		local kind = model:GetAttribute("MechKind")
		if kind ~= "reaping_sweep" and kind ~= "phobetor_reap2" and kind ~= "phobetor_reap3" then continue end
		local startAt, impactAt = tonumber(model:GetAttribute("MechStart")), tonumber(model:GetAttribute("MechImpact"))
		if not startAt or not impactAt or startAt > impactAt or now < startAt or now > impactAt + 0.35 or impactAt > now + 3 then continue end
		local duplicate = false
		for _, zone in ipairs(result) do
			if zone.model == model and zone.attack == kind then duplicate = true; break end
		end
		if not duplicate then
			local reach = math.max(part.Size.X, part.Size.Z) * 0.5
			local zone = {model = model, position = flat(part.Position), kind = "melee", attack = kind,
				creature = "phobetor", state = "mechanic", special = true, shape = "circle",
				radius = 12 + reach + 3, impactAt = impactAt, estimated = true}
			if bot.attackZoneDepth(zone, flat(root.Position)) >= -45 then
				table.insert(result, zone)
				comboCount += 1
			end
		end
	end
	bot.phobetorComboCount = comboCount
	bot.unknownAttackCount = unknown
	return result
end

function bot.attackZoneDepth(zone, position)
	local offset = position - zone.position
	local distance = zone.shape == "lane" and segmentDistance(position, zone.start, zone.finish) or offset.Magnitude
	if zone.shape == "cone" and offset.Magnitude > 0.001 then
		local angle = math.acos(math.clamp(zone.forward:Dot(offset.Unit), -1, 1))
		if angle > zone.halfAngle then
			return -math.max(0.001, offset.Magnitude * math.sin(math.min(math.pi * 0.5, angle - zone.halfAngle)))
		end
	end
	return zone.radius - distance
end

function bot.inAttackZone(position, zones)
	for _, zone in ipairs(zones) do
		if bot.attackZoneDepth(zone, position) > 0 then return true end
	end
	return false
end

function bot.segmentSeparation(a, b, c, d)
	local first, second = b - a, d - c
	local cross = first.X * second.Z - first.Z * second.X
	if math.abs(cross) > 0.00001 then
		local offset = c - a
		local t = (offset.X * second.Z - offset.Z * second.X) / cross
		local u = (offset.X * first.Z - offset.Z * first.X) / cross
		if t >= 0 and t <= 1 and u >= 0 and u <= 1 then return 0 end
	end
	return math.min(segmentDistance(a, c, d), segmentDistance(b, c, d),
		segmentDistance(c, a, b), segmentDistance(d, a, b))
end

function bot.segmentHitsCone(start, finish, zone)
	if bot.attackZoneDepth(zone, start) >= 0 or bot.attackZoneDepth(zone, finish) >= 0 then return true end
	local line = finish - start
	local lengthSquared = line:Dot(line)
	if lengthSquared > 0.0001 then
		local t = math.clamp((zone.position - start):Dot(line) / lengthSquared, 0, 1)
		if bot.attackZoneDepth(zone, start + line * t) >= 0 then return true end
	end
	local c, sin = math.cos(zone.halfAngle), math.sin(zone.halfAngle)
	local f = zone.forward
	local a = Vector3.new(f.X * c - f.Z * sin, 0, f.X * sin + f.Z * c)
	local b = Vector3.new(f.X * c + f.Z * sin, 0, -f.X * sin + f.Z * c)
	return bot.segmentSeparation(start, finish, zone.position, zone.position + a * zone.radius) < 0.001
		or bot.segmentSeparation(start, finish, zone.position, zone.position + b * zone.radius) < 0.001
end

function bot.attackZonePenalty(start, finish, zones, ignoreMelee)
	local penalty = 0
	for _, zone in ipairs(zones) do
		if ignoreMelee and not bot.specialAttackZone(zone) then continue end
		local before, after = bot.attackZoneDepth(zone, start), bot.attackZoneDepth(zone, finish)
		if before > 0 then
			if after >= before - 0.01 then penalty += 100000 end
			penalty += math.max(0, after) * 1000
		else
			-- Test the full segment, including narrow lanes between sampled points.
			if zone.shape == "cone" then
				if bot.segmentHitsCone(start, finish, zone) then penalty += 100000 end
			else
				local distance = zone.shape == "lane" and bot.segmentSeparation(start, finish, zone.start, zone.finish)
					or segmentDistance(zone.position, start, finish)
				if distance < zone.radius then penalty += 100000 end
			end
		end
	end
	return penalty
end


function bot.hazardDepth(hazard, point)
	local separation
	if hazard.start and hazard.finish then
		separation = segmentDistance(point, hazard.start, hazard.finish)
	else
		separation = (point - flat(hazard.position)).Magnitude
	end
	return hazard.radius + 2.5 - separation
end

function bot.hazardRisk(position, direction, distance, speed, allowEscape)
	local now, penalty = workspace:GetServerTimeNow(), 0
	for _, hazard in ipairs(hazards) do
		if allowEscape then
			local initial = bot.hazardDepth(hazard, position)
			local middle = bot.hazardDepth(hazard, position + direction * (distance * 0.5))
			local final = bot.hazardDepth(hazard, position + direction * distance)
			if initial > 0 and middle < initial and final < middle then continue end
		end
		local earliest = math.max(0, hazard.impactAt - now - 0.15)
		local latest = math.max(0, hazard.expiresAt - now)
		if hazard.expiresAt >= now then
			for sample = 0, 4 do
				local t = earliest + (latest - earliest) * sample / 4
				local point = position + direction * math.min(distance, speed * t)
				local depth = bot.hazardDepth(hazard, point)
				if depth > 0 then
					penalty += 10000 + depth * 1000
					break
				end
			end
		end
	end
	return penalty
end

function bot.imminentHazard()
	local now, position = workspace:GetServerTimeNow(), flat(root.Position)
	for _, hazard in ipairs(hazards) do
		local lead = hazard.kind == "volley" and 1.6 or 1.2
		if hazard.impactAt <= now + lead and hazard.expiresAt >= now
			and bot.hazardDepth(hazard, position) > 0 then
			return true
		end
	end
	return false
end

local function chooseEscapeTarget(urgent, objective)
	local center, radius = getArena()
	local position = flat(root.Position)
	-- Plan with native walking; extra translation and an unconfirmed Q are not guaranteed.
	local estimatedSpeed = math.max(1, bot.walkSpeed())
	local moveDistance = math.clamp(estimatedSpeed * 0.8, 12, 45)
	local navigation = objective and navigationTarget(objective)
	local breaths, lionZones = bot.breaths or {}, bot.lionZones or {}
	local attackZones = bot.attackZones or {}
	local stayInZone = objective and objective.kind ~= "Treasure" and objective.kind ~= "Revive" and objective.kind ~= "Thief"
		and (position - objective.position).Magnitude <= objective.radius + 1
	local candidates, candidateLookup = {}, {}
	local bestTarget
	local bestDirection
	local bestScore = -math.huge
	local previousScore, previousTarget, previousDirection
	local objectiveKind, objectiveKey = objective and objective.kind or nil, objective and objective.key or nil
	local stableAllowed = not urgent and (bot.mode == "combat" or bot.mode == "objective")
		and not bot.retreat and not revive.seeking and not bot.hazardUrgent and not bot.attackRetreat
		and not bot.breathRetreat and not bot.lionRetreat and not bot.preleapAim and not bot.dashActive()
		and not bot.ringConstrained and #hazards == 0 and #attackZones == 0 and #breaths == 0 and #lionZones == 0
	local oldPosition = escapeTarget and flat(escapeTarget) or nil
	local previousIndex

	local function addCandidate(target)
		if stayInZone then
			local zoneOffset = target - objective.position
			if zoneOffset.Magnitude > objective.radius then
				target = objective.position + zoneOffset.Unit * objective.radius
			end
		end
		local delta = target - position
		if delta.Magnitude > moveDistance then
			target = position + delta.Unit * moveDistance
		end
		target = clampToArena(target, center, radius)
		if bot.ringConstrained then target = flat(bot.constrainRingPosition(target)) end
		if not stayInZone or (target - objective.position).Magnitude <= objective.radius + 0.01 then
			local column = candidateLookup[target.X]
			if not column then column = {}; candidateLookup[target.X] = column end
			local index = column[target.Z]
			if not index then
				table.insert(candidates, target)
				index = #candidates
				column[target.Z] = index
			end
			return index
		end
	end

	for _, direction in ipairs(candidateDirections) do
		addCandidate(position + direction * moveDistance)
		if objective or #hazards > 0 then
			addCandidate(position + direction * math.min(7, moveDistance))
		end
	end
	if navigation then
		addCandidate(navigation)
	end
	if not objective then
		addCandidate(position)
		addCandidate(center)
	end
	if objective then
		addCandidate(position)
		if objective.kind ~= "Chariot" then
			addCandidate(objective.position)
		end
		if objective.kind ~= "Treasure" then
			for _, direction in ipairs(objectiveDirections) do
				addCandidate(objective.position + direction * objective.radius * 0.7)
			end
		end
	end

	if stableAllowed and oldPosition and bot.stablePlanValid
		and bot.stablePlanObjectiveKind == objectiveKind and bot.stablePlanObjectiveKey == objectiveKey
		and (not objective or (objective.kind ~= "Eye" and objective.kind ~= "Chariot")
			or (position - objective.position).Magnitude <= objective.radius
			and (oldPosition - objective.position).Magnitude <= objective.radius) then
		previousIndex = addCandidate(oldPosition)
	end
	-- Enemy motion is unchanged during this non-yielding planning pass.
	local predictedThreats = {}
	for _, threat in ipairs(threats) do
		if threat.root:IsDescendantOf(enemiesFolder) then
			local enemyPosition, points = flat(threat.root.Position), {}
			for i, predictionTime in ipairs(predictionTimes) do
				points[i] = enemyPosition + threat.velocity * predictionTime
			end
			table.insert(predictedThreats, points)
		end
	end
	bot.lastPlanCandidates, bot.lastPlanThreats = #candidates, #predictedThreats

	for candidateIndex, candidate in ipairs(candidates) do
		local target = candidate
		local offset = target - position
		local distance = offset.Magnitude
		local actualDirection = distance > 0.01 and offset.Unit or Vector3.zero
		if distance > 0.1 then
			local obstacle = workspace:Blockcast(
				CFrame.new(root.Position), Vector3.new(2.5, 2, 2.5),
				actualDirection * distance, obstacleParams
			)
			if obstacle then
				distance = math.max(0, obstacle.Distance - 2)
				if distance < 1 then
					continue
				end
				target = position + actualDirection * distance
			end
		end
		if not hasFloor(target) then
			continue
		end
		local closestDistance = math.huge
		local combinedRisk = 0
		for _, points in ipairs(predictedThreats) do
			for i, predictionTime in ipairs(predictionTimes) do
				local travel = math.min(estimatedSpeed * predictionTime, distance)
				local predictedPlayer = position + actualDirection * travel
				local separation = (predictedPlayer - points[i]).Magnitude
				closestDistance = math.min(closestDistance, separation)
				combinedRisk += 1 / (separation + 2)
			end
		end
		local edgeDistance = radius - (target - center).Magnitude
		local clearance = wallClearance(target)
		local hazardCost = bot.hazardRisk(position, actualDirection, distance, estimatedSpeed)
		local breathCost = bot.breathPenalty(position, target, breaths)
		local lionCost = bot.breathPenalty(position, target, lionZones)
		local attackCost = bot.attackZonePenalty(position, target, attackZones)
		local score = math.min(closestDistance, 20)
			- combinedRisk * 30
			- (not objective and (target - center).Magnitude * 0.35 or 0)
			- (wallMargin - clearance) * 2
			+ math.clamp(edgeDistance, 0, 12) * 0.5
			+ distance * 0.15
			- hazardCost - breathCost - lionCost - attackCost

		if objective then
			score -= math.max(0, 8 - closestDistance) * 120
			local goalDistance = (target - objective.position).Magnitude
			if objective.kind == "Chariot" then
				score -= math.max(0, 4.5 - goalDistance) * 12
			end
			if navigation then
				score += ((position - navigation).Magnitude - (target - navigation).Magnitude) * 6
			else
				score -= math.max(0, goalDistance - objective.radius) * 18
				score -= goalDistance * 0.2
			end
			if objective.kind == "Treasure" and goalDistance <= objective.radius then
				score += 12
			end
		end
		if lastDirection and not urgent then
			score += actualDirection:Dot(lastDirection) * 2
		end
		if candidateIndex == previousIndex and oldPosition and (target - oldPosition).Magnitude < 0.001
			and hazardCost == 0 and breathCost == 0 and lionCost == 0 and attackCost == 0 then
			previousScore, previousTarget, previousDirection = score, target, actualDirection
		end
		if score > bestScore then
			bestScore = score
			bestTarget = target
			bestDirection = actualDirection
		end
	end
	bot.stablePlanValid = stableAllowed == true
	bot.stablePlanObjectiveKind, bot.stablePlanObjectiveKey = objectiveKind, objectiveKey
	if previousScore and bestScore - previousScore <= policy.stableScoreMargin then
		bestTarget, bestDirection = previousTarget, previousDirection
		bot.stablePlanKeeps = (bot.stablePlanKeeps or 0) + 1
	end
	if bestTarget then
		lastDirection = bestDirection.Magnitude > 0.01 and bestDirection or nil
		return Vector3.new(bestTarget.X, root.Position.Y, bestTarget.Z)
	end
	return nil
end

local function updateAttackTarget()
	local bestScore = math.huge
	attackModel, attackRoot = nil, nil
	for _, threat in ipairs(threats) do
		local enemy, enemyRoot = threat.model, threat.root
		if enemy.Parent == enemiesFolder and enemyRoot:IsDescendantOf(enemy) and isAlive(enemy)
			and hasLineOfSight(enemy, enemyRoot) then
			local distance = (enemyRoot.Position - root.Position).Magnitude
			local thiefPriority = not bot.retreat and not bot.lowReviveRetreat and challenge.live and challenge.id == "Treasure" and bot.isThief(enemy)
			local score = distance - (thiefPriority and (bot.isCarrier(enemy) and 200000 or 100000) or 0)
			if score < bestScore then
				bestScore, attackModel, attackRoot = score, enemy, enemyRoot
			end
		end
	end
end

-- Native walking supplies physical velocity (and the game's locomotion animation).
-- TranslateBy is only the additive tpwalk component, never a substitute for walking.
function bot.walkSpeed()
	local speed = humanoid and tonumber(humanoid.WalkSpeed) or 0
	return speed == speed and speed < math.huge and math.max(0, speed) or 0
end

function bot.constrainRingPosition(position)
	local ring = bot.ringConstrained and bot.ringSafeRegion
	if not position or not ring then return position end
	local delta = flat(position) - ring.center
	local radius = math.max(0, ring.radius - policy.hazardMargin - 0.5)
	if delta.Magnitude <= radius then return position end
	local clipped = delta.Magnitude > 0.001 and ring.center + delta.Unit * radius or ring.center
	return Vector3.new(clipped.X, position.Y, clipped.Z)
end

function bot.setDestination(position)
	position = bot.constrainRingPosition(position)
	escapeTarget = position
	wasMoving = position ~= nil
	if bot.mode ~= "combat" and bot.mode ~= "objective" then bot.stablePlanValid = false end
end

function bot.canMove()
	return not bot.matchEnded and character and player.Character == character and root and humanoid
		and humanoid.Health > 0 and not root.Anchored and not humanoid.Sit and not humanoid.PlatformStand
		and player:GetAttribute("Zone") == "Arena" and player:GetAttribute("CombatState") == "Alive"
		and character:GetAttribute("Downed") ~= true and player:GetAttribute("Cinematic") ~= true
		and character:GetAttribute("Cinematic") ~= true and player:GetAttribute("Spectating") ~= true
end

function bot.dashActive()
	return os.clock() < bot.dash.busyUntil or (root and root:FindFirstChild("DashPredict") ~= nil)
end

function bot.combatPaused()
	return bot.retreat or bot.preleapAim ~= nil or revive.arrived or revive.prompt ~= nil
		or (bot.bossIntent and bot.bossIntent.kind ~= "hold")
		or os.clock() < (bot.dash.prepareUntil or 0)
end

-- The game controls the quick-attack cooldown.
bot.bow = {held = false, nextAt = 0, reason = "idle", generation = 0}
function bot.releaseBow(reason, now)
	local bow = bot.bow
	if not bow.held then bow.reason = reason or bow.reason; return false end
	now = now or os.clock()
	if (reason == "combat_paused" or reason == "quick_release") and bow.deferReleaseUntil and now < bow.deferReleaseUntil then return true end
	local tool = bow.tool
	bow.held, bow.tool = false, nil
	bow.deferReleaseUntil = nil
	bow.lastHold = math.max(0, now - bow.pressedAt)
	bow.reason = reason or "released"
	bow.generation += 1
	if tool then pcall(function() tool:Deactivate() end) end
	return true
end
function bot.updateBow(now, tool)
	local bow = bot.bow
	if bow.held and bow.tool ~= tool then bot.releaseBow("tool_changed", now); return end
	if bow.held or not tool or now < bow.nextAt then return end
	local ok = pcall(function() tool:Activate() end)
	if not ok then bow.reason, bow.nextAt = "activate_failed", now + 0.2; return end
	bow.held, bow.tool, bow.pressedAt = true, tool, now
	bow.mode, bow.reason, bow.nextAt = "quick", "quick", now + 0.08
	bow.generation += 1
	local generation = bow.generation
	task.defer(function()
		if bow.held and bow.generation == generation then bot.releaseBow("quick_release") end
	end)
end

function bot.stopCombat()
	attackModel, attackRoot = nil, nil
	bot.releaseAbility()
	if not bot.releaseBow((revive.arrived or revive.prompt) and "revive" or "combat_paused") then
		local tool = character and character:FindFirstChildWhichIsA("Tool")
		if tool then pcall(function() tool:Deactivate() end) end
	end
end

-- Smooth only ordinary movement. A failed safety probe immediately uses the requested direction.
function bot.smoothWalkDirection(desired, forceRaw)
	local now = os.clock()
	local previous, previousAt = bot.walkSmoothDirection, bot.walkSmoothAt
	local function raw(reason)
		bot.walkSmoothDirection, bot.walkSmoothAt, bot.walkSmoothReason = desired, now, reason
		return desired
	end
	if forceRaw or desired.Magnitude < 0.1 or not previous or not previousAt
		or not controls.movement or controls.cursor or not root or not humanoid
		or (bot.mode ~= "combat" and bot.mode ~= "objective") or bot.movementEmergency
		or bot.retreat or revive.seeking or revive.prompt or bot.ringConstrained or bot.preleapAim
		or bot.dashActive() or now < (bot.dash.prepareUntil or 0)
		or (bot.guard and (bot.guard.keyDown or now < (bot.guard.releaseReadyAt or 0)))
		or #hazards > 0 or #(bot.attackZones or {}) > 0 or #(bot.breaths or {}) > 0 or #(bot.lionZones or {}) > 0 then
		return raw("bypass")
	end
	local elapsed = now - previousAt
	if elapsed < 0 or elapsed > 0.12 or previous.Magnitude < 0.1 or previous:Dot(desired) <= 0 then
		return raw("reset")
	end
	local alpha = 1 - math.exp(-elapsed / policy.walkSmoothTime)
	local mixed = previous * (1 - alpha) + desired * alpha
	if mixed.Magnitude < 0.1 then return raw("reset") end
	local direction = mixed.Unit
	if direction:Dot(desired) > 0.999 then return raw("aligned") end
	local offset = escapeTarget and flat(escapeTarget - root.Position)
	if not offset or offset.Magnitude <= math.max(1, bot.walkSpeed() * 0.08) then return raw("near_target") end
	local distance = math.min(offset.Magnitude, math.max(0.5, bot.walkSpeed() * 0.1))
	local point = root.Position + direction * distance
	local center, radius = getArena()
	if (flat(point) - center).Magnitude > radius or not hasFloor(point) or not directTravel(root.Position, point) then
		return raw("path_blocked")
	end
	local objective = currentObjective
	if objective and (objective.kind == "Eye" or objective.kind == "Chariot") then
		local before = (flat(root.Position) - objective.position).Magnitude
		local after = (flat(point) - objective.position).Magnitude
		if before > objective.radius or after > math.max(0, objective.radius - 0.5) then return raw("objective_boundary") end
	end
	bot.walkSmoothDirection, bot.walkSmoothAt, bot.walkSmoothReason = direction, now, "smoothed"
	bot.walkSmoothApplied = (bot.walkSmoothApplied or 0) + 1
	return direction
end


function bot.applyWalkInput(forceRaw)
	if not controls.movement then return end
	if not humanoid or not root or player.Character ~= character then return end
	local direction = Vector3.zero
	if bot.canMove() and escapeTarget and bot.walkSpeed() > 0 then
		local delta = flat(escapeTarget - root.Position)
		if delta.Magnitude > policy.arrivalTolerance then direction = delta.Unit end
	end
	direction = bot.smoothWalkDirection(direction, forceRaw == true)
	local previous = bot.walkLastOutput
	if previous and previous.Magnitude > 0.1 and direction.Magnitude > 0.1 and previous:Dot(direction) < -0.5 then
		bot.walkReversals = (bot.walkReversals or 0) + 1
	end
	bot.walkLastOutput = direction
	-- The control module writes Move every frame; a one-off MoveTo loses that input.
	humanoid:Move(direction, false)
	if orientation then
		local preAim = bot.preleapAim and flat(bot.preleapAim - root.Position)
		local facingMove = preAim and preAim.Magnitude > 0.01 or direction.Magnitude > 0 and (bot.combatPaused() or not attackRoot)
		if preAim and preAim.Magnitude > 0.01 then direction = preAim.Unit end
		orientation.Enabled = facingMove
		humanoid.AutoRotate = not facingMove and originalAutoRotate or false
		if facingMove then orientation.CFrame = CFrame.lookAt(Vector3.zero, direction) end
	end
end

local function applyExtraMovement(deltaTime)
	bot.movementExtra = 0
	if not controls.movement or not bot.canMove() or revive.arrived or revive.prompt or bot.dashActive() or not escapeTarget
		or humanoid.FloorMaterial == Enum.Material.Air then return end
	local speed = bot.walkSpeed()
	local moving = flat(humanoid.MoveDirection)
	local offset = flat(escapeTarget - root.Position)
	if speed <= 0 or moving.Magnitude < 0.1 or offset.Magnitude <= policy.arrivalTolerance then return end
	local direction = moving.Unit
	if direction:Dot(offset.Unit) < 0.9 then return end
	local physical = flat(root.AssemblyLinearVelocity)
	-- No sliding through blocked movement, forced acceleration, or addition to a dash/knockback.
	if physical:Dot(direction) < speed * 0.2 then return end
	local extra = math.min(speed * policy.tpwalkRatio, math.max(0, speed * (1 + policy.tpwalkRatio) - physical.Magnitude))
	local dt = math.clamp(deltaTime, 0, policy.maxMovementStep)
	local remaining = math.max(0, offset.Magnitude - policy.arrivalTolerance - physical.Magnitude * dt)
	local distance = math.min(extra * dt, remaining)
	if distance <= 0 then return end
	local obstacle = workspace:Blockcast(CFrame.new(root.Position), Vector3.new(2, 2, 2), direction * distance, obstacleParams)
	if obstacle then distance = math.min(distance, math.max(0, obstacle.Distance - 0.75)) end
	if distance <= 0 then return end
	local nextPosition = root.Position + direction * distance
	local center, radius = getArena()
	if (flat(nextPosition) - center).Magnitude > radius
		and (flat(nextPosition) - center).Magnitude >= (flat(root.Position) - center).Magnitude then return end
	if not hasFloor(nextPosition) then return end
	character:TranslateBy(direction * distance)
	bot.movementExtra = dt > 0 and distance / dt or 0
end


-- The game handles ability casting.
bot.ability = {keyDown = false, last = -math.huge, focused = true}
pcall(function() bot.ability.input = UserInputService:CreateVirtualInput() end)
pcall(function() bot.ability.legacy = game:GetService("VirtualInputManager") end)
UserInputService.WindowFocused:Connect(function() bot.ability.focused = true end)
UserInputService.WindowFocusReleased:Connect(function()
	bot.ability.focused = false
	if bot.releaseBow then bot.releaseBow("focus_lost") end
	if bot.releaseAbility then bot.releaseAbility() end
	if bot.releaseDashKey then bot.releaseDashKey() end
end)
function bot.sendKey(pressed, key)
	local ability = bot.ability
	if ability.input then
		local ok, result = pcall(function() return ability.input:SendKey(pressed, key, false) end)
		if ok and result ~= false then return true end
	end
	if ability.legacy then
		local ok, result = pcall(function() return ability.legacy:SendKeyEvent(pressed, key, false, game) end)
		if ok and result ~= false then return true end
	end
	return false
end
function bot.updateAutoSkip(now)
	bot.autoSkip = bot.autoSkip or {nextCheck = 0, attempted = {}}
	local skip = bot.autoSkip
	if now < skip.nextCheck then return end
	skip.nextCheck = now + 0.25
	if GameState:GetAttribute("NightmareGate") == "open" then return end
	if GameState:GetAttribute("Phase") ~= "InMatch" or GameState:GetAttribute("RoundPhase") ~= "Intermission"
		or player:GetAttribute("Zone") ~= "Arena" then return end
	local mode, key = GameState:GetAttribute("AutoSkip"), GameState:GetAttribute("AutoSkipKey")
	if (mode ~= "off" and mode ~= "on" and mode ~= "wait" and mode ~= "go") or type(key) ~= "string" or key == "" then return end
	local identity = tostring(GameState:GetAttribute("MatchId") or "") .. ":" .. key
	if skip.attempted[identity] or player:GetAttribute("AutoSkipOn") == key then return end
	if UserInputService:GetFocusedTextBox() or UserInputService:IsKeyDown(Enum.KeyCode.V) then return end
	local gui = player:FindFirstChildOfClass("PlayerGui")
	local button = gui and gui:FindFirstChild("AutoSkipButton", true)
	if not button then return end
	local ancestor = button
	while ancestor and ancestor ~= gui do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then return end
		if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return end
		ancestor = ancestor.Parent
	end
	if ancestor ~= gui then return end
	local ledger = gui:FindFirstChild("AutoBotAutoSkipState")
	if ledger and ledger:GetAttribute("LastAttempt") == identity then return end
	if not ledger then
		ledger = Instance.new("Folder")
		ledger.Name, ledger.Parent = "AutoBotAutoSkipState", gui
	end
	if bot.sendKey(true, Enum.KeyCode.V) then
		skip.attempted[identity] = true
		ledger:SetAttribute("LastAttempt", identity)
		task.delay(0.06, function() bot.sendKey(false, Enum.KeyCode.V) end)
	end
end

function bot.updateNightmareChoice(now)
	bot.nightmareChoice = bot.nightmareChoice or {nextAt = 0, attempts = 0}
	local state = bot.nightmareChoice
	if GameState:GetAttribute("NightmareGate") ~= "open" then
		state.session, state.nextAt, state.attempts, state.reason = nil, 0, 0, "closed"
		return
	end
	if player:GetAttribute("Zone") ~= "Arena" then state.reason = "not_in_arena"; return end
	local choice = player:GetAttribute("NightmareChoice")
	if choice == "descend" then state.reason = "accepted"; return end
	if choice ~= "" then state.reason = choice == "claim" and "already_claimed" or "choice_unavailable"; return end
	local ends = tonumber(GameState:GetAttribute("NightmareGateEnds"))
	if ends and ends > 0 and workspace:GetServerTimeNow() >= ends then state.reason = "expired"; return end
	local session = tostring(GameState:GetAttribute("MatchId") or "") .. ":" .. tostring(ends or "")
	if state.session ~= session then state.session, state.nextAt, state.attempts = session, 0, 0 end
	if now < state.nextAt or state.attempts >= 5 then return end
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("NightmareChoice")
	if not remote or not remote:IsA("RemoteEvent") then state.reason, state.nextAt = "remote_unavailable", now + 0.5; return end
	state.nextAt = now + 3
	local ok = pcall(function() remote:FireServer("descend") end)
	if ok then state.attempts, state.reason = state.attempts + 1, "sent" else state.reason = "send_failed" end
end

function bot.releaseAbility()
	if bot.ability.keyDown and bot.sendKey(false, Enum.KeyCode.R) then bot.ability.keyDown = false end
end
function bot.updateAbility()
	local ability, now = bot.ability, os.clock()
	ability.reason = "gated"
	if ability.qDown and now - (ability.qPressedAt or now) >= 0.06 and bot.releaseDashKey then bot.releaseDashKey() end
	if not controls.ability then bot.releaseAbility(); return end
	if GameState:GetAttribute("Phase") == "Ending" or bot.matchEnded then
		bot.releaseAbility(); ability.reason = "match_ended"; return
	end
	local alive = false
	for _, threat in ipairs(threats) do
		local model, part = threat.model, threat.root
		if model and part and model.Parent == enemiesFolder and part:IsDescendantOf(model) and isAlive(model) then
			alive = true; break
		end
	end
	if not alive then bot.releaseAbility(); ability.reason = "no_enemies"; return end
	if ability.keyDown then
		if now - ability.pressedAt >= 0.05 then bot.releaseAbility() end
		return
	end
	if bot.combatPaused() or not character or player.Character ~= character or not root
		or not humanoid or humanoid.Health <= 0 or root.Anchored or character:GetAttribute("Downed") == true
		or player:GetAttribute("Zone") ~= "Arena" or player:GetAttribute("CombatState") ~= "Alive"
		or now < bot.dash.busyUntil or now - ability.last < 0.5 or not ability.focused
		or UserInputService:GetFocusedTextBox() or UserInputService:IsKeyDown(Enum.KeyCode.R)
		or (tonumber(player:GetAttribute("AbilityReadyAt")) or 0) > workspace:GetServerTimeNow() then return end
	-- Attempt when ready while at least one enemy is alive.
	ability.last = now
	ability.reason = "input_attempt"
	if bot.sendKey(true, Enum.KeyCode.R) then
		ability.keyDown, ability.pressedAt = true, now
		task.delay(0.06, function() bot.releaseAbility() end)
	end
end


-- Use the same prompt hold API as the game's own touch revive UI.
-- The server decides whether the hold, distance, and revive are valid.
local function promptPosition(prompt)
	local parent = prompt.Parent
	if parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

local function eligibleReviver()
	return character and player.Character == character
		and humanoid and humanoid.Health > 0 and root and not root.Anchored
		and player:GetAttribute("Zone") == "Arena"
		and player:GetAttribute("CombatState") == "Alive"
		and character:GetAttribute("Downed") ~= true
end

-- Choose real players before friendly bots. Other revivers do not exclude a target.
bot.departingPlayers = setmetatable({}, {__mode = "k"})
local function validAlly(ally, model, prompt, allowDisabled)
	if not model or not model:IsDescendantOf(workspace)
		or model:GetAttribute("ReviveOffer") == true
		or model:GetAttribute("CombatState") == "Eliminated"
		or model:GetAttribute("CombatState") == "Dead"
		or (ally and (bot.departingPlayers[ally] or ally:GetAttribute("CombatState") == "Eliminated")) then return false end
	if ally then
		if ally == player or ally.Parent ~= Players or ally.Character ~= model
			or ally:GetAttribute("Zone") ~= "Arena" or model:GetAttribute("Downed") ~= true then return false end
	else
		if not model:IsA("Model") or not CollectionService:HasTag(model, "Bot")
			or (model:GetAttribute("Downed") ~= true and model:GetAttribute("CombatState") ~= "Downed") then return false end
	end
	local mine, theirs = player:GetAttribute("MatchId"), (ally or model):GetAttribute("MatchId")
	if type(mine) == "string" and mine ~= "" and type(theirs) == "string" and theirs ~= "" and mine ~= theirs then return false end
	return prompt and prompt:IsA("ProximityPrompt") and prompt.Name == "ReviveP"
		and (prompt.Enabled or allowDisabled) and prompt:IsDescendantOf(model) and promptPosition(prompt) ~= nil
end

function bot.nearestDowned()
	if not eligibleReviver() then return nil end
	local best, bestDistance
	for _, ally in ipairs(Players:GetPlayers()) do
		if ally == player then continue end
		local model = ally.Character
		local prompt = model and model:FindFirstChild("ReviveP", true)
		if not validAlly(ally, model, prompt, true) then continue end
		local position = promptPosition(prompt)
		if not validObjectivePosition(position) then continue end
		local distance = (position - root.Position).Magnitude
		if not bestDistance or distance < bestDistance then
			bestDistance = distance
			best = {ally = ally, character = model, prompt = prompt, position = position,
				range = tonumber(prompt.MaxActivationDistance) or 0}
		end
	end
	return best
end

-- Input acceptance and server progress are separate observations.
local ProximityPromptService = game:GetService("ProximityPromptService")
bot.shownPrompts = setmetatable({}, {__mode = "k"})
ProximityPromptService.PromptShown:Connect(function(prompt)
	bot.shownPrompts[prompt] = true
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	bot.shownPrompts[prompt] = nil
end)
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, who)
	if revive.prompt == prompt and (not who or who == player) then
		revive.localHold, revive.localEnded = true, false
	end
end)
ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, who)
	if revive.prompt == prompt and (not who or who == player) then revive.localEnded = true end
end)

function bot.reviveRange(candidate)
	local prompt = candidate.prompt
	local range = candidate.range or tonumber(prompt.MaxActivationDistance) or 0
	-- Never use the larger cancellation range installed by the game's hold handler to start a hold.
	return math.max(0, range - policy.reviveRangeMargin)
end

function bot.reviveObjective(candidate)
	local position = promptPosition(candidate.prompt)
	if not position then return nil end
	candidate.position = position
	local vertical = position.Y - root.Position.Y
	local range = bot.reviveRange(candidate)
	local horizontal = math.sqrt(math.max(0, range * range - vertical * vertical))
	return {kind = "Revive", key = candidate.character, position = flat(position),
		radius = math.max(0, horizontal - policy.arrivalTolerance)}
end

local function findReviveTarget()
	if not eligibleReviver() then return nil end
	local locked = revive.locked
	if locked and locked.ally and validAlly(locked.ally, locked.character, locked.prompt, true) then
		return locked
	end
	if locked or revive.prompt then endRevive(false, "target_invalid") end
	local chosen = bot.nearestDowned()
	revive.locked = chosen
	revive.tryKey = false
	return chosen
end

endRevive = function(retry, reason)
	local prompt, key = revive.prompt, revive.key
	-- Clear before InputHoldEnd so its synchronous event cannot invalidate the next hold.
	revive.prompt, revive.target, revive.ally, revive.key = nil, nil, nil, nil
	revive.localHold, revive.localEnded, revive.arrived = false, false, false
	if key then bot.sendKey(false, key) end
	if prompt then pcall(function() prompt:InputHoldEnd() end) end
	revive.retryAt = retry and os.clock() + policy.reviveRetry or 0
	if not retry then revive.locked = nil end
	revive.phase = reason or "idle"
	elapsed = updateInterval
end

function bot.reviveKeySafe(prompt)
	if not bot.shownPrompts[prompt] or not prompt.Enabled or not bot.ability.focused
		or UserInputService:GetFocusedTextBox() then return false end
	local key = prompt.KeyboardKeyCode
	if not key or key == Enum.KeyCode.Unknown or UserInputService:IsKeyDown(key) then return false end
	-- A key press can choose the wrong player when prompts overlap: only use it if unambiguous.
	for other in pairs(bot.shownPrompts) do
		if other ~= prompt and other.Parent and other.Enabled and other.KeyboardKeyCode == key then return false end
	end
	return true
end

local function beginRevive(candidate)
	local prompt, now = candidate.prompt, os.clock()
	if revive.prompt or now < revive.retryAt then return end
	if bot.dashActive() then revive.phase = "dash_finishing"; return end
	if not prompt.Enabled then revive.phase = "prompt_disabled"; return end
	revive.prompt, revive.target, revive.ally = prompt, candidate.character, candidate.ally
	revive.startedAt, revive.localHold, revive.localEnded = now, false, false
	revive.progress = tonumber(candidate.character:GetAttribute("ReviveProgress")) or 0
	revive.progressAt = now
	revive.interruptedAt = tonumber(candidate.character:GetAttribute("ReviveInterruptedAt")) or 0
	revive.phase = "requesting"
	local ok
	if revive.tryKey and bot.reviveKeySafe(prompt) then
		revive.key = prompt.KeyboardKeyCode
		ok = bot.sendKey(true, revive.key)
		revive.method = "key"
	else
		ok = pcall(function() prompt:InputHoldBegin() end)
		revive.method = "prompt"
	end
	if not ok then endRevive(true, "input_failed") end
end

local function updateRevive()
	if not revive.prompt then return end
	local prompt, target, now = revive.prompt, revive.target, os.clock()
	if not eligibleReviver() or not validAlly(revive.ally, target, prompt, true) then
		endRevive(false, "target_invalid"); return
	end
	local position = promptPosition(prompt)
	if not position or (position - root.Position).Magnitude > prompt.MaxActivationDistance then
		endRevive(true, "out_of_range"); return
	end
	local progress = tonumber(target:GetAttribute("ReviveProgress")) or 0
	local own = tonumber(target:GetAttribute("ReviverUserId")) == player.UserId
	local interrupted = tonumber(target:GetAttribute("ReviveInterruptedAt")) or 0
	if own and progress > revive.progress then revive.progressAt = now end
	revive.progress = progress
	local duration = math.max(tonumber(prompt.HoldDuration) or 0, 0)
	local endedEarly = revive.localEnded and now - revive.startedAt < duration
	if interrupted > revive.interruptedAt or endedEarly then
		endRevive(true, "interrupted"); return
	end
	if not revive.localHold and not own and now - revive.startedAt >= policy.holdAckTimeout then
		revive.tryKey = not revive.tryKey
		endRevive(true, "input_unacknowledged"); return
	end
	-- Keep a full normal hold when local input is accepted; never cancel on another reviver's ID.
	if now - math.max(revive.startedAt, revive.progressAt) > duration + policy.serverGrace then
		endRevive(true, "progress_stalled"); return
	end
	revive.phase = own and "server_reviving" or revive.localHold and "holding_local" or "requesting"
end

function bot.stepRevive(candidate)
	if not candidate then revive.arrived, revive.phase = false, "idle"; return false end
	local position = promptPosition(candidate.prompt)
	if not position then return false end
	candidate.position = position
	local distance = (position - root.Position).Magnitude
	revive.arrived = revive.prompt ~= nil or distance <= bot.reviveRange(candidate)
	if not revive.arrived then revive.phase = "approaching"; return false end
	bot.stopCombat()
	bot.releaseDashKey()
	-- Crawl following uses normal walking only. A second, smaller radius prevents start/stop chatter.
	local followRange = bot.reviveRange(candidate) * 0.7
	local delta = flat(position - root.Position)
	if revive.prompt and distance > followRange then
		local follow = position - (delta.Magnitude > 0.01 and delta.Unit * followRange * 0.7 or Vector3.zero)
		bot.setDestination(Vector3.new(follow.X, root.Position.Y, follow.Z))
	else
		bot.setDestination(nil)
	end
	bot.applyWalkInput()
	beginRevive(candidate)
	return true
end

function bot.continueAcceptedRevive(candidate)
	if not candidate or not revive.prompt or revive.prompt ~= candidate.prompt then return false end
	local own = tonumber(candidate.character:GetAttribute("ReviverUserId")) == player.UserId
	if not revive.localHold and not own then return false end
	-- Preserve only a locally accepted or server-acknowledged hold.
	revive.selected, revive.seeking = candidate, true
	bot.lowReviveRetreat = false
	bot.preleapAim, bot.ringSafeRegion, bot.ringConstrained = nil, nil, false
	bot.crowdEscape, bot.projectilePlan, bot.projectileActive = nil, nil, false
	bot.normalThreat, bot.strongMeleeDash, bot.waitingForLock = nil, false, false
	bot.breathRetreat, bot.lionRetreat, bot.attackRetreat = false, false, false
	currentObjective = bot.reviveObjective(candidate)
	bot.mode = "revive_hold"
	bot.stepRevive(candidate)
	bot.publishState()
	return true
end

Players.PlayerRemoving:Connect(function(ally)
	bot.departingPlayers[ally] = true
	if revive.locked and revive.locked.ally == ally then endRevive(false, "player_left") end
	if revive.selected and revive.selected.ally == ally then revive.selected = nil end
	elapsed = updateInterval
end)


-- The observed base dash distance is used as an estimate; equipment can change it.
function bot.dashDistance()
	return bot.dash.observedDistance or 20
end

function bot.dashPathClear(direction, length, ignoreHazards, allowEscape)
	local start = root.Position
	local offset = direction * length
	if workspace:Blockcast(CFrame.new(start), Vector3.new(2.5, 2, 2.5), offset, obstacleParams) then bot.dash.pathReason = "obstacle"; return false end
	local center, radius = getArena()
	for i = 1, 4 do
		local point = start + offset * (i / 4)
		if (flat(point) - center).Magnitude > radius then bot.dash.pathReason = "boundary"; return false end
		if not hasFloor(point) then bot.dash.pathReason = "no_floor"; return false end
	end
	local duration = 0.2
	if not ignoreHazards and bot.hazardRisk(flat(start), direction, length, length / duration, allowEscape) > 0 then bot.dash.pathReason = "hazard"; return false end
	bot.dash.pathReason = "clear"
	return true
end

-- Use the normal Q binding. A sent key is an attempt, not proof of a dash.
function bot.releaseDashKey()
	if bot.ability.qDown and bot.sendKey(false, Enum.KeyCode.Q) then bot.ability.qDown = false end
end
function bot.activateDash()
	local ability = bot.ability
	if ability.qDown or not ability.focused or UserInputService:GetFocusedTextBox()
		or UserInputService:IsKeyDown(Enum.KeyCode.Q) then return false, "input_unavailable" end
	if not bot.sendKey(true, Enum.KeyCode.Q) then return false, "input_failed" end
	ability.qDown, ability.qPressedAt = true, os.clock()
	task.delay(0.06, function() bot.releaseDashKey() end)
	return true, "q_attempt"
end

function bot.noteDashAttempt(now, method)
	local dash = bot.dash
	dash.reason, dash.attemptCount = method, (dash.attemptCount or 0) + 1
	-- Sending Q is only an attempt; pause longer only if a local dash is observed.
	dash.busyUntil = now + 0.08
	dash.prepareUntil = math.max(dash.prepareUntil or 0, now + 0.12)
	local dashRoot = root
	task.delay(0.06, function()
		local predict = root == dashRoot and dashRoot and dashRoot:FindFirstChild("DashPredict")
		if predict then
			dash.busyUntil = math.max(dash.busyUntil, now + 0.23)
			dash.prepareUntil = math.max(dash.prepareUntil or 0, now + 0.23)
			local velocity = predict:IsA("LinearVelocity") and flat(predict.VectorVelocity).Magnitude or 0
			if velocity >= 20 and velocity <= 200 then
				dash.observedDistance = math.clamp(velocity * 0.2, 8, 40)
			end
		end
	end)
end

function bot.actualDashDirection()
	local moving, facing = flat(humanoid.MoveDirection), flat(root.CFrame.LookVector)
	if facing.Magnitude < 0.001 then return nil end
	facing = facing.Unit
	if moving.Magnitude < 0.1 then return facing end
	moving = moving.Unit
	local right = Vector3.new(-facing.Z, 0, facing.X)
	local forwardDot, sideDot = moving:Dot(facing), moving:Dot(right)
	if math.abs(sideDot) - 0.001 <= math.abs(forwardDot) then
		return forwardDot >= 0 and facing or -facing
	end
	return sideDot >= 0 and right or -right
end

function bot.prepareDash(now)
	local dash = bot.dash
	if dash.prepareUntil then
		if now >= dash.prepareUntil then
			dash.prepareUntil = nil
			dash.prepareRetryAt = now + 0.1
		end
	elseif now >= (dash.prepareRetryAt or 0) then
		dash.prepareUntil = now + 0.35
	end
end

-- The same gate executes Q for travel, telegraphs, and boss mechanics.
function bot.tryDash(destination, purpose)
	local dash, now = bot.dash, os.clock()
	local function skip(reason) dash.reason = reason end
	if not controls.dash or not controls.movement then return skip("disabled") end
	if not bot.canMove() or revive.arrived or revive.prompt or not escapeTarget then return skip("not_eligible") end
	if bot.dashActive() then return skip("dash_active") end
	-- A previous travel attempt must not block a newly urgent boss or volley dodge.
	local urgentDeadline = (dash.lastSentAt or -math.huge) + 0.18
	if now < (purpose == "travel" and dash.attemptAt or urgentDeadline) then return skip("attempt_interval") end
	local offset = flat(escapeTarget - root.Position)
	if offset.Magnitude < 0.1 then return skip("at_destination") end
	-- Q uses the game's current movement direction; do not smooth a dash attempt.
	bot.applyWalkInput(true)
	local direction, distance = bot.actualDashDirection(), bot.dashDistance()
	if not direction then return skip("no_facing") end
	local allowEscape = purpose ~= "travel" and purpose ~= "ring"
	if bot.ringConstrained and bot.ringSafeRegion then
		local ring = bot.ringSafeRegion
		local landing = flat(root.Position + direction * distance)
		if (landing - ring.center).Magnitude > math.max(0, ring.radius - policy.hazardMargin - 0.5) then
			return skip("ring_boundary")
		end
	end
	if direction:Dot(offset.Unit) < 0.85 then
		if bot.dashPathClear(offset.Unit, distance + 2, false, allowEscape) then bot.prepareDash(now) end
		return skip("aligning")
	end
	if destination and purpose ~= "evade" then
		local before = flat(root.Position - destination).Magnitude
		local after = flat(root.Position + direction * distance - destination).Magnitude
		if purpose == "escape" then
			if after <= before then return skip("no_escape_progress") end
		elseif purpose == "travel" or purpose == "ring" then
			local radius = purpose == "travel" and currentObjective and (currentObjective.radius or 0)
				or purpose == "ring" and bot.bossIntent and math.max(0, bot.bossIntent.radius - 2) or 0
			local oldGap, newGap = math.max(0, before - radius), math.max(0, after - radius)
			if oldGap <= 0 or newGap >= oldGap - 1 then return skip("no_goal_progress") end
		end
	end
	if not bot.dashPathClear(direction, distance + 2, false, allowEscape) then return skip("path_blocked") end
	local attempted, method = bot.activateDash()
	if attempted and bot.bow.held then
		-- The game cancels its draw on an accepted Q. Release the held Tool after
		-- input delivery, so firing on Tool release cannot delay the dash itself.
		local generation = bot.bow.generation
		bot.bow.deferReleaseUntil = now + 0.07
		task.delay(0.07, function()
			if bot.bow.held and bot.bow.generation == generation then bot.releaseBow("dash_attempt") end
		end)
	end
	if attempted then dash.lastSentAt = now end
	dash.reason = method
	dash.attemptAt = now + (attempted and (allowEscape and 0.45 or 0.75) or 0.75)
	if attempted then
		bot.noteDashAttempt(now, method)
		-- No automatic follow-up: re-evaluate danger and goal on the next attempt.
	end
end

function bot.updateDash(urgent)
	local objective = currentObjective
	local travel = objective and (objective.kind == "Revive" or objective.kind == "Eye" or objective.kind == "Chariot"
		or objective.kind == "Treasure" or objective.kind == "Thief")
	-- A second dodge is a new decision, never a reserved chain.
	if not travel and not urgent then bot.dash.reason = "no_dash_goal"; return end
	if travel and not urgent and objective.radius and
		(flat(root.Position) - objective.position).Magnitude <= objective.radius then
		bot.dash.reason = "inside_objective"; return
	end
	bot.tryDash(travel and objective.position or escapeTarget, urgent and "evade" or travel and "travel" or "evade")
end


-- BossMech is a Folder, separate from the BasePart-based BossMark telegraphs.
-- Leap timing is taken from each live marker; ring/echo behaviour is provisional.
function bot.selectBossMechanic(candidate)
	bot.leapReason = "none"
	if not root or not humanoid or root.Anchored then return nil, false end
	local now, position = workspace:GetServerTimeNow(), flat(root.Position)
	local waiting, selected, preLeap = false, nil, nil
	local goal = candidate and promptPosition(candidate.prompt)
	local function consider(kind, shape, center, radius, impact, destination, lockedAt)
		if not selected or (selected.kind == "hold" and kind ~= "hold")
			or ((selected.kind == "hold") == (kind == "hold") and impact < selected.when) then
			selected = {kind = kind, shape = shape, center = center, radius = radius, when = impact,
				position = destination or root.Position, lockedAt = lockedAt}
		end
	end
	for _, mark in ipairs(CollectionService:GetTagged("BossMech")) do
		if not mark:IsDescendantOf(workspace) then continue end
		local kind, center = mark:GetAttribute("Kind"), mark:GetAttribute("Center")
		local impact = tonumber(mark:GetAttribute("ImpactAt"))
		if not impact then continue end
		if kind == "leap" and now <= impact + policy.hazardGrace then
			local target = mark:FindFirstChild("Target")
			local value = target and target:IsA("ObjectValue") and target.Value
			local lockedAt = tonumber(mark:GetAttribute("LockAt"))
			local locked = typeof(center) == "Vector3" and (not lockedAt or now >= lockedAt)
			if not locked then
				if value == character or value == player then
					waiting = true; bot.leapReason = "waiting_for_lock"
					local radius = tonumber(mark:GetAttribute("Radius"))
					if lockedAt and radius and radius > 0 and lockedAt >= now and lockedAt - now <= 0.25 then
						preLeap = {radius = radius, lockedAt = lockedAt}
					end
				end
			else
				local radius = tonumber(mark:GetAttribute("Radius"))
				if radius and radius > 0 then
					center = flat(center)
					if (position - center).Magnitude < radius + policy.hazardMargin then
						local point = bot.bossEscapePoint(center, radius + policy.hazardMargin)
						if point then
							bot.leapReason = "escape_selected"
							consider("leap", "circle", center, radius, impact, point, lockedAt)
						else
							bot.leapReason = "no_safe_path"
						end
					elseif goal and segmentDistance(center, position, flat(goal)) < radius + policy.hazardMargin then
						consider("hold", "circle", center, radius, impact)
					end
				end
			end
		elseif kind == "ring" and typeof(center) == "Vector3" then
			center = flat(center)
			local inner = tonumber(mark:GetAttribute("Inner")) or 13 -- BossMechFx.buildRing fallback
			local echoAt, echoInner = tonumber(mark:GetAttribute("EchoAt")), tonumber(mark:GetAttribute("EchoInner"))
			if inner and inner > policy.hazardMargin and now <= impact + policy.hazardGrace then
				local outside = (position - center).Magnitude > inner - policy.hazardMargin
				consider(outside and "ring" or "hold", "ring", center, inner, impact,
					outside and Vector3.new(center.X, root.Position.Y, center.Z) or nil)
			elseif echoAt and echoAt > impact and now <= echoAt + policy.hazardGrace and echoInner and echoInner > 0 then
				if (position - center).Magnitude < echoInner + policy.hazardMargin then
					local point = bot.bossEscapePoint(center, echoInner + policy.hazardMargin)
					if point then consider("echo", "circle", center, echoInner, echoAt, point) end
				elseif goal and segmentDistance(center, position, flat(goal)) < echoInner + policy.hazardMargin then
					consider("hold", "circle", center, echoInner, echoAt)
				end
			end
		end
	end
	-- A marker can disappear at impact before damage has finished. Keep the last guard briefly.
	local previous = bot.bossIntent
	if not selected and previous and now <= previous.when + policy.hazardGrace then
		local separation = (position - previous.center).Magnitude
		local safe = previous.shape == "ring" and separation <= previous.radius - policy.hazardMargin
			or previous.shape ~= "ring" and separation >= previous.radius + policy.hazardMargin
		selected = table.clone(previous)
		if safe then selected.kind, selected.position = "hold", root.Position end
	end
	return selected, waiting, preLeap
end


function bot.bossEscapePoint(center, safeDistance)
	local best, bestScore
	local start = flat(root.Position)
	local arenaCenter, arenaRadius = getArena()
	local length = bot.dashDistance()
	local cached = bot.escapeCache
	if cached and os.clock() < cached.untilTime and (cached.center - center).Magnitude < 0.5
		and math.abs(cached.safeDistance - safeDistance) < 0.5 then
		local offset = flat(cached.point - root.Position)
		if offset.Magnitude > 0.1 and (flat(cached.point) - center).Magnitude > (start - center).Magnitude + 0.5
			and (flat(cached.point) - arenaCenter).Magnitude <= arenaRadius
			and hasFloor(cached.point) and directTravel(root.Position, cached.point)
			and bot.hazardRisk(start, offset.Unit, offset.Magnitude, length / 0.2, true) == 0 then
			return cached.point
		end
	end
	for i = 0, 23 do
		local angle = i * math.pi * 2 / 24
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local point = start + direction * length
		local world = Vector3.new(point.X, root.Position.Y, point.Z)
		local separation = (point - center).Magnitude
		if (point - arenaCenter).Magnitude <= arenaRadius and hasFloor(world)
			and directTravel(root.Position, world)
			and bot.hazardRisk(start, direction, length, length / 0.2, true) == 0 then
			local score = math.min(separation - safeDistance, 4) * 100 - (point - arenaCenter).Magnitude * 0.1
			if not bestScore or score > bestScore then best, bestScore = world, score end
		end
	end
	-- Near walls, try a shorter walking path if a full dash path is unavailable.
	if not best then
		for _, shortLength in ipairs({12, 8, 4}) do
			for i = 0, 23 do
				local angle = i * math.pi * 2 / 24
				local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local point = start + direction * shortLength
				local world = Vector3.new(point.X, root.Position.Y, point.Z)
				local separation = (point - center).Magnitude
				if separation > (start - center).Magnitude + 0.5 and (point - arenaCenter).Magnitude <= arenaRadius
					and hasFloor(world) and directTravel(root.Position, world)
					and bot.hazardRisk(start, direction, shortLength, math.max(bot.walkSpeed(), 1), true) == 0 then
					local score = math.min(separation - safeDistance, 4) * 100 - (point - arenaCenter).Magnitude * 0.1
					if not bestScore or score > bestScore then best, bestScore = world, score end
				end
			end
			if best then break end
		end
	end
	if best then bot.escapeCache = {point = best, center = center, safeDistance = safeDistance, untilTime = os.clock() + 0.12} end
	return best
end

-- If the current body facing is poorly aligned, test the four dash directions the game can actually choose.
function bot.mechanicDashAlternative(intent)
	local facing = flat(root.CFrame.LookVector)
	if facing.Magnitude < 0.01 then return false end
	facing = facing.Unit
	local right = Vector3.new(-facing.Z, 0, facing.X)
	local directions = {facing, -facing, right, -right}
	local length, start = bot.dashDistance(), flat(root.Position)
	local before = (start - intent.center).Magnitude
	local bestDirection, bestScore
	for _, direction in ipairs(directions) do
		local endpoint = start + direction * length
		local after = (endpoint - intent.center).Magnitude
		local score
		if intent.kind == "ring" then
			local radius = math.max(0, intent.radius - policy.hazardMargin)
			local oldGap, newGap = math.max(0, before - radius), math.max(0, after - radius)
			if oldGap <= 0 or newGap >= oldGap - 1 then continue end
			score = -newGap
		else
			if after <= before + 0.5 then continue end
			score = after - before + math.min(0, after - intent.radius - policy.hazardMargin) * 4
		end
		if bot.dashPathClear(direction, length + 2, false, intent.kind ~= "ring")
			and (not bestScore or score > bestScore) then bestDirection, bestScore = direction, score end
	end
	if not bestDirection then bot.dash.reason = intent.kind == "ring" and "ring_no_safe_dash" or "escape_no_safe_dash"; return false end
	local oldTarget = escapeTarget
	bot.setDestination(root.Position + bestDirection * length)
	bot.applyWalkInput()
	local actual = bot.actualDashDirection()
	if not actual or actual:Dot(bestDirection) < 0.98 then
		-- Preserve the axis for the next frame; never send Q while the game still reports a different direction.
		bot.dash.reason = "mechanic_axis_wait"
		return false
	end
	local count = bot.dash.attemptCount or 0
	bot.tryDash(intent.center, intent.kind == "ring" and "ring" or "escape")
	if (bot.dash.attemptCount or 0) > count then return true end
	if bot.dash.reason ~= "aligning" then bot.setDestination(oldTarget) end
	return false
end


function bot.mechanicDash(intent)
	if not intent or intent.kind == "hold" then bot.dash.reason = "mechanic_hold"; return end
	bot.tryDash(intent.center, intent.kind == "ring" and "ring" or "escape")
	local reason = bot.dash.reason
	if reason == "aligning" or reason == "path_blocked" or reason == "no_goal_progress" or reason == "no_escape_progress" then
		bot.mechanicDashAlternative(intent)
	end
end

-- Compare normal walking and the remaining normal hold with the telegraph deadline.
-- Q charges are unavailable, so a possible dash is never counted as guaranteed travel.
function bot.walkTime(from, to, radius)
	local distance = math.max(0, flat(to - from).Magnitude - (radius or 0))
	if distance == 0 then return 0 end
	if bot.walkSpeed() <= 0 or not directTravel(from, Vector3.new(to.X, from.Y, to.Z)) then return math.huge end
	return distance / bot.walkSpeed()
end

function bot.remainingRevive(candidate)
	local duration = math.max(tonumber(candidate.prompt.HoldDuration) or 0, 0)
	if revive.prompt == candidate.prompt and tonumber(candidate.character:GetAttribute("ReviverUserId")) == player.UserId then
		local progress = math.clamp(tonumber(candidate.character:GetAttribute("ReviveProgress")) or 0, 0, 1)
		return duration * (1 - progress)
	end
	return duration
end

function bot.mechanicBeforeRevive(intent, candidate)
	if not intent then return false end
	if not candidate then return true end
	local position = promptPosition(candidate.prompt)
	if not position then return true end
	local separation = (flat(position) - intent.center).Magnitude
	local ring = intent.shape == "ring" or intent.kind == "ring"
	local safe = ring and separation <= intent.radius - policy.hazardMargin
		or not ring and separation >= intent.radius + policy.hazardMargin
	local current = (flat(root.Position) - intent.center).Magnitude
	local currentlySafe = ring and current <= intent.radius - policy.hazardMargin
		or not ring and current >= intent.radius + policy.hazardMargin
	if safe and currentlySafe and (ring or segmentDistance(intent.center, flat(root.Position), flat(position)) >= intent.radius + policy.hazardMargin) then
		return false
	end
	local approach = bot.walkTime(root.Position, position, bot.reviveRange(candidate))
	local exitDistance = ring and math.max(0, separation - intent.radius + policy.hazardMargin)
		or math.max(0, intent.radius + policy.hazardMargin - separation)
	local escapeTime = bot.walkSpeed() > 0 and exitDistance / bot.walkSpeed() or math.huge
	if ring then escapeTime = bot.walkTime(position, intent.center, intent.radius - policy.hazardMargin) end
	local completesSafely = approach + bot.remainingRevive(candidate) + escapeTime + policy.serverGrace
		< intent.when - workspace:GetServerTimeNow()
	-- Once retreat has begun, finish the mechanic before resuming the saved target.
	return (bot.bossIntent ~= nil and bot.bossIntent.kind ~= "hold") or not completesSafely
end

-- Remember that we actually entered a live volley, then hold the safe position
-- until its retained danger window expires. New danger still interrupts the hold.
function bot.updateVolleyExposure()
	local now, position = workspace:GetServerTimeNow(), flat(root.Position)
	for _, hazard in ipairs(hazards) do
		if hazard.kind == "volley" and hazard.expiresAt >= now and hazard.impactAt <= now + 1.6
			and bot.hazardDepth(hazard, position) > 0 then
			bot.volleyHoldUntil = math.max(bot.volleyHoldUntil or 0, hazard.expiresAt)
		end
	end
	if (bot.volleyHoldUntil or 0) < now then bot.volleyHoldUntil = nil end
end

function bot.canHoldAfterVolley(candidate, mechanic, urgent, retreating)
	return bot.volleyHoldUntil ~= nil and not candidate and not revive.prompt and not mechanic
		and not urgent and not retreating and not bot.dashActive()
end

bot.attackStates = setmetatable({}, {__mode = "k"})
function bot.attackStateChanged()
	local dirty = false
	for _, threat in ipairs(threats) do
		local model = threat.model
		local state, kind, creature = model:GetAttribute("AIState"), model:GetAttribute("AttackKind"), model:GetAttribute("CreatureId")
		local mech, mechStart, mechImpact
		if creature == "phobetor" then
			mech, mechStart, mechImpact = model:GetAttribute("MechKind"), model:GetAttribute("MechStart"), model:GetAttribute("MechImpact")
		end
		local previous = bot.attackStates[model]
		if not previous or previous.state ~= state or previous.kind ~= kind or previous.creature ~= creature
			or previous.mech ~= mech or previous.mechStart ~= mechStart or previous.mechImpact ~= mechImpact then
			bot.attackStates[model] = {state = state, kind = kind, creature = creature, mech = mech, mechStart = mechStart, mechImpact = mechImpact}
			dirty = true
		end
	end
	return dirty
end


function bot.planMovement(urgent)
	if revive.seeking and currentObjective and currentObjective.kind == "Revive" then
		local ring = bot.ringConstrained and bot.ringSafeRegion
		if ring then
			local delta = currentObjective.position - ring.center
			local radius = math.max(0, ring.radius - policy.hazardMargin - 0.5)
			if delta.Magnitude > radius and delta.Magnitude > 0.01 then
				local edge = ring.center + delta.Unit * radius
				return Vector3.new(edge.X, root.Position.Y, edge.Z)
			end
		end
		local point = navigationTarget(currentObjective)
		return point and Vector3.new(point.X, root.Position.Y, point.Z) or nil
	end
	if #threats == 0 and not currentObjective and #hazards == 0 and not bot.ringConstrained then
		local center = select(1, getArena())
		local point = Vector3.new(center.X, root.Position.Y, center.Z)
		if flat(root.Position - point).Magnitude <= 2 then return nil end
		if hasFloor(point) and directTravel(root.Position, point) then return point end
	end
	return chooseEscapeTarget(urgent, currentObjective)
end

function bot.recordPlan(started, nowClock)
	local duration = (os.clock() - started) * 1000
	bot.planningMs, bot.nextUrgentPlan = duration, nowClock + 0.05
	bot.planWindowCount = (bot.planWindowCount or 0) + 1
	bot.planWindowMaxMs = math.max(bot.planWindowMaxMs or 0, duration)
end


function bot.publishState()
	local now = os.clock()
	if now < (bot.nextTraceAt or 0) then return end
	bot.nextTraceAt = now + 0.1
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then return end
	local trace = gui:FindFirstChild("AutoBotDashTraceV14")
	if not trace then trace = Instance.new("Folder"); trace.Name = "AutoBotDashTraceV14"; trace.Parent = gui end
	local candidate = revive.selected
	local values = {time = workspace:GetServerTimeNow(), mode = bot.mode or "idle",
		reviveReason = revive.phase or "idle", reviveInput = revive.method or "none",
		reviveLocalHold = revive.localHold == true, walkSpeed = bot.walkSpeed(), tpwalkExtra = bot.movementExtra or 0,
		reviveTarget = candidate and candidate.character.Name or "none",
		reviveEnabled = candidate and candidate.prompt.Enabled or false,
		dashReason = bot.dash.reason or "none", attemptCount = bot.dash.attemptCount or 0,
		objective = currentObjective and currentObjective.kind or "none",
		dashDistance = bot.dashDistance(), abilityReason = bot.ability.reason or "none",
		dashPathReason = bot.dash.pathReason or "none", leapReason = bot.leapReason or "none",
		mobUrgent = bot.mobUrgent == true, hazardUrgent = bot.hazardUrgent == true,
		breathRetreat = bot.breathRetreat == true, breathCount = #(bot.breaths or {}),
		lionRetreat = bot.lionRetreat == true, lionCount = #(bot.lionZones or {}),
		lionAttack = bot.lionZones and bot.lionZones[1] and bot.lionZones[1].kind or "none",
		attackRetreat = bot.attackRetreat == true, attackCount = #(bot.attackZones or {}),
		attackUnknown = bot.unknownAttackCount or 0, phobetorComboCount = bot.phobetorComboCount or 0,
		bowHeld = bot.bow.held == true, bowMode = bot.bow.mode or "none", bowReason = bot.bow.reason or "none",
		inputFocused = bot.ability.focused == true, textFocused = UserInputService:GetFocusedTextBox() ~= nil,
		bowHold = bot.bow.held and math.max(0, now - bot.bow.pressedAt) or 0,
		bowLastHold = bot.bow.lastHold or 0, bowProgress = bot.bow.observed or -1,
		volleyHoldUntil = bot.volleyHoldUntil or 0,
		frameMaxMs = bot.frameMaxMs or 0, planningMs = bot.planningMs or 0,
		planWindowCount = bot.planWindowCount or 0, planWindowMaxMs = bot.planWindowMaxMs or 0,
		planCandidates = bot.lastPlanCandidates or 0, planThreats = bot.lastPlanThreats or 0,
		stablePlanKeeps = bot.stablePlanKeeps or 0, walkSmoothApplied = bot.walkSmoothApplied or 0,
		walkSmoothReason = bot.walkSmoothReason or "idle", walkReversals = bot.walkReversals or 0,
		sensingMs = bot.sensingMs or 0, classificationMs = bot.classificationMs or 0,
		attackKind = bot.attackZones and bot.attackZones[1] and bot.attackZones[1].kind or "none",
		bossKind = bot.bossIntent and bot.bossIntent.kind or "none",
		bossImpact = bot.bossIntent and bot.bossIntent.when or 0,
		bossRadius = bot.bossIntent and bot.bossIntent.radius or 0}
	for key, value in pairs(values) do trace:SetAttribute(key, value) end
	local center = bot.bossIntent and bot.bossIntent.center
	trace:SetAttribute("bossCenterX", center and center.X or nil)
	trace:SetAttribute("bossCenterZ", center and center.Z or nil)
	trace:SetAttribute("reviveProgress", candidate and candidate.character:GetAttribute("ReviveProgress") or nil)
	trace:SetAttribute("reviveReviver", candidate and candidate.character:GetAttribute("ReviverUserId") or nil)
	trace:SetAttribute("reviveDistance", candidate and (candidate.position - root.Position).Magnitude or nil)
	bot.frameMaxMs = 0
	bot.planWindowCount, bot.planWindowMaxMs = 0, 0
	bot.stablePlanKeeps, bot.walkSmoothApplied, bot.walkReversals = 0, 0, 0
end

-- Freecam controls are separate from the humanoid: I/J/K/L move, U/O go up/down, hold right mouse to look.
bot.freecam = {active = false, looking = false, speed = 34}
function bot.restoreFreecamAim()
	local free = bot.freecam
	if free.aimMouseBehavior ~= nil then
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = free.aimMouseBehavior
		end
		free.aimMouseBehavior = nil
	end
end
function bot.stopFreecam(relinquish)
	bot.restoreFreecamAim()
	local free = bot.freecam
	if not free.active then return end
	if free.looking and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
		UserInputService.MouseBehavior = free.mouseBehavior or Enum.MouseBehavior.Default
	end
	free.looking = false
	if not relinquish and free.camera and free.camera == workspace.CurrentCamera
		and free.camera.CameraType == Enum.CameraType.Scriptable then
		free.camera.CameraType = free.cameraType or Enum.CameraType.Custom
		if free.subject and free.subject.Parent then free.camera.CameraSubject = free.subject end
	end
	if not controls.cursor and UserInputService.MouseBehavior == Enum.MouseBehavior.Default and free.cameraMouseBehavior then
		UserInputService.MouseBehavior = free.cameraMouseBehavior
	end
	free.active, free.camera, free.mouseBehavior, free.cameraMouseBehavior = false, nil, nil, nil
	if not relinquish then bot.ensureCameraFollow() end
end
function bot.updateFreecam(dt)
	bot.restoreFreecamAim()
	local free, camera = bot.freecam, workspace.CurrentCamera
	local current = player.Character
	local gameCamera = player:GetAttribute("Cinematic") == true or player:GetAttribute("Spectating") == true
		or current and current:GetAttribute("Cinematic") == true
	if not controls.freecam or not camera or gameCamera then bot.stopFreecam(gameCamera); return end
	if free.active and free.camera ~= camera then bot.stopFreecam(true) end
	if not free.active then
		restoreCamera()
		-- Leave an unrelated scriptable camera alone.
		if camera.CameraType == Enum.CameraType.Scriptable then return end
		local x, y = camera.CFrame:ToOrientation()
		free.camera, free.cameraType, free.subject = camera, camera.CameraType, camera.CameraSubject
		free.cameraMouseBehavior = UserInputService.MouseBehavior
		if not controls.cursor then UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
		free.position, free.pitch, free.yaw = camera.CFrame.Position, x, y
		free.active = true
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable and camera.CameraType ~= free.cameraType then
		bot.stopFreecam(true); return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local focused = UserInputService:GetFocusedTextBox() ~= nil
	local looking = not focused and not controls.cursor and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	if looking and not free.looking then
		free.mouseBehavior = UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif not looking and free.looking and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition then
		UserInputService.MouseBehavior = free.mouseBehavior or Enum.MouseBehavior.Default
	end
	free.looking = looking
	if looking then
		local delta = UserInputService:GetMouseDelta()
		free.yaw -= delta.X * 0.003
		free.pitch = math.clamp(free.pitch - delta.Y * 0.003, -1.5, 1.5)
	end
	local rotation = CFrame.fromOrientation(free.pitch, free.yaw, 0)
	if not focused and not controls.cursor then
		local function key(code) return UserInputService:IsKeyDown(code) and 1 or 0 end
		local forward = key(Enum.KeyCode.I) - key(Enum.KeyCode.K)
		local right = key(Enum.KeyCode.L) - key(Enum.KeyCode.J)
		local up = key(Enum.KeyCode.U) - key(Enum.KeyCode.O)
		local movement = rotation.LookVector * forward + rotation.RightVector * right + Vector3.yAxis * up
		if movement.Magnitude > 1 then movement = movement.Unit end
		free.position += movement * free.speed * math.clamp(dt, 0, 0.1)
	end
	camera.CFrame = CFrame.new(free.position) * rotation
end
RunService:BindToRenderStep("AutoBotFreecam", Enum.RenderPriority.Camera.Value + 3, bot.updateFreecam)


local cursorBefore
onControlChanged(function(name, enabled)
	if name == "attack" and not enabled then
		attackModel, attackRoot = nil, nil
		if not bot.releaseBow("disabled") then
			local tool = character and character:FindFirstChildWhichIsA("Tool")
			if tool then pcall(function() tool:Deactivate() end) end
		end
		if not revive.arrived and not revive.prompt then restoreCamera() end
	elseif name == "revive" and not enabled then
		if revive.prompt or revive.locked then endRevive(false, "disabled") end
		revive.selected, revive.locked, revive.arrived, revive.seeking = nil, nil, false, false
		elapsed = updateInterval
	elseif name == "dash" and not enabled then
		bot.releaseDashKey()
		bot.dash.prepareUntil, bot.dash.chainUntil = nil, 0
	elseif name == "ability" and not enabled then
		bot.releaseAbility()
	elseif name == "movement" then
		elapsed = updateInterval
		if not enabled then
			bot.releaseDashKey()
			bot.dash.prepareUntil, bot.dash.chainUntil, bot.bossIntent = nil, 0, nil
			bot.setDestination(nil)
			if humanoid then pcall(function() humanoid:Move(Vector3.zero, false) end) end
			if orientation then orientation.Enabled = false end
			if humanoid and originalAutoRotate ~= nil then humanoid.AutoRotate = originalAutoRotate end
		end
	elseif name == "freecam" and not enabled then
		bot.stopFreecam(false)
	elseif name == "cursor" then
		if enabled then
			if not bot.releaseBow("cursor") then
				local tool = character and character:FindFirstChildWhichIsA("Tool")
				if tool then pcall(function() tool:Deactivate() end) end
			end
			restoreCamera()
			cursorBefore = {behavior = UserInputService.MouseBehavior, visible = UserInputService.MouseIconEnabled}
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		elseif cursorBefore then
			if UserInputService.MouseBehavior == Enum.MouseBehavior.Default then UserInputService.MouseBehavior = cursorBefore.behavior end
			if UserInputService.MouseIconEnabled == true then UserInputService.MouseIconEnabled = cursorBefore.visible end
			cursorBefore = nil
		end
	end
end)

RunService.Heartbeat:Connect(function(deltaTime)
	bot.updateNightmareChoice(os.clock())
	bot.updateAutoSkip(os.clock())
	if bot.matchEnded then return end
	bot.frameMaxMs = math.max(bot.frameMaxMs or 0, deltaTime * 1000)
	local model = player.Character
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	local part = model and model:FindFirstChild("HumanoidRootPart")
	if not hum or not part or hum.Health <= 0 then
		if character then cleanup() end
		return
	end
	if model ~= character or hum ~= humanoid or part ~= root then setup(model, hum, part) end
	if not bot.canMove() then
		if revive.prompt or revive.locked then endRevive(false, "self_unavailable") end
		revive.selected, revive.arrived, revive.seeking = nil, false, false
		bot.bossIntent, currentObjective, bot.mode = nil, nil, "inactive"
		bot.setDestination(nil)
		bot.stopCombat(); bot.releaseDashKey(); bot.applyWalkInput(); restoreCamera()
		bot.publishState()
		return
	end
	elapsed += deltaTime
	local replan = elapsed >= updateInterval
	if replan then
		elapsed = 0
		local started = os.clock()
		threats, hazards = collectThreats(), collectHazards()
		bot.syncChallenge()
		bot.sensingMs = (os.clock() - started) * 1000
	end
	if bot.updateRetreat() then replan = true end
	bot.updateVolleyExposure()
	-- Ordinary enemy proximity still influences walking; only a marked hazard may request an emergency Q.
	local mobUrgent = threatImminent(flat(root.AssemblyLinearVelocity))
	local hazardUrgent = bot.imminentHazard()
	local urgent = mobUrgent or hazardUrgent
	bot.mobUrgent, bot.hazardUrgent = mobUrgent, hazardUrgent
	updateRevive()
	local candidate = controls.revive and not bot.retreat and findReviveTarget() or nil
	if bot.retreat and (revive.prompt or revive.locked) then endRevive(false, "out_of_combat") end
	-- Refresh state each frame: use the live AI state, never a fixed breath duration.
	local statesChanged = bot.attackStateChanged()
	if replan or statesChanged or not bot.breaths or not bot.lionZones or not bot.attackZones then
		local started = os.clock()
		bot.breaths = bot.collectBreaths()
		bot.lionZones = bot.collectLionZones()
		bot.attackZones = bot.collectAttackZones()
		bot.classificationMs = (os.clock() - started) * 1000
	end
	local holdAccepted = candidate and revive.prompt == candidate.prompt
		and (revive.localHold or tonumber(candidate.character:GetAttribute("ReviverUserId")) == player.UserId)
	if holdAccepted and bot.continueAcceptedRevive(candidate) then return end
	local lowReviveRetreat = false -- Global retreat already handles rescue at or below 30%.
	if candidate ~= revive.selected or bot.lowReviveRetreat ~= lowReviveRetreat then replan = true end
	bot.lowReviveRetreat = lowReviveRetreat
	revive.selected, revive.seeking = candidate, candidate ~= nil
	local objective
	if candidate then objective = bot.reviveObjective(candidate)
	elseif not lowReviveRetreat then objective = getObjective() end
	local mechanic, waitingForLock, preLeap
	if controls.movement then mechanic, waitingForLock, preLeap = bot.selectBossMechanic(candidate) end
	bot.preleapAim = nil
	if preLeap and not mechanic and controls.movement and controls.dash and not controls.cursor then
		bot.preleapAim = bot.bossEscapePoint(flat(root.Position), preLeap.radius + policy.hazardMargin)
	end
	local ringHold = mechanic and mechanic.kind == "hold" and mechanic.shape == "ring"
	local reviveInsideRing, ringRescueWait, leaveRingForRevive = false, false, false
	if ringHold and candidate and objective and objective.kind == "Revive" then
		local safeRadius = math.max(0, mechanic.radius - policy.hazardMargin - 0.5)
		reviveInsideRing = (objective.position - mechanic.center).Magnitude <= safeRadius + objective.radius
		if not reviveInsideRing then
			ringRescueWait = bot.mechanicBeforeRevive(mechanic, candidate)
			leaveRingForRevive = not ringRescueWait
		end
	end
	local safetyFirst = controls.movement and not ringHold and bot.mechanicBeforeRevive(mechanic, candidate)
	local breathRetreat = not holdAccepted and not revive.prompt and #bot.breaths > 0
		and (bot.inBreathDanger(flat(root.Position), bot.breaths)
			or candidate and bot.inBreathDanger(flat(candidate.position), bot.breaths))
	if bot.breathRetreat ~= breathRetreat then replan = true end
	bot.breathRetreat = breathRetreat
	local lionRetreat = not holdAccepted and not revive.prompt and #bot.lionZones > 0
		and (bot.inBreathDanger(flat(root.Position), bot.lionZones)
			or candidate and bot.inBreathDanger(flat(candidate.position), bot.lionZones))
	if bot.lionRetreat ~= lionRetreat then replan = true end
	bot.lionRetreat = lionRetreat
	-- Normal enemies do not interrupt or divert a selected player rescue.
	local attackRetreat = not candidate and not holdAccepted and not revive.prompt and #bot.attackZones > 0
		and bot.inAttackZone(flat(root.Position), bot.attackZones)
	local phobetorComboDanger = false
	if attackRetreat and (bot.phobetorComboCount or 0) > 0 then
		for _, zone in ipairs(bot.attackZones) do
			if zone.estimated and zone.creature == "phobetor" and bot.attackZoneDepth(zone, flat(root.Position)) > 0 then
				phobetorComboDanger = true; break
			end
		end
	end
	local oldRing, oldConstrained = bot.ringSafeRegion, bot.ringConstrained
	bot.ringSafeRegion = ringHold and mechanic or nil
	-- An immediate independent danger may require leaving the ring.
	bot.ringConstrained = ringHold and not leaveRingForRevive
		and not (hazardUrgent or breathRetreat or lionRetreat or attackRetreat) or false
	if oldConstrained ~= bot.ringConstrained or bot.ringConstrained and (not oldRing
		or (oldRing.center - mechanic.center).Magnitude > 0.5 or math.abs(oldRing.radius - mechanic.radius) > 0.1) then replan = true end
	if breathRetreat or lionRetreat or attackRetreat or hazardUrgent then bot.preleapAim = nil end
	if bot.attackRetreat ~= attackRetreat then replan = true end
	bot.attackRetreat = attackRetreat
	local holdingVolley = bot.canHoldAfterVolley(candidate, mechanic, urgent, breathRetreat or lionRetreat or attackRetreat)
	local nowClock = os.clock()
	local urgentPlan = urgent and nowClock >= (bot.nextUrgentPlan or 0)
	if holdingVolley ~= bot.holdingVolley then replan = true end
	bot.holdingVolley = holdingVolley
	if not controls.movement then
		bot.bossIntent, currentObjective, bot.mode = nil, objective, "manual_movement"
		bot.setDestination(nil)
		bot.stepRevive(candidate)
	elseif safetyFirst then
		if revive.prompt then endRevive(true, "mechanic_pause") end
		revive.arrived = false
		revive.phase = candidate and "mechanic_pause" or "idle"
		bot.bossIntent, currentObjective, bot.mode = mechanic, nil, "boss_" .. mechanic.kind
		bot.setDestination(mechanic.kind ~= "hold" and mechanic.position or nil)
	elseif breathRetreat or lionRetreat or attackRetreat then
		if bot.bossIntent then replan = true end
		bot.bossIntent, currentObjective, bot.mode = nil, nil,
			breathRetreat and "breath_retreat" or lionRetreat and "lion_retreat" or "attack_retreat"
		revive.arrived = false
		if replan or urgentPlan then
			local started = os.clock()
			bot.setDestination(chooseEscapeTarget(true, nil))
			bot.recordPlan(started, nowClock)
		end
	elseif waitingForLock and bot.preleapAim then
		if revive.prompt then endRevive(true, "leap_prepare") end
		revive.arrived = false
		bot.bossIntent, currentObjective, bot.mode = nil, nil, "leap_prepare"
		bot.setDestination(nil)
	elseif ringRescueWait then
		-- Cannot finish this outside rescue and return before the ring; keep the selected target.
		bot.bossIntent, currentObjective, bot.mode = mechanic, objective, "revive_wait_ring"
		revive.phase = "waiting_for_ring"
		bot.setDestination(nil)
	elseif holdingVolley then
		bot.bossIntent, currentObjective, bot.mode = nil, nil, "volley_hold"
		bot.setDestination(nil)
	else
		if bot.bossIntent then replan = true end
		bot.bossIntent, currentObjective = nil, objective
		if bot.stepRevive(candidate) then
			bot.mode = "revive_hold"
		else
			bot.mode = lowReviveRetreat and "low_health_survival" or candidate and "revive_approach" or objective and "objective" or "combat"
			if lowReviveRetreat then revive.phase = "low_health" end
			if replan or urgentPlan then
				local started = os.clock()
				bot.setDestination(bot.planMovement(urgent))
				bot.recordPlan(started, nowClock)
			end
		end
	end
	if ringHold and not bot.bossIntent then bot.bossIntent = mechanic end
	bot.movementEmergency = hazardUrgent or breathRetreat or lionRetreat or attackRetreat or safetyFirst
		or waitingForLock or (mechanic and mechanic.kind ~= "hold") or false
	if not currentObjective and route.key then invalidateRoute() end
	if bot.combatPaused() then bot.stopCombat()
	elseif controls.attack then updateAttackTarget()
	else attackModel, attackRoot = nil, nil end
	bot.applyWalkInput()
	if bot.bossIntent and bot.bossIntent.kind ~= "hold" then bot.mechanicDash(bot.bossIntent)
	elseif not waitingForLock then bot.updateDash(hazardUrgent or phobetorComboDanger) end
	if bot.combatPaused() then bot.stopCombat() end
	applyExtraMovement(deltaTime)
	bot.updateAbility()
	bot.publishState()
end)

-- One movement writer, applied after the game's input and again before physics.
RunService:BindToRenderStep("AutoBotWalkV7", Enum.RenderPriority.Last.Value + 1, bot.applyWalkInput)
RunService.PreSimulation:Connect(bot.applyWalkInput)


RunService:BindToRenderStep(
	"EscapeArcherAim",
	Enum.RenderPriority.Camera.Value - 1,
	function()
		local revivePosition = revive.arrived and revive.selected and promptPosition(revive.selected.prompt)
		if controls.cursor then
			bot.releaseBow("cursor")
			restoreCamera()
			if player:GetAttribute("Cinematic") ~= true and player:GetAttribute("Spectating") ~= true
				and not (character and character:GetAttribute("Cinematic") == true) then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end
			return
		end
		if (not controls.attack and not revivePosition) or (bot.combatPaused() and not revivePosition)
			or not root or not humanoid or humanoid.Health <= 0
			or not character or character:GetAttribute("Downed") == true or player:GetAttribute("CombatState") == "Downed" then
			bot.releaseBow(not controls.attack and "disabled" or "combat_paused")
			restoreCamera()
			return
		end

		if not revivePosition and (not attackModel or not attackRoot) then
			bot.releaseBow("target_missing")
			restoreCamera()
			return
		end
		if not revivePosition and not hasLineOfSight(attackModel, attackRoot) then
			bot.releaseBow("target_obstructed")
			restoreCamera()
			return
		end

		local camera = workspace.CurrentCamera

		if not camera then
			bot.releaseBow("camera_unavailable")
			restoreCamera()
			return
		end
		if player:GetAttribute("Cinematic") == true or character:GetAttribute("Cinematic") == true
			or player:GetAttribute("Spectating") == true then
			bot.releaseBow("cinematic")
			restoreCamera(true)
			return
		end

		local detached = controls.freecam and bot.freecam.active and bot.freecam.camera == camera
		if detached then
			-- Aim before the game combat update; restore the detached view before rendering.
		elseif activeCamera ~= camera then
			restoreCamera()
			-- A scriptable camera already controlled by the game must not be taken over.
			if camera.CameraType == Enum.CameraType.Scriptable then bot.releaseBow("camera_owned"); return end
			activeCamera = camera
			originalCameraType = camera.CameraType
			originalMouseBehavior = UserInputService.MouseBehavior
		elseif camera.CameraType ~= Enum.CameraType.Scriptable then
			-- Another camera controller took control after our previous frame.
			bot.releaseBow("camera_owned")
			restoreCamera(true)
			return
		end

		if detached and bot.freecam.aimMouseBehavior == nil then
			bot.freecam.aimMouseBehavior = UserInputService.MouseBehavior
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		camera.CameraType = Enum.CameraType.Scriptable

		local aimPosition = revivePosition or getAimPosition(attackModel, attackRoot)
		local cameraPosition = getCameraPosition(aimPosition)

		if (aimPosition - cameraPosition).Magnitude < 0.01 then
			bot.releaseBow("invalid_aim")
			return
		end

		camera.CFrame = CFrame.lookAt(cameraPosition, aimPosition)

		if revivePosition then bot.releaseBow("revive"); return end
		if bot.combatPaused() then bot.releaseBow("combat_paused"); return end
		bot.updateBow(os.clock(), character:FindFirstChildWhichIsA("Tool"))
	end
)

end)

task.spawn(function()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local boonPick = remotes:WaitForChild("BoonPick")

local connected = {}
local offerNumber = 0
local pending

local function getFirstBoonId(payload)
	local options = payload.boons
		or payload.choices
		or payload.options
		or payload.offer
		or payload.ids

	if type(options) ~= "table" then
		return nil
	end

	for _, option in ipairs(options) do
		local id

		if type(option) == "string" then
			id = option
		elseif type(option) == "table" then
			id = option.id or option.boonId
		end

		if type(id) == "string" and id ~= "" and #id <= 64 then
			return id
		end
	end

	return nil
end

local function belongsToPlayer(payload)
	local userId = tonumber(payload.userId)
	return userId == nil or userId == player.UserId
end

local function scheduleOffer(offer)
	if not offer or offer.scheduled or offer.sent or offer.confirmed or not controls.boon then return end
	offer.scheduled = true
	task.spawn(function()
		task.wait(0.4)
		while pending == offer and controls.boon and player:GetAttribute("CombatState") == "Downed" do
			if offer.endsAt and workspace:GetServerTimeNow() >= offer.endsAt then break end
			task.wait(0.2)
		end
		offer.scheduled = false
		if pending ~= offer or not controls.boon or offer.confirmed or offer.sent
			or player:GetAttribute("CombatState") == "Downed" then return end
		if offer.endsAt and workspace:GetServerTimeNow() >= offer.endsAt then return end
		if not boonPick:IsA("RemoteEvent") then return end
		offer.sent = true
		boonPick:FireServer(offer.id)
	end)
end

onControlChanged(function(name, enabled)
	if name == "boon" and enabled then scheduleOffer(pending) end
end)

local function handleOffer(payload)
	if not belongsToPlayer(payload) then return end
	local id = getFirstBoonId(payload)
	if not id then return end
	offerNumber += 1
	local offer = {number = offerNumber, id = id, endsAt = tonumber(payload.endsAt), confirmed = false}
	pending = offer
	scheduleOffer(offer)
end


local function handlePicked(payload)
	if not belongsToPlayer(payload) then
		return
	end

	local id = payload.boonId or payload.id

	if pending and id == pending.id then
		pending.confirmed = true
	end
end

local function handlePayload(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.type == "boonOffer" then
		handleOffer(payload)
	elseif payload.type == "boonPicked" then
		handlePicked(payload)
	elseif payload.type == "matchEnd"
		or payload.type == "matchStart"
		or payload.type == "entryCinematic" then

		pending = nil
	end
end

local function connectRemote(instance)
	if connected[instance] then
		return
	end

	if not instance:IsA("RemoteEvent")
		and not instance:IsA("UnreliableRemoteEvent") then

		return
	end

	connected[instance] = instance.OnClientEvent:Connect(function(...)
		local arguments = table.pack(...)

		for i = 1, arguments.n do
			handlePayload(arguments[i])
		end
	end)
end

remotes.DescendantAdded:Connect(connectRemote)

for _, instance in ipairs(remotes:GetDescendants()) do
	connectRemote(instance)
end


end)


