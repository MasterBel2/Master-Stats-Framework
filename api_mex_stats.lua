function widget:GetInfo()
    return {
        name = "Statistics Collection: Metal Extraction",
        desc = "Records stats for metal extraction, including extraction lost due to e-stall.\n" ..
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
                vertices = { x = { 0 }, y = { 0 } }
            }
        end)
    }
end


local metalExtractedGraph = Graph()
local metalLostDuringEStallGraph = Graph()

function widget:MasterStatsCategories()
    return {
        ["Metal Extraction"] = {
            ["Metal Extracted"] = metalExtractedGraph,
            ["Metal Lost During E-Stall"] = metalLostDuringEStallGraph,
        },
    }
end

function widget:GameFrame(n)
    for _, teamID in ipairs(teamIDs) do
        local metalExtracted = 0
        local metalLostDuringEStall = 0
        for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
            local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
            if unitDef.extractsMetal ~= 0 then
                local _, _, _, energyUse = Spring.GetUnitResources(unitID)
                local metalExtraction = Spring.GetUnitMetalExtraction(unitID)
                -- Spring.Echo(energyUse)
                -- Spring.Echo("upkeep: " .. unitDef.energyUpkeep)
                -- Spring.Echo("metalExtraction: " .. metalExtraction)
                -- Spring.Echo(math.min(energyUse, unitDef.energyUpkeep) / unitDef.energyUpkeep * metalExtraction)
                -- Spring.Echo(((unitDef.energyUpkeep - math.min(energyUse, unitDef.energyUpkeep)) / unitDef.energyUpkeep * metalExtraction))
                -- error()
                metalExtracted = metalExtracted + math.min(energyUse, unitDef.energyUpkeep) / unitDef.energyUpkeep * metalExtraction
                -- metalExtracted = metalExtracted + metalExtraction
                metalLostDuringEStall = metalLostDuringEStall + ((unitDef.energyUpkeep - math.min(energyUse, unitDef.energyUpkeep)) / unitDef.energyUpkeep * metalExtraction)
            end
        end
        metalExtracted = metalExtracted / 30
        metalLostDuringEStall = metalLostDuringEStall / 30

        local metalExtractedVertices = metalExtractedGraph.lines[teamID + 1].vertices
        metalExtractedVertices.x[#metalExtractedVertices.x + 1] = n
        metalExtractedVertices.y[#metalExtractedVertices.y + 1] = metalExtractedVertices.y[#metalExtractedVertices.y] + metalExtracted

        local metalLostDuringEStallVertices = metalLostDuringEStallGraph.lines[teamID + 1].vertices
        metalLostDuringEStallVertices.x[#metalLostDuringEStallVertices.x + 1] = n
        metalLostDuringEStallVertices.y[#metalLostDuringEStallVertices.y + 1] = metalLostDuringEStallVertices.y[#metalLostDuringEStallVertices.y] + metalLostDuringEStall
    end
end

function widget:Initialize()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end

function widget:Shutdown()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end