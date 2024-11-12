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

--[=[
    To Display Your Graph Here: Implement `function widget:MasterStatsCategories()`

    This function should return a table of categories, where: 
    - the key for each category should be a human-readable string, that will be case-sensitively merged with categories from other widgets.
    - the value for each category should be a table of graphs, where:
      - the key for each graph should be a unique human-readable string that will be used as the graph's title on-screen
      - the value for each graph should follow one of the following formats:

    Raw Table:
    - (string) xUnit: Specifies the units for the x axis. Custom formatting will be provided for the values "Frames" and "Seconds" - they will be shown with `hrs, mins, secs` formatting.
    - (string) yUnit: Specifies the units for the y axis. Custom formatting will be provided for the values "Frames" and "Seconds" - they will be shown with `hrs, mins, secs` formatting.
    - (boolean) discrete Specifies whether each value is a descrete step. If true, the graph will draw extra vertices to avoid "interpolated" slanted lines between values.
    - (array) lines, where each value is a table with the following properties:
        - (table) color: A table containing { r = r, g = g, b = b, a = a }
        - (string) title: A human-readable string indicating what the line describes.
        - (table) vertices:
            - (array) x, y: the array of x/y values, respectively. vertices.x[n] corresponds to vertices.y[n]. The data is structured like this to achieve SIGNIFICANT speedups.

    Dependent Table:
    - (array)  dependencyPaths: Each value is a string containing the category, widget name, and name of the graph to be depended upon.
                                Each dependency must have the xUnit and the same line count, color, and titles.
    - (string) yUnit: specifies the units for the y axis. Custom formatting will be provided for the values "Frames" and "Seconds" - they will be shown with `hrs, mins, secs` formatting.

    The following fields will be auto-generated for a dependent table, based on the dependencies:
    - (string)   xUnit: specifies the units for the y axis. Custom formatting will be provided for the values "Frames" and "Seconds" - they will be shown with `hrs, mins, secs` formatting.
    - (array)    lines: Describes each of the lines to be drawn, where each value is a table with the following properties:
        - (table) color: A table containing { r = r, g = g, b = b, a = a }
        - (string) title: A human-readable string indicating what the line describes.
    - (function) generator:
        parameters:
            - x: The value represented by the horizontal location the pixel will be drawn.
            - dependencyYValues: An array containing the y value corresponding to the provided x value for each of the dependencies.
    
    These auto-generated fields should be considered read-only.

    E.g. 

    ```lua
    function widget:MasterStatsCategories()
        return {
            ["Demo Category"] = {
                ["Demo Raw Graph"] = {
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
                ["Demo Dependent Graph"] = {
                    dependencies = { "Demo Category/Stats (MasterBel2 Edition)/Demo Raw Graph" },
                    xUnit = "Frames", --[[Auto-generated! DO NOT PROVIDE A VALUE FOR THIS]]
                    yUnit = "Metal",
                    lines = --[[Auto-generated! DO NOT PROVIDE A VALUE FOR THIS]] {
                        {
                            title = "Belmakor", -- optional
                            hidden = true, -- optional; when absent, the line is assumed to be showing. (i.e. lines are only hidden if explicitely set to be hidden)
                            color = { r = 1, g = 0, b = 0, a = 1 }
                        },
                        {
                            title = "BelSon", -- optional
                            color = { r = 0, g = 0, b = 1, a = 1 }
                        },
                        {
                            title = "MasterBel2", -- optional
                            color = { r = 0, g = 1, b = 0, a = 1 }
                        }
                    }
                }
            }
        }
    end
    ```
]=]

------------------------------------------------------------------------------------------------------------
-- Dummy Data (For testing purposes)
------------------------------------------------------------------------------------------------------------

local demoGraph = {
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
local math_huge = math.huge
local math_floor = math.floor

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

local function returnZero() return 0 end
local function returnOne() return 1 end
local function returnFirstDependency(x, dependencyYValues)
    return dependencyYValues[1]
end

------------------------------------------------------------------------------------------------------------
-- Data
------------------------------------------------------------------------------------------------------------

local categories
local graphData

local selectedGraphTitle

local composedGraphsDir = "LuaUI/Custom Stats/Composed Graphs"

local function SaveComposedGraph(graphName, graph)
    Spring.CreateDir(composedGraphsDir)
    local file = io.open(composedGraphsDir .. "/" .. graphName .. ".json", "w")
    file:write(Json.encode({
        graphName = graphName,
        generator = graph._rawGenerator,
        yUnit = graph.yUnit,
        dependencyPaths = graph.dependencyPaths
    }))
    file:close()
end

local customComposedGraphs = {}

function widget:MasterStatsCategories()
    return {
        ["Custom Composed Graphs"] = customComposedGraphs
    }
end

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
        local thousandsMagnitude = math.floor(math.log(math.abs(number))/math.log(1000))
        local tensMagnitude = math.floor(math.log(math.abs(number))/math.log(10))
        local magnitudeSuffix = {
            [-6] = "a",
            [-5] = "f",
            [-4] = "p",
            [-3] = "n",
            [-2] = "µ",
            [-1] = "m",
            [0] = "",
            [1] = "k",
            [2] = "M",
            [3] = "B",
            [4] = "T",
            [5] = "P",
            [6] = "E",
        }
        local formatString = {
            [0] = "%.2f",
            [1] = "%.1f",
            [2] = "%.0f"
        }
        if number == 0 then
            return "0.00"
        end
        if thousandsMagnitude < 0 then
            number = number * math.pow(10, 0 - thousandsMagnitude * 3)
        elseif thousandsMagnitude > 0 then
            number = number / math.pow(10, thousandsMagnitude * 3)
        end
        return string.format(formatString[tensMagnitude % 3], number) .. (magnitudeSuffix[thousandsMagnitude] or "")
    end
end

------------------------------------------------------------------------------------------------------------
-- Interface Structure
------------------------------------------------------------------------------------------------------------

local function MatchWidth(target, body)
    local matchWidth = {}

    function matchWidth:Layout(availableWidth, availableHeight)
        local width, _ = target:Size()
        local _, height = body:Layout(width, availableHeight)
        return width, height
    end

    function matchWidth:Position(...)
        body:Position(...)
    end

    return matchWidth
end

local function MatchHeight(target, body)
    local matchHeight = {}

    function matchHeight:Layout(availableWidth, availableHeight)
        local _, height = target:Size()
        local width, _ = body:Layout(availableWidth, height)
        return width, height
    end

    function matchHeight:Position(...)
        body:Position(...)
    end

    return matchHeight
end

local function UIGraph(data)

    local graph = MasterFramework:Component(true, true)

    -- local xOffset = 0
    -- local yOffset = 0
    -- local xScale = 1
    -- local yScale = 1

    -- function graph:GetScales()
    --     return xScale, yScale
    -- end
    -- function graph:SetScales(newXScale, newYScale)
    --     if xScale ~= newXScale or yScale ~= newYScale then
    --         xScale = newXScale
    --         yScale = newYScale
    --         self:NeedsLayout()
    --     end
    -- end
    -- function graph:GetOffsets()
    --     return xOffset, yOffset
    -- end
    -- function graph:SetOffsets(newXOffset, newYOffset)
    --     if xOffset ~= newXOffset or yOffset ~= newYOffset then
    --         xOffset = newXOffset
    --         yOffset = newYOffset
    --         self:NeedsLayout()
    --     end
    -- end

    function graph:SetData(newData)
        data = newData
    end

    function graph:GetData()
        return data
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

    local cachedX, cachedX
    local cachedWidth, cachedHeight
    local verticalRatio

    local lastDrawnY

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
                     -- + 1 offsets from selection indicator & graph top border
                    self.overlay:SetOffsets(overlayX + 1, MasterFramework.viewportHeight - overlayY + 1)
                else
                    local stackMembers = table.imap(data.lines, function(_, line)
                        local valueText = MasterFramework:Text("")
                        local member = MasterFramework:HorizontalStack(
                            { MasterFramework:Text(line.title or "<Unknown>", MasterFramework:Color(line.color.r, line.color.g, line.color.b, line.color.a)), valueText },
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

    local function vertex(x, y, line, minY, maxY, lineVertexXCoordinates, lineVertexYCoordinates)
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
        local newVertexCount = vertexCounts[line] + 1
        lineVertexXCoordinates[newVertexCount] = x
        lineVertexYCoordinates[newVertexCount] = y

        vertexCounts[line] = newVertexCount

        return math_min(y, minY), math_max(y, maxY)
    end

    -- Layout, Position & Draw

    local font = MasterFramework.defaultFont
    local color = MasterFramework:Color(0.3, 0.3, 0.3, 1)

    local topText = MasterFramework:Text("", color, font)
    local zeroText = MasterFramework:Text("0", color, font)
    local bottomText = MasterFramework:Text("", color, font)
    local bottomRightText = MasterFramework:Text("", color, font)
    local bottomRightTextWidth

    local indent = MasterFramework:AutoScalingDimension(2)

    local function graphMetadata(data, pixelWidth)
        local minY = math.huge
        local maxY = -math.huge

        if data.dependencies then
            if #data.dependencies == 0 or not data.generator then
                return 0, "", 0, 0, 0, 0
            end
            -- if not data.xUnit then error("graphMetadata: no xUnit on non-dependent graph!") end
            local firstLineCount, firstXUnit, minX, maxX = graphMetadata(data.dependencies[1], pixelWidth)
            for i = 2, #data.dependencies do
                local lineCount, xUnit, _minX, _maxX = graphMetadata(data.dependencies[i], pixelWidth)
                if lineCount ~= firstLineCount then
                    error("graphMetadata: Dependency has mismatched line count!")
                end
                if firstXUnit ~= xUnit then
                    error("graphMetadata: Dependency has mismatched x unit!")
                end
                minX = math.max(minX, _minX)
                maxX = math.min(maxX, _maxX)
            end

            for lineIndex = 1, firstLineCount do
                local line
                if data.lines[lineIndex] ~= nil then
                    line = data.lines[lineIndex]
                else
                    line = { 
                        color = data.dependencies[1].lines[lineIndex].color,
                        title = data.dependencies[1].lines[lineIndex].title
                    }
                    data.lines[lineIndex] = line
                    vertexXCoordinates[line] = {}
                    vertexYCoordinates[line] = {}
                    line.vertices = { x = vertexXCoordinates[line], y = vertexYCoordinates[line] }
                end

                local dependencyYValues = table.repeating(firstLineCount, returnZero)
                local dependencyNextXIndex = table.repeating(firstLineCount, returnOne)

                local xCoordinates = vertexXCoordinates[line]
                local yCoordinates = vertexYCoordinates[line]
                
                local vertexCount = 0
                local dependencyCount = #data.dependencies
                for graphX = 0, pixelWidth do
                    local x = graphX / pixelWidth * (maxX - minX)
                    for i = 1, dependencyCount do
                        local dependencyLine = data.dependencies[i].lines[lineIndex]
                        local dependencyXCoordinates = vertexXCoordinates[dependencyLine]
                        local dependencyYCoordinates = vertexYCoordinates[dependencyLine]

                        while dependencyXCoordinates[dependencyNextXIndex[i]] and (dependencyXCoordinates[dependencyNextXIndex[i]] < x) do
                            dependencyNextXIndex[i] = dependencyNextXIndex[i] + 1
                        end
                        -- if true then
                        if data.dependencies[i].discrete or not dependencyXCoordinates[dependencyNextXIndex[i] - 1] or not dependencyXCoordinates[dependencyNextXIndex[i]] then
                            dependencyYValues[i] = dependencyYCoordinates[dependencyNextXIndex[i]] or dependencyYValues[i]
                        else
                            local previousY = dependencyYCoordinates[dependencyNextXIndex[i] - 1] or dependencyYValues[i]
                            local nextY = dependencyYCoordinates[dependencyNextXIndex[i]] or dependencyYValues[i]
                            local previousX = dependencyXCoordinates[dependencyNextXIndex[i] - 1]
                            local nextX = dependencyXCoordinates[dependencyNextXIndex[i]] or x
                            dependencyYValues[i] = (previousY + ((nextY - previousY) * (x - previousX) / (nextX - previousX) )) or dependencyYValues[i]
                        end
                    end

                    local y = data.generator(x, dependencyYValues)

                    vertexCount = vertexCount + 1
                    xCoordinates[vertexCount] = x
                    yCoordinates[vertexCount] = y
                    
                    minY = math.min(minY, y)
                    maxY = math.max(maxY, y)
                end
                vertexCounts[line] = vertexCount

                for i = vertexCount + 1, #vertexXCoordinates do
                    xCoordinates[i] = nil
                    yCoordinates[i] = nil
                end
            end

            return firstLineCount, firstXUnit, minX, maxX, minY, maxY
        else
            local minX = math_huge
            local maxX = -math_huge
            for i = 1, #data.lines do
                local line = data.lines[i]
                minX = math_min(minX, line.vertices.x[1])
                maxX = math_max(maxX, line.vertices.x[#line.vertices.x])
            end

            local generatePixel = data.discrete and not data.showAsDelta
            local xPerPixelWidth = (maxX - minX) / pixelWidth

            for i = 1, #data.lines do
                local line = data.lines[i]
                vertexCounts[line] = 0
                if not vertexXCoordinates[line] then
                    vertexXCoordinates[line] = {}
                    vertexYCoordinates[line] = {}
                end

                
                local vertexCount = #line.vertices.x
                local vertices = line.vertices
                local xVertices = vertices.x
                local yVertices = vertices.y
                local firstX = xVertices[1]
                local firstY = yVertices[1]
                local lastX = xVertices[vertexCount]
                local lastY = yVertices[vertexCount]

                local lineVertexXCoordinates = vertexXCoordinates[line]
                local lineVertexYCoordinates = vertexYCoordinates[line]

                lastDrawnY = firstY
                minY, maxY = vertex(firstX, firstY, line, minY, maxY, lineVertexXCoordinates, lineVertexYCoordinates)

                local nextDrawX = xPerPixelWidth
                
                for i = 2, vertexCount do
                    if xVertices[i] >= nextDrawX then
                        if generatePixel then
                            minY, maxY = vertex(xVertices[i], yVertices[i - 1], line, minY, maxY, lineVertexXCoordinates, lineVertexYCoordinates)
                        end
                        minY, maxY = vertex(xVertices[i], yVertices[i], line, minY, maxY, lineVertexXCoordinates, lineVertexYCoordinates)
                        nextDrawX = nextDrawX + xPerPixelWidth
                    end
                end

                minY, maxY = vertex(lastX, lastY, line, minY, maxY, lineVertexXCoordinates, lineVertexYCoordinates)
                if generatePixel then
                    minY, maxY = vertex(maxX, lastY, line, minY, maxY, lineVertexXCoordinates, lineVertexYCoordinates)
                end

                for i = vertexCounts[line] + 1, #lineVertexXCoordinates do
                    lineVertexXCoordinates[i] = nil
                    lineVertexYCoordinates[i] = nil
                end
            end

            return #data.lines, data.xUnit, minX, maxX, minY, maxY
        end
    end

    function graph:Layout(availableWidth, availableHeight)
        self:RegisterDrawingGroup()
        self:NeedsLayout()
        
        local _, _, _minX, _maxX, _minY, _maxY = graphMetadata(data, availableWidth)
        minX = _minX
        maxX = _maxX
        minY = _minY
        maxY = _maxY

        verticalRatio = (maxY - minY) / availableHeight

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
            if not line.hidden then
                gl_BeginEnd(GL_LINE_STRIP, DrawGraphData, line, cachedWidth)
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

local compositionLogicField
local graphDependenciesField
local wrappedGraphLinesMenu
local graphFooterStack

local refreshRequested = true

local function UISectionedButtonList(name, options, action)
    local padding = MasterFramework:AutoScalingDimension(8)

    local newButtons = {}

    for _, optionName in pairs(options) do
        local button = MasterFramework:Button(
            MasterFramework:Text(optionName),
            function(self)
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

local function DisplayGraph(graphName)
    selectedGraphTitle = graphName
    graphTitle:SetString(graphName .. ":")
    uiGraph:SetData(graphData[graphName])

    logarithmicCheckBox:SetChecked(graphData[graphName].showAsLogarithmic)
    deltaCheckBox:SetChecked(graphData[graphName].showAsDelta)

    if graphData[graphName].lines then
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
    end

    if graphData[graphName]._customComposedGraph then
        graphDependenciesField.text:SetString(table.concat(table.imap(graphData[graphName].dependencyPaths, function(_, dependencyName) return "\"" .. dependencyName .. "\"" end), ", ") or "")
        compositionLogicField.text:SetString(graphData[graphName]._rawGenerator)
        graphFooterStack:SetMembers({
            graphDependenciesField,
            compositionLogicField,
            wrappedGraphLinesMenu
        })
    else
        graphFooterStack:SetMembers({
            wrappedGraphLinesMenu
        })
    end
end

------------------------------------------------------------------------------------------------------------
-- Create / Destroy
------------------------------------------------------------------------------------------------------------

function widget:Update()

    if refreshRequested then
        categories = {}

        for _, widget in pairs(widgetHandler.widgets) do
            if widget.MasterStatsCategories then
                -- categories[name] = { graphs = table }
                local widgetCategories = widget:MasterStatsCategories()

                for categoryName, widgetCategory in pairs(widgetCategories) do
                    local section = {}
                    for graphName, graph in pairs(widgetCategory) do
                        section[graphName] = graph
                    end

                    local existingCategory = categories[categoryName] or { sections = {} }
                    existingCategory.sections[widget.whInfo.name] = section

                    categories[categoryName] = existingCategory
                end
            end
        end

        for categoryKey, category in pairs(categories) do
            for sectionKey, section in pairs(category.sections) do
                for graphName, graph in pairs(section) do
                    if graph.dependencyPaths then
                        graph.lines = {}
                        if not pcall(function()
                            graph.dependencies = table.imap(graph.dependencyPaths, function(_, path)
                                local categoryName, widgetName, graphName = path:match("([^/]+)/([^/]+)/([^/]+)")
                                local category = categories[categoryName]
                                if category then
                                    local section = category.sections[widgetName]
                                    if section and section[graphName] then
                                        return section[graphName]
                                    else
                                        error()
                                    end
                                else
                                    error()
                                end
                            end)
                        end) then
                            graph.dependencies = {}
                            -- section[graphName] = nil
                            -- if next(section) == nil then
                            --     Spring.Echo("Section empty!")
                            --     category.sections[sectionKey] = nil
                            --     if next(category.sections) == nil then
                            --         Spring.Echo("Category empty!")
                            --         categories[categoryKey] = nil
                            --     end
                            -- end
                        end
                    end
                end
            end
        end

        graphData = {}
        local uiCategories = table.mapToArray(categories, function(key, value)

            local graphNames = {}

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
                    DisplayGraph(graphName)
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

    for _, filename in ipairs(VFS.DirList(composedGraphsDir, nil, VFS.RAW)) do
        local success, _error = pcall(function()
            local data = Json.decode(VFS.LoadFile(filename, VFS.RAW))
            customComposedGraphs[data.graphName] = {
                _customComposedGraph = true,
                yUnit = data.yUnit,
                rawGenerator = data.generator,
                dependencyPaths = data.dependencyPaths
            }

            local func = loadstring("return function(x, dependencyYValues)\nreturn " .. data.generator .. "\nend")
            if func and data.generator ~= "" then
                if type(func()) == "function" then
                    customComposedGraphs[data.graphName].generator = func()
                else
                    customComposedGraphs[data.graphName].generator = returnFirstDependency
                end
            else
                customComposedGraphs[data.graphName].generator = returnFirstDependency
            end
        end)
        if not success then Spring.Echo(_error) end
    end

    
    table = MasterFramework.table
    reduce = table.reduce

    uiGraph = UIGraph(demoGraph)

    menu = MasterFramework:VerticalStack(
        {},
        MasterFramework:AutoScalingDimension(8),
        0
    )

    graphLinesMenu = HorizontalWrap({}, MasterFramework:AutoScalingDimension(8), MasterFramework:AutoScalingDimension(2), 0.5, 0.5)

    logarithmicCheckBox = MasterFramework:CheckBox(12, function(_, checked) uiGraph:SetShowAsLogarithmic(checked) end)
    deltaCheckBox = MasterFramework:CheckBox(12, function(_, checked) uiGraph:SetShowAsDelta(checked) end)
    graphTitle = MasterFramework:Text("Demo Graph: ")

    compositionLogicField = WG.LuaTextEntry(MasterFramework, "", "Enter Composition Logic Here", function()
        local data = uiGraph:GetData()
        if data and data._customComposedGraph then
            local func = loadstring("return function(x, dependencyYValues)\nreturn " .. compositionLogicField.text:GetRawString() .. "\nend")
            if func then
                local success, errorOrGenerator = pcall(func)
                if success and (type(errorOrGenerator) == "function") then
                    local yValues = table.repeating(#data.lines, returnZero)
                    local success, result = pcall(errorOrGenerator, 0, yValues)
                    if success and (type(result) == "number") then
                        data._rawGenerator = compositionLogicField.text:GetRawString()
                        data.generator = errorOrGenerator
                        SaveComposedGraph(selectedGraphTitle, data)
                    else
                        Spring.Echo(result)
                    end
                else
                    Spring.Echo(errorOrGenerator)
                end
            end
        end
    end)
    graphDependenciesField = WG.LuaTextEntry(MasterFramework, "", "Enter Graph Dependencies Here", function()
        local data = uiGraph:GetData()
        if data and data._customComposedGraph then
            local func = loadstring("return { " .. graphDependenciesField.text:GetRawString() .. " }")
            if func then
                local success, result = pcall(func)
                if success and (type(result) == "table") then
                    for _, value in ipairs(result) do
                        if type(value) ~= "string" then
                            return
                        end
                        data.dependencyPaths = result
                        SaveComposedGraph(selectedGraphTitle, data)
                        WG.MasterStats:Refresh()
                    end
                else
                    Spring.Echo(result)
                end
            end
        end
    end)
    wrappedGraphLinesMenu = MasterFramework:MarginAroundRect(
        graphLinesMenu, 
        MasterFramework:AutoScalingDimension(20), 
        MasterFramework:AutoScalingDimension(20), 
        MasterFramework:AutoScalingDimension(20), 
        MasterFramework:AutoScalingDimension(20)
    )

    graphFooterStack = MasterFramework:VerticalStack({}, MasterFramework:AutoScalingDimension(8), 0)

    local split = MasterFramework:HorizontalStack(
        {
            MasterFramework:VerticalHungryStack(
                MasterFramework:Rect(MasterFramework:AutoScalingDimension(0), MasterFramework:AutoScalingDimension(0)),
                MasterFramework:VerticalScrollContainer(menu),
                MasterFramework:Button(
                    MasterFramework:Text("+"),
                    function()
                        local baseGraphTitle = "New Composed Graph"
                        local graphTitle = baseGraphTitle
                        local counter = 0

                        while customComposedGraphs[graphTitle] do
                            counter = counter + 1
                            graphTitle = baseGraphTitle .. " " .. counter
                        end
                        customComposedGraphs[graphTitle] = {
                            _customComposedGraph = true,
                            yUnit = "",
                            _rawGenerator = "",
                            generator = returnFirstDependency,
                            dependencyPaths = {}
                        }

                        WG.MasterStats:Refresh()
                    end
                ),
                0
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
                    { MasterFramework.color.baseBackgroundColor },
                    MasterFramework:AutoScalingDimension(0)
                ),
                graphFooterStack,
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
    if uiGraph.overlay then
        MasterFramework:RemoveElement(uiGraph.overlay.key)
    end
    MasterFramework:RemoveElement(key)
    WG.MasterStats = nil
end