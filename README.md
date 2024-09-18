Master-Stats-Framework is a real-time statistics widget for the Recoil Engine (with specific focus on Beyond All Reason: compatibility with other games is not guaranteed). It provides an interface by which statistics-collection widgets may make their statistics available to a player/spectator - currently limited to graphs.

Note: Master Stats Framework depends upon [MasterBel2's GUI Framework](https://github/MasterBel2/Master-GUI-Framework) and [Recoil Lua Editor](https://github.com/MasterBel2/Recoil-Lua-Editor).

Widgets wishing to present stats must implement `function widget:MasterStatsCategories()`.
This function should return a table of categories, where: 
    - the key for each category should be a human-readable string, that will be case-sensitively merged with categories from other widgets.
    - the value for each category should be a table of graphs, where:
      - the key for each graph should be a unique human-readable string that will be used as the graph's title on-screen.
      - the value for each graph should be a table with the following fields:
        - (number) `minX`, `maxX`. Values provided in the table should not exceed the bounds specified by these values.
        - (boolean) `discrete` - specifies whether each value is a descrete step. If true, the graph will draw extra vertices to avoid "interpolated" slanted lines between values.
        - (array) `lines`, where each value is a table with the following properties:
          - (table) `color` - a table containing { r = r, g = g, b = b, a = a }
          - (table) `vertices` where:
            - (array) `x`, `y` - the array of x/y values, respectively. `vertices.x[n]` corresponds to `vertices.y[n]`. The data is structured like this to achieve SIGNIFICANT speedups.

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

If your widget is after `Master Stats Framework`, you will need to tell it about your widget. Call `WG.MasterStats:Refresh()` (usually only in `widget:Initialize()`) to trigger a re-scan of statistics available by widgets, so that your new graph is shown.