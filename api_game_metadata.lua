function widget:GetInfo()
    return {
        name = "Demo Metadata",
        author = "MasterBel2",
        date = "March 2026",
        license = "GNU GPL, v2"
    }
end

local demoFileName
function widget:AddConsoleLine(line)
    demoFileName = line:match("[PreGame::GameDataReceived] recording demo to \".+demos/(.+)\"")
    
    if demoFileName then
        Spring.Echo("Found demoFileName: " .. demoFileName)
        widgetHandler:RemoveCallIn("AddConsoleLine")
        return
    end

    demoFileName = line:match("Opening demofile demos%/(.+)")
    if demoFileName then
         Spring.Echo("Found demoFileName: " .. demoFileName)
        widgetHandler:RemoveCallIn("AddConsoleLine")
        return
    end
end

function widget:Initialize()
    WG.GetDemoFileName = function() return demoFileName end
end