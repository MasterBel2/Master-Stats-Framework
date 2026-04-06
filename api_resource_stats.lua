function widget:GetInfo()
	return {
        name      = "Statistics Collection: Resource Storage",
        desc      = "Records Resource statistics",
        author    = "MasterBel2",
        date      = "January 2023",
        license   = "GNU GPL, v2",
        enabled   = true, --enabled by default
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
        lines = imap(teamIDs, function(index, teamID)
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

local metalInStorageGraph = Graph("Metal")
local energyInStorageGraph = Graph("Energy")
local metalInUnits = Graph("Metal")
local energyInUnits = Graph("Energy")

function widget:MasterStatsCategories()
    return {
        Resources = {
            ["Metal In Storage"] = metalInStorageGraph,
            ["Energy In Storage "] = energyInStorageGraph
        }
    }
end

function widget:Initialize()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end

function widget:Shutdown()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end

function widget:GameFrame(n)
    if n % 30 ~= 0 then return end
    for _, teamID in ipairs(teamIDs) do

        local metalInStorage = Spring.GetTeamResources(teamID, "metal")
        local energyInStorage = Spring.GetTeamResources(teamID, "energy")
        if metalInStorage and energyInStorage then
            table.insert(metalInStorageGraph.lines[teamID + 1].vertices.x, n)
            table.insert(metalInStorageGraph.lines[teamID + 1].vertices.y, metalInStorage)
            table.insert(energyInStorageGraph.lines[teamID + 1].vertices.x, n)
            table.insert(energyInStorageGraph.lines[teamID + 1].vertices.y, energyInStorage)
        end
    end
end
