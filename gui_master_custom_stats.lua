function widget:GetInfo()
    return {
        name = "Stats (MasterBel2 Edition)",
        description = "Provides information on custom statistics",
        author = "MasterBel2",
        version = 0,
        date = "March 2022",
        license = "GNU GPL, v2 or later",
        layer = math.huge,
        handler = true
    }
end

------------------------------------------------------------------------------------------------------------
-- Imports
------------------------------------------------------------------------------------------------------------

local MasterFramework
local requiredFrameworkVersion = 14
local key

local math_max = math.max
local math_huge = math.huge

local string_format = string.format

local gl_BeginEnd = gl.BeginEnd
local gl_Color = gl.Color
local gl_Vertex = gl.Vertex
local gl_Translate = gl.Translate
local gl_PushMatrix = gl.PushMatrix
local gl_Scale = gl.Scale
local gl_PopMatrix = gl.PopMatrix
local gl_Shape = gl.Shape

local GL_LINE_STRIP = GL.LINE_STRIP
local GL_LINES = GL.LINES

------------------------------------------------------------------------------------------------------------
-- Interface Structure
------------------------------------------------------------------------------------------------------------

local stepInterval

local function stringOfNumberRoundedToPow10(value, pow10)
    if pow10 <= 0 then
        return string_format("%." .. -pow10 .. "f", value)
    elseif pow10 > 0 then
        return string_format("%0" .. pow10 .. "d", value)
    end
end

local function ContinuousGraphKeys(min, max, stepCount, roundPow10)
    local stepMagnitude = (max - min) / stepCount
    local steps = {}
    for i = 1, stepCount - 1 do
        steps[i] = stringOfNumberRoundedToPow10(min + (i - 1) * stepMagnitude, roundPow10)
    end

    steps[stepCount] = stringOfNumberRoundedToPow10(max, roundPow10)

    return steps
end

local reduce = table.reduce

local count = 0

local function UIGraph(data, xKeyStepCount, yKeyStepCount)
    local graph = {}

    local uiXKeys = {}
    local maxXKeyHeight
    local uiYKeys = {}
    local maxYKeyWidth

    local graphBaseline
    local graphSideline

    local width, height
    local graphWidth, graphHeight

    function graph:SetData(newData)
        data = newData
    end

    graph:SetData(data)

    local function DrawGraphEdges()
        gl_Color(1, 1, 1, 1)
        gl_Vertex(0, graphHeight)
        gl_Vertex(0, 0)
        gl_Vertex(graphWidth, 0)
    end

    local function DrawGraphHorizontalLines(xKeySeparation, yKeySeparation)
        gl_Color(0.5, 0.5, 0.5, 1)

        for i = 1, xKeyStepCount do
            local xOffset = xKeySeparation * i
            gl_Vertex(xOffset, 0)
            gl_Vertex(xOffset, graphHeight)
        end 
        for i = 1, yKeyStepCount do
            local yOffset = yKeySeparation * i
            gl_Vertex(0, yOffset)
            gl_Vertex(graphWidth, yOffset)
        end
    end

    local keyPadding = MasterFramework:Dimension(10)

    local function maxWidth(currentValue, nextValue)
        local width, _ = nextValue:Layout(0, 0)
        return math_max(currentValue, width)
    end
    local function maxHeight(currentValue, nextValue)
        local _, height = nextValue:Layout(0, 0)
        return math_max(currentValue, height)
    end

    function graph:Layout(availableWidth, availableHeight)

        local uiXKeyTitles = ContinuousGraphKeys(data.minX, data.maxX, xKeyStepCount + 1, -1)
        local uiYKeyTitles = ContinuousGraphKeys(data.minY, data.maxY, yKeyStepCount + 1, -1)

        for index, keyName in ipairs(uiXKeyTitles) do
            local key = uiXKeys[index]
            if key then
                key.label:SetString(keyName)
            else
                key = {}
                local label = MasterFramework:Text(keyName, nil, nil, nil, nil, index == 5)
                local padding = MasterFramework:MarginAroundRect(label, keyPadding, keyPadding, keyPadding, keyPadding)
                key.label = label

                function key:Draw(...)
                   padding:Draw(...) 
                end
                function key:Layout(...)
                    return padding:Layout(...)
                end
            end

            uiXKeys[index] = key
        end

        if #uiXKeyTitles < #uiXKeys then
            for i = #uiXKeys + 1, #uiXKeyTitles do
                uiXKeys[i] = nil
            end
        end

        for index, keyName in ipairs(uiYKeyTitles) do
            local key = uiYKeys[index]
            if key then
                key.label:SetString(keyName)
            else
                key = {}
                local label = MasterFramework:Text(keyName)
                local padding = MasterFramework:MarginAroundRect(label, keyPadding, keyPadding, keyPadding, keyPadding)
                key.label = label

                function key:Draw(...)
                   padding:Draw(...) 
                end
                function key:Layout(...)
                    return padding:Layout(...)
                end
            end

            uiYKeys[index] = key
        end

        if #uiYKeyTitles < #uiYKeys then
            for i = #uiYKeys + 1, #uiYKeyTitles do
                uiYKeys[i] = nil
            end
        end

        maxYKeyWidth = reduce(uiYKeys, -math_huge, maxWidth)
        maxXKeyHeight = reduce(uiXKeys, -math_huge, maxHeight)

        width = availableWidth
        height = availableHeight

        graphBaseline = maxXKeyHeight
        graphSideline = maxYKeyWidth
        graphWidth = width - 2 * graphSideline
        graphHeight = height - 2 * graphBaseline

        return availableWidth, availableHeight
    end

    local function DrawGraphData(line)
        local color = line.color
        gl_Color(color.r, color.g, color.b, color.a)
        
        for _, vertex in ipairs(line.vertices) do
            count = count + 1
            gl_Vertex(vertex)
        end
    end
    local function X(key, value)
        return { v = value }
    end

    function graph:Draw(x, y)

        local xKeySeparation = graphWidth / xKeyStepCount
        local yKeySeparation = graphHeight / yKeyStepCount

        for index, key in ipairs(uiXKeys) do
            local width, height = key:Layout(0, 0)
            key:Draw(x + (index - 1) * xKeySeparation + graphSideline - width / 2, y + graphBaseline - height)
        end
        for index, key in ipairs(uiYKeys) do
            local width, height = key:Layout(0, 0)
            key:Draw(x + graphSideline - width, y + (index - 1) * yKeySeparation + graphBaseline - height / 2)
        end

        gl_PushMatrix()

        gl_Translate(x + graphSideline, y + graphBaseline, 0)

        gl_BeginEnd(GL_LINE_STRIP, DrawGraphEdges)
        gl_BeginEnd(GL_LINES, DrawGraphHorizontalLines, xKeySeparation, yKeySeparation)
        
        gl_Scale(graphWidth / (data.maxX - data.minX), graphHeight / (data.maxY - data.minY), 1)
        for _, line in ipairs(data.lines) do
            -- local color = line.color
            -- gl_Color(color.r, color.g, color.b, color.a)
            -- gl_Shape(GL_LINE_STRIP, table.imap(line.vertices, X))
            -- Thought that would be faster, but it seems to be something like 10% slower. Yay. But testing it on like 9 data points so who knows.
            gl_BeginEnd(GL_LINE_STRIP, DrawGraphData, line)
        end
        gl_PopMatrix()
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
-- UI Element Var Declarations
------------------------------------------------------------------------------------------------------------

local uiGraph
local menu
local uiCategories = {}

local refreshRequested = true

local function UISectionedButtonList(name, options, action)
    local padding = MasterFramework:Dimension(8)

    local newButtons = {}

    for _, optionName in pairs(options) do
        local button = MasterFramework:Button(
            MasterFramework:Text(optionName),
            function(self)
                self.margin.background = MasterFramework:Color(0.66, 1, 1, 0.66) -- SelectedColor
                action(name, optionName)
            end
        )
        table.insert(newButtons, button)
    end

    local buttonList = MasterFramework:VerticalStack(
        {
            MasterFramework:Text(name, MasterFramework:Color(1, 1, 1, 0.66)),
            MasterFramework:VerticalStack(
                newButtons,
                padding,
                0
            )
        },
        padding,
        0
    )

    return buttonList
end


------------------------------------------------------------------------------------------------------------
-- Dummy Data (For testing purposes)
------------------------------------------------------------------------------------------------------------

local graphData = {
    minY = 0,
    minX = 0,
    maxY = 1,
    maxX = 1,
    lines = {
        {
            color = { r = 1, g = 0, b = 0, a = 1 },
            vertices = { { 0, 0 }, { 0.5, 1 }, { 1, 0.5 } }
        },
        {
            color = { r = 0, g = 0, b = 1, a = 1 },
            vertices = { { 0, 0.25 }, { 0.5, 0.75 }, { 1, 0.5 } }
        },
        {
            color = { r = 0, g = 1, b = 0, a = 1 },
            vertices = { { 0, 0 }, { 0.5, 0.75 }, { 1, 0.75 } }
        }
    }
}

------------------------------------------------------------------------------------------------------------
-- Create / Destroy
------------------------------------------------------------------------------------------------------------

function widget:Update()

    if refreshRequested then
        local categories = {}

        for widgetName, widget in pairs(widgetHandler.widgets) do
            if widget.MasterStatsCategories then
                -- categories[name] = { graphs = table }
                local widgetCategories = widget:MasterStatsCategories()

                for categoryName, widgetCategory in pairs(widgetCategories) do
                    local section = {}
                    for graphName, graph in pairs(widgetCategory) do
                        section[graphName] = graph 
                    end

                    local existingCategory = categories[categoryName] or { sections = {} }
                    existingCategory.sections[widgetName] = section

                    categories[categoryName] = existingCategory
                end
            end
        end

        local uiCategories = table.mapToArray(categories, function(key, value)

            local graphNames = {}
            local graphData = {}

            for _, section in pairs(value.sections) do
                for graphName, _graphData in pairs(section) do
                    table.insert(graphNames, graphName)
                    graphData[graphName] = _graphData
                end
            end

            table.sort(graphNames)

            return {
                name = key,
                list = UISectionedButtonList(key, graphNames, function(_, graphName)
                    uiGraph:SetData(graphData[graphName])
                end)
            }
        end)

        table.sort(uiCategories, function(a, b) return a.name < b.name end)

        menu.members = table.imap(uiCategories, function(_, value)
            return value.list
        end)

        refreshRequested = nil
    end
end

WG.MasterStats = {}
function WG.MasterStats:Refresh()
    refreshRequested = true
end
    
function widget:Initialize()
    MasterFramework = WG.MasterFramework[requiredFrameworkVersion]
    if not MasterFramework then
        error("[Master Custom Stats] MasterFramework " .. requiredFrameworkVersion .. " not found!")
    end

    if not MasterFramework.areComplexElementsAvailable then
        error("[Master Custom Stats] MasterFramework complex elements not found!")
    end

    stepInterval = MasterFramework:Dimension(50)

    uiGraph = UIGraph(
        graphData,
        5,
        5
    )

    menu = MasterFramework:VerticalStack(
        {},
        MasterFramework:Dimension(8),
        0
    )

    local split = MasterFramework:HorizontalStack(
        { 
            menu,
            MasterFramework:MarginAroundRect(
                uiGraph,
                MasterFramework:Dimension(0),
                MasterFramework:Dimension(0),
                MasterFramework:Dimension(0),
                MasterFramework:Dimension(0),
                { MasterFramework:Color(0, 0, 0, 0.7) },
                MasterFramework:Dimension(0),
                false
                -- false
            )
        },
        MasterFramework:Dimension(8), 
        1
    )

    local resizableFrame = MasterFramework:ResizableMovableFrame(
        -- "MasterCustomStats StatsFrame",
        nil,
        MasterFramework:PrimaryFrame(
            MasterFramework:MarginAroundRect(
                split,
                MasterFramework:Dimension(20),
                MasterFramework:Dimension(20),
                MasterFramework:Dimension(20),
                MasterFramework:Dimension(20),
                { MasterFramework:Color(0, 0, 0, 0.7) },
                MasterFramework:Dimension(5),
                -- MasterFramework:Dimension(0),
                false
                -- false
            )
        ),
        MasterFramework.viewportWidth * 0.1, MasterFramework.viewportHeight * 0.1, 
        MasterFramework.viewportWidth * 0.8, MasterFramework.viewportHeight * 0.8,
        false
    )
    
    key = MasterFramework:InsertElement(
        resizableFrame,
        "Stats",
        MasterFramework.layerRequest.top()
    )

    WG.MasterStats = API
end

function widget:Shutdown() 
    MasterFramework:RemoveElement(key)
    WG.MasterStats = nil
end