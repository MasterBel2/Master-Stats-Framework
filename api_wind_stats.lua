function widget:GetInfo()
	return {
	name      = "Statistics Collection: Wind Speed",
	desc      = "Records Wind statistics",
	author    = "MasterBel2",
	date      = "June 2024",
	license   = "GNU GPL, v2",
	enabled   = true, --enabled by default
	}
end

local line = {
    title = "Wind Speed",
    color = { r = 1, g = 1, b = 1, a = 1 },
    vertices = { x = { 0 }, y = { (Game.windMin + Game.windMax) / 2 },  }
}

local lines = { line }

local unitDefs = {
    armsolar = { r = 0, g = 0, b = 1, a = 1 },
    armadvsol = { r = 0, g = 0.5, b = 1, a = 1 },
    corsolar = { r = 1, g = 0, b = 0, a = 1 },
    coradvsol = { r = 1, g = 0.5, b = 0, a = 1 },
    armfus = { r = 0.5, g = 0, b = 1, a = 1 },
    armafus = { r = 0.5, g = 0.5, b = 1, a = 1 },
    corfus = { r = 1, g = 0, b = 0.5, a = 1 },
    corafus = { r = 1, g = 0.5, b = 0.5, a = 1 },
}

for key, color in pairs(unitDefs) do
    local energyMake = UnitDefNames[key].energyMake - UnitDefNames[key].energyUpkeep
    local equivalentSpeed = 37 / UnitDefNames[key].metalCost * energyMake
    table.insert(lines, {
        title = key,
        color = color,
        vertices = { x = { 0, 1 }, y = { equivalentSpeed, equivalentSpeed } }
    })
end

local graph = {
    xUnit = "Frames",
    yUnit = "Energy",
    lines = lines
}

function widget:Initialize()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end

function widget:GameFrame(n)
    local _, _, _, windStrength = Spring.GetWind()
    table.insert(line.vertices.x, n)
    table.insert(line.vertices.y, math.min(25, windStrength))

    for i = 2, #lines do
        lines[i].vertices.x[2] = n
    end
end

function widget:Shutdown()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end

function widget:MasterStatsCategories()
    return {
        ["World"] = {
            ["Wind Speed"] = graph
        }
    }
end