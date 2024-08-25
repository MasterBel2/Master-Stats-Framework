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

    This function should return a table of categories, where: 
    - the key for each category should be a human-readable string, that will be case-sensitively merged with categories from other widgets.
    - the value for each category should be a table of graphs, where:
      - the key for each graph should be a unique human-readable string that will be used as the graph's title on-screen
      - the value for each graph should be a table with the following fields:
        - (string) xUnit - specifies the units for the x axis. Custom formatting will be provided for the values "Frames" and "Seconds" - they will be shown with `hrs, mins, secs` formatting.
        - (string) yUnit - specifies the units for the y axis. Custom formatting will be provided for the values "Frames" and "Seconds" - they will be shown with `hrs, mins, secs` formatting.
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
                    xUnit = "Frames",
                    yUnit = "Metal",
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
local requiredFrameworkVersion = "Dev"
local key

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
local gl_Rect = gl.Rect
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

    local graph = MasterFramework:Component(true, true)

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

    local selectionAnchor
    local selectionLimit

    local vertexCounts = {}
    local vertexXCoordinates = {}
    local vertexYCoordinates = {}
    
    local minX, maxX, minY, maxY

    local magnitude
    local cachedX, cachedX
    local cachedWidth, cachedHeight
    local verticalRatio

    local mouseY = 1000

    local lastDrawnY

    local function format(number, unit)
        if unit == "Frames" then
            unit = "Seconds"
            number = number / 30
        end
        if unit == "Seconds" then
            local seconds = number % 60
            local minutes = math.floor(number / 60 % 60)
            local hours   = math.floor(number / 3600 % 24)
        
            return ((hours > 0) and (hours .. (hours == 1 and "hr, " or "hrs, ")) or "") .. ((minutes > 0) and (minutes  .. (minutes == 1 and "min, " or "mins, ")) or "") .. ((seconds > 0) and (string.format("%.1f", seconds) .. (seconds == 1 and "sec" or "secs")) or "")
        else
            local thousandsMagnitude = math.floor(math.log(number)/math.log(1000))
            local tensMagnitude = math.floor(math.log(number)/math.log(10))
            local magnitudeSuffix = {
                [1] = "k",
                [2] = "M",
                [3] = "B",
                [4] = "T"
            }
            local result = math.floor(number * math.pow(10, 1 - tensMagnitude) + 0.5) / math.pow(10, 1 - (tensMagnitude - math.max(0, thousandsMagnitude) * 3)) .. (magnitudeSuffix[thousandsMagnitude] or "")
            return result
        end
    end

    function graph:Select(anchor, limit)
        if selectionAnchor ~= anchor or selectionLimit ~= limit then
            selectionAnchor = anchor
            selectionLimit = limit
            self:NeedsRedraw()

            if anchor then
                local overlayX
                local overlayY = cachedY + cachedHeight
                if selectionLimit and selectionLimit < selectionAnchor then
                    overlayX = cachedX + selectionLimit
                else
                    overlayX = cachedX + selectionAnchor
                end

                if self.overlay then
                    self.overlay:SetOffsets(overlayX + 1, MasterFramework.viewportHeight - overlayY)
                else
                    local stackMembers = table.imap(data.lines, function(_, line)
                        local valueText = MasterFramework:Text("")
                        local member = MasterFramework:HorizontalStack(
                            { MasterFramework:Text(line.title or "", MasterFramework:Color(line.color.r, line.color.g, line.color.b, line.color.a)), valueText },
                            MasterFramework:AutoScalingDimension(2),
                            0
                        )

                        function member:Update(scaledAnchor, scaledLimit)
                            local i = 1
                            while line.vertices.x[i] and scaledAnchor > line.vertices.x[i] do
                                i = i + 1
                            end
                            local _string = format(scaledAnchor, data.xUnit) .. ": " .. (line.vertices.y[i - 1] and format(line.vertices.y[i - 1], data.yUnit) or "???")

                            if scaledLimit then
                                i = 1
                                while line.vertices.x[i] and scaledLimit > line.vertices.x[i] do
                                    i = i + 1
                                end
                                local limitString = format(scaledLimit, data.xUnit) .. ": " .. (line.vertices.y[i - 1] and format(line.vertices.y[i - 1], data.yUnit) or "???")

                                if scaledLimit < scaledAnchor then
                                    _string = limitString .. ", " .. _string
                                else
                                    _string = _string .. ", " .. limitString
                                end
                            end

                            valueText:SetString(_string)
                        end

                        return member
                    end)
                    self.overlay = MasterFramework:AbsoluteOffsetFromTopLeft(MasterFramework:PrimaryFrame(MasterFramework:Background(
                        MasterFramework:MarginAroundRect(
                            MasterFramework:VerticalStack(stackMembers, MasterFramework:AutoScalingDimension(2), 0),
                            MasterFramework:AutoScalingDimension(8),
                            MasterFramework:AutoScalingDimension(8),
                            MasterFramework:AutoScalingDimension(8),
                            MasterFramework:AutoScalingDimension(8)
                        ),
                        { MasterFramework.color.baseBackgroundColor },
                        MasterFramework:AutoScalingDimension(5)
                    )), overlayX, overlayY)
                    self.overlay.stackMembers = stackMembers

                    local key = MasterFramework:InsertElement(self.overlay, "Graph Overlay", MasterFramework.layerRequest.top())
                    self.overlay.key = key
                end

                local xScale = (maxX - minX) / cachedWidth
                for _, member in ipairs(self.overlay.stackMembers) do
                    member:Update(xScale * anchor, limit and (limit * xScale))
                end
            else
                if self.overlay then
                    MasterFramework:RemoveElement(self.overlay.key)
                    self.overlay = nil
                end
            end
        end
    end
    function graph:GetSelection()
        return selectionAnchor, selectionLimit
    end

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
                if data.discrete and not data.showAsDelta then
                    vertex(vertices.x[i], vertices.y[i - 1], line)
                end
                vertex(vertices.x[i], vertices.y[i], line)
                lastDrawnX = i
            end
        end

        vertex(lastX, lastY, line)
        if data.discrete and not data.showAsDelta then
            vertex(maxX, lastY, line)
        end
    end

    -- Layout, Position & Draw

    local keyPadding = MasterFramework:AutoScalingDimension(10)

    local font = MasterFramework.defaultFont
    local color = MasterFramework:Color(0.3, 0.3, 0.3, 1)

    local topText = MasterFramework:Text("", color, font)
    local zeroText = MasterFramework:Text("0", color, font)
    local bottomText = MasterFramework:Text("", color, font)
    local bottomRightText = MasterFramework:Text("", color, font)
    local bottomRightTextWidth

    local indent = MasterFramework:AutoScalingDimension(2)

    function graph:Layout(availableWidth, availableHeight)
        self:RegisterDrawingGroup()
        self:NeedsLayout()
        minY = math.huge
        maxY = -math.huge
        minX = math.huge
        maxX = -math.huge

        for _, line in ipairs(data.lines) do
            minX = math.min(minX, line.vertices.x[1])
            maxX = math.max(maxX, line.vertices.x[#line.vertices.x])

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
            topText:SetString(format(math.exp(maxY), data.yUnit))
            bottomText:SetString(format(minX, data.xUnit) .. ", " .. format(-math.exp(-minY), data.yUnit))
        else
            topText:SetString(format(maxY, data.yUnit))
            bottomText:SetString(format(minX, data.xUnit) .. ", " .. format(minY, data.yUnit))
        end
        bottomRightText:SetString(format(maxX, data.xUnit))
        
        topText:Layout(availableWidth, font:ScaledSize())
        bottomText:Layout(availableWidth, font:ScaledSize())
        bottomRightTextWidth = bottomRightText:Layout(availableWidth, font:ScaledSize())
        
        return availableWidth, availableHeight
    end

    function graph:Position(x, y)
        if minY < 0 and maxY > 0 then
            zeroText:Position(x + indent(), y - minY / verticalRatio)
        end

        topText:Position(x + indent(), y + cachedHeight - font:ScaledSize())
        bottomText:Position(x + indent(), y)
        bottomRightText:Position(x + cachedWidth - bottomRightTextWidth - indent(), y)

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
        self:RegisterDrawingGroup()
        gl_PushMatrix()

        gl_LineWidth(1)

        gl_Translate(cachedX, cachedY, 0)

        if selectionAnchor then
            gl_Color(0.25, 0.25, 0.25, 1)
            if not selectionLimit or selectionAnchor == selectionLimit then
                gl_Rect(selectionAnchor, 0, selectionAnchor + 1, cachedHeight)
            elseif selectionAnchor > selectionLimit then
                gl_Rect(selectionLimit, 0, selectionAnchor, cachedHeight)
            else -- selectionAnchor < selectionLimit
                gl_Rect(selectionAnchor, 0, selectionLimit, cachedHeight)
            end
        end

        gl_BeginEnd(GL_LINES, DrawGraphHorizontalLines)
        
        gl_PushMatrix()

        gl_Scale(cachedWidth / (maxX - minX), cachedHeight / (maxY - minY), 1)
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
    local padding = MasterFramework:AutoScalingDimension(8)

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
                    graphTitle:SetString(graphName .. ":")
                    uiGraph:SetData(graphData[graphName])
                    uiGraph:Select()
                    logarithmicCheckBox:SetChecked(graphData[graphName].showAsLogarithmic)
                    deltaCheckBox:SetChecked(graphData[graphName].showAsDelta)
                    graphLinesMenu.items = table.imap(graphData[graphName].lines, function(_, line)
                        local color = MasterFramework:Color(line.color.r, line.color.g, line.color.b, line.color.a)
                        local checkbox = MasterFramework:CheckBox(12, function(_, checked) line.hidden = not checked end)
                        checkbox:SetChecked(not line.hidden)
                        return MasterFramework:HorizontalStack(
                            {
                                checkbox,
                                line.title and MasterFramework:Text(line.title, color) or MasterFramework:Background(MasterFramework:Rect(MasterFramework:AutoScalingDimension(20), MasterFramework:AutoScalingDimension(12)), { color }, MasterFramework:AutoScalingDimension(3))
                            },
                            MasterFramework:AutoScalingDimension(8),
                            0.5
                        )
                    end)
                end)
            }
        end)

        table.sort(uiCategories, function(a, b) return a.name < b.name end)

        menu:SetMembers(table.imap(uiCategories, function(_, value)
            return value.list
        end))

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

    stepInterval = MasterFramework:AutoScalingDimension(50)

    uiGraph = UIGraph(
        graphData,
        5,
        5
    )

    menu = MasterFramework:VerticalStack(
        {},
        MasterFramework:AutoScalingDimension(8),
        0
    )

    graphLinesMenu = HorizontalWrap({}, MasterFramework:AutoScalingDimension(8), MasterFramework:AutoScalingDimension(2), 0.5, 0.5)

    logarithmicCheckBox = MasterFramework:CheckBox(12, function(_, checked) uiGraph:SetShowAsLogarithmic(checked) end)
    deltaCheckBox = MasterFramework:CheckBox(12, function(_, checked) uiGraph:SetShowAsDelta(checked) end)
    graphTitle = MasterFramework:Text("Demo Graph: ")

    local split = MasterFramework:HorizontalStack(
        { 
            MasterFramework:VerticalScrollContainer(
                MasterFramework:MarginAroundRect(
                    menu,
                    MasterFramework:AutoScalingDimension(0),
                    MasterFramework:AutoScalingDimension(0),
                    MasterFramework:AutoScalingDimension(0),
                    MasterFramework:AutoScalingDimension(0)
                )
            ),
            MasterFramework:VerticalHungryStack(
                MasterFramework:HorizontalStack({
                        graphTitle,
                        logarithmicCheckBox, MasterFramework:Text("Logarithmic"),
                        deltaCheckBox, MasterFramework:Text("Delta")
                    },
                    MasterFramework:AutoScalingDimension(8),
                    0.5
                ),
                MasterFramework:Background(
                    MasterFramework:MarginAroundRect(
                        MasterFramework:MouseOverResponder(
                            MasterFramework:MousePressResponder(
                                MasterFramework:DrawingGroup(uiGraph, true),
                                function(responder, x, y, button)
                                    local baseX, _ = responder:CachedPosition()
                                    uiGraph:Select(x - baseX)
                                    return true
                                end,
                                function(responder, x, y, dx, dy, button)
                                    local responderX, _, responderWidth, _ = responder:Geometry()
                                    if button == 1 then
                                        local baseX, _ = responder:CachedPosition()
                                        local selectionAnchor, _ = uiGraph:GetSelection()
                                        uiGraph:Select(selectionAnchor, math.max(math.min(x - baseX, responderWidth), 0))
                                    end
                                end,
                                function(responder, x, y, button) end
                            ),
                            function(responder, x, y)
                                local _, selectionLimit = uiGraph:GetSelection()
                                if not selectionLimit then
                                    local baseX, _ = responder:CachedPosition()
                                    uiGraph:Select(x - baseX)
                                end
                            end,
                            function() end,
                            function()
                                local _, selectionLimit = uiGraph:GetSelection()
                                if not selectionLimit then
                                    uiGraph:Select()
                                end
                            end
                        ),
                        MasterFramework:AutoScalingDimension(0),
                        MasterFramework:AutoScalingDimension(0),
                        MasterFramework:AutoScalingDimension(0),
                        MasterFramework:AutoScalingDimension(0)
                    ),
                    { MasterFramework.color.baseBackgroundColor },
                    MasterFramework:AutoScalingDimension(0)
                ),
                MasterFramework:MarginAroundRect(
                    graphLinesMenu,
                    MasterFramework:AutoScalingDimension(20),
                    MasterFramework:AutoScalingDimension(20),
                    MasterFramework:AutoScalingDimension(20),
                    MasterFramework:AutoScalingDimension(20)
                ),
                0.5
            )
        },
        MasterFramework:AutoScalingDimension(8),
        1
    )

    local resizableFrame = MasterFramework:ResizableMovableFrame(
        "MasterCustomStats StatsFrame",
        MasterFramework:PrimaryFrame(
            MasterFramework:Background(
                MasterFramework:MarginAroundRect(
                    split,
                    MasterFramework:AutoScalingDimension(20),
                    MasterFramework:AutoScalingDimension(20),
                    MasterFramework:AutoScalingDimension(20),
                    MasterFramework:AutoScalingDimension(20)
                ),
                { MasterFramework.color.baseBackgroundColor },
                MasterFramework:AutoScalingDimension(5)
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

    if uiGraph.overlay then
        MasterFramework:RemoveElement(uiGraph.overlay.key)
    end
    MasterFramework:RemoveElement(key)
    WG.MasterStats = nil
end