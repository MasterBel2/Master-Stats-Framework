function widget:GetInfo()
    return {
        name = "Statistics Collection: Resource-Scaled Damage",
        author    = "MasterBel2",
        license   = "GNU GPL, v2",
        version   = "2026-04",
    }
end

local teamIDs = Spring.GetTeamList()

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

function Stats()
    return table.imap(teamIDs, function(index, teamID)
        return teamID, 0
    end)
end


local isSpectator = Spring.GetSpectatingState()
local myPlayerID = Spring.GetMyPlayerID()

local metalDamageMitigatedGraphData = Graph("Metal Equivalent")
local metalDamageDealtGraphData = Graph("Metal Equivalent")
local energyDamageMitigatedGraphData = Graph("Energy Equvalent")
local energyDamageDealtGraphData = Graph("Energy Equivalent")
local metalDamageReceivedGraphData = Graph("Metal Equivalent")
local energyDamageReceivedGraphData = Graph("Energy Equivalent")

local totalMetalDamageMitigated = Stats()
local totalMetalDamageDealt = Stats()
local totalEnergyDamageMitigated = Stats()
local totalEnergyDamageDealt = Stats()
local totalMetalDamageReceived = Stats()
local totalEnergyDamageReceived = Stats()

local _MasterStatsCategories = {
    Efficiency = {
        -- ["Metal-Damage Mitigated"] = metalDamageMitigatedGraphData,
        -- ["Energy-Damage Mitigated"] = energyDamageMitigatedGraphData,
        ["Metal-Damage Received"] = metalDamageReceivedGraphData,
        ["Energy-Damage Received"] = energyDamageReceivedGraphData
    }
}

if isSpectator then
    _MasterStatsCategories.Efficiency["Metal-Damage Dealt"] = metalDamageDealtGraphData
    _MasterStatsCategories.Efficiency["Energy-Damage Dealt"] = energyDamageDealtGraphData
end


-- function widget:PlayerChanged(playerID)
--     if playerID == myPlayerID then
--         isSpectator = Spring.GetSpectatingState()
--
--     end
-- end

function widget:Shutdown()

end

function widget:MasterStatsCategories()
    return _MasterStatsCategories
end

local function UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if unitDefID == UnitDefNames.armcom or unitDefID == UnitDefNames.corcom then return end
    local health, maxHealth = Spring.GetUnitHealth(unitID)
    local healthPreDamage = math.floor(health + damage)

    damage = math.floor(math.min(damage, healthPreDamage))

    local gameFrame = Spring.GetGameFrame()

    local unitDef = UnitDefs[unitDefID]
    local damageRatio = math.min(damage, healthPreDamage) / maxHealth

    local metalDamage = damageRatio * unitDef.metalCost
    local energyDamage = damageRatio * unitDef.energyCost

    if isSpectator and attackerTeam then
        local metalDamageDealtLine = metalDamageDealtGraphData.lines[attackerTeam + 1].vertices
        local energyDamageDealtLine = energyDamageDealtGraphData.lines[attackerTeam + 1].vertices

        totalMetalDamageDealt[attackerTeam] = totalMetalDamageDealt[attackerTeam] + metalDamage
        table.insert(metalDamageDealtLine.x, gameFrame)
        table.insert(metalDamageDealtLine.y, totalMetalDamageDealt[attackerTeam])

        totalEnergyDamageDealt[attackerTeam] = totalEnergyDamageDealt[attackerTeam] + energyDamage
        table.insert(energyDamageDealtLine.x, gameFrame)
        table.insert(energyDamageDealtLine.y, totalEnergyDamageDealt[attackerTeam])
        -- table.insert(energyDamageDealtLine, { gameFrame, totalEnergyDamageDealt[attackerTeam] })
    end

    local _, _, _, _, _, unitAllyTeam = Spring.GetTeamInfo(unitTeam)

    if isSpectator or unitAllyTeam == Spring.GetMyAllyTeamID() then
        local metalDamageReceivedLine = metalDamageReceivedGraphData.lines[unitTeam + 1].vertices
        local energyDamageReceivedLine = energyDamageReceivedGraphData.lines[unitTeam + 1].vertices

        totalMetalDamageReceived[unitTeam] = totalMetalDamageReceived[unitTeam] + metalDamage
        table.insert(metalDamageReceivedLine.x, gameFrame)
        table.insert(metalDamageReceivedLine.y, totalMetalDamageReceived[unitTeam])

        totalEnergyDamageReceived[unitTeam] = totalEnergyDamageReceived[unitTeam] + energyDamage
        table.insert(energyDamageReceivedLine.x, gameFrame)
        table.insert(energyDamageReceivedLine.y, totalEnergyDamageReceived[unitTeam])
    end
end

function widget:Initialize()
    if WG.MasterStats then WG.MasterStats:Refresh() end

    if Spring.IsReplay() then
        if not widgetHandler:RegisterGlobal("UnitDamagedReplay", UnitDamaged) then
            Spring.Echo("[" .. widget:GetInfo().name .. "] WARNING: Damage statistics cannot be collected, because another widget is receiving the information!")
        end
    else
        Spring.Echo("[" .. widget:GetInfo().name .. "] WARNING: Damage statistics may be incomplete, because this is not a replay!")
        function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
            UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
        end
    end
end

function widget:Shutdown()
    if WG.MasterStats then WG.MasterStats:Refresh() end
end