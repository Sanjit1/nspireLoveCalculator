platform.apilevel = '2.0'     

----------------------------------
-- ETK 4.0 Demo project         --
--                              --
-- (C) 2015 Jim Bauwens         --
-- Licensed under the GNU GPLv3 --
----------------------------------

--------------------------------------
-- Start of extra/lua_additions.lua --
--------------------------------------

-- The following defines/macros are supposed to be used for simple cases only
-- (within simple syntax constructs that wouldn't confuse the "parser". See examples.)

--Lua variable pattern


--Lambda style!




--Indexing of strings, string:sub(index, index)


--Increment/Decrement (Note: just use that in a "standalone way", not like: print(a = a + 1) etc.)



--Compound assignment operators


------------------------------------
-- End of extra/lua_additions.lua --
------------------------------------

--------------------------
-- Start of etk/etk.lua --
--------------------------

----------------
-- ETK Loader --
----------------

etk = {}

do
    local etk = etk

    ------------------------------
-- Start of etk/helpers.lua --
------------------------------

----------------------------------
-- ETK Helpers / Utilities      --
--                              --
-- (C) 2015 Jim Bauwens         --
-- Licensed under the GNU GPLv3 --
----------------------------------

------------------
-- Enumerations --
------------------

Enum = function(enumTable)
    for k,v in ipairs(enumTable) do
        enumTable[v] = k
    end

    return enumTable
end


-------------
-- Logging --
-------------

do Logger = {}
    Logger.Log = function (message, ...)
        print(message:format(...))
    end

    Logger.Warn = function (message, ...)
        Logger.Log("Warning: " .. message, ...)
    end
end


-----------------------------------------------
-- Handle different types of user unit input --
-----------------------------------------------

do UnitCalculator = {}
    UnitCalculator.GetAbsoluteValue = function (value, referenceValue)
        local numberValue, unit = string.match(tostring(value), "([-%d.]+)(.*)")

        local number = tonumber(numberValue)

        if not number then
             Logger.Warn("UnitCalculator.GetAbsoluteValue - Invalid number value, returning 0")
             return 0
        end

        local isPercent = unit == "%"

        if number < 0 then
            print(number, "from")
            number = (isPercent and 100 or referenceValue) + number
            print(number, "to")
        end

        if isPercent then
            return referenceValue / 100 * number
        else
           return number
        end
    end
end


-------------------------------------------------
-- Keep dimensions in a nice to handle wrapper --
-------------------------------------------------

do Dimension = class()
    function Dimension:init(width, height)
        self.width = width
        self.height = height
    end

    function Dimension:get(parentWidth, parentHeight, dirty)
        if self.width then
            if dirty or not self.cachedWidth then
                self.cachedWidth  = UnitCalculator.GetAbsoluteValue(self.width, parentWidth)
                self.cachedHeight = UnitCalculator.GetAbsoluteValue(self.height, parentHeight)
            end

            return self.cachedWidth, self.cachedHeight
        else
            self.cachedWidth = parentWidth
            self.cachedHeight = parentHeight

            return parentWidth, parentHeight
        end
    end

    function Dimension:getCachedDimension()
        return self.cachedWidth or 0, self.cachedHeight or 0
    end

    function Dimension:invalidate()
        self.cachedWidth = nil
        self.cachedHeight = nil
    end
end

do Position = class()
    Position.Type  = Enum { "Absolute", "Relative" }
    Position.Sides = Enum { "Left", "Right", "Top", "Bottom" }

    function Position:init(arg)
        arg = arg or {}

        self.left   = arg.left
        self.top    = arg.top
        self.bottom = arg.bottom
        self.right  = arg.right

        self.alignment = arg.alignment or {}

        if not (self.left or self.right) then
            self.left = 0
        end

        if not (self.top or self.bottom) then
            self.top = 0
        end
    end

    function Position:get(parentX, parentY, parentWidth, parentHeight, width, height, dirty)
        if dirty or not self.cachedX then
            local x, y
            local originX = parentX
            local originY = parentY

            if self.right then
                originX = originX + parentWidth
            end

            if self.bottom then
                originY = originY + parentHeight
            end

            for _, alignment in ipairs(self.alignment) do
                local side = alignment.side
                local ref = alignment.ref
                local refWidth, refHeight = ref:getDimension()
                local refX, refY = ref:getPosition()

                if side == Position.Sides.Left then
                    originX = refX
                elseif side == Position.Sides.Right then
                    originX = refX + refWidth
                elseif side == Position.Sides.Top then
                    originY = refY
                elseif side == Position.Sides.Bottom then
                    originY = refY + refHeight
                else
                    Logger.Warn("Invalid side specified")
                end
            end

            if self.left then
                x = originX + UnitCalculator.GetAbsoluteValue(self.left, parentWidth)
            elseif self.right then
                x = originX - UnitCalculator.GetAbsoluteValue(self.right, parentWidth) - width
            end

            if self.top then
                y = originY + UnitCalculator.GetAbsoluteValue(self.top, parentHeight)
            elseif self.bottom then
                y = originY - UnitCalculator.GetAbsoluteValue(self.bottom, parentHeight) - height
            end

            self.cachedX = x
            self.cachedY = y
        end

        return self.cachedX, self.cachedY
    end

    function Position:invalidate()
        self.cachedX = nil
        self.cachedY = nil
    end

    function Position:getCachedPosition()
        return self.cachedX or 0, self.cachedY or 0
    end

end


-----------
-- Color --
-----------

local function unpackColor(col)
    return col[1] or 0, col[2] or 0, col[3] or 0
end


-------------
-- Unicode --
-------------

function string.ulen(str)
    return select(2, str:gsub("[^\128-\193]", "")) -- count the number of non-continuing bytes
end


-------------------
-- Event calling --
-------------------

local CallEvent = function(object, event, ...)
    local handler = object[event]

    if handler then
        return handler, handler(object, ...)
    end
end

----------------------------
-- End of etk/helpers.lua --
----------------------------

    -------------------------------
-- Start of etk/graphics.lua --
-------------------------------

----------------------------------
-- ETK Graphics                 --
-- Some flags and functions     --
-- for painting and more        --
--                              --
-- (C) 2015 Jim Bauwens         --
-- Licensed under the GNU GPLv3 --
----------------------------------

do
    etk.graphics = {}
    local eg = etk.graphics

    eg.needsFullRedraw = true
    eg.dimensionsChanged = true

    eg.isColor = platform.isColorDisplay()

    eg.viewPortWidth  = 318
    eg.viewPortHeight = 212

    eg.areaToRedraw = {0, 0, 0, 0}


    ------------------------------------------------
    -- Replacement for platform.window:invalidate --
    ------------------------------------------------

    eg.invalidate = function (x, y, w, h)
        platform.window:invalidate(x, y, w, h)

        if x then
            eg.needsFullRedraw = false
            eg.areaToRedraw = {x, y, w, h}
        end
    end


    ----------------------------------------------
    -- Replacement for graphicalContex:clipRect --
    ----------------------------------------------

    local clipRectData  = {}
    local clipRects = 0

    local gc_clipRect = function (gc, what, x, y, w, h)
        if what == "set"  then
            clipRects = clipRects + 1
            clipRectData[clipRects] = {x, y, w, h}

        elseif what == "subset" and clipRects > 0 then
            local old  = clipRectData[clipRects]

            x   = old[1] < x and x or old[1]
            y   = old[2] < y and y or old[2]
            h   = old[2] + old[4] > y + h and h or old[2] + old[4] - y
            w   = old[1] + old[3] > x + w and w or old[1] + old[3] - x

            what = "set"

            clipRects = clipRects + 1
            clipRectData[clipRects] = {x, y, w, h}

        elseif what == "restore" and clipRects > 0 then
            what = "set"

            clipRectData[clipRects] = nil
            clipRects = clipRects - 1

            local old  = clipRectData[clipRects]
            x, y, w, h = old[1], old[2], old[3], old[4]

        elseif what == "restore" then
            what = "reset"
        end

        gc:clipRect(what, x, y, w, h)
    end

    --------------------------------------
    -- platform.withGC for apiLevel < 2 --
    --------------------------------------

    if not platform.withGC then
        platform.withGC = function (f, ...)
            local gc = platform.gc()
            gc:begin()
            local args = {...}
            args[#args+1] = gc
            local results = { f(unpack(args)) }
            gc:finish()
            return unpack(results)
        end
    end

    ---------------------------------
    -- Patch the Graphical Context --
    ---------------------------------

    local addToGC = function (name, func)
        local gcMeta = platform.withGC(getmetatable)
        gcMeta[name] = func
    end

    ------------------------
    -- Apply some patches --
    ------------------------

    addToGC("smartClipRect", gc_clipRect)

end

-----------------------------
-- End of etk/graphics.lua --
-----------------------------

    ------------------------------------
-- Start of etk/screenmanager.lua --
------------------------------------

----------------------------------
-- ETK Screenmanager            --
-- stuff and stuff I guess      --
-- cookies                      --
--                              --
-- (C) 2015 Jim Bauwens         --
-- Licensed under the GNU GPLv3 --
----------------------------------

do etk.RootScreen = {}
    local RootScreen = etk.RootScreen
    local eg = etk.graphics

    local x, y = 0, 0

    ---------------------
    -- Screen handling --
    ---------------------

    RootScreen.screens = {}
    local screens = RootScreen.screens

    function RootScreen:pushScreen(screen, args)
        screen:onPushed(args)

        table.insert(screens, screen)
        screen.parent = self
    end

    function RootScreen:popScreen(args)
        local index = #screens
        screens[index]:onPopped(args)

        return table.remove(screens, index)
    end

    function RootScreen:peekScreen()
        return screens[#screens] or RootScreen
    end

    ----------------------------
    -- Dimension and position --
    ----------------------------

    function RootScreen:getDimension()
        return eg.viewPortWidth, eg.viewPortHeight
    end

    function RootScreen:getPosition()
        return x, y
    end

    -------------------
    -- Draw children --
    -------------------

    function RootScreen:paint(gc)
        for k, screen in ipairs(self.screens) do
            screen:paint(gc)
        end
    end

    ----------------
    -- Invalidate --
    ----------------

    function RootScreen:invalidate()
        eg.invalidate()
    end
end

------------------
-- Screen class --
------------------

do etk.Screen = class()
    local Screen = etk.Screen
    local eg = etk.graphics

    function Screen:init(position, dimension)
        self.parent = parent
        self.position = position
        self.dimension = dimension

        self.children = {}
    end

    --------------------------------
    -- Dimension helper functions --
    --------------------------------

    function Screen:getDimension()
        local parentWidth, parentHeight = self.parent:getDimension()

        return self.dimension:get(parentWidth, parentHeight, eg.dimensionsChanged)
    end

    function Screen:getPosition()
        local parentX, parentY = self.parent:getPosition()
        local parentWidth, parentHeight = self.parent:getDimension()
        local width, height = self:getDimension()

        return self.position:get(parentX, parentY, parentWidth, parentHeight, width, height, eg.dimensionsChanged)
    end

    function Screen:containsPosition(x, y)
        local cachedX, cachedY = self.position:getCachedPosition()
        local cachedWidth, cachedHeight = self.dimension:getCachedDimension()

        return x >= cachedX and y >= cachedY and x < cachedX + cachedWidth and y < cachedY + cachedHeight
    end

    ---------------------
    -- Manage children --
    ---------------------

    function Screen:addChild(child)
        table.insert(self.children, child)
        child.parent = self
    end

    function Screen:addChildren(...)
        for k, child in ipairs{...} do
            self:addChild(child)
        end
    end

    ----------------
    -- Invalidate --
    ----------------

    function Screen:invalidate()
        local cachedX, cachedY = self.position:getCachedPosition()
        local cachedWidth, cachedHeight = self.dimension:getCachedDimension()

        eg.invalidate(cachedX, cachedY, cachedWidth, cachedHeight)
    end

    -------------------
    -- Screen events --
    -------------------

    function Screen:onPushed(args)
        -- when pushed
    end

    function Screen:onPopped(args)
        -- when popped
    end

    --------------------
    -- Drawing events --
    --------------------

    function Screen:paint(gc)
        self:prepare(gc)

        local width, height = self:getDimension()
        local x, y = self:getPosition()

        --debug draw bouding boxes
        --gc:drawRect(x, y, width, height)

        self:draw(gc, x, y, width, height, eg.isColor)

        for k, screen in ipairs(self.children) do
            screen:paint(gc)

            -- Reset color to default
            -- Possibly this should also be done with the pen and the font
            gc:setColorRGB(0,0,0)
        end

        self:postDraw(gc, x, y, width, height, eg.isColor)
    end

    function Screen:prepare(gc)
        -- use this callback to calculate dimensions
    end

    function Screen:draw(gc, x, y, width, height, isColor)
        -- all drawing should happen here

        -- called before drawing children
    end

    function Screen:postDraw(gc, x, y, width, height, isColor)
        -- all drawing should happen here

        -- called after drawing children
    end
end

----------------------------------
-- End of etk/screenmanager.lua --
----------------------------------

    ----------------------------------
-- Start of etk/viewmanager.lua --
----------------------------------

----------------
-- View class --
----------------

do etk.View = class(etk.Screen)
    local View   = etk.View
    local Screen = etk.Screen
    local eg     = etk.graphics

    function View:init(args)
        args = args or {}

        local dimension = args.dimension or Dimension()
        local position  = args.position  or Position()

        Screen.init(self, position, dimension)

        self.focusIndex = 0
    end

    -----------------
    -- Focus logic --
    -----------------

    function View:switchFocus(direction, isChildView, counter)
        local children = self.children

        local focusIndex = self.focusIndex

        local currentChild = children[focusIndex]
        local continue = true

        if currentChild and currentChild.focusIndex then
            continue = not currentChild:switchFocus(direction, true, 0) -- do we need to handle the focus change
        end

        if continue then

            if counter > #children then
                return
            else
                counter = counter + 1
            end

            self:removeFocusFromChild(currentChild)

            local nextFocusIndex = focusIndex + direction
            local childrenCount = #self.children
            local wrapped = false

            if nextFocusIndex > childrenCount then
                nextFocusIndex = 1
                wrapped = true
            elseif nextFocusIndex <= 0 then
                nextFocusIndex = childrenCount
                wrapped = true
            end

            if wrapped and isChildView then
                return false -- we are not handling the focus change due to wrapping, the parent focus manager needs to handle it
            else
                return self:giveFocusToChildAtIndex(nextFocusIndex, direction, isChildView, counter)
            end
        end
    end

    function View:removeFocusFromChild(child)
        if child then
            self.focusIndex = 0
            child.hasFocus = false
            CallEvent(child, "onBlur")
        end
    end

    function View:removeFocusFromChildAtIndex(index)
        self:removeFocusFromChild(self:getFocusedChild())
    end

    function View:giveFocusToChildAtIndex(index, direction, isChildView, counter)
        local nextChild = self.children[index]
        self.focusIndex = index

        if nextChild then
            if nextChild.ignoreFocus and direction and counter then
                self:switchFocus(direction, false, counter)
            else
                nextChild.hasFocus = true
                CallEvent(nextChild, "onFocus")
            end
        end
    end

    function View:getFocusedChild()
        return self.children[self.focusIndex]
    end

    -------------------------------------
    -- Link tab events to focus change --
    -------------------------------------

    function View:tabKey()
        self:switchFocus(1, false, 0)

        eg.invalidate()
    end

    function View:backtabKey()
        self:switchFocus(-1, false, 0)
        eg.invalidate()
    end

    -----------------------------------
    -- Link touch event focus change --
    -- and propagete the event       --
    -----------------------------------

    View.lastChildMouseDown = nil
    View.lastChildMouseOver = nil


    function View:getChildIn(x, y)
        local lastChildIndex = View.lastChildMouseDown

        if lastChildIndex then
            local lastChild = self.children[lastChildIndex]
            if lastChild and lastChild:containsPosition(x, y) then
                return lastChildIndex, lastChild
            end
        end

        for index, child in pairs(self.children) do
            if child:containsPosition(x, y) then
                return index, child
            end
        end
    end

    function View:mouseDown(x, y)
        local index, child = self:getChildIn(x, y)

        local lastChild = self:getFocusedChild()
        if child ~= lastChild then
            self:removeFocusFromChild(lastChild)

            if index then
                self:giveFocusToChildAtIndex(index)
            end
        end

        View.lastChildMouseDown = index

        if child then
            CallEvent(child, "onMouseDown", x, y)
        end

        self:invalidate()
    end

    function View:mouseUp(x, y)
        local lastChildIndex = View.lastChildMouseDown

        if lastChildIndex then
            local lastChild = self.children[lastChildIndex]
            CallEvent(lastChild, "onMouseUp", x, y, lastChild:containsPosition(x, y))
        end

        self:invalidate()
    end

    ---------------------------------------------
    -- Propagate other events to focused child --
    ---------------------------------------------

    function View:onEvent(event, eventHandler, ...)
        Logger.Log("View %q - event %q - eventHandler %q", tostring(self), tostring(event), tostring(eventHandler))

        local child = self:getFocusedChild()

        --if not eventHandler and child then -- TODO: ADD event propogation block support
        if child then
            CallEvent(child, "onEvent", event, child[event], ...)
            CallEvent(child, event, ...)
        end
    end
end

--------------------------------
-- End of etk/viewmanager.lua --
--------------------------------

    -----------------------------------
-- Start of etk/eventmanager.lua --
-----------------------------------

----------------------------------
-- ETK Event Manager            --
-- Handle the events!           --
--                              --
-- (C) 2015 Jim Bauwens         --
-- Licensed under the GNU GPLv3 --
----------------------------------

do
    etk.eventmanager = {}
    etk.eventhandlers = {}

    local em = etk.eventmanager
    local eh = etk.eventhandlers
    local eg = etk.graphics
    local rs = etk.RootScreen

    -----------
    -- TOOLS --
    -----------

    -- We will use this function when calling events
    local callEventHandler = function (func, ...)
        if func then
            func(...)
        end
    end


    -------------------
    -- EVENT LINKING --
    -------------------

    local eventLinker = {}
    local triggeredEvent

    local eventDistributer = function (...)
        local currentScreen = rs:peekScreen()
        local eventHandler = currentScreen[triggeredEvent]

        local genericEventHandler = currentScreen.onEvent
        if genericEventHandler then
            genericEventHandler(currentScreen, triggeredEvent, eventHandler, ...)
        end

        if eventHandler then
            eventHandler(currentScreen, ...)
        end
    end

    eventLinker.__index = function (on, event)
        triggeredEvent = event
        return eventDistributer
    end

    setmetatable(on, eventLinker)

    on.activate = function ()
        eg.needsFullRedraw = true
    end

    on.getFocus = function ()
        eg.needsFullRedraw = true
    end

    on.resize = function (width, height)
        Logger.Log("Viewport dimensions changed to %dx%d", width, height)

        eg.dimensionsChanged = true
        eg.needsFullRedraw = true

        eg.viewPortWidth  = width
        eg.viewPortHeight = height
    end

    on.paint = function(gc)
        gc:smartClipRect("set", 0, 0, eg.viewPortWidth, eg.viewPortHeight)

        --eventLinker.__index(on, "paint")(gc)
        rs:paint(gc, 0, 0, eg.viewPortWidth, eg.viewPortHeight)

        eg.dimensionsChanged = false
    end

end

---------------------------------
-- End of etk/eventmanager.lua --
---------------------------------

    ------------------------------------
-- Start of etk/widgetmanager.lua --
------------------------------------

-------------------
-- Widget things --
-------------------

etk.Widgets = {}

do etk.Widget = class(etk.Screen)
    local Widget = etk.Widget
    local Screen = etk.Screen

    function Widget:init(position, dimension)
        Screen.init(self, position, dimension)

        self.hasFocus = false;
    end

end


do Box = class(etk.Widget)
    local Widget = etk.Widget

    function Box:init(position, dimension, text)
        Widget.init(self, position, dimension)

        self.text = text
    end

    function Box:draw(gc, x, y, width, height, isColor)
        Logger.Log("In Box:draw %d, %d, %d, %d", x, y, width, height)

        gc:setColorRGB(0, 0, 0)

        if self.hasFocus then
            gc:fillRect(x, y, width, height)
        else
            -- No, draw only the outline
            gc:drawRect(x, y, width, height)
        end

        gc:setColorRGB(128, 128, 128)
        gc:setFont("sansserif", "r", 7)

        if self.text then
            gc:drawString(self.text, x+2, y, "top")
            gc:drawString(width .. "," .. height, x+2, y+9, "top")
        end
    end

end

-------------------------------------
-- Start of etk/widgets/button.lua --
-------------------------------------

-------------------
-- Button widget --
-------------------

do
    local Widget  = etk.Widget
    local Widgets = etk.Widgets

    do Widgets.Button = class(Widget)
        local Widget = etk.Widget
        local Button = Widgets.Button

        Button.defaultStyle = {
            textColor       = {{000,000,000},{000,000,000}},
            backgroundColor = {{248,252,248},{248,252,248}},
            borderColor     = {{136,136,136},{160,160,160}},
            focusColor      = {{040,148,184},{000,000,000}},

            defaultWidth  = 48,
            defaultHeight = 27,
            font = {
                    serif="sansserif",
                    style="r",
                    size=10
                }
        }

        function Button:init(arg)
            self.text = arg.text or "Button"

            local style = arg.style or Button.defaultStyle
            self.style = style

            local dimension = Dimension(style.defaultWidth, style.defaultHeight)

            Widget.init(self, arg.position, dimension)
        end

        function Button:prepare(gc)
            local font = self.style.font

            gc:setFont(font.serif, font.style, font.size)
            self.dimension.width = gc:getStringWidth(self.text) + 10
            self.dimension:invalidate()
            self.position:invalidate()
        end

        function Button:draw(gc, x, y, width, height, isColor)
            if self.meDown then
                y = y + 1
            end

            local color = isColor and 1 or 2
            local style = self.style

            gc:setColorRGB(unpackColor(style.backgroundColor[color]))
            gc:fillRect(x + 2, y + 2, width - 4, height - 4)

            gc:setColorRGB(unpackColor(style.textColor[color]))
            gc:drawString(self.text, x + 5, y + 3, "top")

            if self.hasFocus then
                gc:setColorRGB(unpackColor(style.focusColor[color]))
                gc:setPen("medium", "smooth")
            else
                gc:setColorRGB(unpackColor(style.borderColor[color]))
                gc:setPen("thin", "smooth")
            end

            gc:fillRect(x + 2, y, width - 4, 2)
            gc:fillRect(x + 2, y + height - 2, width - 4, 2)
            gc:fillRect(x, y + 2, 1, height - 4)
            gc:fillRect(x + 1, y + 1, 1, height - 2)
            gc:fillRect(x + width - 1, y + 2, 1, height - 4)
            gc:fillRect(x + width - 2, y + 1, 1, height - 2)

            if self.hasFocus then
                gc:setColorRGB(unpackColor(style.focusColor[color]))
            end

            gc:setPen("thin", "smooth")
        end


        function Button:doAction()
            self.parent:invalidate()
            CallEvent(self, "onAction")
        end

        function Button:onMouseDown()
            self.meDown = true
        end

        function Button:onMouseUp(x, y, onMe)
            self.meDown = false

            if onMe then
                self:doAction()
            end
        end

        function Button:enterKey()
            self:doAction()
        end
    end

end

-----------------------------------
-- End of etk/widgets/button.lua --
-----------------------------------

------------------------------------
-- Start of etk/widgets/input.lua --
------------------------------------

------------------
-- Input widget --
------------------

do
    local Widget  = etk.Widget
    local Widgets = etk.Widgets

    do Widgets.Input = class(Widget)
        local Widget = etk.Widget
        local Input = Widgets.Input

        Input.defaultStyle = {
            textColor       = {{000,000,000},{000,000,000}},
            cursorColor     = {{000,000,020},{000,000,020}},
            backgroundColor = {{255,255,255},{255,255,255}},
            borderColor     = {{136,136,136},{160,160,160}},
            focusColor      = {{040,148,184},{000,000,000}},
            disabledColor   = {{128,128,128},{128,128,128}},

            defaultWidth  = 100,
            defaultHeight = 20,

            font = {
                    serif="sansserif",
                    style="r",
                    size=10
                }
        }

        local prev__index = Input.__index
        function Input:__index(idx)
            return idx == "value" and self._value or prev__index(self, idx)
        end

        function Input:__newindex(idx, val)
            if idx == "value" then
                self:setValue(val)
                self.parent:invalidate()
            else
                rawset(self, idx, val)
            end
        end

        function Input:init(arg)
            self.number = arg.number == true
            self:setValue(arg.value or "")
            self.disabled = arg.disabled
            self.cursorPos = tostring(self._value):ulen()
            self.cursorX = 0
            self.cursorDirty = true

            local style = arg.style or Input.defaultStyle
            self.style = style

            local dimension = Dimension(style.defaultWidth, style.defaultHeight)
            Widget.init(self, arg.position, dimension)
        end

        function Input:setValue(val)
            if val then
                if self.number then
                    self._value = type(val) == "number" and val or 0
                else
                    self._value = tostring(val)
                end
            else
                self._value = self.number and 0 or ""
            end
            self.cursorPos = tostring(self._value):ulen()
            self:doValueChange()
        end

        function Input:draw(gc, x, y, width, height, isColor)
            local color = isColor and 1 or 2
            local style = self.style
            local font = style.font

            gc:setFont(font.serif, font.style, font.size)

            gc:setColorRGB(unpackColor(style.backgroundColor[color]))
            gc:fillRect(x, y, width, height)

            gc:setColorRGB(unpackColor(style.borderColor[color]))
            gc:drawRect(x, y, width, height)

            if self.hasFocus then
                gc:setColorRGB(unpackColor(style.focusColor[color]))
                gc:drawRect(x - 1, y - 1, width + 2, height + 2)
                gc:setColorRGB(0, 0, 0)
            end

            gc:smartClipRect("subset", x, y, width, height)

            if self.disabled or self._value == "" then
                gc:setColorRGB(unpackColor(style.focusColor[color]))
            end

            local value = tostring(self._value)
            local text = value

            if value == "" then
                text = self.placeholder or value
            end

            if self.cursorDirty then
                self.cursorX = gc:getStringWidth(value:usub(1, self.cursorPos)) + 2
                self.cursorDirty = false
            end

            -- TODO: make 3 a constant value

            local strWidth = gc:getStringWidth(text)
            local xOffset = width - 3 - strWidth

            if not (xOffset < 0 and self.hasFocus) then
                xOffset = 0
            elseif self.cursorX < -xOffset then
                xOffset = -self.cursorX + 3
            end

            gc:drawString(text, x + xOffset + 2, y, "top")

            if self.hasFocus then
                gc:setColorRGB(unpackColor(style.cursorColor[color]))
                gc:drawLine(x + self.cursorX + xOffset, y+2, x + self.cursorX + xOffset, y+height-2)
            end

            gc:smartClipRect("restore")
        end

        ------------------------
        -- Handle input event --
        ------------------------

        function Input:doValueChange()
            self.cursorDirty = true
            CallEvent(self, "onValueChange", self._value)
        end

        function Input:charIn(char)
            if self.disabled then
                return
            end

            local newValue = tostring(self._value)

            if self.cursorPos >= 0 and self.cursorPos < newValue:ulen() then
                newValue = newValue:usub(1, self.cursorPos) .. char .. newValue:usub(self.cursorPos+1)
            else
                newValue = newValue .. char
            end

            if self.number then
                newValue = tonumber(newValue)
            end

            if not newValue then
                return
            end

            self._value = newValue
            self.cursorPos = self.cursorPos + 1

            self:doValueChange()
            self.parent:invalidate()
        end

        function Input:clearKey()
            if self.disabled then
                return
            end

            self._value = self.number and 0 or ""
            self.cursorPos = self.number and 1 or 0

            self:doValueChange()
            self.parent:invalidate()
        end

        function Input:backspaceKey()
            if self.disabled then
                return
            end

            local newValue = tostring(self._value)

            if self.cursorPos == 0 then
                return
            elseif self.cursorPos > 0 and self.cursorPos < newValue:ulen() then
                newValue = newValue:usub(1, self.cursorPos-1) .. newValue:usub(self.cursorPos+1)
            else
                newValue = tostring(self._value):usub(1,-2)
            end

            if self.number then
                newValue = tonumber(newValue)
            end

            if newValue and tostring(newValue):ulen() > 0 then
                self._value = newValue
                self.cursorPos = self.cursorPos - 1
            else
                if self.number then
                    self._value = 0
                    self.cursorPos = 1
                else
                    self._value = ""
                    self.cursorPos = 0
                end
            end

            self:doValueChange()
            self.parent:invalidate()
        end

        function Input:deleteKey()
            if self.disabled then
                return
            end

            local newValue = tostring(self._value)

            if self.cursorPos == newValue:ulen() then
                return
            elseif self.cursorPos >= 0 then
                newValue = newValue:usub(1, self.cursorPos) .. newValue:usub(self.cursorPos+2)
            end

            if self.number then
                newValue = tonumber(newValue)
            end

            if newValue and tostring(newValue):ulen() > 0 then
                self._value = newValue
            else
                if self.number then
                    self._value = 0
                    self.cursorPos = 1
                else
                    self._value = ""
                    self.cursorPos = 0
                end
            end

            self:doValueChange()
            self.parent:invalidate()
        end

        function Input:arrowUp()
            if not self.disabled and self.number then
                self._value = self._value + 1
                self:doValueChange()
                self.parent:invalidate()
            end
        end

        function Input:arrowDown()
            if not self.disabled and self.number then
                self._value = self._value - 1
                self:doValueChange()
                self.parent:invalidate()
            end
        end

        function Input:arrowLeft()
            if self.disabled then
                return
            end
            if self.cursorPos > 0 then
                self.cursorPos = self.cursorPos - 1
                self.cursorDirty = true
                self.parent:invalidate()
            end
        end

        function Input:arrowRight()
            if self.disabled then
                return
            end
            if self.cursorPos < tostring(self._value):ulen() then
                self.cursorPos = self.cursorPos + 1
                self.cursorDirty = true
                self.parent:invalidate()
            end
        end

    end

end

----------------------------------
-- End of etk/widgets/input.lua --
----------------------------------

------------------------------------
-- Start of etk/widgets/label.lua --
------------------------------------

------------------
-- Label widget --
------------------

do
    local Widget  = etk.Widget
    local Widgets = etk.Widgets

    do Widgets.Label = class(Widget)
        local Widget = etk.Widget
        local Label = Widgets.Label

        Label.defaultStyle = {
            textColor       = {{000,000,000},{000,000,000}},
            --backgroundColor = {{248,252,248},{248,252,248}},

            defaultWidth = 20,
            defaultHeight = 30,

            font = {
                serif="sansserif",
                style="r",
                size=10
            }
        }

        function Label.TextPart(gc, text, max)
            local out = ""

            local width = gc:getStringWidth(text)

            if width < max then
                return text
            else
                for i=1, #text do
                    local part = text:usub(1, i)
                    if gc:getStringWidth(part .. "..") > max then
                        break
                    end
                    out = part
                end

                return out .. ".."
            end
        end

        function Label:init(arg)
            self.text = arg.text or "Button"

            local style = arg.style or Label.defaultStyle
            self.style = style
            self.limit = arg.limit == true
            self.ignoreFocus = true

            local dimension = Dimension(style.defaultWidth, style.defaultHeight)

            Widget.init(self, arg.position, dimension)
        end

        function Label:prepare(gc)
            local font = self.style.font

            gc:setFont(font.serif, font.style, font.size)

            if not self.limit then
                self.dimension.width = gc:getStringWidth(self.text)
                self.dimension.height = gc:getStringHeight(self.text)

                self.dimension:invalidate()
                self.position:invalidate()
            end
        end

        function Label:draw(gc, x, y, width, height, isColor)
            local color = isColor and 1 or 2
            local style = self.style

            gc:setColorRGB(unpackColor(style.textColor[color]))

            local displayText = self.limit and Label.TextPart(gc, self.text, width) or self.text

            gc:drawString(displayText, x, y, "top")
        end
    end

end

----------------------------------
-- End of etk/widgets/label.lua --
----------------------------------


----------------------------------
-- End of etk/widgetmanager.lua --
----------------------------------

    -----------------------------
-- Start of etk/dialog.lua --
-----------------------------

-----------------
-- Dialog view --
-----------------

do
    local View = etk.View

    do etk.Dialog = class(View)
        local Dialog = etk.Dialog

        function Dialog:invalidate()
            self.parent:invalidate()
        end

        function Dialog:init(title, position, dimension)
            self.title = title
            View.init(self, {position=position, dimension=dimension})
        end

        function Dialog:draw(gc,x, y, width, height)
            gc:setFont("sansserif", "r", 10)
            gc:setColorRGB(224, 224, 224)

            gc:fillRect(x, y, width, height)

            for i=1, 14, 2 do
                gc:setColorRGB(32+i*3, 32+i*4, 32+i*3)
                gc:fillRect(x, y + i, width, 2)
            end

            gc:setColorRGB(32+16*3, 32+16*4, 32+16*3)
            gc:fillRect(x, y+15, width, 10)

            gc:setColorRGB(128,128,128)
            gc:drawRect(x, y, width, height)
            gc:drawRect(x-1, y-1, width+2, height+2)

            gc:setColorRGB(96, 100, 96)
            gc:fillRect(x+width+1, y, 1, height+2)
            gc:fillRect(x, y+height+2, width+3, 1)

            gc:setColorRGB(104, 108, 104)
            gc:fillRect(x+width+2, y+1, 1, height+2)
            gc:fillRect(x+1, y+height+3, width+3, 1)
            gc:fillRect(x+width+3, y+2, 1, height+2)
            gc:fillRect(x+2, y+height+4, width+2, 1)

            gc:setColorRGB(255, 255, 255)
            gc:drawString(self.title, x+4, y+2, "top")
        end
    end

end

-----------z----------------
-- End of etk/dialog.lua --
---------------------------

end

------------------------
-- End of etk/etk.lua --
------------------------