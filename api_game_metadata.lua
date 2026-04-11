function widget:GetInfo()
    return {
        name = "Demo Metadata",
        author = "MasterBel2",
        date = "March 2026",
        version   = "2026-04-rev1",
        license = "GNU GPL, v2"
    }
end

local demoFileName
function widget:AddConsoleLine(line)
    demoFileName = line:match("[PreGame::GameDataReceived] recording demo to \".+demos/(.+)\"")
    
    if demoFileName then
        widgetHandler:RemoveCallIn("AddConsoleLine")
        return
    end

    demoFileName = line:match("Opening demofile demos%/(.+)")
    if demoFileName then
        widgetHandler:RemoveCallIn("AddConsoleLine")
        return
    end
end

function widget:Initialize()
    WG.GetDemoFileName = function() return demoFileName end
end