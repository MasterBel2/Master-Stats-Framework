function widget:GetInfo()
    return {
        name = "Stats (MasterBel2 Edition)",
        description = "Provides information on custom statistics",
        author = "MasterBel2",
        version = 0,
        date = "March 2022",
        license = "GNU GPL, v2 or later",
        layer = -1
    }
end

------------------------------------------------------------------------------------------------------------
-- Imports
------------------------------------------------------------------------------------------------------------

local MasterFramework
local requiredFrameworkVersion = 13
local key

local gl_BeginEnd = gl.BeginEnd
local gl_Color = gl.Color
local gl_Vertex = gl.Vertex
local gl_Translate = gl.Translate

------------------------------------------------------------------------------------------------------------
-- Interface Structure
------------------------------------------------------------------------------------------------------------

-- Creates a new table composed of the results of calling a function on each key-value pair of the original table.
local function map(table, transform)
    local newTable = {}

    for key, value in pairs(table) do
        local newKey, newValue = transform(key, value)
        newTable[newKey] = newValue
    end

    return newTable
end

local stepInterval

local function keysTransform(key, value)
    return key, MasterFramework:MarginAroundRect(MasterFramework:Text(value), MasterFramework:Dimension(10), MasterFramework:Dimension(10), MasterFramework:Dimension(10), MasterFramework:Dimension(10))
end

local function stringOfNumberRoundedToPow10(value, pow10)
    if pow10 <= 0 then
        return string.format("%." .. -pow10 .. "f", value)
    elseif pow10 > 0 then
        return string.format("%0" .. pow10 .. "d", value)
    end
end

local function ContinuousGraphKeys(min, max, stepCount, roundPow10)
    local stepMagnitude = (max - min) / stepCount
    local steps = {}
    for i = 1, stepCount - 1 do
        steps[i] = stringOfNumberRoundedToPow10(min + (i - 1) * stepMagnitude, roundPow10)
    end

    steps[stepCount] = stringOfNumberRoundedToPow10(max, roundPow10)

    return map(steps, keysTransform)
end

local function reduce(array, initialValue, operation)
    local value = initialValue
    for _, element in ipairs(array) do
        value = operation(initialValue, element)
    end
    return value
end

local count = 0

local function UIGraph(data, xKeyStepCount, yKeyStepCount)
    local graph = {}

    local uiXKeys
    local maxXKeyHeight
    local uiYKeys
    local maxYKeyWidth

    local graphBaseline
    local graphSideline

    local width, height
    local graphWidth, graphHeight

    function graph:SetData(newData)
        data = newData

        uiXKeys = ContinuousGraphKeys(data.minX, data.maxX, xKeyStepCount + 1, -1)
        uiYKeys = ContinuousGraphKeys(data.minY, data.maxY, yKeyStepCount + 1, -1)
    end

    graph:SetData(data)

    local function DrawGraphEdges()
        gl_Color(1, 1, 1, 1)
        gl_Vertex(0, graphHeight)
        gl_Vertex(0, 0)
        gl_Vertex(graphWidth, 0)
    end

    local function DrawGraphHorizontalLines()
        gl_Color(0.5, 0.5, 0.5, 1)

        for i = 1, xKeyStepCount do
            gl_Vertex(graphWidth / xKeyStepCount * i, 0)
            gl_Vertex(graphWidth / xKeyStepCount * i, graphHeight)
        end 
        for i = 1, yKeyStepCount do
            gl_Vertex(0, graphHeight / yKeyStepCount * i)
            gl_Vertex(graphWidth, graphHeight / yKeyStepCount * i)
        end
    end

    function graph:Layout(availableWidth, availableHeight)

        maxYKeyWidth = reduce(uiXKeys, -math.huge, function(currentValue, nextValue)
            local width, _ = nextValue:Layout(0, 0)
            return math.max(currentValue, width)
        end)
        maxXKeyHeight = reduce(uiXKeys, -math.huge, function(currentValue, nextValue)
            local _, height = nextValue:Layout(0, 0)
            return math.max(currentValue, height)
        end)

        width = availableWidth
        height = availableHeight

        graphBaseline = maxXKeyHeight
        graphSideline = maxYKeyWidth
        graphWidth = width - 2 * graphSideline
        graphHeight = height - 2 * graphBaseline

        return availableWidth, availableHeight
    end

    local function DrawGraphData(line)
        gl.Color(line.color.r, line.color.g, line.color.b, line.color.a)
        
        for _, vertex in ipairs(line.vertices) do
            count = count + 1
            gl.Vertex(vertex.x, vertex.y)
        end
    end

    function graph:Draw(x, y)

        for index, key in ipairs(uiXKeys) do
            local width, _ = key:Layout(0, 0)
            key:Draw(x + (index - 1) * graphWidth / xKeyStepCount  + width / 2, y)
        end
        for index, key in ipairs(uiYKeys) do
            local width, height = key:Layout(0, 0)
            key:Draw(x, y + (index - 1) * graphHeight / yKeyStepCount + height / 2)
        end

        gl.PushMatrix()

        gl_Translate(x + graphSideline, y + graphBaseline, 0)

        gl_BeginEnd(GL.LINE_STRIP, DrawGraphEdges)
        gl_BeginEnd(GL.LINES, DrawGraphHorizontalLines)
        
        gl.Scale(graphWidth / (data.maxX - data.minX), graphHeight / (data.maxY - data.minY), 1)
        for _, line in ipairs(data.lines) do
            
            gl_BeginEnd(GL.LINE_STRIP, DrawGraphData, line)
        end 
        gl.PopMatrix()
    end

    return graph
end

-- local function UIBarGraph(xKeys, yKeys, data)
--     local graph = {}

--     local function keysTransform(key, name)
--         return key, MasterFramework:GeometryTarget(MasterFramework:Text(name))
--     end

--     local uiXKeys = map(xKeys, keysTransform)
--     local uiYKeys = map(yKeys, keysTransform)

--     local xKey = GraphKeyMargin(MasterFramework:HorizontalStack(uiXKeys, MasterFramework:Dimension(20), 0.5))
--     local yKey = GraphKeyMargin(MasterFramework:VerticalStack(uiYKeys, MasterFramework:Dimension(20), 0.5))

--     local width, height
--     local xKeyWidth, xKeyHeight
--     local yKeyWidth, yKeyHeight

--     local function DrawGraphEdges()
--         gl_Color(1, 1, 1, 1)
--         gl_Vertex(yKeyWidth, height)
--         gl_Vertex(yKeyWidth, xKeyHeight)
--         gl_Vertex(width, xKeyHeight)
--     end

--     local function DrawGraphHorizontalLines()
--         gl_Color(0.5, 0.5, 0.5, 1)

--         for _, target in ipairs(uiXKeys) do
--             local targetX, targetY = target:CachedPosition()
--             local targetWidth, targetHeight = target:Size()

--             gl_Vertex(targetX + targetWidth / 2, xKeyHeight)
--             gl_Vertex(targetX + targetWidth / 2, height)
--         end 
--         for _, target in ipairs(uiYKeys) do
--             local targetX, targetY = target:CachedPosition()
--             local targetWidth, targetHeight = target:Size()

--             gl_Vertex(yKeyWidth, targetY + targetHeight / 2)
--             gl_Vertex(width, targetY + targetHeight / 2)
--         end
--     end

--     function graph:Layout(availableWidth, availableHeight)
--         xKeyWidth, xKeyHeight = xKey:Layout(availableWidth, availableHeight)
--         yKeyWidth, yKeyHeight = yKey:Layout(availableWidth, availableHeight)

--         width = xKeyWidth + yKeyWidth
--         height = yKeyHeight + xKeyHeight

--         return availableWidth, availableHeight
--     end

--     local function DrawGraphData(line)
--         gl.Color(line.color.r, line.color.g, line.color.b, line.color.a)

--         for _, vertex in ipairs(line.vertices) do
--             gl.Vertex(vertex.x, vertex.y)
--         end
--     end

--     function graph:Draw(x, y)
--         xKey:Draw(yKeyWidth, 0)
--         yKey:Draw(0, xKeyHeight)

--         gl_BeginEnd(GL.LINE_STRIP, DrawGraphEdges)
--         gl_BeginEnd(GL.LINES, DrawGraphHorizontalLines)

--         gl.PushMatrix()
--         gl.Translate(x + yKeyWidth, y + xKeyHeight, 0)
--         gl.Scale(xKeyWidth / (data.maxX - data.minX), yKeyHeight / (data.maxY - data.minY), 1)
--         for _, line in ipairs(data.lines) do
--             gl_BeginEnd(GL.LINE_STRIP, DrawGraphData, line)
--         end 
--         gl.PopMatrix()
--     end

--     return graph
-- end

-- local function UIBarGraphContent(barGraph)
--     local barGraph = {}

    

--     -- local rasterizer = MasterFramework:Rasterizer()

--     function barGraph:Refesh()

--     end

--     function barGraph:Layout(availableWidth, availableHeight)
--         return availableWidth, availableHeight
--     end
--     function barGraph:Draw(x, y)
--     end
--     return barGraph
-- end
-- local function UILineGraphContent(lineGraph)
--     local lineGraph = {}
--     function lineGraph:Layout(availableWidth, availableHeight)
--         return availableWidth, availableHeight
--     end
--     function lineGraph:Draw(x, y)
--     end
--     return lineGraph
-- end

-- local function UICategory(category)
--     local category = {}

--     return category
-- end

------------------------------------------------------------------------------------------------------------
-- Data Structure
------------------------------------------------------------------------------------------------------------

local uiGraph

local graphData = {
    minY = 0,
    minX = 0,
    maxY = 1,
    maxX = 1,
    lines = {
        {
            color = { r = 1, g = 0, b = 0, a = 1 },
            vertices = { {x = 0, y = 0}, {x = 0.5, y = 1}, { x = 1, y = 0.5} }
        },
        {
            color = { r = 0, g = 0, b = 1, a = 1 },
            vertices = { {x = 0, y = 0.25}, {x = 0.5, y = 0.75}, { x = 1, y = 0.5} }
        },
        {
            color = { r = 0, g = 1, b = 0, a = 1 },
            vertices = { {x = 0, y = 0}, {x = 0.5, y = 0.75}, { x = 1, y = 0.75} }
        }
    }
}

------------------------------------------------------------------------------------------------------------
-- Data Structure
------------------------------------------------------------------------------------------------------------

local API = {}
local categories = {}

local function NewCategory()
    local category = {}
    local graphs = {}

    function category:AddGraph(name, widget, data)
        graphs[name] = { name = name, data = data }
    end
    function category:RemoveGraph(name, widget)
        graphs[name] = nil
    end
    function category:Graphs()
        return graphs
    end

    return category
end

function API:Category(name)
    local category = categories[name]
    if not category then 
        category = NewCategory()

        categories[name] = category
    end
    return category 
end

------------------------------------------------------------------------------------------------------------
-- Create / Destroy
------------------------------------------------------------------------------------------------------------

function widget:Update()
    -- temp, just find a graph and show it
    for name, category in pairs(categories) do
        for _, graph in pairs(category:Graphs()) do
            uiGraph:SetData(graph.data)
        end
    end
end

function widget:Initialize()
    MasterFramework = WG.MasterFramework[requiredFrameworkVersion]
    if not MasterFramework then
        Spring.Echo("[Key Tracker] Error: MasterFramework " .. requiredFrameworkVersion .. " not found! Removing self.")
        widgetHandler:RemoveWidget(self)
        return
    end

    stepInterval = MasterFramework:Dimension(50)

    uiGraph = UIGraph( 
        graphData,
        5,
        5
    )
    
    key = MasterFramework:InsertElement(
        MasterFramework:PrimaryFrame(
            MasterFramework:MarginAroundRect(
                MasterFramework:MarginAroundRect(
                    uiGraph,
                    MasterFramework:Dimension(0),
                    MasterFramework:Dimension(0),
                    MasterFramework:Dimension(0),
                    MasterFramework:Dimension(0),
                    { MasterFramework:Color(1, 1, 1, 0.1) },
                    MasterFramework:Dimension(0)
                ),
                MasterFramework:Dimension(100),
                MasterFramework:Dimension(100),
                MasterFramework:Dimension(100),
                MasterFramework:Dimension(100),
                { MasterFramework:Color(0, 0, 0, 0.7) },
                MasterFramework:Dimension(0)
            )
        ),
        "Test Graph"
    )

    WG.MasterStats = API
end

function widget:Shutdown() 
    MasterFramework:RemoveElement(key)
    WG.MasterStats = nil
end