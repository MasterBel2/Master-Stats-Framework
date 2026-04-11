function widget:GetInfo()
	return {
    	name      = "Statistics Collection: APM",
    	desc      = "Records APM statistics for MasterBel2's Custom Stats",
    	author    = "MasterBel2",
    	date      = "January 2023",
    	license   = "GNU GPL, v2"
	}
end

local teamIDs = Spring.GetTeamList()

function table.imap(array, transform)
    local newArray = {}

    for index, value in ipairs(array) do
        table.insert(newArray, transform(index, value))
    end

    return newArray
end

function Graph()
    return {
        xUnit = "Frames",
        yUnit = "Commands",
        -- discrete = true,
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

function Stats()
    return table.imap(teamIDs, function(index, teamID)
        return teamID, { lastFrame = -1, count = 0 }
    end)
end

local totalCommandsGraphData = Graph()
local intervaledCommandsGraphData = Graph()

local totalCommands = Stats()
local intervaledCommands = Stats()

local interval = 30 * 30 -- unit: game frames (1/30th of a second)
-- Every 5 seconds is a bit on thhe noisy side, 10 ok, 30 pretty good

function widget:MasterStatsCategories()
    return {
        APM = {
            Total = totalCommandsGraphData,
            Intervalled = intervaledCommandsGraphData
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
    for lineID, line in ipairs(totalCommandsGraphData.lines) do
        line.vertices.x[#line.vertices.x] = n
    end
    for lineID, line in ipairs(intervaledCommandsGraphData.lines) do
        local currentVertexIndex = #line.vertices.x
        line.vertices.x[currentVertexIndex] = n

        if n % interval == 0 then
            line.vertices.x[currentVertexIndex + 1] = (n / interval) + 1
            line.vertices.y[currentVertexIndex + 1] = 0
        end
    end

    if n % interval == 0 then
        for _, stats in pairs(intervaledCommands) do
            stats.count = 0
        end
    end
end

function widget:UnitCommand(_, _, unitTeam, _, _)
    local gameFrame = Spring.GetGameFrame()
    local stats = totalCommands[unitTeam]

    if stats.lastFrame ~= gameFrame then
        stats.count = stats.count + 1
        stats.lastFrame = gameFrame

        local line = totalCommandsGraphData.lines[unitTeam + 1]
        local vertexCount = #line.vertices.x

        line.vertices.x[vertexCount + 1] = gameFrame
        line.vertices.y[vertexCount + 1] = stats.count
    end

    local intervaledStats = intervaledCommands[unitTeam]
    if intervaledStats.lastFrame ~= gameFrame then
        intervaledStats.count = intervaledStats.count + 1

        local countScaledToPerMinute = intervaledStats.count * 30 * 60 / interval  -- interval is in game frames; scale to minutes for APM

        local line = intervaledCommandsGraphData.lines[unitTeam + 1]
        
        line.vertices.y[#line.vertices.y] = countScaledToPerMinute

        intervaledStats.lastFrame = gameFrame
    end
end
