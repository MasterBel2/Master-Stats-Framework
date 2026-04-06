function widget:GetInfo()
    return {
        name = "Statistics Collection: Builders",
        desc = "Records stats for builders, including time stalled.\n" ..
               "E-stall stats may be inaccurate when mexes fire or cloak during e-stall.",
        author    = "MasterBel2",
        license   = "GNU GPL, v2"
    }
end

local teamIDs = Spring.GetTeamList()

function imap(array, transform)
    local newArray = {}

    for index, value in ipairs(array) do
        table.insert(newArray, transform(index, value))
    end

    return newArray
end

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
                vertices = { x = { 0, 1 }, y = { 0, 0 } },
                AddVertex = function(self, x, y)
                    local vertices = self.vertices
                    -- if y ~= vertices.y[#vertices.y] then
                        vertices.x[#vertices.x + 1] = x
                        vertices.y[#vertices.y + 1] = y
                    -- else
                    --     if #vertices.y > 1 and vertices.y[#vertices.y] == vertices.y[#vertices.y - 1] then
                    --         vertices.x[#vertices.x] = x
                    --     else
                    --         vertices.x[#vertices.x + 1] = x
                    --         vertices.y[#vertices.y + 1] = vertices.y[#vertices.y]
                    --     end
                    -- end
                end,
                AddVertexRelative = function(self, x, y)
                    self:AddVertex(x, y + self.vertices.y[#self.vertices.y])
                end
            }
        end)
    }
end


local buildpowerStalledGraph = Graph()
local passiveBuildPowerGraph = Graph()


local buildpowerRampingGraph = Graph()

function widget:MasterStatsCategories()
    return {
        ["Construction"] = {
            ["Build Power Stalled"] = buildpowerStalledGraph,
            ["Passive Build Power"] = passiveBuildPowerGraph,
            ["Build Power Ramp Up"] = buildpowerRampingGraph,
        },
    }
end

-- Builders scale up their build power linearly over 0.5 of a second (15 frames)
local expectedBuildRate = {}
local buildTargets = {}

local debugInfo = {}

function widget:UnitDestroyed(unitID)
    expectedBuildRate[unitID] = nil
    buildTargets[unitID] = nil
end

function widget:DebugInfo()
    return debugInfo
end

function widget:GameFrame(n)
    for _, teamID in ipairs(teamIDs) do
        local buildPowerStalled = 0
        local passiveBuildPower = 0
        local buildPowerLostRamping = 0
        for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
            local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
            if unitDef.buildSpeed > 0 then
                local buildTarget = Spring.GetUnitIsBuilding(unitID) 
                if buildTarget then
                    local _, _, _, _, buildProgress = Spring.GetUnitHealth(buildTarget)
                    if buildProgress < 1 then
                        if buildTargets[unitID] ~= buildTarget then
                            buildTargets[unitID] = buildTarget
                            expectedBuildRate[unitID] = 0
                        end
                        local currentBuildPower = Spring.GetUnitCurrentBuildPower(unitID)
                        expectedBuildRate[unitID] = math.min(1, (expectedBuildRate[unitID] or 0) + 1/60)
                        local expectedBuildPower = unitDef.buildSpeed * (1 - expectedBuildRate[unitID])
                        
                        local _, metalUse, _, energyUse = Spring.GetUnitResources(unitID)
                        local targetUnitDef = UnitDefs[Spring.GetUnitDefID(buildTarget)]
                        local expectedMetalUse = currentBuildPower * unitDef.buildSpeed * (targetUnitDef.metalCost / targetUnitDef.buildTime)

                        -- local expectedMetalUse = targetUnitDef.metalCost / (targetUnitDef.buildTime / expectedBuildPower) 
                        -- local expectedEnergyUse = targetUnitDef.energyCost / (targetUnitDef.buildTime / expectedBuildPower)

                        if expectedBuildRate[unitID] > 59.5/60 and expectedMetalUse > 0 then
                            passiveBuildPower = passiveBuildPower + (expectedMetalUse - metalUse) / expectedMetalUse * unitDef.buildSpeed
                        end

                        if expectedBuildRate[unitID] - currentBuildPower < 0.0001 then
                            buildPowerLostRamping = buildPowerLostRamping + expectedBuildPower
                        end
                        buildPowerStalled = buildPowerStalled + unitDef.buildSpeed * math.max(0, (expectedBuildRate[unitID] - currentBuildPower))

                        debugInfo[unitID] = {
                            currentBuildPower = currentBuildPower,
                            expectedBuildRate = expectedBuildRate[unitID],
                            expectedBuildPower = expectedBuildPower,
                            buildSpeed = unitDef.buildSpeed,
                            metalUse = metalUse,
                            energyUse = energyUse,
                            expectedMetalUse = expectedMetalUse,
                            passiveBuildPower = passiveBuildPower,
                            buildPowerLostRamping = buildPowerLostRamping,
                            buildPowerStalled = buildPowerStalled,
                        }
                    end
                end
            end
        end
        do

            passiveBuildPowerGraph.lines[teamID + 1]:AddVertexRelative(n, passiveBuildPower / 30)
            buildpowerStalledGraph.lines[teamID + 1]:AddVertexRelative(n, buildPowerStalled / 30)
        end
        do
            buildpowerRampingGraph.lines[teamID + 1]:AddVertexRelative(n, buildPowerLostRamping / 30)
        end
    end
end

function widget:Initialize()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end

function widget:Shutdown()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end