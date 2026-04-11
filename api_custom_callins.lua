function widget:GetInfo()
    return {
        name = "Custom Callins (API)",
        description = "Dev tool, do not disable",
        author = "MasterBel2",
        version = 0,
        date = "December 2024",
        version   = "2026-04",
        license = "GNU GPL, v2 or later",
        layer = -math.huge,
        handler = true
    }
end

--[[
    Structure:
    ```lua
    publisherCallIns = {
        ["<widgetName>"] = {
            ["<callInName>"] = true,
        },
    }
]]
local publisherCallIns = {}
--[[
    Structure:
    ```lua
    callInListeners = {
        ["<callInName>"] = {
            ["<widgetName"] = true,
        },
    }
]]
local callInListeners = {}

function widget:DebugInfo()
    return {
        publisherCallIns,
        callInListeners
    }
end

--------------------
-- Setup/Teardown --
--------------------

function widget:Initialize()

    --[[
    .

    To avoid potential duplicate hooks, we create our hooks once and re-use them.
    These WG functions are created on Initialize and removed on Shutdown.

    WG.CustomCallIns_UpdateWidget(widget):
    - To be called only from widgetHandler when a widget is added or updates a callin.
    - Scans the widget for known custom callins and subscribes it as a listener for each.

    WG.CustomCallIns_RemovedWidget(widget):
    - To be called only from widgetHandler when a widget is removed.
    - Removes all callins created by the widget.
    - Removes the widget from all callin listener lists.

    WG.CustomCallIns_NewCallIn(widget, callInName):
    - Returns a func that can be called to trigger a callin.
    - Creates an empty listener list for widgets to subscribe to.
    - Auto-populates the listener list with any widgets that implement the custom callin.
    - Fails with error if another callin has been created with the same callin name.
    e.g.
    ```lua
    local MyCallIn = WG.CustomCallIns_NewCallIn()
    ```
    ]]

    WG.CustomCallIns_UpdateWidget = function(widget)
        for callInName, listeners in pairs(callInListeners) do
            listeners[widget] = widget[callInName] and true or nil
        end
    end
    WG.CustomCallIns_RemovedWidget = function(widget)
        for callInName, listeners in pairs(callInListeners) do
            listeners[widget] = nil
        end
        if publisherCallIns[widget] then
            for callInName, _ in pairs(publisherCallIns[widget]) do
                callInListeners[callInName] = nil
            end
            publisherCallIns[widget] = nil
        end
    end
    WG.CustomCallIns_NewCallIn = function(widget, callInName)
        if callInListeners[callInName] then
            -- error("CallIn \"" .. callInName .. "\" already exists!")
        end
        
        local listeners = {}
        callInListeners[callInName] = listeners
        publisherCallIns[widget] = publisherCallIns[widget] or {}
        publisherCallIns[widget][callInName] = true

        for i = 1, #widgetHandler.widgets do
            if widgetHandler.widgets[i][callInName] then
                callInListeners[callInName][widgetHandler.widgets[i]] = true
            end
        end

        return function(...)
            for listener, _ in pairs(listeners) do
                listener[callInName](listener, ...)
            end
        end
    end

    if widgetHandler.customCallIns_hooked then return end
    widgetHandler.customCallIns_hooked = true

    local _RemoveWidgetRaw = widgetHandler.RemoveWidgetRaw
    widgetHandler.RemoveWidgetRaw = function(widgetHandler, widget)
        _RemoveWidgetRaw(widgetHandler, widget)
        if WG.CustomCallIns_RemovedWidget then WG.CustomCallIns_RemovedWidget(widget) end
    end
    local _LoadWidget = widgetHandler.LoadWidget
    widgetHandler.LoadWidget = function(...)
        local widget = _LoadWidget(...)
        if WG.CustomCallIns_UpdateWidget then WG.CustomCallIns_UpdateWidget(widget) end
        return widget
    end
    local _UpdateWidgetCallIn = widgetHandler.UpdateWidgetCallIn
    widgetHandler.UpdateWidgetCallIn = function(widgetHandler, name)
        _UpdateWidgetCallIn(widgetHandler, name, widget)
        if WG.CustomCallIns_UpdateWidget then WG.CustomCallIns_UpdateWidget(widget) end
    end
    local _RemoveCallIn = widgetHandler.RemoveCallIn
    widgetHandler.RemoveCallIn = function(widgetHandler, name, widget)
        _RemoveCallIn(name, widget)
        if WG.CustomCallIns_UpdateWidget then WG.CustomCallIns_UpdateWidget(widget) end
    end
end

function widget:Shutdown()
    WG.CustomCallIns_NewCallIn = nil
    WG.CustomCallIns_RemovedWidget = nil
    WG.CustomCallIns_UpdateWidget = nil
end