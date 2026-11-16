
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
if not player then warn("[RankedSurvey] LocalPlayer unavailable"); return end
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("RankedSurvey")
if old then old:Destroy() end
local create = function(class, properties, parent)
    local instance = Instance.new(class)
    for key, value in pairs(properties) do instance[key] = value end
    instance.Parent = parent
    return instance
end
local screen = create("ScreenGui", {Name="RankedSurvey", ResetOnSpawn=false, DisplayOrder=1200}, playerGui)
local panel = create("Frame", {Name="Panel", Size=UDim2.fromOffset(285,82), Position=UDim2.fromOffset(15,120), BackgroundColor3=Color3.fromRGB(28,28,28)}, screen)
local label = create("TextLabel", {Size=UDim2.new(1,-12,0,30), Position=UDim2.fromOffset(6,4), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), Font=Enum.Font.SourceSans, TextSize=15, Text="Ranked survey: recording"}, panel)
local copyButton = create("TextButton", {Size=UDim2.fromOffset(125,31), Position=UDim2.fromOffset(6,43), BackgroundColor3=Color3.fromRGB(55,55,55), TextColor3=Color3.new(1,1,1), Text="Copy current", Font=Enum.Font.SourceSans, TextSize=15}, panel)
local stopButton = create("TextButton", {Size=UDim2.fromOffset(137,31), Position=UDim2.fromOffset(140,43), BackgroundColor3=Color3.fromRGB(55,55,55), TextColor3=Color3.new(1,1,1), Text="Stop + copy", Font=Enum.Font.SourceSans, TextSize=15}, panel)
local started = os.clock()
local state = {recording=true, samples={}, events={}, map=nil, mapStatus="waiting", nextSample=0, nextMap=0, nextAutoCopy=12, sawRanked=false, sawLive=false, lastPhase=nil, lastCopy="none"}
local MAX_EVENTS=6000
local connections = {}
local function connect(signal, fn) local c=signal:Connect(fn); table.insert(connections,c); return c end
local function scalar(value)
    local kind=typeof(value)
    if kind=="string" or kind=="boolean" then return value end
    if kind=="number" and value==value and value~=math.huge and value~=-math.huge then return math.floor(value*100+0.5)/100 end
    return nil
end
local function vec(v)
    if typeof(v)~="Vector3" then return nil end
    return {x=scalar(v.X),y=scalar(v.Y),z=scalar(v.Z)}
end
local function attrs(object, names)
    local result={}
    if not object then return result end
    for _,name in ipairs(names) do local value=scalar(object:GetAttribute(name)); if value~=nil then result[name]=value end end
    return result
end
local gameKeys={"PvpMode","PvpPhase","PvpMap","PvpLockAt","PvpEndsAt","PvpReadyT1","PvpReadyT2","PvpScoreT1","PvpScoreT2","PvpTarget","ServerMode","MatchId"}
local playerKeys={"Zone","CombatState","PvpMode","PvpTeam","PvpKit","Kit","WeaponId","AbilityEquipped","AbilityReadyAt","Spectating","Cinematic","PvpRespawnAt","SpawnShield"}
local charKeys={"Downed","Move","MoveAt","MoveDuration","Blocking","Charging","ChargeRate","Cinematic","Dashing","DashAt","AttackAt","V2State","V2StateEnd","PvpRespawnAt","SpawnShield"}
local botKeys={"reason","detail","mode","phase","distance","targetId","ability","dashReason","abilityReason","attackAttempts","dashAttempts","abilityAttempts","tpwalkExtra","teleport","roundLocked","roundReason","stunned","arrowEta","arrowCount","arrowMoveId","arrowEvading","arrowEvadeAttempts","foeCharging","chargeThreat","dashEstimate","foeFastEscape","foeDashing","zigSide","lancerThreat","lancerThreatFront","lancerThreatSide","foeKit","desiredGap","dashThrustAttempts","blightActive","blightSource","blightGap","stormActive","stormSource","stormGap","attackReason","attackRange","attackFacing","jumpAttempts","jumpReason","navJumpAttempts","jumpObserved","jumpUnconfirmed","blockHeld","blockReason","arrowGuardExtensions","guardHazardSafe","guardMeleeThreat","blockAttempts","blockObserved","blockUnconfirmed","ownReachEstimate","enemyReachEstimate","ownWeaponReach","ownWeaponReachSource","controlIntervalMs","controlStepMs","guardReleasePending","parryReason","parryPredictions","parryAttempts","parryConfirmed","parryNext","parryDueIn","parryEdgeSamples","parryHitSamples","riposteActive","reachGapState","reachDashLanding","lastDashReason","reachDashAttempts","evadeDashAttempts","closeDashAttempts","blightReady","blightBait","blightStuck","dashObserved","dashUnconfirmed","mapReady","mapRadius","mapKind","navStatus","orcusMode","orcusEntryAttempts","orcusExitAttempts","orcusConfirmed","orcusUnconfirmed","orcusRadius","orcusPredicted","orcusAreaBonus","orcusAreaSource","statsSource","estimatedDashDistance","estimatedDashCooldown","statAttackCooldown","statWeapon"}
local function playerSample(p)
    local char=p.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    return {self=p==player,id=p.UserId, player=attrs(p,playerKeys),character=attrs(char,charKeys),
        position=root and vec(root.Position),velocity=root and vec(root.AssemblyLinearVelocity),
        facing=root and vec(root.CFrame.LookVector),health=hum and scalar(hum.Health),
        maxHealth=hum and scalar(hum.MaxHealth),walkSpeed=hum and scalar(hum.WalkSpeed),
        floor=hum and tostring(hum.FloorMaterial),dashPredict=root and root:FindFirstChild("DashPredict")~=nil}
end
local function sample()
    local list={}
    for _,p in ipairs(Players:GetPlayers()) do
        local mode=p:GetAttribute("PvpMode")
        if p==player or mode=="Ranked" or (p:GetAttribute("PvpTeam") and player:GetAttribute("PvpTeam")) then table.insert(list,playerSample(p)) end
    end
    local gs=ReplicatedStorage:FindFirstChild("GameState")
    local bot=playerGui:FindFirstChild("RankedGladiator") or playerGui:FindFirstChild("RankedArcher") or playerGui:FindFirstChild("RankedLancer") or playerGui:FindFirstChild("RankedBerserker")
    local trace=bot and bot:FindFirstChild("Trace")
    return {t=scalar(os.clock()-started),serverTime=scalar(workspace:GetServerTimeNow()),game=attrs(gs,gameKeys),bot=attrs(trace,botKeys),players=list}
end
local function mapSnapshot()
    local arena=workspace:FindFirstChild("Arena")
    local pvp=arena and arena:GetAttribute("ArenaKind")=="Pvp"
    local core=arena and arena:FindFirstChild("Core")
    local floor=core and core:FindFirstChild("Floor")
    local rawA,rawB=arena and arena:GetAttribute("EllipseA"),arena and arena:GetAttribute("EllipseB")
    local a,b=tonumber(rawA),tonumber(rawB)
    local survival=not pvp and floor and floor:IsA("BasePart") and a and b and a>0 and b>0
    local known=pvp or survival
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local origin=root and root.Position
    local gs=ReplicatedStorage:FindFirstChild("GameState")
    -- An Arena from loading or the previous place can exist before the
    -- current map is ready. Capture only after Ranked combat is live.
    if not origin or not gs or gs:GetAttribute("PvpMode")~="Ranked"
        or (gs:GetAttribute("PvpPhase")~="Live" and gs:GetAttribute("PvpPhase")~="SuddenDeath"
            and gs:GetAttribute("PvpPhase")~="Overtime") then
        state.mapStatus="waiting for active Ranked match";return
    end
    local candidates,descendants={},known and arena:GetDescendants() or workspace:GetDescendants()
    local characters={}
    if not known then for _,p in ipairs(Players:GetPlayers()) do if p.Character then characters[#characters+1]=p.Character end end end
    local total=0
    for _,part in ipairs(descendants) do
        if part:IsA("BasePart") and part.CanCollide then
            local characterPart=false
            for _,character in ipairs(characters) do if part:IsDescendantOf(character) then characterPart=true;break end end
            local distance=origin and (part.Position-origin).Magnitude or 0
            -- A large floor may have its center outside the capture radius.
            local extent=math.min(300,part.Size.Magnitude*0.5)
            if not characterPart and (known or distance<=160+extent) then
                total=total+1
                table.insert(candidates,{part=part,distance=distance})
            end
        end
    end
    table.sort(candidates,function(a,b) return a.distance<b.distance end)
    local parts={}
    for i=1,math.min(#candidates,pvp and 220 or 300) do
        local part=candidates[i].part
        table.insert(parts,{path=part:GetFullName(),class=part.ClassName,position=vec(part.Position),size=vec(part.Size),look=vec(part.CFrame.LookVector),up=vec(part.CFrame.UpVector),collide=part.CanCollide,transparency=scalar(part.Transparency)})
    end
    local ok,cf,size=false,nil,nil
    if known then ok,cf,size=pcall(function() return arena:GetBoundingBox() end) end
    state.map={name=known and arena.Name or "nearby_workspace",
        source=pvp and "pvp_arena" or survival and "survival_arena" or "nearby_workspace",
        attributes=attrs(known and arena or gs,{"ArenaKind","PvpMap","MapId","MapName","EllipseA","EllipseB","FloorY"}),
        arenaCenter=survival and vec(arena:GetAttribute("Center")) or nil,
        origin=vec(origin),captureRadius=not known and 160 or nil,
        boundPosition=ok and vec(cf.Position) or nil,boundSize=ok and vec(size) or nil,
        collisionParts=total,capturedParts=#parts,parts=parts}
    state.mapStatus=(pvp and "captured PvP " or survival and "captured Survival " or "captured nearby ")..#parts.."/"..total.." parts"
end
local function event(label,value)
    if #state.events>=MAX_EVENTS then table.remove(state.events,1) end
    table.insert(state.events,{t=scalar(os.clock()-started),name=label,value=scalar(value)})
end
-- Higher-resolution combat evidence. These are observations, not proof that
-- a block, parry, hit, or skill was accepted by the server.
local function precise(value)
    if type(value)~="number" or value~=value or value==math.huge or value==-math.huge then return nil end
    return math.floor(value*10000+0.5)/10000
end
local function combatEvent(name,data)
    if not state.recording then return end
    if #state.events>=MAX_EVENTS then table.remove(state.events,1) end
    data=data or {};data.name=name;data.t=precise(os.clock()-started)
    local ok,server=pcall(function() return workspace:GetServerTimeNow() end)
    if ok then data.serverTime=precise(server) end
    table.insert(state.events,data)
end
local watchedPlayers,watchedCharacters,watchedHumanoids={},{},{}
local function relevant(p)
    if p==player then return true end
    local own,other=player:GetAttribute("PvpTeam"),p:GetAttribute("PvpTeam")
    return own~=nil and other~=nil and own~=other and p:GetAttribute("PvpMode")=="Ranked"
end
local function watchCharacter(p,char)
    if not char or watchedCharacters[char] then return end
    watchedCharacters[char]=true
    local keys={"Move","MoveAt","MoveDuration","Blocking","Charging","ChargeRate","Dashing","V2State","V2StateEnd","Downed"}
    for _,key in ipairs(keys) do
        connect(char:GetAttributeChangedSignal(key),function()
            if not state.recording or not relevant(p) then return end
            local root=char:FindFirstChild("HumanoidRootPart")
            combatEvent("character_attribute",{userId=p.UserId,self=p==player,key=key,value=scalar(char:GetAttribute(key)),
                move=scalar(char:GetAttribute("Move")),moveAt=precise(char:GetAttribute("MoveAt")),
                moveDuration=precise(char:GetAttribute("MoveDuration")),blocking=scalar(char:GetAttribute("Blocking")),
                position=root and vec(root.Position),facing=root and vec(root.CFrame.LookVector)})
        end)
    end
    local function watchHumanoid(hum)
        if not hum or not hum:IsA("Humanoid") or watchedHumanoids[hum] then return end
        watchedHumanoids[hum]=true
        local old=hum.Health
        connect(hum.HealthChanged,function(value)
            local previous=old;old=value
            if state.recording and relevant(p) then
                local root=char:FindFirstChild("HumanoidRootPart")
                combatEvent("health_change",{userId=p.UserId,self=p==player,health=precise(value),previous=precise(previous),
                    position=root and vec(root.Position),blocking=scalar(char:GetAttribute("Blocking")),
                    move=scalar(char:GetAttribute("Move"))})
            end
        end)
    end
    watchHumanoid(char:FindFirstChildOfClass("Humanoid"))
    connect(char.ChildAdded,function(child) if child:IsA("Humanoid") then watchHumanoid(child) end end)
end
local function watchPlayer(p)
    if watchedPlayers[p] then return end
    watchedPlayers[p]=true
    connect(p.CharacterAdded,function(char) watchCharacter(p,char) end)
    watchCharacter(p,p.Character)
    if p==player then
        for _,key in ipairs({"ParryCount","ParryLastTier"}) do
            connect(p:GetAttributeChangedSignal(key),function()
                combatEvent("parry_attribute",{userId=p.UserId,key=key,value=scalar(p:GetAttribute(key))})
            end)
        end
    end
end
for _,p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
connect(Players.PlayerAdded,watchPlayer)
local function observeInput(input,processed,down)
    local key=input.KeyCode==Enum.KeyCode.F and "F" or input.UserInputType==Enum.UserInputType.MouseButton2 and "MouseButton2" or nil
    if key then combatEvent("block_input",{key=key,down=down,processed=processed==true}) end
end
connect(UserInputService.InputBegan,function(input,processed) observeInput(input,processed,true) end)
connect(UserInputService.InputEnded,function(input,processed) observeInput(input,processed,false) end)
local function attachCombatFx(remotes)
    local fx=remotes and remotes:FindFirstChild("CombatFx")
    if fx and fx~=state.combatFx and (fx:IsA("RemoteEvent") or fx:IsA("UnreliableRemoteEvent")) then
        state.combatFx=fx
        connect(fx.OnClientEvent,function(payload)
            if not state.recording or type(payload)~="table" then return end
            if payload.t=="arrow" then
                combatEvent("arrow",{userId=scalar(payload.userId),moveId=scalar(payload.moveId),
                    origin=vec(payload.origin),direction=vec(payload.dir),speed=scalar(payload.speed),distance=scalar(payload.dist)})
            elseif payload.t=="playerHit" or payload.t=="parry" or payload.t=="v2"
                or payload.t=="blocked" or payload.t=="dodged" or payload.t=="swing" or payload.t=="hit" then
                local fields={}
                for key,value in pairs(payload) do
                    if type(key)=="string" and #key<=50 then
                        local item=type(value)=="number" and precise(value) or scalar(value)
                        if item~=nil and (type(item)~="string" or #item<=200) then fields[key]=item
                        elseif typeof(value)=="Vector3" then fields[key]=vec(value) end
                    end
                end
                combatEvent("combat_fx",{payload=fields})
            end
        end)
    end
    local ability=remotes and remotes:FindFirstChild("AbilityFx")
    if ability and ability~=state.abilityFx and (ability:IsA("RemoteEvent") or ability:IsA("UnreliableRemoteEvent")) then
        state.abilityFx=ability
        connect(ability.OnClientEvent,function(payload)
            if not state.recording or type(payload)~="table" or type(payload.id)~="string" then return end
            local points={}
            if type(payload.pts)=="table" then
                for i=1,math.min(#payload.pts,10) do local point=vec(payload.pts[i]);if point then table.insert(points,point) end end
            end
            if #state.events>=MAX_EVENTS then table.remove(state.events,1) end
            table.insert(state.events,{t=precise(os.clock()-started),name="ability_fx",ability=scalar(payload.id),phase=scalar(payload.ph),
                userId=scalar(payload.uid),origin=vec(payload.o),castTime=precise(payload.t),points=points})
        end)
    end
    if remotes and remotes~=state.watchedRemotes and remotes.ChildAdded then
        state.watchedRemotes=remotes
        connect(remotes.ChildAdded,function(child) if child.Name=="CombatFx" or child.Name=="AbilityFx" then attachCombatFx(remotes) end end)
    end
end
attachCombatFx(ReplicatedStorage:FindFirstChild("Remotes"))
if ReplicatedStorage.ChildAdded then
    connect(ReplicatedStorage.ChildAdded,function(child) if child.Name=="Remotes" then attachCombatFx(child) end end)
end
local function report()
    return HttpService:JSONEncode({version=1,placeId=game.PlaceId,elapsed=scalar(os.clock()-started),
        mapStatus=state.mapStatus,map=state.map,events=state.events,samples=state.samples})
end
local function copy(quiet)
    local ok,text=pcall(report)
    if not ok then warn("[RankedSurvey] JSON failed: "..tostring(text)); return end
    local fn=type(setclipboard)=="function" and setclipboard or type(toclipboard)=="function" and toclipboard or nil
    local copied=false
    if fn then local callOk,result=pcall(fn,text); copied=callOk and result~=false end
    if copied then
        state.lastCopy="clipboard"
        if not quiet then print("[RankedSurvey] Copied "..#text.." bytes to clipboard.") end
    else
        state.lastCopy="console"
        if not quiet then
            print("[RankedSurvey] Clipboard unavailable; JSON follows in numbered pieces.")
            local n=math.ceil(#text/6000)
            for i=1,n do print("[RankedSurvey] PART "..i.."/"..n.." "..string.sub(text,(i-1)*6000+1,i*6000)) end
        end
    end
end
local function stop()
    if not state.recording then copy(false); return end
    state.recording=false
    event("stop",true)
    copy(false)
    label.Text="Stopped: "..#state.samples.." samples | "..state.lastCopy
end
connect(copyButton.MouseButton1Click,function() copy(false) end)
connect(stopButton.MouseButton1Click,stop)
connect(screen.Destroying,function() state.recording=false; for _,c in ipairs(connections) do c:Disconnect() end end)
connect(RunService.Heartbeat,function()
    if not state.recording then return end
    local now=os.clock()-started
    if not state.map and now>=state.nextMap then
        state.nextMap=now+2
        local ok,err=pcall(mapSnapshot)
        if not ok then state.mapStatus="capture error: "..tostring(err) end
    end
    if now>=state.nextSample then
        state.nextSample=now+0.25
        local ok,row=pcall(sample)
        if ok then
            if #state.samples>=1000 then table.remove(state.samples,1) end
            table.insert(state.samples,row)
            local phase=row.game.PvpPhase
            if row.game.PvpMode=="Ranked" then
                state.sawRanked=true
                if not state.sawLive and (phase=="Live" or phase=="SuddenDeath" or phase=="Overtime") then
                    state.sawLive=true;state.nextAutoCopy=now+12
                end
            end
            if phase~=state.lastPhase then state.lastPhase=phase; event("phase",phase) end
            if state.sawRanked and phase=="Ended" then stop(); return end
        end
        label.Text="REC "..#state.samples.." | "..state.mapStatus
    end
    if now>=state.nextAutoCopy then
        state.nextAutoCopy=now+12
        if state.sawLive then copy(true) end
    end
    if now>=300 then stop() end
end)
print("[RankedSurvey] Recording. Start during Ranked warmup. Use Stop + copy after the match; JSON is copied every 12 seconds if available.")
