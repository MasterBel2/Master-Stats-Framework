function widget:GetInfo()
    return {
        name = "Statistics Collection: Default Stats",
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
                vertices = { x = { 0, 0 }, y = { 0, 0 } }
            }
        end)
    }
end

local totalMetalUsedGraph = Graph("Total Metal Used")
local totalMetalProducedGraph = Graph("Total Metal Produced")
local totalMetalExcessGraph = Graph("Total Metal Excess")
local totalMetalReceivedGraph = Graph("Total Metal Received")
local totalMetalSentGraph = Graph("Total Metal Sent")
local totalEnergyUsedGraph = Graph("Total Energy Used")
local totalEnergyProducedGraph = Graph("Total Energy Produced")
local totalEnergyExcess = Graph("Total Energy Excess")
local totalEnergyReceivedGraph = Graph("Total Energy Received")
local totalEnergySentGraph = Graph("Total Energy Sent")
local totalDamageDealtGraph = Graph("Total Damage Dealt")
local totalDamageReceivedGraph = Graph("Total Damage Received")
local totalUnitsProducedGraph = Graph("Total Units Produced")
local totalUnitsDiedGraph = Graph("Total Units Died")
local totalUnitsReceivedGraph = Graph("Total Units Recieved")
local totalUnitsSentGraph = Graph("Total Units Sent")
local totalUnitsCapturedGraph = Graph("Total Units Stolen")
local totalUnitsOutCapturedGraph = Graph("Total Units Lost")
local totalUnitsKilledGraph = Graph("Total Units Killed")

local graphs = {
    metalUsed = totalMetalUsedGraph,
    metalExcess = totalMetalExcess,
    metalProduced = totalMetalProducedGraph,
    metalReceived = totalMetalReceivedGraph,
    metalSent = totalMetalSentGraph,
    energyUsed = totalEnergyUsedGraph,
    energyProduced = totalEnergyProducedGraph,
    energyExcess = totalEnergyExcess,
    energyReceived = totalEnergyReceivedGraph,
    energySent = totalEnergySentGraph,
    damageDealt = totalDamageDealtGraph,
    damageReceived = totalDamageReceivedGraph,
    unitsProduced = totalUnitsProducedGraph,
    unitsDied = totalUnitsDiedGraph,
    unitsReceived = totalUnitsReceivedGraph,
    unitsSent = totalUnitsSentGraph,
    unitsCaptured = totalUnitsCapturedGraph,
    unitsOutCaptured = totalUnitsOutCapturedGraph,
    unitsKilled = totalUnitsKilledGraph
}

function widget:MasterStatsCategories()
    return {
        Resources = {
            ["Total Metal Used"] = totalMetalUsedGraph,
            ["Total Metal Produced"] = totalMetalProducedGraph,
            ["Total Metal Excess"] = totalMetalExcessGraph,
            ["Total Metal Received"] = totalMetalReceivedGraph,
            ["Total Metal Sent"] = totalMetalSentGraph,
            ["Total Energy Used"] = totalEnergyUsedGraph,
            ["Total Energy Produced"] = totalEnergyProducedGraph,
            ["Total Energy Excess"] = totalEnergyExcess,
            ["Total Energy Received"] = totalEnergyReceivedGraph,
            ["Total Energy Sent"] = totalEnergySentGraph,
        },
        Damage = {
            ["Total Damage Dealt"] = totalDamageDealtGraph,
            ["Total Damage Received"] = totalDamageReceivedGraph,
        },
        Units = {
            ["Total Units Produced"] = totalUnitsProducedGraph,
            ["Total Units Died"] = totalUnitsDiedGraph,
            ["Total Units Recieved"] = totalUnitsReceivedGraph,
            ["Total Units Sent"] = totalUnitsSentGraph,
            ["Total Units Stolen"] = totalUnitsCapturedGraph,
            ["Total Units Lost"] = totalUnitsOutCapturedGraph,
            ["Total Units Killed"] = totalUnitsKilledGraph,
        }
    }
end

function widget:GameFrame(n)
    if n % 30 ~= 0 then return end
    
    for _, teamID in ipairs(teamIDs) do
        local maxIndex = Spring.GetTeamStatsHistory(teamID)
        local stats = Spring.GetTeamStatsHistory(teamID, maxIndex)
        if stats then
            for key, value in pairs(stats[1]) do
                local graph = graphs[key]
                if graph then
                    local line = graph.lines[teamID + 1]
                    local vertices = line.vertices
                    vertices.x[#vertices.x + 1] = n
                    vertices.y[#vertices.y + 1] = value
                end
            end
        end
    end
end

function widget:Initialize()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end

function widget:Shutdown()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end