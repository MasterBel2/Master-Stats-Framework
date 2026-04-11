function widget:GetInfo()
    return {
        name = "Statistics Collection: Repair, Reclaim, Auto-Heal",
        desc = "Records stats and provides callins & callouts for reclaim, repair, and autoheal.\n\nNote: These statistics aren't necessarily accurate - consider them approximations instead!\n\n" ..
        "When api_custom_callins.lua is present, also provides the following callins:\n" ..
        " - widget:UnitAutoHeal(unitID, healthRestored)\n" ..
        " - widget:UnitReclaim(unitID, reclaimerID, healthRemoved)\n" ..
        " - widget:UnitRepair(unitID, repairerID, healthRestored)\n" ..
        " - widget:FeatureReclaim(featureID, reclaimerID, metalGenerated, energyGenerated)",
        handler = true,
        version   = "2026-04-rev1",
        author    = "MasterBel2",
        license   = "GNU GPL, v2"
    }
end

local teamIDs = Spring.GetTeamList()

--------------------
-- Custom CallIns --
--------------------

local UnitRepair
local FeatureReclaim
local UnitReclaim
local UnitAutoHeal

-----------
-- Cache --
-----------

local spectating, fullView, fullSelect = Spring.GetSpectatingState(Spring.GetMyPlayerID())

local unitDefCache = {}
local unitDefIDCache = {}
local damagedUnits = {}

local unitHealthDamageChange = {}
local unitHealthBuilderChange = {}
local unitHealthCache = {}
local builderIDs = {}
local finishedUnitIDs = {}
local ignoredUnitIDs = {}

-- local reportedUnits = {}

-----------
-- Graph --
-----------

function Graph(yUnit)
    return {
        xUnit = "Frames",
        yUnit = yUnit,
        discrete = true,
        lines = table.imap(teamIDs, function(index, teamID)
            local r, g, b, a = Spring.GetTeamColor(teamID)
            local playerID = Spring.GetPlayerList(teamID)[1]
            local name = playerID and Spring.GetPlayerInfo(playerID)
            return teamID + 1, {
                title = name,
                color = { r = r, g = g, b = b, a = a },
                vertices = { x = { 0, 0 }, y = { 0, 0 } }
            }
        end),
        NewFrame = function(self, n)
            for _, line in ipairs(self.lines) do
                local vertexCount = #line.vertices.y
                if n % 30 ~= 0 or line.vertices.y[vertexCount] == line.vertices.y[vertexCount - 1] then
                    line.vertices.x[vertexCount] = n
                else
                    line.vertices.y[vertexCount + 1] = line.vertices.y[vertexCount]
                    line.vertices.x[vertexCount + 1] = n
                end
            end
        end
    }
end

local reclaimDamageDealtGraph = Graph("Health Reclaimed")
local reclaimSelfDamageGraph = Graph("Health Reclaimed")
-- local unitReclaimMetalRecycled = Graph()
-- local unitReclaimMetalStolen = Graph()

local repairDamageMitigatedGraph = Graph("Health Repaired")--
local autohealGraphData = Graph("Health Autohealed")--

local featureReclaimMetalGraph = Graph("Metal Reclaimed")--
local featureReclaimEnergyGraph = Graph("Energy Reclaimed")--

local _MasterStatsCategories = {
    ["Reclaim / Repair"] = {
        ["Reclaim Damage Dealt"] = reclaimDamageDealtGraph,
        ["Reclaim Self Damage"] = reclaimSelfDamageGraph,
        ["Repair Damage Mitigated"] = repairDamageMitigatedGraph,
        ["Autoheal Health Restored"] = autohealGraphData,
        ["Feature Reclaim Metal Income"] = featureReclaimMetalGraph,
        ["Feature Reclaim Energy Income"] = featureReclaimEnergyGraph,
    }
}

function widget:MasterStatsCategories()
    return _MasterStatsCategories
end

-------------
-- Helpers --
-------------

local frameStoppedReclaiming = {}
local buildersReclaiming = {}

function widget:DebugInfo()
    return buildersReclaiming
end
-- returns 
function Spring.GetUnitIsReclaiming(builderID)
    local reclaimTarget = buildersReclaiming[builderID]
    if buildersReclaiming[builderID] == true then
        local commands = Spring.GetUnitCommands(builderID, 1)
        reclaimTarget = (#commands[1].params == 1 or #commands[1].params == 5) and commands[1].params[1]     
    end
    if reclaimTarget then
        return (unitDefCache[reclaimTarget] or Spring.GetFeatureDefID(reclaimTarget - Game.maxUnits)) and reclaimTarget
    else
        return nil, lastReclaimTarget
    end
end

local function firstCommandIsReclaim(unitID)
    local commands = Spring.GetUnitCommands(unitID, 1)
    return commands and commands[1] and commands[1].id == CMD.RECLAIM
end

-------------
-- Updates --
-------------

function widget:GameFrame(n)
    reclaimDamageDealtGraph:NewFrame(n)
    reclaimSelfDamageGraph:NewFrame(n)
    -- unitReclaimMetalRecycled:NewFrame(n)
    -- unitReclaimMetalStolen:NewFrame(n)
    repairDamageMitigatedGraph:NewFrame(n)
    autohealGraphData:NewFrame(n)
    featureReclaimMetalGraph:NewFrame(n)
    featureReclaimEnergyGraph:NewFrame(n)

    for builderID, _ in pairs(builderIDs) do
        if not Spring.GetUnitIsDead(builderID) then
            local builderTeam = Spring.GetUnitTeam(builderID)
            local builderAllyTeam = Spring.GetUnitAllyTeam(builderID)
            local buildTarget = Spring.GetUnitIsBuilding(builderID)
            local builderDef = unitDefCache[unitDefIDCache[builderID]]
            if buildTarget then
                if not Spring.GetUnitIsDead(buildTarget) then
                    local _, maxHealth, _, _, buildProgress = Spring.GetUnitHealth(buildTarget)
                    if buildProgress > 0.99999 then
                        local targetDef = unitDefCache[unitDefIDCache[buildTarget]]

                        -- Note: You can repair enemy units, but currently we dont check for that!
                        local healthRepaired = maxHealth / targetDef.buildTime * builderDef.buildSpeed / 30 -- * (Spring.GetUnitCurrentBuildPower(builderID) or 0) -- !! THIS DOESNT ACTUALLY IMPACT REPAIR
                        unitHealthBuilderChange[buildTarget] = unitHealthBuilderChange[buildTarget] + healthRepaired
                        
                        UnitRepair(buildTarget, builderID, healthRepaired)

                        local yVertices = repairDamageMitigatedGraph.lines[builderTeam + 1].vertices.y
                        yVertices[#yVertices] = yVertices[#yVertices] + healthRepaired
                    end
                end
            else
                local reclaimTarget = Spring.GetUnitIsReclaiming(builderID)
                if reclaimTarget and reclaimTarget ~= true then
                    if reclaimTarget > Game.maxUnits then
                        local metalMake, _, energyMake, _ = Spring.GetUnitResources(builderID)

                        local metalReclaimed = (metalMake - (builderDef.metalMake or 0)) / 30
                        local energyReclaimed = (energyMake - (builderDef.energyMake or 0)) / 30

                        if (metalReclaimed > 0) or (energyReclaimed > 0) then
                            FeatureReclaim(reclaimTarget, builderID, metalReclaimed, energyReclaimed)
                        end

                        local featureReclaimMetalYVertices = featureReclaimMetalGraph.lines[builderTeam + 1].vertices.y
                        featureReclaimMetalYVertices[#featureReclaimMetalYVertices] = featureReclaimMetalYVertices[#featureReclaimMetalYVertices] + metalReclaimed
                        local featureReclaimEnergyYVertices = featureReclaimEnergyGraph.lines[builderTeam + 1].vertices.y
                        featureReclaimEnergyYVertices[#featureReclaimEnergyYVertices] = featureReclaimEnergyYVertices[#featureReclaimEnergyYVertices] + energyReclaimed
                    else
                        if not Spring.GetUnitIsDead(reclaimTarget) then
                            local builderAllyTeam = Spring.GetUnitAllyTeam(builderID)
                            local targetAllyTeam = Spring.GetUnitAllyTeam(reclaimTarget)

                            local _, maxHealth = Spring.GetUnitHealth(reclaimTarget)
                            local targetDefID = unitDefIDCache[reclaimTarget]
                            
                            if targetDefID then
                                local targetDef = unitDefCache[targetDefID]
                                -- Use GetUnitCurrentBuildPower to detect while the reclaiming happens, but the reclaim doesnt respect the current build power
                                local healthReclaimed = maxHealth / targetDef.buildTime * math.ceil((Spring.GetUnitCurrentBuildPower(builderID) or 0)) * builderDef.buildSpeed / 30
                                unitHealthBuilderChange[builderID] = unitHealthBuilderChange[builderID] - healthReclaimed

                                UnitReclaim(reclaimTarget, builderID, healthReclaimed)

                                if builderAllyTeam == targetAllyTeam then
                                    local yVertices = reclaimSelfDamageGraph.lines[builderTeam + 1].vertices.y
                                    yVertices[#yVertices] = yVertices[#yVertices] + healthReclaimed
                                else
                                    local yVertices = reclaimDamageDealtGraph.lines[builderTeam + 1].vertices.y
                                    yVertices[#yVertices] = yVertices[#yVertices] + healthReclaimed
                                end
                            -- else
                                -- if not reportedUnits[reclaimTarget] then
                                --     reportedUnits[reclaimTarget] = true
                                    -- Spring.Echo("Failed to find unit def id for unit " .. reclaimTarget .. "(max units: " .. Game.maxUnits .. ", isDead: " .. tostring(Spring.GetUnitIsDead(reclaimTarget) or "nil") .. ")")
                                -- end
                            end
                        end
                    end
                end
            end
        end
    end

    -- TODO: Iterate only on damaged units
    for unitID, _ in pairs(damagedUnits) do
        if (not ignoredUnitIDs[unitID]) then
            local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(unitID)
            if buildProgress > 0.99999 then
                local unitTeam = Spring.GetUnitTeam(unitID)
                if not health then error() end
                local healthChange = health - unitHealthCache[unitID]
                unitHealthCache[unitID] = health or 0
                
                local unitAutoHeal = math.max(0, healthChange + unitHealthDamageChange[unitID] - unitHealthBuilderChange[unitID])
                unitHealthDamageChange[unitID] = 0
                unitHealthBuilderChange[unitID] = 0

                if unitAutoHeal > 0.00001 then
                    local yVertices = autohealGraphData.lines[unitTeam + 1].vertices.y
                    yVertices[#yVertices] = yVertices[#yVertices] + unitAutoHeal
                    UnitAutoHeal(unitID, unitAutoHeal)
                end
            end
        end
    end
end

function widget:UnitCommand(unitID, _, _, cmdID, cmdParams, options, cmdTag)
    if builderIDs[unitID]
    and cmdID == CMD.RECLAIM
    and ((options.shift == false) or firstCommandIsReclaim(unitID)) -- The more we can reduce the number of cases where we do this engine round-trip, the better
    and (#cmdParams == 1 or #cmdParams == 4 or #cmdParams == 5) then
        if (#cmdParams == 1) or (#cmdParams == 5) then
            buildersReclaiming[unitID] = (unitDefIDCache[cmdParams[1]] or Spring.GetFeatureDefID(cmdParams[1] - Game.maxUnits)) and cmdParams[1]
        else
            buildersReclaiming[unitID] = true
        end
    else
        buildersReclaiming[unitID] = nil
    end
end
function widget:UnitCmdDone(unitID)
    buildersReclaiming[unitID] = nil
    if builderIDs[unitID] then
        local commands = Spring.GetUnitCommands(unitID, 1)
        if commands and commands[1] and commands[1].id == CMD.RECLAIM then
            self:UnitCommand(unitID, nil, nil, commands[1].id, commands[1].params, commands[1].options)
        end
    end
end

function widget:PlayerChanged(playerID)
    if playerID == Spring.GetMyPlayerID() then
        spectating, fullView, fullSelect = Spring.GetSpectatingState(playerID)
    end
end

function widget:UnitEnteredRadar(unitID)
    if (not spectating) or (not fullView) then
        ignoredUnitIDs[unitID] = true
    end
end

function widget:UnitEnteredLos(unitID, unitTeam, unitAllyTeam, unitDefID)
    if ((not spectating) or (not fullView)) and unitDefID then
        ignoredUnitIDs[unitID] = nil
        self:UnitCreated(unitID, unitDefID)
    end
end
function widget:UnitLeftLos(unitID, unitTeam, unitAllyTeam, unitDefID)
    if (not spectating) or (not fullView) then
        self:UnitDestroyed(unitID)
        local _, radar = Spring.GetUnitLosState(unitID)
        if radar then
            ignoredUnitIDs[unitID] = true
        end
    end
end
function widget:UnitLeftRadar(unitID)
    if (not spectating) or (not fullView) then
        self:UnitDestroyed(unitID)
        ignoredUnitIDs[unitID] = nil
    end
end
function widget:PlayerChanged(playerID)
    if playerID == Spring.GetMyPlayerID() then
        if spectating and fullView then
            ignoredUnitIDs = {}
        end
    end
end

function widget:UnitCreated(unitID, unitDefID)
    local unitHealth, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
    unitDefCache[unitDefID] = unitDefCache[unitDefID] or UnitDefs[unitDefID]
    unitDefIDCache[unitID] = unitDefID
    unitHealthCache[unitID] = unitHealth or 0
    unitHealthDamageChange[unitID] = 0
    unitHealthBuilderChange[unitID] = 0
    if buildProgress > 0.999 then
        self:UnitFinished(unitID, unitDefID)
    end
    self:UnitCmdDone(unitID)
end

function widget:UnitFinished(unitID, unitDefID)
    local unitDef = unitDefCache[unitDefID]
    if unitDef.buildSpeed ~= 0 and not ignoredUnitIDs[builderID] then
        builderIDs[unitID] = true
    end

    local unitHealth, maxHealth = Spring.GetUnitHealth(unitID)
    if unitHealth < maxHealth then
        damagedUnits[unitID] = true
    end
end

function widget:UnitDamaged(unitID, _, _, damage, paralyzer)
    if paralyzer then return end
    unitHealthDamageChange[unitID] = (unitHealthDamageChange[unitID] or 0) + damage
    damagedUnits[unitID] = true
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    damagedUnits[unitID] = nil
    builderIDs[unitID] = nil
    unitHealthCache[unitID] = nil
    unitHealthDamageChange[unitID] = nil
    unitHealthBuilderChange[unitID] = nil

    -- if weaponDefID == -12 then
    --     TODO
    -- end
end

function widget:Initialize()
    if WG.MasterStats then WG.MasterStats:Refresh() end

    if WG.CustomCallIns_NewCallIn then 
        UnitRepair = WG.CustomCallIns_NewCallIn(self, "UnitRepair")
        FeatureReclaim = WG.CustomCallIns_NewCallIn(self, "FeatureReclaim")
        UnitReclaim = WG.CustomCallIns_NewCallIn(self, "UnitReclaim")
        UnitAutoHeal = WG.CustomCallIns_NewCallIn(self, "UnitAutoHeal")
    else
        UnitRepair = function() end
        FeatureReclaim = function() end
        UnitReclaim = function() end
        UnitAutoHeal = function() end
    end
    
    for _, unitID in ipairs(Spring.GetAllUnits()) do
        self:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
    end
end

function widget:Shutdown()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end