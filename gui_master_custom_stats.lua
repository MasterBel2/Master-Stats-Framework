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

-- TODO:
-- https://discord.com/channels/549281623154229250/1132864533258575872
-- https://discord.com/channels/549281623154229250/1069705949348114572

--[[
    To Display Your Graph Here: Implement `function widget:MasterStatsCategories()`

    This widget should return a table of categories, where: 
    - the key for each category should be a human-readable string, that will be case-sensitively merged with categories from other widgets.
    - the value for each category should be a table of graphs, where:
      - the key for each graph should be a unique human-readable string that will be used as the graph's title on-screen
      - the value for each graph should be a table with the following fields:
        - (number) minX, maxX, minY, maxX. Values provided in the table should not exceed the bounds specified by these values
        - (boolean) discrete - specifies whether each value is a descrete step. If true, the graph will draw extra vertices to avoid "interpolated" slanted lines between values.
        - (array) lines, where each value is a table with the following properties
          - (table) color - a table containing { r = r, g = g, b = b, a = a }
          - (table) vertices where:
            - (array) x, y - the array of x/y values, respectively. vertices.x[n] corresponds to vertices.y[n]. The data is structured like this to achieve SIGNIFICANT speedups.

    E.g. 

    ```lua
    function widget:MasterStatsCategories()
        return {
            ["Test Category"] = {
                ["Test Graph"] = {
                    minX = 0,
                    maxX = 1,
                    minY = 0,
                    maxY = 1,
                    lines = {
                        {
                            title = "Belmakor", -- optional
                            hidden = true, -- optional; when absent, the line is assumed to be showing. (i.e. lines are only hidden if explicitely set to be hidden)
                            color = { r = 1, g = 0, b = 0, a = 1 },
                            vertices = { x = { 0, 0.5, 1 }, y = {0, 1 , 0.5 } }
                        },
                        {
                            title = "BelSon", -- optional
                            color = { r = 0, g = 0, b = 1, a = 1 },
                            vertices = { x = { 0, 0.5, 1 }, y = {0.25, 0.75 , 0.5 } }
                        },
                        {
                            title = "MasterBel2", -- optional
                            color = { r = 0, g = 1, b = 0, a = 1 },
                            vertices = { x = { 0, 0.5, 1 }, y = {0, 0.75 , 0.75 } }
                        }
                    }
                }
            }
        }
    end
    ```
]]

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
            vertices = { x = { 0, 0.5, 1 }, y = {0, 1 , 0.5 } }
        },
        {
            color = { r = 0, g = 0, b = 1, a = 1 },
            vertices = { x = { 0, 0.5, 1 }, y = {0.25, 0.75 , 0.5 } }
        },
        {
            color = { r = 0, g = 1, b = 0, a = 1 },
            vertices = { x = { 0, 0.5, 1 }, y = {0, 0.75 , 0.75 } }
        }
    }
}

------------------------------------------------------------------------------------------------------------
-- Imports
------------------------------------------------------------------------------------------------------------

local MasterFramework
local requiredFrameworkVersion = 42
local key

local math_huge = math.huge

local math_max = math.max
local math_min = math.min
local math_log = math.log

local reduce

local string_format = string.format

local gl_BeginEnd = gl.BeginEnd
local gl_Color = gl.Color
local gl_LineWidth = gl.LineWidth
local gl_PopMatrix = gl.PopMatrix
local gl_PushMatrix = gl.PushMatrix
local gl_Scale = gl.Scale
local gl_Shape = gl.Shape
local gl_Translate = gl.Translate
local gl_Vertex = gl.Vertex

local GL_LINE_STRIP = GL.LINE_STRIP
local GL_LINES = GL.LINES

------------------------------------------------------------------------------------------------------------
-- Interface Structure
------------------------------------------------------------------------------------------------------------

local objectsToDelete = {}

local stepInterval

local function stringOfNumberRoundedToPow10(value, pow10)
    if pow10 <= 0 then
        return string_format("%." .. -pow10 .. "f", value)
    elseif pow10 > 0 then
        return string_format("%0" .. pow10 .. "d", value)
    end
end

local function ContinuousGraphKeys(min, max, stepCount, roundPow10, isLogarithmic)
    local steps = {}
        
    for i = 1, stepCount - 1 do
        local value
        if isLogarithmic then
            value = math.exp(math.log(max) / stepCount * (i - 1))
        else
            value = min + (i - 1) * (max - min) / stepCount
        end
        steps[i] = stringOfNumberRoundedToPow10(value, roundPow10)
    end

    steps[stepCount] = stringOfNumberRoundedToPow10(max, roundPow10)

    return steps
end

local function UIGraph(data, xKeyStepCount, yKeyStepCount)

    local graph = {}

    -- local uiGraphData = UIGraphData(data, xKeyStepCount, yKeyStepCount)

    local uiXKeys = {}
    local maxXKeyHeight
    local uiYKeys = {}
    local maxYKeyWidth

    local graphBaseline, graphSideline

    local graphWidth, graphHeight

    function graph:SetData(newData)
        data = newData
    end

    function graph:SetShowAsLogarithmic(newValue)
        data.showAsLogarithmic = newValue
    end
    function graph:SetShowAsDelta(newValue)
        data.showAsDelta = newValue
    end

    graph:SetData(data)

    -- Generate Data

    local vertexCounts = {}
    local vertexXCoordinates = {}
    local vertexYCoordinates = {}
    local minY
    local maxY
    local magnitude
    local cachedWidth, cachedHeight
    local verticalRatio

    local mouseY = 1000

    local lastDrawnY
    -- local function gl_Vertex_Delta(x, y, vertexFunc)
    --     vertexFunc(x, y - lastY)
    -- end
    -- local function gl_Vertex_Logarithmic(x, y)
    --     gl_Vertex(x, math_max(0, math_log(y)))
    -- end

    local function vertex(x, y, line)
        if data.showAsDelta then
            local _lastDrawnY = y
            y = y - lastDrawnY
            lastDrawnY = _lastDrawnY
        end
        if data.showAsLogarithmic then
            if y >= 1 then
                y = math_max(0, math_log(y))
            elseif y <= -1 then
                y = -math_max(0, math_log(-y))
            else
                y = 0
            end
        end
        vertexXCoordinates[line][vertexCounts[line] + 1] = x
        vertexYCoordinates[line][vertexCounts[line] + 1] = y

        vertexCounts[line] = vertexCounts[line] + 1

        minY = math_min(y, minY)
        maxY = math_max(y, maxY)
    end

    local function GenerateLineData(line, pixelWidth)
        local vertexCount = #line.vertices.x
        local vertices = line.vertices
        local lastDrawnX = -1
        local firstX = vertices.x[1]
        local firstY = vertices.y[1]
        local lastX = vertices.x[vertexCount]
        local lastY = vertices.y[vertexCount]

        lastDrawnY = firstY
        vertex(firstX, firstY, line)

        local xPerPixelWidth = (lastX - firstX) / pixelWidth
        
        for i = 2, vertexCount do
            if vertices.x[i] > lastDrawnX + xPerPixelWidth then
                if data.discrete then
                    vertex(vertices.x[i], vertices.y[i - 1], line)
                end
                vertex(vertices.x[i], vertices.y[i], line)
                lastDrawnX = i
            end
        end

        vertex(lastX, lastY, line)
        if data.discrete then
            vertex(data.maxX, lastY, line)
        end
    end

    -- Layout, Position & Draw

    local keyPadding = MasterFramework:Dimension(10)

    local function maxWidth(currentValue, nextValue)
        local width, _ = nextValue:Layout(math_huge, math_huge)
        return math_max(currentValue, width)
    end
    local function maxHeight(currentValue, nextValue)
        local _, height = nextValue:Layout(math_huge, math_huge)
        return math_max(currentValue, height)
    end

    local font = MasterFramework.defaultFont
    local color = MasterFramework:Color(0.3, 0.3, 0.3, 1)

    local topText = MasterFramework:Text("", color, font)
    local zeroText = MasterFramework:Text("0", color, font)
    local bottomText = MasterFramework:Text("", color, font)

    local mouseText = MasterFramework:Text("", color, font)
    local indent = MasterFramework:Dimension(2)

    function graph:Layout(availableWidth, availableHeight)
        minY = math.huge
        maxY = -math.huge

        for _, line in ipairs(data.lines) do
            if not line.hidden then
                vertexCounts[line] = 0
                if not vertexXCoordinates[line] then
                    vertexXCoordinates[line] = {}
                    vertexYCoordinates[line] = {}
                end

                GenerateLineData(line, availableWidth)

                for i = vertexCounts[line] + 1, #vertexXCoordinates[line] do
                    vertexXCoordinates[line][i] = nil
                    vertexYCoordinates[line][i] = nil
                end
            end
        end

        verticalRatio = (maxY - minY) / availableHeight

        magnitude = (maxY - minY) / 5

        cachedWidth = availableWidth
        cachedHeight = availableHeight

        if minY < 0 and maxY > 0 then
            zeroText:Layout(availableWidth, font:ScaledSize())
        end

        if data.showAsLogarithmic then
            topText:SetString(tostring(math.exp(maxY)))
            bottomText:SetString(tostring(-math.exp(-minY)))

            -- mouseText:SetString(tostring(minY + verticalRatio * mouseY))
        else
            topText:SetString(tostring(maxY))
            bottomText:SetString(tostring(minY))
            -- mouseText:SetString(tostring(minY + verticalRatio * mouseY))
        end

        topText:Layout(availableWidth, font:ScaledSize())
        bottomText:Layout(availableWidth, font:ScaledSize())
        mouseText:Layout(availableWidth, font:ScaledSize())
        
        return availableWidth, availableHeight
    end

    function graph:Position(x, y)
        if minY < 0 and maxY > 0 then
            zeroText:Position(x + indent(), y - minY / verticalRatio)
        end

        topText:Position(x + indent(), y + cachedHeight - font:ScaledSize())
        bottomText:Position(x + indent(), y)

        mouseText:Position(x + indent(), y + (minY - mouseY * verticalRatio))

        cachedX = x
        cachedY = y

        table.insert(MasterFramework.activeDrawingGroup.drawTargets, self)
    end

    local function DrawGraphHorizontalLines()
        gl_Color(0.5, 0.5, 0.5, 1)
        if minY < 0 and maxY > 0 then
            gl_Vertex(0, -minY / verticalRatio)
            gl_Vertex(cachedWidth, -minY / verticalRatio)
        end

        gl_Vertex(0, cachedHeight)
        gl_Vertex(cachedWidth, cachedHeight)
    end

    local function DrawGraphEdges()
        gl_Color(1, 1, 1, 1)
        gl_Vertex(0, 0)
        gl_Vertex(0, cachedHeight)
        gl_Vertex(0, 0)
        gl_Vertex(cachedWidth, 0)
    end

    local function DrawGraphData(line, cachedWidth)
        local color = line.color
        gl_Color(color.r, color.g, color.b, color.a)

        local lineVertexXCoordinates = vertexXCoordinates[line]
        local lineVertexYCoordinates = vertexYCoordinates[line]

        for i = 1, #lineVertexXCoordinates do
            gl_Vertex(lineVertexXCoordinates[i], lineVertexYCoordinates[i])
        end
    end

    function graph:Draw()
        gl_PushMatrix()

        gl_LineWidth(1)

        gl_Translate(cachedX, cachedY, 0)

        gl_BeginEnd(GL_LINES, DrawGraphHorizontalLines)
        
        gl_PushMatrix()

        gl_Scale(cachedWidth / (data.maxX - data.minX), cachedHeight / (maxY - minY), 1)
        gl_Translate(0, -minY, 0)

        for _, line in ipairs(data.lines) do
            -- local color = line.color
            -- gl_Color(color.r, color.g, color.b, color.a)
            -- gl_Shape(GL_LINE_STRIP, table.imap(line.vertices, X))
            -- Thought that would be faster, but it seems to be something like 10% slower. Yay. But testing it on like 9 data points so who knows.
            if not line.hidden then
                if gl4 then
                    -- DrawGraphDataGL4(line, cachedWidth)
                else
                    gl_BeginEnd(GL_LINE_STRIP, DrawGraphData, line, cachedWidth)
                end
            end
        end
        gl_PopMatrix()

        gl_BeginEnd(GL_LINES, DrawGraphEdges)
        
        gl_PopMatrix()
    end

    return graph
end

------------------------------------------------------------------------------------------------------------
-- UI Element Var Declarations
------------------------------------------------------------------------------------------------------------

local uiGraph
local menu
local logarithmicCheckBox
local deltaCheckBox
local graphLinesMenu
local uiCategories = {}

local refreshRequested = true

local function UISectionedButtonList(name, options, action)
    local padding = MasterFramework:Dimension(8)

    local newButtons = {}

    for _, optionName in pairs(options) do
        local button = MasterFramework:Button(
            MasterFramework:Text(optionName),
            function(self)
                -- self.margin.background = MasterFramework:Color(0.66, 1, 1, 0.66) -- SelectedColor
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
                    logarithmicCheckBox:SetChecked(graphData[graphName].showAsLogarithmic)
                    deltaCheckBox:SetChecked(graphData[graphName].showAsDelta)
                    graphLinesMenu.items = table.imap(graphData[graphName].lines, function(_, line)
                        local color = MasterFramework:Color(line.color.r, line.color.g, line.color.b, line.color.a)
                        local checkbox = MasterFramework:CheckBox(12, function(_, checked) line.hidden = not checked end)
                        checkbox:SetChecked(not line.hidden)
                        return MasterFramework:HorizontalStack(
                            {
                                checkbox,
                                line.title and MasterFramework:Text(line.title, color) or MasterFramework:Rect(MasterFramework:Dimension(20), MasterFramework:Dimension(12), MasterFramework:Dimension(3), { color })
                            },
                            MasterFramework:Dimension(8),
                            0.5
                        )
                    end)
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

-- function widget:DebugInfo()
--     return graphLinesMenu
-- end

local function HorizontalWrap(items, horizontalSpacing, verticalSpacing, xAnchor, yAnchor)
    local wrap = { items = items }
    local rows

    local cachedWidth
    local cachedHeight

    function wrap:Layout(availableWidth, availableHeight)
        rows = { { cumulativeWidth = 0, maxHeight = 0, verticalOffset = 0 } }
        local scaledHorizontalSpacing = horizontalSpacing()
        local scaledVerticalSpacing = verticalSpacing()

        for index, item in ipairs(self.items) do
            local row = rows[#rows]
            local itemWidth, itemHeight = item:Layout(availableWidth, availableHeight)
            local newCumulativeWidth = row.cumulativeWidth + itemWidth

            if #row > 0 then
                newCumulativeWidth = newCumulativeWidth + scaledHorizontalSpacing
            end

            if newCumulativeWidth > availableWidth then
                item._horizontalWrap_xOffset = 0
                rows[#rows + 1] = {
                    cumulativeWidth = itemWidth,
                    maxHeight = itemHeight,
                    verticalOffset = row.verticalOffset + row.maxHeight + scaledVerticalSpacing, 
                    [1] = item 
                }
            else
                row.maxHeight = math.max(row.maxHeight, itemHeight)

                item._horizontalWrap_xOffset = row.cumulativeWidth
                if #row > 0 then
                    item._horizontalWrap_xOffset = item._horizontalWrap_xOffset + scaledHorizontalSpacing
                end

                row.cumulativeWidth = newCumulativeWidth

                row[#row + 1] = item
            end
        end

        local rowCount = #rows
        cachedWidth = 0
        for i = 1, rowCount do
            cachedWidth = math.max(rows[i].cumulativeWidth, cachedWidth)
        end

        local lastRow = rows[#rows]
        
        cachedHeight = lastRow.verticalOffset + lastRow.maxHeight + (rowCount > 1 and verticalSpacing() or 0)

        self._rows = rows
        
        return cachedWidth, cachedHeight
    end
    function wrap:Position(x, y)
        for rowIndex, row in ipairs(rows) do
            for itemIndex, item in ipairs(row) do
                item:Position(
                    x + item._horizontalWrap_xOffset + (cachedWidth - row.cumulativeWidth) * xAnchor, 
                    y + cachedHeight - row.verticalOffset - row.maxHeight
                )
            end
        end
    end

    return wrap
end
    
function widget:Initialize()
    MasterFramework = WG["MasterFramework " .. requiredFrameworkVersion]
    if not MasterFramework then
        error("[" .. widget:GetInfo().name .. "] MasterFramework " .. requiredFrameworkVersion .. " not found!")
    end
    
    table = MasterFramework.table
    reduce = table.reduce

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

    graphLinesMenu = HorizontalWrap({}, MasterFramework:Dimension(8), MasterFramework:Dimension(2), 0.5, 0.5)

    logarithmicCheckBox = MasterFramework:CheckBox(12, function(_, checked) uiGraph:SetShowAsLogarithmic(checked) end)
    deltaCheckBox = MasterFramework:CheckBox(12, function(_, checked) uiGraph:SetShowAsDelta(checked) end)

    local split = MasterFramework:HorizontalStack(
        { 
            MasterFramework:VerticalScrollContainer(
                MasterFramework:MarginAroundRect(
                    menu,
                    MasterFramework:Dimension(0),
                    MasterFramework:Dimension(0),
                    MasterFramework:Dimension(0),
                    MasterFramework:Dimension(0),
                    {},
                    MasterFramework:Dimension(0),
                    false
                    -- false
                )
            ),
            MasterFramework:VerticalHungryStack(
                MasterFramework:HorizontalStack({
                        logarithmicCheckBox, MasterFramework:Text("Logarithmic"),
                        deltaCheckBox, MasterFramework:Text("Delta")
                    },
                    MasterFramework:Dimension(8),
                    0.5
                ),
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
                ),
                MasterFramework:MarginAroundRect(
                    graphLinesMenu,
                    MasterFramework:Dimension(20),
                    MasterFramework:Dimension(20),
                    MasterFramework:Dimension(20),
                    MasterFramework:Dimension(20),
                    {},
                    MasterFramework:Dimension(0),
                    false
                ),
                0.5
            )
        },
        MasterFramework:Dimension(8),
        1
    )

    local resizableFrame = MasterFramework:ResizableMovableFrame(
        "MasterCustomStats StatsFrame",
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
        MasterFramework.viewportWidth * 0.2, MasterFramework.viewportHeight * 0.9, 
        MasterFramework.viewportWidth * 0.8, MasterFramework.viewportHeight * 0.8,
        false
    )
    
    key = MasterFramework:InsertElement(
        resizableFrame,
        "Stats",
        MasterFramework.layerRequest.top()
    )
end

function widget:Shutdown() 
    for _, object in ipairs(objectsToDelete) do
        object:Delete()
    end

    MasterFramework:RemoveElement(key)
    WG.MasterStats = nil
end