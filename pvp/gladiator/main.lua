loadstring(game:HttpGet("https://raw.githubusercontent.com/krissisis898-dev/Roblox-/refs/heads/main/Roblox%20Anti%20AFK-Script%20(updatet)", true))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
if not player then warn("[RankedGladiator] LocalPlayer unavailable"); return end
local gui = player:WaitForChild("PlayerGui")
local tpwalkTest=gui:FindFirstChild("GloryBoundTPWalkStop")
if tpwalkTest and tpwalkTest:IsA("BindableEvent") then pcall(function() tpwalkTest:Fire() end) end
-- Avoid two generations issuing conflicting controls in the same server.
for _,name in ipairs({"RankedGladiator","RankedLancer","RankedArcher","RankedBerserker"}) do
    local old=gui:FindFirstChild(name)
    if old then
        local stop = old:FindFirstChild("Shutdown")
        if stop and stop:IsA("BindableEvent") then stop:Fire() end
        old:Destroy()
    end
end
local function new(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local screen = new("ScreenGui", {Name="RankedGladiator", ResetOnSpawn=false, DisplayOrder=1000}, gui)
local shutdown = new("BindableEvent", {Name="Shutdown"}, screen)
local panel = new("Frame", {Size=UDim2.fromOffset(260,82), Position=UDim2.fromOffset(18,190), BackgroundColor3=Color3.fromRGB(30,30,30)}, screen)
local label = new("TextLabel", {Size=UDim2.new(1,-12,0,38), Position=UDim2.fromOffset(6,3), BackgroundTransparency=1, TextColor3=Color3.new(1,1,1), TextWrapped=true, Font=Enum.Font.SourceSans, TextSize=14, Text="Ranked Gladiator: starting"}, panel)
local stopButton = new("TextButton", {Size=UDim2.new(1,-12,0,28), Position=UDim2.fromOffset(6,46), BackgroundColor3=Color3.fromRGB(65,45,45), TextColor3=Color3.new(1,1,1), Font=Enum.Font.SourceSans, TextSize=15, Text="STOP (F8)"}, panel)
local trace = new("Folder", {Name="Trace"}, screen)
local state = {active=true, focused=true, reason="starting", move=Vector3.zero, side=1, zigSide=1, arrows={}, dashHistory={},
    lastAttack=-math.huge,lastDash=-math.huge,lastAbility=-math.huge,lastJump=-math.huge,
    lastReady=-math.huge,lastRetry=-math.huge,keys={},retryCount=0,
    retryMatch=nil, wasInRanked=false, queueEligible=nil}
-- Horizontal root-to-root distances are estimates, not server hitbox radii.
local MELEE_GAP=5.5
local ARCHER_GAP=4.5
-- Input threshold is an estimate, not a server hitbox. Skill-tree blessing
-- area is separate from basic-attack reach and is not applied here.
local SWORD_BASE_REACH=7
local MAX_MELEE_SLACK=2.5
-- Fallback assumes both area nodes at max rank (15% + 9%).
-- Ranked may apply different server balance; this is an estimate, not a hit guarantee.
local ASSUMED_SKILL_ABILITY_AREA=0.24
-- Timing lead is an estimate, not measured server latency.
local PARRY_INPUT_LEAD=0.16
local PARRY_SAMPLE_MIN=2
-- Heartbeat is frame-bound: this is a minimum interval, not a 100 Hz promise.
local CONTROL_INTERVAL=0.01
-- The game's block controller imposes a 0.15 s transition interval.
local PARRY_TAP_TIME=0.16
local PARRY_REARM_TIME=0.16
local BLOCK_INPUT_MIN=0.15
-- Infinite Yield's default tpwalk adds 10 studs/s along MoveDirection.
local TPWALK_MULTIPLIER=1
local connections={}
local function connect(signal,fn) local c=signal:Connect(fn); table.insert(connections,c); return c end
local virtual,legacy
pcall(function() virtual=UserInputService:CreateVirtualInput() end)
pcall(function() legacy=game:GetService("VirtualInputManager") end)
local function sendKey(down,key)
    if virtual then local ok,result=pcall(function() return virtual:SendKey(down,key,false) end); if ok and result~=false then return true end end
    if legacy then local ok,result=pcall(function() return legacy:SendKeyEvent(down,key,false,game) end); if ok and result~=false then return true end end
    -- Some executors expose paired keypress/keyrelease functions instead.
    local code=key==Enum.KeyCode.Q and 0x51 or key==Enum.KeyCode.R and 0x52 or key==Enum.KeyCode.F and 0x46 or key==Enum.KeyCode.Space and 0x20 or nil
    if code and type(keypress)=="function" and type(keyrelease)=="function" then
        local fn=down and keypress or keyrelease
        local ok,result=pcall(fn,code)
        if ok and result~=false then return true end
    end
    return false
end
local function releaseKey(key)
    if state.keys[key] then
        sendKey(false,key)
        state.keys[key]=nil
    end
end
local function tapKey(key)
    if not state.focused or UserInputService:GetFocusedTextBox() or state.keys[key] or UserInputService:IsKeyDown(key) then return false end
    if not sendKey(true,key) then return false end
    state.keys[key]=true
    task.delay(0.06,function() releaseKey(key) end)
    return true
end
local function remote(name)
    local remotes=ReplicatedStorage:FindFirstChild("Remotes")
    local r=remotes and remotes:FindFirstChild(name)
    return r and r:IsA("RemoteEvent") and r or nil
end
local function fire(name,...)
    local r=remote(name)
    if not r then return false end
    return pcall(r.FireServer,r,...)
end
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local function observeBlight(opponent,origin,source,age)
    if not state.active or state.reason~="active" or state.roundLocked or state.target~=opponent
        or typeof(origin)~="Vector3" then return end
    local now=os.clock()
    age=math.clamp(tonumber(age) or 0,0,1)
    local old=state.blight
    if old and old.opponent==opponent and now-old.detected<1 then
        -- The FX origin is more useful than the cooldown fallback position.
        if source=="fx" then
            if old.source~="fx" then old.detected=now-age end
            old.origin=origin;old.source=source
        end
        return
    end
    state.blight={opponent=opponent,origin=origin,detected=now-age,expires=now+math.max(0,3.6-age),source=source}
    state.nextPlan=nil
end
local function observeStorm(opponent,points,source,age)
    if not state.active or state.reason~="active" or state.roundLocked or state.target~=opponent or #points==0 then return end
    local now=os.clock()
    local old=state.storm
    if old and old.opponent==opponent and now-old.detected<1 then
        if source=="fx" then old.points=points;old.source=source end
        return
    end
    state.storm={opponent=opponent,points=points,source=source,detected=now,expires=now+math.max(0,1.8-math.clamp(tonumber(age) or 0,0,1))}
    state.nextPlan=nil
end
local function teamOf(p)
    local t=p and p:GetAttribute("PvpTeam")
    if t=="T1" or t=="T2" then return t end
end
local function respawning(p,character)
    local now=workspace:GetServerTimeNow()
    local a=p and tonumber(p:GetAttribute("PvpRespawnAt")) or nil
    local b=character and tonumber(character:GetAttribute("PvpRespawnAt")) or nil
    return (a~=nil and a>now) or (b~=nil and b>now)
end
local function shielded(p,character)
    local function on(value)
        if value==true then return true end
        if type(value)=="number" then
            if value>1000000000 then return workspace:GetServerTimeNow()<value end
            return value>0
        end
        return false
    end
    return (p and on(p:GetAttribute("SpawnShield"))) or (character and on(character:GetAttribute("SpawnShield"))) or false
end
-- A small rolling timing table, populated only by this opponent's current
-- combat events. Estimated event timing includes unknown delivery latency.
local PARRY_NEXT={lance_thrust1="lance_thrust2",lance_thrust2="lance_sweep",lance_sweep="lance_thrust1",
    glad_slash1="glad_slash2",glad_slash2="glad_bash",glad_bash="glad_slash1",
    bers_cleave="bers_reaver",bers_reaver="bers_earthsplit",bers_earthsplit="bers_cleave"}
local function timingAdd(bucket,key,value)
    bucket[key]=bucket[key] or {};local list=bucket[key]
    list[#list+1]=value;if #list>8 then table.remove(list,1) end
end
local function timingMean(bucket,key)
    local list=bucket and bucket[key]
    if not list or #list<PARRY_SAMPLE_MIN then return nil end
    local sum=0;for _,value in ipairs(list) do sum=sum+value end
    return sum/#list
end
local function observeCombatMove(name,at,nowServer)
    if type(name)~="string" or not at or at~=at then return end
    local last=state.parryLastMove
    if last and at<=last.at+0.0001 then return end
    local age=nowServer-at
    if age< -0.1 or age>0.8 then return end
    if last and PARRY_NEXT[last.name]==name then
        local elapsed=at-last.at
        if elapsed>=0.15 and elapsed<=1.2 then
            state.parryEdges=state.parryEdges or {};timingAdd(state.parryEdges,last.name..">"..name,elapsed)
        end
    end
    state.parryLastMove={name=name,at=at}
end
local function observeCombatResult(payload)
    if not state.active or state.reason~="active" or state.roundLocked or type(payload)~="table" then return end
    local now=os.clock()
    local confirmed=(payload.t=="playerHit" and payload.blocked==true and (payload.parry=="good" or payload.parry=="perfect"))
        or (payload.t=="parry" and tonumber(payload.userId)==player.UserId)
        or (payload.t=="v2" and (payload.e=="parried" or payload.e=="deflect") and tonumber(payload.v)==player.UserId and not payload.arrow)
    if confirmed and now-(state.lastParryFxAt or -math.huge)>=0.2 then
        state.lastParryFxAt=now;state.parryConfirmed=(state.parryConfirmed or 0)+1
        state.riposteUntil=now+0.7;state.parryReason="confirmed"
        if state.keys[Enum.KeyCode.F] then
            local started=state.blockStartedAt or now
            releaseKey(Enum.KeyCode.F);state.blockUntil=nil;state.blockStartedAt=nil
            -- The game's own block release can be delayed by its 0.15 s
            -- toggle limit. Avoid firing an attack before it can unblock.
            state.guardAttackAt=math.max(now+0.02,started+BLOCK_INPUT_MIN+0.02)
            state.nextBlockAt=now+PARRY_REARM_TIME
        end
    end
    if payload.t~="playerHit" or typeof(payload.kb)~="Vector3" then return end
    local opponent=state.target
    local foe=opponent and opponent.Character
    local name=foe and foe:GetAttribute("Move")
    local at=foe and tonumber(foe:GetAttribute("MoveAt"))
    if type(name)~="string" or not PARRY_NEXT[name] or not at then return end
    local age=workspace:GetServerTimeNow()-at
    -- This association is heuristic: a skill may overlap a melee move.
    if age>=0.05 and age<=0.7 then
        state.parryHits=state.parryHits or {};timingAdd(state.parryHits,name,age)
    end
end
-- Arrow FX are an observation of a broadcast, not the server hitbox or a
-- guarantee that every projectile will be delivered to this client.
local function attachCombatFx(remotes)
    local fx=remotes and remotes:FindFirstChild("CombatFx")
    if fx and fx~=state.combatFx and (fx:IsA("RemoteEvent") or fx:IsA("UnreliableRemoteEvent")) then
        state.combatFx=fx
        connect(fx.OnClientEvent,function(payload)
            if not state.active or type(payload)~="table" then return end
            observeCombatResult(payload)
            if payload.t~="arrow" then return end
            local id,speed=tonumber(payload.userId),tonumber(payload.speed)
            local origin,direction=payload.origin,payload.dir
            if not id or id==player.UserId or typeof(origin)~="Vector3" or typeof(direction)~="Vector3"
                or direction.Magnitude<0.1 or not speed or speed~=speed or speed<20 or speed>500 then return end
            local shooter=Players:GetPlayerByUserId(id)
            local own,other=teamOf(player),teamOf(shooter)
            if not own or not other or own==other then return end
            local range=tonumber(payload.dist)
            if not range or range~=range or range<1 or range>1000 then range=200 end
            if #state.arrows>=24 then table.remove(state.arrows,1) end
            local receivedAt=os.clock()
            state.lastEnemyArrowAt=receivedAt
            table.insert(state.arrows,{origin=origin,direction=direction.Unit,speed=speed,at=receivedAt,
                moveId=type(payload.moveId)=="string" and payload.moveId or "unknown",
                lifetime=math.min(1.5,range/speed+0.25)})
        end)
    end
    local ability=remotes and remotes:FindFirstChild("AbilityFx")
    if ability and ability~=state.abilityFx and (ability:IsA("RemoteEvent") or ability:IsA("UnreliableRemoteEvent")) then
        state.abilityFx=ability
        connect(ability.OnClientEvent,function(payload)
            if type(payload)~="table" or (payload.id~="orcus_blight" and payload.id~="jupiter_wrath") or type(payload.ph)=="string" then return end
            if payload.id=="orcus_blight" and tonumber(payload.uid)==player.UserId then state.ownOrcusFxAt=os.clock();return end
            local opponent=state.target
            if not opponent or tonumber(payload.uid)~=opponent.UserId then return end
            local age=workspace:GetServerTimeNow()-(tonumber(payload.t) or workspace:GetServerTimeNow())
            if age< -0.2 or age>1 then return end
            if payload.id=="orcus_blight" then observeBlight(opponent,payload.o,"fx",age)
            else
                local points={}
                if type(payload.pts)=="table" then
                    for i=1,math.min(#payload.pts,10) do
                        if typeof(payload.pts[i])=="Vector3" then table.insert(points,payload.pts[i]) end
                    end
                end
                observeStorm(opponent,points,"fx",age)
            end
        end)
    end
    if remotes and remotes~=state.watchedRemotes then
        state.watchedRemotes=remotes
        connect(remotes.ChildAdded,function(child) if child.Name=="CombatFx" or child.Name=="AbilityFx" then attachCombatFx(remotes) end end)
    end
end
attachCombatFx(ReplicatedStorage:FindFirstChild("Remotes"))
connect(ReplicatedStorage.ChildAdded,function(child) if child.Name=="Remotes" then attachCombatFx(child) end end)
local function incomingArrow(root,now)
    local best
    for i=#state.arrows,1,-1 do
        local arrow=state.arrows[i]
        local age=now-arrow.at
        if age<0 or age>arrow.lifetime then table.remove(state.arrows,i)
        else
            -- Use the horizontal projection conservatively; airborne evasion is
            -- deliberately not assumed to avoid the game's hits.
            local position=arrow.origin+arrow.direction*(arrow.speed*age)
            local relative=flat(position-root.Position)
            local velocity=flat(arrow.direction*arrow.speed-root.AssemblyLinearVelocity)
            local speed2=velocity:Dot(velocity)
            if speed2>1 then
                local eta=-relative:Dot(velocity)/speed2
                if eta>=0 and eta<=0.45 then
                    local miss=(relative+velocity*eta).Magnitude
                    if miss<=5 and (not best or eta<best.eta) then
                        best={eta=eta,miss=miss,position=position,direction=arrow.direction,moveId=arrow.moveId}
                    end
                end
            end
        end
    end
    return best
end
local function projectileGap(position,arrow)
    local direction=flat(arrow.direction)
    if direction.Magnitude<0.01 then return math.huge end
    direction=direction.Unit
    local relative=flat(position-arrow.position)
    return (relative-direction*relative:Dot(direction)).Magnitude
end
local function hazardClearance(position,hazard)
    if not hazard.points then return flat(position-hazard.origin).Magnitude end
    local best=math.huge
    for _,point in ipairs(hazard.points) do best=math.min(best,flat(position-point).Magnitude) end
    return best
end
local function stunActive(character)
    local name=character and character:GetAttribute("V2State")
    if name~="stagger" and name~="guardbreak" and name~="parried" and name~="feint" then return false end
    local untilAt=tonumber(character:GetAttribute("V2StateEnd"))
    return untilAt==nil or untilAt~=untilAt or untilAt>workspace:GetServerTimeNow()
end
local function dashDirection(humanoid,root)
    local moving,facing=flat(humanoid.MoveDirection),flat(root.CFrame.LookVector)
    if facing.Magnitude<0.01 then return nil end
    facing=facing.Unit
    if moving.Magnitude<0.1 then return facing end
    moving=moving.Unit
    local right=Vector3.new(-facing.Z,0,facing.X)
    local forwardDot,sideDot=moving:Dot(facing),moving:Dot(right)
    if math.abs(sideDot)-0.001<=math.abs(forwardDot) then return forwardDot>=0 and facing or -facing end
    return sideDot>=0 and right or -right
end
-- Prefer the same client StatSheet used by CombatController when accessible.
-- Some executors cannot require game modules; retain bounded fallbacks.
local function combatStats(now)
    if now<(state.nextStatsAt or 0) then return end
    state.nextStatsAt=now+1
    if not state.clientState and now>=(state.nextClientStateAt or 0) then
        state.nextClientStateAt=now+15
        local ok,module=pcall(function()
            local ps=player:FindFirstChild("PlayerScripts")
            local folder=ps and ps:FindFirstChild("Controllers")
            local source=folder and folder:FindFirstChild("ClientState")
            return source and require(source)
        end)
        if ok and type(module)=="table" and type(module.get)=="function" then state.clientState=module end
    end
    if not state.weaponDefs and now>=(state.nextWeaponDefsAt or 0) then
        state.nextWeaponDefsAt=now+15
        local ok,defs=pcall(function()
            local shared=ReplicatedStorage:FindFirstChild("Shared")
            local folder=shared and shared:FindFirstChild("Defs")
            local module=folder and folder:FindFirstChild("Weapons")
            return module and require(module)
        end)
        if ok and type(defs)=="table" then state.weaponDefs=defs end
    end
    local view
    if state.clientState then
        local ok,result=pcall(state.clientState.get)
        if ok and type(result)=="table" then view=result end
    end
    local sheet=view and type(view.StatSheet)=="table" and view.StatSheet or nil
    local skills=view and type(view.Skills)=="table" and view.Skills or nil
    local area=sheet and tonumber(sheet.abilityArea or sheet.AbilityArea) or nil
    local source=area and "stat_sheet" or nil
    if not area and skills and (skills.WideReach~=nil or skills.VastDomain~=nil) then
        local wide=math.clamp(tonumber(skills.WideReach) or 0,0,5)
        local vast=math.clamp(tonumber(skills.VastDomain) or 0,0,3)
        area=(wide+vast)*0.03;source="skill_ranks"
    end
    state.areaBonus=math.clamp(area or ASSUMED_SKILL_ABILITY_AREA,0,0.25)
    state.areaSource=source or "assumed_max_skills"
    state.statDashDistance=math.clamp(tonumber(sheet and sheet.dashDistance) or 16,8,40)
    state.statDashCooldown=math.clamp(tonumber(sheet and sheet.dashCooldown) or 4,0.2,10)
    state.statsSource=sheet and "stat_sheet" or "pvp_fallback"
    state.statAttackCooldown=sheet and tonumber(sheet.cooldownMult) or nil
    state.statWeapon=sheet and type(sheet.weaponId)=="string" and sheet.weaponId or ""
end
local function dashCharges(now)
    while state.dashHistory[1] and now-state.dashHistory[1]>=(state.statDashCooldown or 4) do table.remove(state.dashHistory,1) end
    return math.max(0,2-#state.dashHistory)
end
local function abilityId()
    local equipped=player:GetAttribute("AbilityEquipped")
    if type(equipped)=="string" and equipped~="" then return equipped end
    local raw=player:GetAttribute("AbilityState")
    if type(raw)=="string" and raw~="" then
        local ok,data=pcall(HttpService.JSONDecode,HttpService,raw)
        if ok and type(data)=="table" and type(data.slots)=="table" then
            local slot=tonumber(data.eq) or 1
            return data.slots[slot]
        end
    end
    return nil
end
local function selectedOpponent()
    local own=teamOf(player)
    if not own then return nil,"no_team" end
    local found,count=nil,0
    for _,other in ipairs(Players:GetPlayers()) do
        if other~=player then
            local team=teamOf(other)
            local mode=other:GetAttribute("PvpMode")
            if team and team~=own and (mode==nil or mode=="" or mode=="Ranked") then
                local ch=other.Character
                local hum=ch and ch:FindFirstChildOfClass("Humanoid")
                local root=ch and ch:FindFirstChild("HumanoidRootPart")
                if ch and hum and hum.Health>0 and root and ch:GetAttribute("Downed")~=true
                    and other:GetAttribute("CombatState")=="Alive" and not respawning(other,ch) then
                    found=other; count=count+1
                end
            end
        end
    end
    if count~=1 then return nil,count==0 and "no_opponent" or "ambiguous_opponents" end
    return found,"found"
end
local rayParams=RaycastParams.new()
rayParams.FilterType=Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater=true
local function setRayFilter(own,foe)
    rayParams.FilterDescendantsInstances={own,foe}
end
-- Infer the circular barrier from this map's actual parts, not the Arena's
-- bounding box (which also contains the spawn rooms and underground limbo).
local function refreshRing(now)
    if now<(state.nextMapProbe or 0) then return state.ring end
    state.nextMapProbe=now+2
    local ok,ring=pcall(function()
        local arena=workspace:FindFirstChild("Arena")
        state.mapKind="unknown"
        if not arena then return nil end
        local core=arena:FindFirstChild("Core")
        local floor=core and core:FindFirstChild("Floor")
        local rawA,rawB=arena:GetAttribute("EllipseA"),arena:GetAttribute("EllipseB")
        local a,b=tonumber(rawA),tonumber(rawB)
        if floor and floor:IsA("BasePart") and a and b and a>0 and b>0 then
            state.mapKind="survival_arena"
            return nil
        end
        if arena:GetAttribute("PvpMap")~="RingS1" then return nil end
        local barrier=arena:FindFirstChild("Barrier")
        if not barrier then return nil end
        local points={};local sum=Vector3.zero
        for _,part in ipairs(barrier:GetChildren()) do
            if part.Name=="Ring" and part:IsA("BasePart") and part.CanCollide and typeof(part.Position)=="Vector3" then
                local point=flat(part.Position);points[#points+1]=point;sum=sum+point
            end
        end
        if #points<16 then return nil end
        local center=sum*(1/#points);local radius=0
        for _,point in ipairs(points) do radius=radius+(point-center).Magnitude end
        radius=radius/#points
        if radius<20 or radius>100 then return nil end
        for _,point in ipairs(points) do if math.abs((point-center).Magnitude-radius)>3 then return nil end end
        state.mapKind="ranked_ring"
        return {center=center,radius=radius}
    end)
    state.ring=ok and ring or nil
    return state.ring
end
local function pathClear(root,dir,length,floorDepth)
    if dir.Magnitude<0.01 then return false end
    local ok,obstacle=pcall(function() return workspace:Blockcast(CFrame.new(root.Position),Vector3.new(2.5,2,2.5),dir*length,rayParams) end)
    if not ok or obstacle then return false end
    -- While jumping after an Archer, the normal 12-stud floor probe can
    -- stop the chase in midair before it reaches the same floor.
    local probeDepth=floorDepth or (state.root==root and state.foeKit=="Archer" and state.humanoid
        and state.humanoid.FloorMaterial==Enum.Material.Air and 24 or 12)
    for i=1,math.ceil(length/4) do
        local step=math.min(length,i*4)
        local origin=root.Position+dir*step+Vector3.new(0,3,0)
        local floorOk,hit=pcall(function() return workspace:Raycast(origin,Vector3.new(0,-probeDepth,0),rayParams) end)
        if not floorOk or not hit or hit.Normal.Y<0.5 then return false end
    end
    return true
end
-- Compute a route off the combat loop. Try walking first on level terrain,
-- then a jump-capable path; use a jump route directly for elevated targets.
local function archerRoute(root,foeRoot,toward,distance,now)
    local probe=math.min(16,math.max(4,distance-2))
    local elevated=foeRoot.Position.Y-root.Position.Y>=4
    if not elevated and pathClear(root,toward,probe) then
        state.navPath=nil;state.navStatus="direct"
        return nil
    end
    local route=state.navPath
    if route and (route.foe~=foeRoot or now-route.at>3 or flat(foeRoot.Position-route.goal).Magnitude>16
        or math.abs(foeRoot.Position.Y-route.goal.Y)>6) then
        state.navPath=nil;route=nil
    end
    if not state.navPending and now>=(state.navNextAt or 0) and type(task.spawn)=="function" then
        state.navNextAt=now+0.9
        local request={foe=foeRoot,origin=root.Position,goal=foeRoot.Position,elevated=elevated}
        state.navPending=request;state.navStatus="computing"
        task.spawn(function()
            local ok,points=pcall(function()
                local service=game:GetService("PathfindingService")
                local function compute(canJump)
                    local path
                    local good,nodes=pcall(function()
                        path=service:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=canJump,WaypointSpacing=4})
                        path:ComputeAsync(request.origin,request.goal)
                        if path.Status~=Enum.PathStatus.Success then return nil end
                        return path:GetWaypoints()
                    end)
                    if path then pcall(function() path:Destroy() end) end
                    return good and nodes and #nodes>1 and nodes or nil
                end
                local nodes=compute(request.elevated)
                if not nodes and not request.elevated then nodes=compute(true) end
                return nodes
            end)
            if state.navPending~=request then return end
            state.navPending=nil
            if not state.active then return end
            if ok and points and #points>1 and flat(root.Position-request.origin).Magnitude<16
                and flat(foeRoot.Position-request.goal).Magnitude<16
                and math.abs(foeRoot.Position.Y-request.goal.Y)<6 then
                state.navPath={points=points,index=2,foe=foeRoot,goal=request.goal,at=os.clock()}
                state.navStatus="ready";state.nextPlan=nil
            else state.navStatus="unavailable" end
        end)
    end
    route=state.navPath
    if not route or route.foe~=foeRoot then return nil end
    while route.index<=#route.points do
        local point=route.points[route.index]
        local offset=flat(point.Position-root.Position)
        local jumping=point.Action==Enum.PathWaypointAction.Jump
        if jumping and offset.Magnitude<5 and route.jumpedIndex~=route.index then
            local hum=state.humanoid
            if state.reason=="active" and not state.stunned and hum and hum.FloorMaterial~=Enum.Material.Air
                and now-state.lastJump>=1.5 then
                local sent=tapKey(Enum.KeyCode.Space)
                local requested=sent or pcall(function() hum.Jump=true end)
                if requested then
                    state.lastJump=now;state.jumpAttempts=(state.jumpAttempts or 0)+1
                    state.pendingJump={at=now};state.navJumpAttempts=(state.navJumpAttempts or 0)+1
                    state.navJumpAt=now;state.navJumpReason=sent and "route_space" or "route_humanoid"
                    route.jumpedIndex=route.index;route.jumpUntil=now+0.8
                end
            end
        end
        if offset.Magnitude>=3 or jumping and route.jumpedIndex~=route.index then break end
        route.index=route.index+1
    end
    local point=route.points[route.index]
    if not point then state.navPath=nil;return nil end
    local offset=flat(point.Position-root.Position)
    if offset.Magnitude<0.1 then return Vector3.zero end
    if pathClear(root,offset.Unit,math.min(4,offset.Magnitude)) then
        state.navStatus=(route.jumpUntil or 0)>now and "jumping" or "following"
        return offset.Unit
    end
    -- Once a path-directed jump is requested, permit the next short segment
    -- only if its landing has a floor. Pathfinding supplies the jump itself.
    if (route.jumpUntil or 0)>now and offset.Magnitude<=12 and math.abs(point.Position.Y-root.Position.Y)<=12 then
        local ok,landing=pcall(function()
            return workspace:Raycast(point.Position+Vector3.new(0,4,0),Vector3.new(0,-12,0),rayParams)
        end)
        if ok and landing and landing.Normal.Y>=0.5 then state.navStatus="jumping";return offset.Unit end
    end
    state.navPath=nil;state.navStatus="blocked"
    return nil
end
local function safeHazardPath(root,dir,length,hazard)
    if not pathClear(root,dir,length) then return false end
    local margin=hazard.leave+0.5
    for i=1,math.ceil(length) do
        if hazardClearance(root.Position+dir*math.min(length,i),hazard)<margin then return false end
    end
    return true
end
local function visible(own,foe,from,to)
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude; p.FilterDescendantsInstances={own}; p.IgnoreWater=true
    local ok,hit=pcall(function() return workspace:Raycast(from,to-from,p) end)
    return ok and (not hit or hit.Instance:IsDescendantOf(foe))
end
local function bodyRadius(part)
    local size=part and part.Size
    if typeof(size)=="Vector3" and size.X>0 and size.Z>0 then
        return math.clamp(math.max(size.X,size.Z)*0.5,0.5,2)
    end
    return 1
end
local KNOWN_WEAPON_REACH={gladius_devotio=8.4,spear_luna=12.5,spear_devotio=12.8,axe_devotio=10.7}
local function weaponReach(owner)
    local id=owner and owner:GetAttribute("WeaponId")
    if type(id)~="string" or id=="" then return nil,"unknown" end
    local defs=state.weaponDefs
    local item=defs and type(defs.byId)=="table" and defs.byId[id] or nil
    local value=item and tonumber(item.range) or KNOWN_WEAPON_REACH[id]
    if value and value==value and value>=2 and value<=30 then
        return value,item and "weapon_defs" or "dump_weapon"
    end
    return nil,"unknown"
end
local function estimateSwordReach(foeRoot,closing)
    -- The weapon listing and move definitions differ. Using the larger as an
    -- input estimate is intentional; the server alone decides if it hits.
    local weapon,source=weaponReach(player)
    state.ownWeaponReach=weapon or 0;state.ownWeaponReachSource=source
    local base=math.max(SWORD_BASE_REACH,weapon or 0)
    local bodyAllowance=math.min(MAX_MELEE_SLACK,bodyRadius(foeRoot)+1)
    local motionAllowance=math.clamp((closing or 0)*0.12,0,1.5)
    return base+bodyAllowance+motionAllowance
end
local function estimateLongReach(kit,ownRoot,opponent)
    local base=kit=="Lancer" and 12.5 or kit=="Berserker" and 12 or nil
    if not base then return 0 end
    local weapon=weaponReach(opponent)
    return math.max(base,weapon or 0)+bodyRadius(ownRoot)+0.5
end
local function planMovement(root,foeRoot,foeKit,arrow,now,lancerThreat)
    local velocity=flat(foeRoot.AssemblyLinearVelocity)
    local lead=velocity*0.22
    if lead.Magnitude>6 then lead=lead.Unit*6 end
    local delta=flat(foeRoot.Position+lead-root.Position)
    local actual=flat(foeRoot.Position-root.Position)
    local distance=actual.Magnitude
    local elevated=foeKit=="Archer" and foeRoot.Position.Y-root.Position.Y>=4
    if (delta.Magnitude<0.1 or distance<0.1) and not elevated then return Vector3.zero,distance,"near" end
    local toward=delta.Magnitude>=0.1 and delta.Unit or flat(root.CFrame.LookVector)
    if toward.Magnitude<0.1 then toward=Vector3.new(1,0,0) else toward=toward.Unit end
    local side=Vector3.new(-toward.Z,0,toward.X)*state.side
    -- Archer: commit to the approach rather than using lateral arrow dodges.
    -- Retain a small stop distance so that chasing does not run through them.
    if foeKit=="Archer" then
        if not elevated and distance<=ARCHER_GAP and velocity:Dot(actual.Unit)<=5 then return Vector3.zero,distance,"archer_hold" end
        local route=archerRoute(root,foeRoot,toward,distance,now)
        if route then return route,distance,"archer_route" end
        if elevated and distance<=ARCHER_GAP+1 then return Vector3.zero,distance,"archer_find_height" end
        local candidates={toward,(toward+side*0.6).Unit,(toward-side*0.6).Unit,side,-side}
        local best,score=Vector3.zero,-math.huge
        for _,dir in ipairs(candidates) do
            if pathClear(root,dir,6) then
                local progress=distance-flat(foeRoot.Position+lead-(root.Position+dir*6)).Magnitude
                if progress>score then best,score=dir,progress end
            end
        end
        return best,distance,best.Magnitude>0 and "archer_chase" or "archer_blocked"
    end
    if lancerThreat then
        -- A rushing Lancer may follow a dash with a narrow thrust. Prefer a
        -- checked lateral step; its server hitbox and facing lock are unknown.
        local lateral=Vector3.new(-actual.Unit.Z,0,actual.Unit.X)*state.side
        local candidates={(lateral-actual.Unit*0.2).Unit,(-lateral-actual.Unit*0.2).Unit,lateral,-lateral}
        for _,dir in ipairs(candidates) do
            if pathClear(root,dir,6) then return dir,distance,"lancer_rush_evade" end
        end
        return Vector3.zero,distance,"lancer_rush_blocked"
    end
    if distance<=MELEE_GAP+2 then
        -- Keep reach against melee kits; against Archer favor sticking closer.
        -- Facing is an observable hint, not proof of the opponent's hitbox.
        local towardActual=actual.Unit
        local lateral=Vector3.new(-towardActual.Z,0,towardActual.X)
        local enemyFacing=flat(foeRoot.CFrame.LookVector)
        if enemyFacing.Magnitude>0.01 then enemyFacing=enemyFacing.Unit else enemyFacing=nil end
        local predicted=flat(foeRoot.Position)+lead
        local desiredGap=foeKit=="Archer" and ARCHER_GAP or MELEE_GAP
        local candidates={lateral*state.side,-lateral*state.side,towardActual,-towardActual,
            (towardActual+lateral*0.7).Unit,(towardActual-lateral*0.7).Unit,
            (-towardActual+lateral*0.7).Unit,(-towardActual-lateral*0.7).Unit}
        local best,bestScore,bestSide=Vector3.zero,-math.huge,state.side
        for _,dir in ipairs(candidates) do
            local sideDot=dir:Dot(lateral)
            local side=sideDot>0.35 and 1 or sideDot< -0.35 and -1 or state.side
            local allowed=side==state.side or os.clock()-(state.lastSideFlip or -math.huge)>=1.2
            if allowed and pathClear(root,dir,4) then
                local position=flat(root.Position+dir*4)
                local fromFoe=position-predicted
                local gap=fromFoe.Magnitude
                if gap>=2.5 then
                    local angle=enemyFacing and fromFoe.Magnitude>0.01 and enemyFacing:Dot(fromFoe.Unit) or 0
                    local score=-math.abs(gap-desiredGap)*2.5-math.max(0,gap-(state.ownReachEstimate or 9))*2-angle*1.5
                    if arrow then score=score+math.min(8,projectileGap(root.Position+dir*4,arrow))*1.5 end
                    if side==state.side then score=score+1.0 end
                    if math.abs(sideDot)>0.35 then score=score+0.7 end
                    if score>bestScore then best,bestScore,bestSide=dir,score,side end
                end
            end
        end
        if best.Magnitude==0 then return best,distance,"orbit_blocked" end
        if bestSide~=state.side then state.side=bestSide;state.lastSideFlip=os.clock() end
        return best,distance,state.side==1 and "orbit_left" or "orbit_right"
    end
    local candidates={toward,(toward+side*0.6).Unit,(toward-side*0.6).Unit,side,-side}
    local best,bestScore=Vector3.zero,-math.huge
    for _,dir in ipairs(candidates) do
        if pathClear(root,dir,6) then
            local endpoint=root.Position+dir*6
            local after=flat(foeRoot.Position+lead-endpoint).Magnitude
            local score=(distance-after)*2+dir:Dot(toward)
            if score>bestScore then best,bestScore=dir,score end
        end
    end
    if best.Magnitude==0 then return best,distance,"blocked" end
    if best:Dot(side)<-0.4 and os.clock()-(state.lastSideFlip or 0)>1.5 then state.side=-state.side; state.lastSideFlip=os.clock() end
    return best,distance,"approach"
end
local attachment,align,orientationHumanoid,originalAutoRotate
local function restoreOrientation()
    if orientationHumanoid and orientationHumanoid.Parent and originalAutoRotate~=nil then pcall(function() orientationHumanoid.AutoRotate=originalAutoRotate end) end
    if align then pcall(function() align:Destroy() end) end
    if attachment then pcall(function() attachment:Destroy() end) end
    attachment,align,orientationHumanoid,originalAutoRotate=nil,nil,nil,nil
end
local function ensureOrientation(humanoid,root)
    if orientationHumanoid==humanoid and align and align.Parent==root then return end
    restoreOrientation()
    orientationHumanoid,originalAutoRotate=humanoid,humanoid.AutoRotate
    attachment=new("Attachment",{Name="RankedGladiatorFacingAttachment"},root)
    align=new("AlignOrientation",{Name="RankedGladiatorFacing",Mode=Enum.OrientationAlignmentMode.OneAttachment,Attachment0=attachment,MaxTorque=math.huge,Responsiveness=40,Enabled=false},root)
end
local savedCamera,savedCameraType,savedMouseBehavior
local function restoreCamera()
    local camera=workspace.CurrentCamera
    if savedCamera and camera==savedCamera and camera.CameraType==Enum.CameraType.Scriptable then
        camera.CameraType=savedCameraType or Enum.CameraType.Custom
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then camera.CameraSubject=hum end
    end
    if savedMouseBehavior and UserInputService.MouseBehavior==Enum.MouseBehavior.LockCenter then UserInputService.MouseBehavior=savedMouseBehavior end
    savedCamera,savedCameraType,savedMouseBehavior=nil,nil,nil
end
local function releaseCombat()
    for key in pairs(state.keys) do releaseKey(key) end
    if state.heldTool then pcall(function() state.heldTool:Deactivate() end); state.heldTool=nil end
    if state.humanoid and state.character==player.Character and state.movementOwned then pcall(function() state.humanoid:Move(Vector3.zero,false) end) end
    state.movementOwned=false
    state.blockUntil=nil;state.blockStartedAt=nil;state.blockReason=nil;state.pendingBlock=nil;state.guardAttackAt=nil
    state.move=Vector3.zero
    restoreOrientation()
    restoreCamera()
end
-- Ranked can remain in PvpPhase=Live between rounds.  On defeat the game
-- may already show full Humanoid.Health while CombatState is Respawning.
local scoreConnections,targetConnections,localConnections={},{},{}
local function disconnectAll(list)
    for _,connection in ipairs(list) do pcall(function() connection:Disconnect() end) end
end
local function lockRound(reason)
    if not state.active then return end
    if not state.roundLocked then
        state.roundSawRespawn=false
        state.roundResumeAfter=os.clock()+4.2
    elseif reason=="score_changed" then
        state.roundResumeAfter=os.clock()+4.2
    end
    state.roundLocked=true
    if reason~="score_changed" then state.roundSawRespawn=true end
    state.roundReason=reason
    state.reason="round_pause"
    releaseCombat()
end
local function combatPhase()
    return state.mode=="Ranked" and (state.phase=="Live" or state.phase=="SuddenDeath" or state.phase=="Overtime")
end
local function syncScores(gs)
    local id=tostring(gs:GetAttribute("MatchId") or "")
    if state.scoreMatch~=id then
        state.scoreMatch=id;state.scoreT1=nil;state.scoreT2=nil
        state.roundLocked=false;state.roundResumeAfter=nil;state.roundReason=nil;state.roundSawRespawn=false
    end
    local a,b=tonumber(gs:GetAttribute("PvpScoreT1")),tonumber(gs:GetAttribute("PvpScoreT2"))
    if a==nil or b==nil then return end
    if state.scoreT1~=nil and state.scoreT2~=nil and (a~=state.scoreT1 or b~=state.scoreT2) then
        lockRound("score_changed")
    end
    state.scoreT1,state.scoreT2=a,b
end
local function watchScores(gs)
    if state.scoreSource==gs then
        if gs then syncScores(gs) end
        return
    end
    disconnectAll(scoreConnections);scoreConnections={};state.scoreSource=gs
    if not gs then return end
    syncScores(gs)
    for _,name in ipairs({"PvpScoreT1","PvpScoreT2","MatchId"}) do
        table.insert(scoreConnections,gs:GetAttributeChangedSignal(name):Connect(function() syncScores(gs) end))
    end
end
local function watchTarget(opponent,character,humanoid)
    if state.watchedOpponent==opponent and state.watchedCharacter==character and state.watchedHumanoid==humanoid then return end
    disconnectAll(targetConnections);targetConnections={}
    state.watchedOpponent,state.watchedCharacter,state.watchedHumanoid=opponent,character,humanoid
    if not opponent or not character or not humanoid then return end
    state.watchedReadyAt=tonumber(opponent:GetAttribute("AbilityReadyAt")) or 0
    table.insert(targetConnections,opponent:GetAttributeChangedSignal("AbilityReadyAt"):Connect(function()
        local ready=tonumber(opponent:GetAttribute("AbilityReadyAt")) or 0
        local old=state.watchedReadyAt or 0
        state.watchedReadyAt=ready
        local root=character:FindFirstChild("HumanoidRootPart")
        if ready>old+1 and ready>workspace:GetServerTimeNow()+1 and root then
            local ability=opponent:GetAttribute("AbilityEquipped")
            if ability=="orcus_blight" then observeBlight(opponent,root.Position,"cooldown",0)
            elseif ability=="jupiter_wrath" then
                local own=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if own and flat(own.Position-root.Position).Magnitude<=46 then
                    -- Fallback estimates the current target position; FX points
                    -- replace it if the actual broadcast arrives.
                    observeStorm(opponent,{own.Position},"cooldown_estimate",0)
                end
            end
        end
    end))
    table.insert(targetConnections,opponent:GetAttributeChangedSignal("CombatState"):Connect(function()
        local value=opponent:GetAttribute("CombatState")
        if combatPhase() and value~=nil and value~="Alive" then lockRound("opponent_"..tostring(value)) end
    end))
    table.insert(targetConnections,opponent:GetAttributeChangedSignal("PvpRespawnAt"):Connect(function()
        if combatPhase() and respawning(opponent,character) then lockRound("opponent_respawn_timer") end
    end))
    table.insert(targetConnections,character:GetAttributeChangedSignal("PvpRespawnAt"):Connect(function()
        if combatPhase() and respawning(opponent,character) then lockRound("opponent_respawn_timer") end
    end))
    local function onShield()
        if combatPhase() and shielded(opponent,character) then
            state.reason="opponent_spawn_shield"
            releaseCombat()
        end
    end
    table.insert(targetConnections,opponent:GetAttributeChangedSignal("SpawnShield"):Connect(onShield))
    table.insert(targetConnections,character:GetAttributeChangedSignal("SpawnShield"):Connect(onShield))
    table.insert(targetConnections,character:GetAttributeChangedSignal("Downed"):Connect(function()
        if combatPhase() and character:GetAttribute("Downed")==true then lockRound("opponent_downed") end
    end))
    table.insert(targetConnections,humanoid.HealthChanged:Connect(function(health)
        if combatPhase() and health<=0 then lockRound("opponent_defeated") end
    end))
end
local function watchLocal(character,humanoid)
    if state.watchedLocal==character and state.watchedLocalHumanoid==humanoid then return end
    disconnectAll(localConnections);localConnections={}
    state.watchedLocal,state.watchedLocalHumanoid=character,humanoid
    state.lastHealth=nil
    if not character or not humanoid then return end
    table.insert(localConnections,character:GetAttributeChangedSignal("Downed"):Connect(function()
        if combatPhase() and character:GetAttribute("Downed")==true then lockRound("self_downed") end
    end))
    table.insert(localConnections,character:GetAttributeChangedSignal("V2State"):Connect(function()
        if combatPhase() and stunActive(character) then
            state.stunned=true
            releaseCombat()
        end
    end))
    table.insert(localConnections,character:GetAttributeChangedSignal("PvpRespawnAt"):Connect(function()
        if combatPhase() and respawning(player,character) then lockRound("self_respawn_timer") end
    end))
    table.insert(localConnections,humanoid.HealthChanged:Connect(function(health)
        if combatPhase() and health<=0 then lockRound("self_defeated") end
    end))
end
local function applyMovement()
    if not state.active or (state.reason~="active" and state.reason~="spawn_exit" and state.reason~="warmup_approach") then return end
    local hum,root,foe=state.humanoid,state.root,state.foeRoot
    if not hum or not root or not foe or player.Character~=state.character then return end
    ensureOrientation(hum,root)
    local facing=flat(foe.Position-root.Position)
    if align and facing.Magnitude>0.01 then
        align.Enabled=true; hum.AutoRotate=false; align.CFrame=CFrame.lookAt(Vector3.zero,facing)
    end
    hum:Move(state.stunned and Vector3.zero or state.move,false)
    state.movementOwned=true
end
local function applyExtraMovement(deltaTime)
    state.tpwalkExtra=0
    if not state.active or (state.reason~="active" and state.reason~="spawn_exit" and state.reason~="warmup_approach")
        or not state.humanoid or not state.character or player.Character~=state.character then return end
    local hum=state.humanoid
    if not hum.Parent then return end
    local direction=hum.MoveDirection
    if direction.Magnitude>0 then
        -- Infinite Yield default displacement, applied each Heartbeat.
        local ok=pcall(function() state.character:TranslateBy(direction*TPWALK_MULTIPLIER*deltaTime*10) end)
        if ok then state.tpwalkExtra=direction.Magnitude*TPWALK_MULTIPLIER*10 end
    end
end
local function aimCamera()
    if not state.active or state.reason~="active" then return end
    local camera,root,foe=workspace.CurrentCamera,state.root,state.foeRoot
    if not camera or not root or not foe then return end
    if savedCamera~=camera then
        restoreCamera()
        if camera.CameraType==Enum.CameraType.Scriptable then return end
        savedCamera,savedCameraType,savedMouseBehavior=camera,camera.CameraType,UserInputService.MouseBehavior
    elseif camera.CameraType~=Enum.CameraType.Scriptable then
        savedCamera,savedCameraType,savedMouseBehavior=nil,nil,nil
        return
    end
    local direction=flat(foe.Position-root.Position)
    if direction.Magnitude<0.01 then return end
    local eye=root.Position+Vector3.new(0,3,0)
    local offset=-direction.Unit*8
    local ok,hit=pcall(function() return workspace:Raycast(eye,offset,rayParams) end)
    if not ok then return end
    local position=hit and hit.Position+direction.Unit*0.5 or eye+offset
    local target=foe.Position+Vector3.new(0,1,0)
    if (target-position).Magnitude<0.01 then return end
    UserInputService.MouseBehavior=Enum.MouseBehavior.LockCenter
    camera.CameraType=Enum.CameraType.Scriptable
    camera.CFrame=CFrame.lookAt(position,target)
end
local function publish()
    local text=state.reason
    if state.distance then text=text..string.format(" | %.1f studs",state.distance) end
    if state.detail then text=text.." | "..state.detail end
    label.Text="Gladiator: "..text
    local values={reason=state.reason,detail=state.detail or "",mode=state.mode or "",phase=state.phase or "",distance=state.distance or -1,
        targetId=state.target and state.target.UserId or 0,ability=abilityId() or "",dashReason=state.dashReason or "",abilityReason=state.abilityReason or "",
        attackAttempts=state.attackAttempts or 0,dashAttempts=state.dashAttempts or 0,abilityAttempts=state.abilityAttempts or 0,
        tpwalkExtra=state.tpwalkExtra or 0,teleport="external_autoexec",roundLocked=state.roundLocked==true,
        roundReason=state.roundReason or "",stunned=state.stunned==true,arrowEta=state.arrowEta or -1,
        arrowCount=#state.arrows,arrowMoveId=state.arrowMoveId or "",arrowEvading=state.arrowEvading==true,arrowEvadeAttempts=state.arrowEvadeAttempts or 0,
        foeCharging=state.foeCharging or -1,chargeThreat=state.chargeThreat==true,
        dashEstimate=state.dashEstimate or 0,foeFastEscape=state.foeFastEscape==true,
        foeDashing=state.foeDashing==true,zigSide=state.zigSide,
        lancerThreat=state.lancerThreat==true,lancerThreatFront=state.lancerThreatFront or -999,
        lancerThreatSide=state.lancerThreatSide or -1,
        foeKit=state.foeKit or "",desiredGap=state.desiredGap or 0,dashThrustAttempts=state.dashThrustAttempts or 0,
        blightActive=state.blightActive==true,blightSource=state.blightSource or "",blightGap=state.blightGap or -1,
        attackReason=state.attackReason or "",attackRange=state.attackRange or 0,attackFacing=state.attackFacing or 0,
        stormActive=state.stormActive==true,stormSource=state.stormSource or "",stormGap=state.stormGap or -1,
        jumpAttempts=state.jumpAttempts or 0,jumpReason=state.jumpReason or "",navJumpAttempts=state.navJumpAttempts or 0,
        jumpObserved=state.jumpObserved or 0,jumpUnconfirmed=state.jumpUnconfirmed or 0,
        blockHeld=state.keys[Enum.KeyCode.F]==true,blockReason=state.blockReason or "",
        arrowGuardExtensions=state.arrowGuardExtensions or 0,
        guardHazardSafe=state.guardHazardSafe==true,guardMeleeThreat=state.guardMeleeThreat==true,
        blockAttempts=state.blockAttempts or 0,blockObserved=state.blockObserved or 0,blockUnconfirmed=state.blockUnconfirmed or 0,
        ownReachEstimate=state.ownReachEstimate or 0,enemyReachEstimate=state.enemyReachEstimate or 0,
        ownWeaponReach=state.ownWeaponReach or 0,ownWeaponReachSource=state.ownWeaponReachSource or "",
        controlIntervalMs=CONTROL_INTERVAL*1000,controlStepMs=state.controlStepMs or 0,
        guardReleasePending=os.clock()<(state.guardAttackAt or 0),
        parryReason=state.parryReason or "",parryPredictions=state.parryPredictions or 0,
        parryAttempts=state.parryAttempts or 0,parryConfirmed=state.parryConfirmed or 0,
        parryNext=state.parryNext or "",parryDueIn=state.parryDueIn or -1,
        parryEdgeSamples=state.parryEdgeSamples or 0,parryHitSamples=state.parryHitSamples or 0,
        riposteActive=(state.riposteUntil or 0)>os.clock(),
        reachGapState=state.reachGapState or "",reachDashLanding=state.reachDashLanding or -1,
        lastDashReason=state.lastDashReason or "",reachDashAttempts=state.reachDashAttempts or 0,
        evadeDashAttempts=state.evadeDashAttempts or 0,closeDashAttempts=state.closeDashAttempts or 0,
        blightReady=state.blightReady==true,blightBait=state.blightBait==true,blightStuck=state.blightStuck==true,
        dashObserved=state.dashObserved or 0,dashUnconfirmed=state.dashUnconfirmed or 0,
        mapReady=state.ring~=nil,mapRadius=state.ring and state.ring.radius or 0,mapKind=state.mapKind or "unknown",navStatus=state.navStatus or "",
        orcusRadius=state.orcusRadius or 0,orcusPredicted=state.orcusPredicted or 0,
        orcusAreaBonus=state.areaBonus or 0,orcusAreaSource=state.areaSource or "",
        statsSource=state.statsSource or "",estimatedDashDistance=state.statDashDistance or 16,
        estimatedDashCooldown=state.statDashCooldown or 4,
        statAttackCooldown=state.statAttackCooldown or -1,statWeapon=state.statWeapon or "",
        orcusConfirmed=state.orcusConfirmed or 0,orcusUnconfirmed=state.orcusUnconfirmed or 0}
    for key,value in pairs(values) do trace:SetAttribute(key,value) end
end
local function matchFlow(gs,mode,phase,kit,now)
    local zone=player:GetAttribute("Zone")
    if mode=="Ranked" and zone~="Lobby" then state.wasInRanked=true;state.queueEligible=false end
    if state.queueEligible==nil then
        if zone=="Arena" or gs and gs:GetAttribute("ServerMode")=="Arena" then state.queueEligible=false
        elseif zone=="Lobby" and not state.wasInRanked then state.queueEligible=true end
    end
    if mode=="Ranked" and phase=="Warmup" and state.lastFlowPhase=="Ended" then
        state.retryMatch=nil;state.retryCount=0;state.lastRetry=-math.huge
    end
    state.lastFlowPhase=phase
    local team=teamOf(player)
    if mode=="Ranked" and phase=="Warmup" and kit=="Gladiator" and team and gs then
        local lock=tonumber(gs:GetAttribute("PvpLockAt")) or 0
        local ready=gs:GetAttribute("PvpReady"..team)
        if lock>workspace:GetServerTimeNow() and ready~=true and now-state.lastReady>=4 then
            state.lastReady=now
            if fire("PvpAction","ready") then state.detail="ready sent" end
        end
    end
    if mode=="Ranked" and phase=="Ended" and player:GetAttribute("Zone")=="Arena" then
        state.endedAt=state.endedAt or now
        local id=tostring(gs and gs:GetAttribute("MatchId") or "")
        if state.retryMatch~=id then state.retryMatch=id;state.retryCount=0;state.lastRetry=-math.huge end
        if now-state.endedAt>=3 and state.retryCount<2 and now-state.lastRetry>=12 then
            state.lastRetry=now;state.retryCount=state.retryCount+1
            if fire("LeaveMatch","continue") then state.detail="return to lobby sent" end
        end
        return
    end
    state.endedAt=nil
    if state.queueEligible and zone=="Lobby" and (not gs or gs:GetAttribute("ServerMode")~="Arena") then
        local queueState=player:GetAttribute("QueueState")
        local queueMode=player:GetAttribute("Queue") or player:GetAttribute("QueueMode")
        local idle=(queueState==nil or queueState=="" or string.lower(tostring(queueState))=="idle")
            and (queueMode==nil or queueMode=="")
        if not idle then state.queueEligible=false
        elseif remote("QueueJoin") then
            state.queueEligible=false
            if fire("QueueJoin","PvpRanked") then state.detail="ranked queue sent" end
        end
    end
end
local function tick()
    local gs=ReplicatedStorage:FindFirstChild("GameState")
    watchScores(gs)
    local mode=gs and gs:GetAttribute("PvpMode") or player:GetAttribute("PvpMode")
    if not mode or mode=="" then mode=player:GetAttribute("PvpMode") end
    local phase=gs and gs:GetAttribute("PvpPhase")
    local kit=player:GetAttribute("PvpKit") or player:GetAttribute("Kit")
    local now=os.clock()
    local ring=refreshRing(now)
    state.mode,state.phase,state.detail=mode,phase,nil
    matchFlow(gs,mode,phase,kit,now)
    local character=player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")
    watchLocal(character,humanoid)
    local opponent,why=selectedOpponent()
    local foe=opponent and opponent.Character
    local foeHum=foe and foe:FindFirstChildOfClass("Humanoid")
    local foeRoot=foe and foe:FindFirstChild("HumanoidRootPart")
    if opponent then watchTarget(opponent,foe,foeHum) end
    if state.roundLocked then
        local previous=state.watchedOpponent
        if (player:GetAttribute("CombatState")~=nil and player:GetAttribute("CombatState")~="Alive")
            or (previous and previous:GetAttribute("CombatState")~=nil and previous:GetAttribute("CombatState")~="Alive")
            or respawning(player,character) or respawning(previous,state.watchedCharacter) then state.roundSawRespawn=true end
    end
    if state.roundLocked and state.roundSawRespawn and now>=(state.roundResumeAfter or math.huge)
        and player:GetAttribute("CombatState")=="Alive" and opponent and opponent:GetAttribute("CombatState")=="Alive"
        and humanoid and humanoid.Health>0 and root and not root.Anchored
        and foeHum and foeHum.Health>0 and foeRoot and not foeRoot.Anchored
        and character:GetAttribute("Downed")~=true and foe:GetAttribute("Downed")~=true
        and not respawning(player,character) and not respawning(opponent,foe) and not shielded(opponent,foe) then
        state.roundLocked=false;state.roundReason=nil
    end
    if not state.focused or UserInputService:GetFocusedTextBox() then state.reason="input_paused"
    elseif mode~="Ranked" or (phase~="Live" and phase~="SuddenDeath" and phase~="Overtime") then state.reason="waiting_for_live"
    elseif kit~="Gladiator" then state.reason="gladiator_not_confirmed"
    elseif state.roundLocked then state.reason="round_pause"
    elseif player:GetAttribute("Zone")~="Arena" or player:GetAttribute("Spectating")==true or player:GetAttribute("Cinematic")==true then state.reason="not_in_arena"
    elseif player:GetAttribute("CombatState")~="Alive" or respawning(player,character) or not character or not humanoid or humanoid.Health<=0 or not root or root.Anchored or character:GetAttribute("Downed")==true or character:GetAttribute("Cinematic")==true then state.reason="character_unavailable"
    elseif not opponent then state.reason=why
    elseif not foe or not foeHum or foeHum.Health<=0 or not foeRoot or foe:GetAttribute("Downed")==true then state.reason="opponent_unavailable"
    elseif shielded(opponent,foe) then state.reason="opponent_spawn_shield"
    else state.reason="active" end
    -- Some arenas allow movement during Warmup. Follow a moving Archer on
    -- maps other than the verified Ranked ring without spending combat cooldowns.
    if phase~="Warmup" then state.warmupEngaged=false end
    if state.reason=="waiting_for_live" and mode=="Ranked" and phase=="Warmup" and not ring
        and kit=="Gladiator" and state.focused and not UserInputService:GetFocusedTextBox()
        and not state.roundLocked and player:GetAttribute("Zone")=="Arena"
        and player:GetAttribute("Spectating")~=true and player:GetAttribute("Cinematic")~=true
        and player:GetAttribute("CombatState")=="Alive" and character and humanoid and humanoid.Health>0
        and root and not root.Anchored and (tonumber(humanoid.WalkSpeed) or 0)>0
        and character:GetAttribute("Downed")~=true and character:GetAttribute("Cinematic")~=true
        and not stunActive(character) and not respawning(player,character)
        and opponent and opponent:GetAttribute("CombatState")=="Alive" and foe and foeHum and foeHum.Health>0
        and foeRoot and not foeRoot.Anchored and foe:GetAttribute("Downed")~=true and not respawning(opponent,foe)
        and (opponent:GetAttribute("PvpKit") or opponent:GetAttribute("Kit"))=="Archer" then
        local movedAt=tonumber(foe:GetAttribute("MoveAt"))
        local recentMove=movedAt and workspace:GetServerTimeNow()-movedAt>=0 and workspace:GetServerTimeNow()-movedAt<1
        if recentMove or flat(foeRoot.AssemblyLinearVelocity).Magnitude>3 then state.warmupEngaged=true end
        if state.warmupEngaged then
            if not state.warmupMoving then releaseCombat();state.warmupMoving=true end
            setRayFilter(character,foe)
            state.character,state.humanoid,state.root,state.foeRoot=character,humanoid,root,foeRoot
            state.move,state.distance,state.detail=planMovement(root,foeRoot,"Archer",nil,now,false)
            state.reason="warmup_approach";state.stunned=false
            publish();return
        end
    end
    state.warmupMoving=false
    if state.reason~="active" then
        -- Positioning is allowed once both combatants have respawned, even
        -- if the combat lock or spawn shield is still active. Combat inputs
        -- remain released until the ordinary round-start checks pass.
        local mayExit=(state.reason=="opponent_spawn_shield" or state.reason=="round_pause" and state.roundSawRespawn)
            and ring and character and humanoid and humanoid.Health>0 and root and not root.Anchored
            and player:GetAttribute("Zone")=="Arena" and player:GetAttribute("Spectating")~=true
            and player:GetAttribute("Cinematic")~=true and character:GetAttribute("Cinematic")~=true
            and player:GetAttribute("CombatState")=="Alive" and character:GetAttribute("Downed")~=true
            and not stunActive(character) and not respawning(player,character)
            and state.focused and not UserInputService:GetFocusedTextBox()
            and opponent and opponent:GetAttribute("CombatState")=="Alive" and foe and foeHum and foeHum.Health>0
            and foeRoot and foe:GetAttribute("Downed")~=true and not respawning(opponent,foe)
        local exitDirection=mayExit and flat(ring.center-root.Position) or nil
        local wasSpawnMoving=state.spawnMoving==true
        state.target,state.distance=nil,nil
        state.arrows={};state.arrowEta=nil;state.lastEnemyArrowAt=nil;state.stunned=false
        state.arrowEvading=false;state.arrowEvadeUntil=nil;state.arrowEvadeDirection=nil;state.arrowEvadeTarget=nil
        state.blight=nil;state.blightActive=false;state.blightSource=nil;state.blightGap=nil
        state.storm=nil;state.stormActive=false;state.stormSource=nil;state.stormGap=nil
        state.blightAnchor=nil;state.blightAnchorAt=nil;state.blightStuck=false;state.blightBait=false;state.blightReady=false
        state.pendingDash=nil;state.pendingOrcus=nil;state.pendingJump=nil
        if not wasSpawnMoving then releaseCombat() end
        state.spawnMoving=false
        if exitDirection then
            setRayFilter(character,foe)
            local move,detail,plannedDistance
            if exitDirection.Magnitude>ring.radius-5 then
                move,detail=exitDirection.Unit,"toward_ring"
            else
                local foeKit=opponent:GetAttribute("PvpKit") or opponent:GetAttribute("Kit")
                move,plannedDistance,detail=planMovement(root,foeRoot,foeKit,nil,now,false)
                if move.Magnitude>0.01 then detail="toward_opponent" end
            end
            if move and move.Magnitude>0.01 then
                local here=flat(root.Position-ring.center).Magnitude
                local there=flat(root.Position+move*4-ring.center).Magnitude
                local inside=here>ring.radius-2 and there<here or here<=ring.radius-2 and there<=ring.radius-1
                if inside and pathClear(root,move,math.min(6,math.max(1,here>ring.radius-2 and here-(ring.radius-2) or 4))) then
                    state.character,state.humanoid,state.root,state.foeRoot=character,humanoid,root,foeRoot
                    state.move=move;state.distance=plannedDistance or flat(foeRoot.Position-root.Position).Magnitude
                    state.reason="spawn_exit";state.detail=detail;state.spawnMoving=true
                end
            end
        end
        if wasSpawnMoving and not state.spawnMoving then releaseCombat() end
        publish();return
    end
    state.spawnMoving=false
    if state.character~=character then releaseCombat() end
    if state.target~=opponent then
        state.foeEscapeUntil=nil;state.nextZigAt=nil;state.blightBaitKey=nil;state.blightBaitUntil=nil
        if state.parryOpponent~=opponent then
            state.parryOpponent=opponent;state.parryLastMove=nil;state.parryEdges={};state.parryHits={};state.riposteUntil=nil
        end
    end
    state.character,state.humanoid,state.root,state.foeRoot,state.target=character,humanoid,root,foeRoot,opponent
    setRayFilter(character,foe)
    state.stunned=stunActive(character)
    local jumpPending=state.pendingJump
    if jumpPending then
        if humanoid.FloorMaterial==Enum.Material.Air or root.AssemblyLinearVelocity.Y>3 then
            state.jumpObserved=(state.jumpObserved or 0)+1;state.pendingJump=nil
        elseif now-jumpPending.at>=0.8 then
            state.jumpUnconfirmed=(state.jumpUnconfirmed or 0)+1;state.pendingJump=nil
        end
    end
    if state.pendingBlock then
        if character:GetAttribute("Blocking")==true then
            state.blockObserved=(state.blockObserved or 0)+1;state.pendingBlock=nil
        elseif now-state.pendingBlock.at>=0.7 then
            state.blockUnconfirmed=(state.blockUnconfirmed or 0)+1;state.pendingBlock=nil
        end
    end
    combatStats(now)
    local ownReady=tonumber(player:GetAttribute("AbilityReadyAt")) or 0
    local pendingOrcus=state.pendingOrcus
    if pendingOrcus then
        if ownReady>pendingOrcus.previousReady+1 and ownReady>workspace:GetServerTimeNow()+1
            or state.ownOrcusFxAt and state.ownOrcusFxAt>=pendingOrcus.at then
            state.orcusConfirmed=(state.orcusConfirmed or 0)+1;state.pendingOrcus=nil
        elseif now-pendingOrcus.at>=1.2 then
            state.orcusUnconfirmed=(state.orcusUnconfirmed or 0)+1;state.pendingOrcus=nil
        end
    end
    local pending=state.pendingDash
    if pending then
        local move=character:GetAttribute("Move")
        local movedAt=tonumber(character:GetAttribute("MoveAt"))
        local observed=character:GetAttribute("Dashing")==true or root:FindFirstChild("DashPredict")~=nil
            or type(move)=="string" and string.sub(move,1,5)=="dash_" and movedAt and movedAt>(pending.moveAt or 0)
        if observed then state.dashObserved=(state.dashObserved or 0)+1;state.pendingDash=nil
        elseif now-pending.at>=0.5 then state.dashUnconfirmed=(state.dashUnconfirmed or 0)+1;state.pendingDash=nil end
    end
    if state.lastHealth and humanoid.Health<state.lastHealth then
        state.zigSide=-state.zigSide
        state.nextZigAt=now+0.65+math.random()*0.6
        state.nextPlan=nil
    end
    state.lastHealth=humanoid.Health
    local foeKit=opponent:GetAttribute("PvpKit") or opponent:GetAttribute("Kit")
    state.foeKit=foeKit
    state.desiredGap=foeKit=="Archer" and ARCHER_GAP or MELEE_GAP
    local arrow=incomingArrow(root,now)
    state.arrowEta=arrow and arrow.eta or nil
    state.arrowMoveId=arrow and arrow.moveId or nil
    local arrowPresent=arrow~=nil
    local relative=flat(foeRoot.Position-root.Position)
    local closing=relative.Magnitude>0.01 and -flat(foeRoot.AssemblyLinearVelocity-root.AssemblyLinearVelocity):Dot(relative.Unit) or 0
    local foeMove=foe:GetAttribute("Move")
    local moveAt=tonumber(foe:GetAttribute("MoveAt"))
    local moveDuration=tonumber(foe:GetAttribute("MoveDuration")) or 0.3
    observeCombatMove(foeMove,moveAt,workspace:GetServerTimeNow())
    local recentThrust=foeMove=="lance_dashthrust" and moveAt and workspace:GetServerTimeNow()-moveAt>=-0.1
        and workspace:GetServerTimeNow()-moveAt<=math.min(0.6,math.max(0.1,moveDuration))
    local rawLancerThreat=foeKit=="Lancer" and relative.Magnitude<=45 and relative.Magnitude>=5
        and (recentThrust or foe:GetAttribute("Dashing")==true and closing>8)
    local lancerThreat=rawLancerThreat
    state.lancerThreatFront=nil;state.lancerThreatSide=nil
    if rawLancerThreat then
        local foeFacing=flat(foeRoot.CFrame.LookVector)
        if foeFacing.Magnitude>0.01 then
            foeFacing=foeFacing.Unit
            local offset=flat(root.Position-foeRoot.Position)
            local right=Vector3.new(-foeFacing.Z,0,foeFacing.X)
            local front=offset:Dot(foeFacing)
            local side=math.abs(offset:Dot(right))
            local approachSpeed=math.max(0,flat(foeRoot.AssemblyLinearVelocity):Dot(foeFacing))
            local projectedFront=front-math.min(18,approachSpeed*0.18)
            state.lancerThreatFront=front;state.lancerThreatSide=side
            -- Dash-thrust is a narrow line. Margin covers body and uncertain
            -- replication; this remains an estimate, not a hitbox guarantee.
            lancerThreat=front>=-6 and side<=7.5 and (front<=19 or projectedFront<=19)
        end
    end
    state.lancerThreat=lancerThreat==true
    local foeAbility=opponent:GetAttribute("AbilityEquipped")
    local foeReadyAt=tonumber(opponent:GetAttribute("AbilityReadyAt"))
    local blightReady=foeAbility=="orcus_blight" and (not foeReadyAt or foeReadyAt<=workspace:GetServerTimeNow()+0.1)
    state.blightReady=blightReady==true
    local blight=state.blight
    if blight and (blight.opponent~=opponent or now>=blight.expires) then state.blight=nil;blight=nil end
    local blightOffset=blight and flat(root.Position-blight.origin)
    local blightGap=blightOffset and blightOffset.Magnitude
    state.blightActive=blight~=nil
    state.blightSource=blight and blight.source or nil
    state.blightGap=blightGap
    local storm=state.storm
    if storm and (storm.opponent~=opponent or now>=storm.expires) then state.storm=nil;storm=nil end
    local closest,stormGap
    if storm then
        for _,point in ipairs(storm.points) do
            local gap=flat(root.Position-point).Magnitude
            if not stormGap or gap<stormGap then closest,stormGap=point,gap end
        end
    end
    state.stormActive=storm~=nil;state.stormSource=storm and storm.source or nil;state.stormGap=stormGap
    local stormThreat=storm and stormGap and stormGap<18
    -- Orcus binding has an estimated 0.5 s delay. Keep a conservative margin
    -- for replication, then resume combat even while rot/thorns continue.
    -- Their server hit timing and effects are not fully known.
    local blightInitial=blight and now-blight.detected<1.1
    local hazard=blightInitial and blightGap<30 and {origin=blight.origin,gap=blightGap,leave=22,hold=24,kind="blight"}
        or stormThreat and {origin=closest,points=storm.points,gap=stormGap,leave=11,hold=13,kind="storm"} or nil
    local ownReach=estimateSwordReach(foeRoot,closing)
    local enemyReach=estimateLongReach(foeKit,root,opponent)
    state.ownReachEstimate=ownReach;state.enemyReachEstimate=enemyReach
    local committedReach=SWORD_BASE_REACH+bodyRadius(foeRoot)+0.5
    local inReachGap=enemyReach>0 and relative.Magnitude>committedReach and relative.Magnitude<=enemyReach+4
    local availableCharges=dashCharges(now)
    local reachBreak=false
    state.reachGapState=inReachGap and "no_safe_dash" or "none";state.reachDashLanding=nil
    if inReachGap and not hazard and not lancerThreat and availableCharges>0
        and now-(state.lastDashAttempt or -math.huge)>=0.7 and relative.Magnitude>0.1 then
        local toward=relative.Unit
        local dashDistance=state.statDashDistance or 16
        local future=flat(foeRoot.AssemblyLinearVelocity)*0.2
        if future.Magnitude>6 then future=future.Unit*6 end
        local target=foeRoot.Position+future
        local landing=root.Position+toward*dashDistance
        local before=flat(target-root.Position).Magnitude
        local after=flat(target-landing).Magnitude
        state.reachDashLanding=after
        local insideMap=true
        if ring then
            local here=flat(root.Position-ring.center).Magnitude
            local there=flat(landing-ring.center).Magnitude
            insideMap=here>ring.radius and there<here or here<=ring.radius and there<=ring.radius-2
        end
        if after>=1.25 and after<=ownReach+1 and before-after>=2
            and insideMap and pathClear(root,toward,dashDistance+2) then
            reachBreak=true;state.reachGapState="dash_candidate"
        end
    elseif inReachGap and availableCharges<=0 then state.reachGapState="no_charges" end
    local baitKey=blightReady and foeKit~="Archer" and tostring(foeReadyAt or "unknown") or nil
    if not hazard and baitKey and relative.Magnitude>=20 and relative.Magnitude<=32 and state.blightBaitKey~=baitKey then
        state.blightBaitKey=baitKey;state.blightBaitUntil=now+1.2
    end
    local bait=not hazard and baitKey and state.blightBaitKey==baitKey and now<(state.blightBaitUntil or 0)
        and relative.Magnitude>=14 and relative.Magnitude<=38
    state.blightBait=bait==true
    -- Only step aside for an observed incoming arrow when we are outside
    -- melee reach and the estimated travel time leaves room to move. The
    -- estimate includes unknown replication and server timing; it is not a
    -- guarantee of avoiding the hit.
    local canArrowEvade=foeKit=="Archer" and relative.Magnitude>ownReach+6 and not hazard
        and not state.stunned and character:GetAttribute("Dashing")~=true and not root:FindFirstChild("DashPredict")
    if state.arrowEvadeTarget~=opponent or not canArrowEvade or now>=(state.arrowEvadeUntil or 0) then
        state.arrowEvadeUntil=nil;state.arrowEvadeDirection=nil;state.arrowEvadeTarget=nil
    end
    if canArrowEvade and not state.arrowEvadeDirection and arrow and arrow.eta>=0.08 then
        local flight=flat(arrow.direction)
        local available=((tonumber(humanoid.WalkSpeed) or 0)+TPWALK_MULTIPLIER*10)*math.max(0,arrow.eta-0.03)
        local stepLength=math.min(6,available)
        if flight.Magnitude>0.01 and stepLength>=1.5 then
            flight=flight.Unit
            local lateral=Vector3.new(-flight.Z,0,flight.X)*state.side
            local before=projectileGap(root.Position,arrow)
            local best,bestScore=nil,-math.huge
            for _,dir in ipairs({lateral,-lateral}) do
                local landing=root.Position+dir*stepLength
                local clearance=projectileGap(landing,arrow)
                local insideMap=true
                if ring then
                    local here=flat(root.Position-ring.center).Magnitude
                    local there=flat(landing-ring.center).Magnitude
                    insideMap=here>ring.radius and there<here or here<=ring.radius and there<=ring.radius-2
                end
                if clearance>=3.25 and clearance>=before+1.5 and insideMap and pathClear(root,dir,stepLength) then
                    local progress=relative.Magnitude-flat(foeRoot.Position-landing).Magnitude
                    local score=clearance+progress*0.1
                    if score>bestScore then best,bestScore=dir,score end
                end
            end
            if best then
                state.arrowEvadeDirection=best;state.arrowEvadeTarget=opponent
                state.arrowEvadeUntil=now+math.min(0.5,arrow.eta+0.1)
                state.arrowEvadeAttempts=(state.arrowEvadeAttempts or 0)+1
            end
        end
    end
    local arrowEvading=state.arrowEvadeDirection and canArrowEvade
        and pathClear(root,state.arrowEvadeDirection,3) or false
    if arrowEvading and ring then
        local here=flat(root.Position-ring.center).Magnitude
        local there=flat(root.Position+state.arrowEvadeDirection*3-ring.center).Magnitude
        arrowEvading=here>ring.radius and there<here or here<=ring.radius and there<=ring.radius-2
    end
    if state.arrowEvadeDirection and not arrowEvading then
        state.arrowEvadeUntil=nil;state.arrowEvadeDirection=nil;state.arrowEvadeTarget=nil
    end
    state.arrowEvading=arrowEvading==true
    if hazard then
        -- The origin is fixed at cast time. Stay outside the estimated area
        -- until it expires; the server's actual radius/timing can differ.
        local offset=flat(root.Position-hazard.origin)
        local away=hazard.gap>0.1 and offset.Unit or relative.Magnitude>0.1 and -relative.Unit or Vector3.new(1,0,0)
        local side=Vector3.new(-away.Z,0,away.X)
        local candidates={away,(away+side*0.4).Unit,(away-side*0.4).Unit,side,-side}
        local best,bestGap=Vector3.zero,hazard.gap
        if hazard.gap<hazard.hold then
            for _,dir in ipairs(candidates) do
                local after=hazardClearance(root.Position+dir*6,hazard)
                if after>bestGap and pathClear(root,dir,6) then best,bestGap=dir,after end
            end
        else
            -- Move around the outside instead of standing still. Check the
            -- whole proposed path against every observed hazard point.
            local toward=relative.Magnitude>0.1 and relative.Unit or side
            local candidates={toward,(toward+side*0.7).Unit,(toward-side*0.7).Unit,side,-side,away}
            local score=-math.huge
            for _,dir in ipairs(candidates) do
                if safeHazardPath(root,dir,6,hazard) then
                    local endpoint=root.Position+dir*6
                    local s=-flat(foeRoot.Position-endpoint).Magnitude+dir:Dot(side)*state.side*0.25
                    if s>score then best,score=dir,s end
                end
            end
        end
        state.move=best;state.distance=relative.Magnitude
        state.planReason=best.Magnitude==0 and hazard.kind.."_hold"
            or hazard.gap<hazard.hold and hazard.kind.."_retreat" or hazard.kind.."_skirt"
        state.nextPlan=nil
    elseif arrowEvading then
        state.move=state.arrowEvadeDirection;state.distance=relative.Magnitude;state.planReason="incoming_arrow_evade"
        state.nextPlan=nil
    elseif reachBreak then
        state.move=relative.Unit;state.distance=relative.Magnitude;state.planReason="reach_break"
        state.nextPlan=nil
    elseif inReachGap and not lancerThreat and relative.Magnitude>0.1 then
        -- No safe gap-closing dash: look for a checked oblique route and use
        -- the shield when appropriate; this is not a guaranteed dodge.
        local toward=relative.Unit
        local side=Vector3.new(-toward.Z,0,toward.X)*state.side
        local candidates={(side+toward*0.35).Unit,(-side+toward*0.35).Unit,side,-side}
        local best=Vector3.zero
        for _,dir in ipairs(candidates) do if pathClear(root,dir,6) then best=dir;break end end
        state.move=best;state.distance=relative.Magnitude
        state.planReason=best.Magnitude>0 and "reach_angle" or "reach_blocked"
        state.nextPlan=nil
    elseif bait then
        local toward=relative.Unit
        local away=-toward
        local side=Vector3.new(-toward.Z,0,toward.X)*state.side
        local first=(relative.Magnitude<=26 or foe:GetAttribute("Dashing")==true) and away or side
        local candidates={first,away,side,-side}
        local best=Vector3.zero
        for _,dir in ipairs(candidates) do if pathClear(root,dir,6) then best=dir;break end end
        state.move=best;state.distance=relative.Magnitude;state.planReason=best.Magnitude>0 and "blight_bait" or "blight_bait_blocked"
        state.nextPlan=nil
    elseif not state.nextPlan or now>=state.nextPlan or arrowPresent~=state.hadArrow or lancerThreat~=state.hadLancerThreat then
        state.move,state.distance,state.planReason=planMovement(root,foeRoot,foeKit,arrow,now,lancerThreat)
        state.nextPlan=now+0.12
    end
    state.hadArrow,state.hadLancerThreat=arrowPresent,lancerThreat
    state.detail=state.stunned and "stunned" or state.planReason
    local delta=foeRoot.Position-root.Position
    local distance=flat(delta).Magnitude
    state.distance=distance
    -- Timing is based on a replicated shot or visual projectile;
    -- neither proves that jumping avoids a server-side PvP hit.
    local bowMove=foeKit=="Archer" and (foeMove=="bow_shot" or foeMove=="bow_charged" or foeMove=="bow_volley")
    local bowAge=moveAt and workspace:GetServerTimeNow()-moveAt or math.huge
    local freshBow=bowMove and bowAge>=-0.1 and bowAge<=0.2
    state.jumpReason=state.navJumpAt==now and state.navJumpReason or "not_needed"
    if foeKit=="Archer" and not hazard and not state.stunned and not state.roundLocked
        and distance>=18 and distance<=75 and (arrow or freshBow)
        and humanoid.FloorMaterial~=Enum.Material.Air and state.move.Magnitude>0.1
        and now-state.lastJump>=1.5 and pathClear(root,state.move,4) then
        local sent=tapKey(Enum.KeyCode.Space)
        if not sent then pcall(function() humanoid.Jump=true end) end
        state.lastJump=now;state.jumpAttempts=(state.jumpAttempts or 0)+1;state.pendingJump={at=now}
        state.jumpReason=sent and "space_input" or "humanoid_request"
    end
    local face=flat(root.CFrame.LookVector)
    local direction=flat(delta)
    local facing=face.Magnitude>0.01 and direction.Magnitude>0.01 and face.Unit:Dot(direction.Unit) or 0
    local line=visible(character,foe,root.Position+Vector3.new(0,1,0),foeRoot.Position+Vector3.new(0,1,0))
    local tool=character:FindFirstChildWhichIsA("Tool")
    local guardHazardSafe=not hazard or hazard.gap>=math.max(hazard.hold or 0,hazard.leave+1.5)+1
    -- Against a bow, keep moving out of the hazard while attempting to guard.
    -- Whether the server accepts simultaneous movement and guard is unknown.
    local bowGuardSafe=guardHazardSafe or (foeKit=="Archer" and hazard~=nil)
    local rawCharge=foe:GetAttribute("Charging")
    local foeCharge=tonumber(rawCharge)
    state.foeCharging=foeCharge or -1
    -- The opponent's Charging attribute can be replicated before the arrow;
    -- if absent, keep the usual reactive guard rather than guessing a shot.
    local chargeThreat=foeKit=="Archer" and foeCharge and foeCharge>0
        and (distance>ownReach+6 or foeCharge>=0.5) and distance<=90 and line and bowGuardSafe
    state.chargeThreat=chargeThreat==true
    if state.keys[Enum.KeyCode.F] and state.blockReason=="charge_guard" then
        local started=state.blockStartedAt or now
        if foeKit=="Archer" and foeCharge and foeCharge>0 and bowGuardSafe then
            state.chargeGuardEndedAt=nil
            state.blockUntil=math.min(started+1.5,math.max(state.blockUntil or now,now+0.25))
        else
            -- The bow can fire at close range immediately after charging ends.
            -- Hold briefly through that shot before allowing the counterattack.
            state.chargeGuardEndedAt=state.chargeGuardEndedAt or now
            local untilShot=state.chargeGuardEndedAt+0.24
            if arrow and arrow.eta<=0.45 then untilShot=math.max(untilShot,now+math.min(0.35,arrow.eta+0.06)) end
            state.blockUntil=math.min(started+1.5,math.max(state.blockUntil or now,untilShot))
        end
    end
    local stopChargeGuard=state.blockReason=="charge_guard" and not bowGuardSafe
    -- At range, a stream of observed arrows can outlast the normal 0.3 s
    -- guard. Extend on new shots, with a cap so closing and attacks resume.
    if state.keys[Enum.KeyCode.F] and state.blockReason=="arrow_guard" and foeKit=="Archer"
        and distance>ownReach+6 and bowGuardSafe and state.lastEnemyArrowAt
        and now-state.lastEnemyArrowAt<=0.45 then
        local started=state.blockStartedAt or now
        local extended=math.min(started+1.5,state.lastEnemyArrowAt+0.32)
        if extended>(state.blockUntil or 0)+0.01 then
            state.blockUntil=extended
            state.arrowGuardExtensions=(state.arrowGuardExtensions or 0)+1
        end
    end
    -- Brief guards around observed attacks. A held shield suppresses the
    -- game's attack input, so impose a release window before the next guard.
    local actualDash=reachBreak and dashDirection(humanoid,root) or nil
    local gapAligned=actualDash and state.move.Magnitude>0.1 and actualDash:Dot(state.move.Unit)>0.8
    local moveAge=moveAt and workspace:GetServerTimeNow()-moveAt or math.huge
    -- Release after a short guard so we do not suppress attacks through
    -- the opponent's entire combo. Server timing and protection are unknown.
    if state.keys[Enum.KeyCode.F] and (state.stunned or state.roundLocked or gapAligned or stopChargeGuard or now>=(state.blockUntil or 0)) then
        local started=state.blockStartedAt or now
        local predicted=state.blockReason=="predicted_parry"
        releaseKey(Enum.KeyCode.F);state.blockUntil=nil;state.blockStartedAt=nil
        state.guardAttackAt=math.max(now+0.02,started+BLOCK_INPUT_MIN+0.02)
        state.chargeGuardEndedAt=nil
        state.nextBlockAt=now+(predicted and PARRY_REARM_TIME or 0.3);state.blockReason="released"
    end
    local meleeMove=type(foeMove)=="string" and (string.sub(foeMove,1,5)=="glad_"
        or string.sub(foeMove,1,6)=="lance_" or string.sub(foeMove,1,5)=="bers_")
    local meleeThreat=meleeMove and distance<=15 and moveAge>=-0.1 and moveAge<=math.min(0.32,math.max(0.16,moveDuration))
    local threatKey=meleeThreat and (foeMove..":"..tostring(moveAt)) or nil
    local arrowThreat=foeKit=="Archer" and arrow and arrow.eta<=0.35 and distance<=85
    -- Skirting an enemy ability outside its estimated area does not make an
    -- incoming melee attack safe. Permit guard with a margin; keep retreat
    -- priority inside the hazard. The actual server radius is not known.
    state.guardHazardSafe=guardHazardSafe;state.guardMeleeThreat=meleeThreat==true
    local nextMove=PARRY_NEXT[foeMove]
    local edgeKey=nextMove and (foeMove..">"..nextMove) or nil
    local edge=nextMove and timingMean(state.parryEdges,edgeKey) or nil
    local nextImpact=nextMove and timingMean(state.parryHits,nextMove) or nil
    local currentImpact=timingMean(state.parryHits,foeMove)
    state.parryNext=nextMove or "";state.parryDueIn=nil
    state.parryEdgeSamples=edgeKey and state.parryEdges and state.parryEdges[edgeKey] and #state.parryEdges[edgeKey] or 0
    state.parryHitSamples=nextMove and state.parryHits and state.parryHits[nextMove] and #state.parryHits[nextMove] or 0
    local dueIn=edge and nextImpact and moveAt and (moveAt+edge+nextImpact-PARRY_INPUT_LEAD-workspace:GetServerTimeNow()) or nil
    local riposte=(state.riposteUntil or 0)>now
    local parryDistance=enemyReach>0 and enemyReach+3 or 13
    local preparing=dueIn and dueIn>=-0.025 and dueIn<=0.25 and currentImpact
        and workspace:GetServerTimeNow()>=moveAt+currentImpact+0.01 and distance<=parryDistance
        and guardHazardSafe and not reachBreak and not riposte
    if dueIn then
        state.parryDueIn=dueIn
        local predictionKey=tostring(moveAt)..">"..nextMove
        if predictionKey~=state.lastPredictionKey then
            state.lastPredictionKey=predictionKey;state.parryPredictions=(state.parryPredictions or 0)+1
        end
    end
    if preparing and state.keys[Enum.KeyCode.F] and now-(state.blockStartedAt or now)>=0.15 and dueIn>=0.15 then
        local started=state.blockStartedAt or now
        releaseKey(Enum.KeyCode.F);state.blockUntil=nil;state.blockStartedAt=nil
        state.guardAttackAt=math.max(now+0.02,started+BLOCK_INPUT_MIN+0.02)
        state.nextBlockAt=now+PARRY_REARM_TIME;state.parryReason="prepare_next"
    end
    local predictedDue=preparing and dueIn>=-0.025 and dueIn<=0.035
    if predictedDue and not state.keys[Enum.KeyCode.F] and not state.stunned and not state.roundLocked
        and not state.heldTool and now>=(state.nextBlockAt or 0) and state.focused
        and not UserInputService:GetFocusedTextBox() and not UserInputService:IsKeyDown(Enum.KeyCode.F) then
        if sendKey(true,Enum.KeyCode.F) then
            state.keys[Enum.KeyCode.F]=true;state.blockUntil=now+PARRY_TAP_TIME;state.blockStartedAt=now
            state.blockReason="predicted_parry";state.parryReason="predicted_input"
            state.parryAttempts=(state.parryAttempts or 0)+1;state.blockAttempts=(state.blockAttempts or 0)+1
            if state.pendingBlock then state.blockUnconfirmed=(state.blockUnconfirmed or 0)+1 end
            state.pendingBlock={at=now}
        else state.parryReason="input_unavailable" end
    end
    if not state.keys[Enum.KeyCode.F] and not state.stunned and not state.roundLocked and not reachBreak
        and not preparing and not riposte and not state.heldTool and now>=(state.nextBlockAt or 0)
        -- Keep attempting a guard during a sidestep: observed arrows can
        -- still hit after local evasion because of timing and replication.
        and ((arrowThreat or chargeThreat) and bowGuardSafe
            or meleeThreat and guardHazardSafe and threatKey~=state.lastBlockThreat) then
        if state.focused and not UserInputService:GetFocusedTextBox() and not UserInputService:IsKeyDown(Enum.KeyCode.F)
            and sendKey(true,Enum.KeyCode.F) then
            state.keys[Enum.KeyCode.F]=true;state.blockUntil=now+0.3;state.blockStartedAt=now
            state.blockReason=arrowThreat and "arrow_guard" or chargeThreat and "charge_guard" or "melee_guard"
            if state.blockReason=="charge_guard" then state.chargeGuardEndedAt=nil end
            state.lastBlockThreat=threatKey or state.lastBlockThreat
            state.blockAttempts=(state.blockAttempts or 0)+1
            if state.pendingBlock then state.blockUnconfirmed=(state.blockUnconfirmed or 0)+1 end
            state.pendingBlock={at=now}
        else state.blockReason="input_unavailable" end
    end
    -- Gladiator has wide sword swings, not Lancer's dash thrust.
    local thrustWindow=false
    local attackRange=ownReach
    local requiredFacing=0.55
    state.attackRange,state.attackFacing=attackRange,facing
    local retreatingBlight=hazard and hazard.kind=="blight" and hazard.gap<hazard.leave+1.5
    if retreatingBlight then
        local position=flat(root.Position)
        if not state.blightAnchor or (position-state.blightAnchor).Magnitude>=1.5 then
            state.blightAnchor=position;state.blightAnchorAt=now;state.blightStuck=false
        elseif now-(state.blightAnchorAt or now)>=0.6 then state.blightStuck=true end
    else state.blightAnchor=nil;state.blightAnchorAt=nil;state.blightStuck=false end
    local blightAttackWindow=retreatingBlight and now-(blight.detected or now)>=0.55
        and (tonumber(humanoid.WalkSpeed) or 0)>0
    if hazard and hazard.gap<hazard.leave+1.5 and not blightAttackWindow then state.attackReason=hazard.kind.."_retreat"
    elseif state.stunned or state.roundLocked then state.attackReason="stunned_or_round_pause"
    elseif state.keys[Enum.KeyCode.F] then state.attackReason="blocking"
    elseif now<(state.guardAttackAt or 0) then state.attackReason="block_release_pending"
    elseif player:GetAttribute("CombatState")~="Alive" or opponent:GetAttribute("CombatState")~="Alive"
        or foeHum.Health<=0 or foe:GetAttribute("Downed")==true then state.attackReason="combatant_unavailable"
    elseif not tool then state.attackReason="no_tool"
    elseif not line then state.attackReason="line_blocked"
    elseif distance>attackRange then state.attackReason="out_of_range"
    elseif math.abs(delta.Y)>=12 then state.attackReason="height_difference"
    elseif facing<=requiredFacing then state.attackReason="facing"
    elseif now-state.lastAttack<0.22 or state.heldTool then state.attackReason="input_interval"
    else
        state.attackReason="attempting"
        local ok=pcall(function() tool:Activate() end)
        if ok then
            state.heldTool=tool;state.lastAttack=now;state.attackAttempts=(state.attackAttempts or 0)+1
            if thrustWindow then state.dashThrustAttempts=(state.dashThrustAttempts or 0)+1 end
            task.delay(0.06,function() if state.heldTool==tool then pcall(function() tool:Deactivate() end);state.heldTool=nil end end)
        else state.attackReason="tool_activate_failed" end
    end
    local ability=abilityId()
    state.abilityReason="outside_engagement"
    local radius=20*(1+(state.areaBonus or ASSUMED_SKILL_ABILITY_AREA))
    local lead=flat(foeRoot.AssemblyLinearVelocity)*0.25
    if lead.Magnitude>6 then lead=lead.Unit*6 end
    local predicted=relative+lead
    state.orcusRadius=radius;state.orcusPredicted=predicted.Magnitude
    if ability~="iron_skin" and ability~="orcus_blight" then state.abilityReason="supported_ability_not_confirmed"
    elseif state.stunned or state.roundLocked then state.abilityReason="stunned_or_round_pause"
    elseif state.keys[Enum.KeyCode.F] then state.abilityReason="blocking"
    elseif ownReady>workspace:GetServerTimeNow() then state.abilityReason="cooldown"
    elseif ability=="orcus_blight" and now<(state.orcusRetryAfter or 0) then state.abilityReason="retry_wait"
    elseif ability=="orcus_blight" and distance>radius-0.8 then state.abilityReason="outside_radius_estimate"
    elseif ability=="orcus_blight" and math.abs(delta.Y)>=12 then state.abilityReason="height_difference"
    elseif ability=="orcus_blight" and not line then state.abilityReason="line_blocked"
    elseif ability=="orcus_blight" and distance>12 and predicted.Magnitude>radius then state.abilityReason="predicted_escape"
    elseif player:GetAttribute("CombatState")=="Alive" and opponent:GetAttribute("CombatState")=="Alive"
        and foeHum.Health>0 and foe:GetAttribute("Downed")~=true and now-state.lastAbility>=1 then
        -- An enemy hazard is not itself a reason to suppress our ability.
        local orcusEligible=ability=="orcus_blight"
        local ironEligible=ability=="iron_skin" and (distance<=17 or foeKit~="Archer" and distance<=30 and closing>=8
            or foeKit=="Lancer" and distance<=45 and closing>=12
            or foeKit=="Archer" and distance<=58 and (closing>=5 or arrow~=nil or freshBow))
        if orcusEligible or ironEligible then
            state.lastAbility=now
            if tapKey(Enum.KeyCode.R) then
                state.abilityAttempts=(state.abilityAttempts or 0)+1;state.abilityReason="sent"
                if orcusEligible then
                    state.orcusRetryAfter=now+2.5
                    state.pendingOrcus={at=now,previousReady=ownReady}
                end
            else state.abilityReason="input_unavailable" end
        end
    end
    local escape=0
    if direction.Magnitude>0.01 then escape=flat(foeRoot.AssemblyLinearVelocity):Dot(direction.Unit) end
    state.foeDashing=foe:GetAttribute("Dashing")==true
    if foeKit=="Archer" and (escape>28 or state.foeDashing and escape>12) then state.foeEscapeUntil=now+0.9 end
    state.foeFastEscape=(state.foeEscapeUntil or 0)>now
    local charges=dashCharges(now)
    state.dashEstimate=charges
    state.dashReason="not_needed"
    -- Do not sidestep or use a sideways dash against Archer projectiles.
    local urgent=foeKit~="Archer" and arrow and arrow.eta<0.3
    local hazardUrgent=hazard~=nil and hazard.gap<hazard.leave
    local lancerUrgent=lancerThreat and relative.Magnitude<=45
    local reservedBlight=blightReady and foeKit~="Archer" and not hazard
    local wantsClose=not arrowEvading and (reachBreak or (foeKit=="Archer" and distance>18.5 and distance<80)
        or (foeKit~="Archer" and distance>19 and distance<31 and not lancerThreat and not reservedBlight))
    if reservedBlight and distance>19 and distance<31 then state.dashReason="reserve_for_blight" end
    local wantsCounter=not arrowEvading and state.foeFastEscape and distance>11 and distance<80
    local dashInterval=foeKit=="Archer" and 0.3 or 0.7
    local guardDashAllowed=foeKit=="Archer" and (state.blockReason=="charge_guard" or state.blockReason=="arrow_guard")
    if not state.stunned and not state.roundLocked and (not state.keys[Enum.KeyCode.F] or guardDashAllowed) and player:GetAttribute("CombatState")=="Alive"
        and opponent:GetAttribute("CombatState")=="Alive" and foeHum.Health>0 and foe:GetAttribute("Downed")~=true
        and (hazardUrgent or not hazard and (lancerUrgent or wantsClose or wantsCounter or urgent)) and now-(state.lastDashAttempt or -math.huge)>=dashInterval then
        local archerPressure=foeKit=="Archer" and wantsClose and (distance<=26 or state.foeFastEscape or chargeThreat)
        local reserveAllowed=charges>=2 or (charges==1 and (reachBreak or archerPressure or hazardUrgent or lancerUrgent or wantsCounter or urgent))
        if not reserveAllowed then state.dashReason=charges==0 and "charges_estimated_empty" or "reserve_one"
        else
            local actual=dashDirection(humanoid,root)
            local future=flat(foeRoot.AssemblyLinearVelocity)*0.2
            if future.Magnitude>10 then future=future.Unit*10 end
            local target=foeRoot.Position+future
            local dashDistance=state.statDashDistance or 16
            local landing=actual and root.Position+actual*dashDistance
            local before=flat(target-root.Position).Magnitude
            local after=landing and flat(target-landing).Magnitude or math.huge
            local progress=before-after
            local forward=actual and direction.Magnitude>0.01 and actual:Dot(direction.Unit) or -1
            local safeReachBreak=actual and reachBreak and progress>=2 and after>=1.25 and after<=ownReach+1 and forward>0.8
            local safeClose=actual and progress>=4 and after>=3.5 and forward>0.55
            local safeEvade=actual and urgent and forward>=-0.2 and after<=before+12
                and projectileGap(landing,arrow)>=math.max(5,projectileGap(root.Position,arrow)+2)
            local safeHazard=actual and hazardUrgent
                and hazardClearance(landing,hazard)>=math.max(hazard.leave,hazard.gap+6)
            local foeFacing=flat(foeRoot.CFrame.LookVector)
            local across=foeFacing.Magnitude>0.01 and Vector3.new(-foeFacing.Unit.Z,0,foeFacing.Unit.X) or nil
            local beforeSide=across and math.abs(flat(root.Position-foeRoot.Position):Dot(across)) or 0
            local afterSide=across and landing and math.abs(flat(landing-foeRoot.Position):Dot(across)) or 0
            local safeLancer=actual and lancerUrgent and across and state.move.Magnitude>0.1 and afterSide>=math.max(5,beforeSide+3)
                and actual:Dot(state.move.Unit)>0.8
            local insideMap=true
            if ring and landing then
                local here=flat(root.Position-ring.center).Magnitude
                local there=flat(landing-ring.center).Magnitude
                insideMap=here>ring.radius and there<here or here<=ring.radius and there<=ring.radius-2
            end
            if actual and state.move.Magnitude>0.1 and actual:Dot(state.move.Unit)>0.55 and insideMap
                and (hazard and safeHazard or not hazard and (safeLancer or not lancerUrgent and (safeReachBreak or safeClose or safeEvade))) and pathClear(root,actual,dashDistance+2) then
                state.lastDashAttempt=now
                if tapKey(Enum.KeyCode.Q) then
                    state.lastDash=now;table.insert(state.dashHistory,now)
                    if state.pendingDash then state.dashUnconfirmed=(state.dashUnconfirmed or 0)+1 end
                    state.pendingDash={at=now,moveAt=tonumber(character:GetAttribute("MoveAt")) or 0}
                    state.dashEstimate=dashCharges(now)
                    state.dashAttempts=(state.dashAttempts or 0)+1
                    state.dashReason=safeHazard and hazard.kind.."_evade_attempt" or safeLancer and "lancer_evade_attempt"
                        or safeReachBreak and "reach_break_attempt" or safeEvade and "evade_attempt" or wantsCounter and "counter_escape_attempt" or "close_attempt"
                    state.lastDashReason=state.dashReason
                    if safeReachBreak then
                        state.reachGapState="dash_attempt";state.reachDashAttempts=(state.reachDashAttempts or 0)+1
                    elseif safeLancer or safeHazard or safeEvade then state.evadeDashAttempts=(state.evadeDashAttempts or 0)+1
                    else state.closeDashAttempts=(state.closeDashAttempts or 0)+1 end
                else state.dashReason="input_unavailable" end
            else state.dashReason="path_alignment_or_landing" end
        end
    end
    publish()
end
local function cleanup()
    if not state.active then return end
    state.active=false
    releaseCombat()
    disconnectAll(scoreConnections)
    disconnectAll(targetConnections)
    disconnectAll(localConnections)
    RunService:UnbindFromRenderStep("RankedGladiatorAim")
    RunService:UnbindFromRenderStep("RankedGladiatorMove")
    for _,c in ipairs(connections) do c:Disconnect() end
end
connect(shutdown.Event,cleanup)
connect(screen.Destroying,cleanup)
local function stopByUser()
    cleanup();screen:Destroy()
    print("[RankedGladiator] Stopped current run.")
end
connect(stopButton.MouseButton1Click,stopByUser)
connect(UserInputService.InputBegan,function(input)
    if input.KeyCode==Enum.KeyCode.F8 and not UserInputService:GetFocusedTextBox() then stopByUser() end
end)
connect(UserInputService.WindowFocusReleased,function() state.focused=false;releaseCombat() end)
connect(UserInputService.WindowFocused,function() state.focused=true end)
connect(player:GetAttributeChangedSignal("CombatState"),function()
    local value=player:GetAttribute("CombatState")
    if combatPhase() and value~=nil and value~="Alive" then lockRound("self_"..tostring(value)) end
end)
connect(player:GetAttributeChangedSignal("PvpRespawnAt"),function()
    if combatPhase() and respawning(player,player.Character) then lockRound("self_respawn_timer") end
end)
connect(player.CharacterRemoving,function() releaseCombat();state.reason="character_removing" end)
local nextTick=0
connect(RunService.Heartbeat,function()
    if not state.active then return end
    local now=os.clock()
    if now<nextTick then return end
    nextTick=now+CONTROL_INTERVAL
    if state.lastControlAt then state.controlStepMs=(now-state.lastControlAt)*1000 end
    state.lastControlAt=now
    local ok,err=pcall(tick)
    if not ok then
        state.reason="runtime_error";state.detail=tostring(err);releaseCombat()
        if now-(state.lastErrorLog or -math.huge)>=3 then state.lastErrorLog=now;warn("[RankedGladiator] "..tostring(err)) end
        pcall(publish)
    end
end)
connect(RunService.PreSimulation,applyMovement)
connect(RunService.Heartbeat,applyExtraMovement)
RunService:BindToRenderStep("RankedGladiatorAim",Enum.RenderPriority.Camera.Value-1,aimCamera)
RunService:BindToRenderStep("RankedGladiatorMove",Enum.RenderPriority.Last.Value+1,applyMovement)
print("[RankedGladiator] Started. Press F8 to stop.")
