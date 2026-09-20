-- plain-menu.lua
-- Plain menu, usable version. Same look as the screenshot, fixed layout.
-- Features: tabs, buttons, toggles, textboxes, sliders, dropdowns,
-- multi-dropdowns, lists (custom height), color pickers, keybinds
-- (+ keybind list), watermark, notifications. Fixed size, drag to move.
-- Toggle with Semicolon. Drag from the top bar.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

local GUI_NAME = "PlainMenuV2"
do
    local ok, parent = pcall(function()
        return (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if ok and parent then
        local old = parent:FindFirstChild(GUI_NAME)
        if old then pcall(function() old:Destroy() end) end
        local oldWm = parent:FindFirstChild(GUI_NAME .. "_Popups")
        if oldWm then pcall(function() oldWm:Destroy() end) end
    end
    if getgenv then
        pcall(function() getgenv().PlainMenu = nil end)
    end
end

local function getParent()
    local ok, p = pcall(function()
        return (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if ok and p then return p end
    return LocalPlayer:WaitForChild("PlayerGui")
end
local rootParent = getParent()

-- // theme (matches screenshot) // --
local C = {
    BG         = Color3.fromRGB(17, 17, 17),
    Top        = Color3.fromRGB(23, 23, 23),
    Side       = Color3.fromRGB(14, 14, 14),
    Row        = Color3.fromRGB(17, 17, 17),
    Line       = Color3.fromRGB(42, 42, 42),
    Text       = Color3.fromRGB(225, 225, 225),
    Dim        = Color3.fromRGB(165, 165, 165),
    Faint      = Color3.fromRGB(120, 120, 120),
    Button     = Color3.fromRGB(56, 56, 56),
    ButtonText = Color3.fromRGB(180, 180, 180),
    Hover      = Color3.fromRGB(68, 68, 68),
    Track      = Color3.fromRGB(46, 46, 46),
    Fill       = Color3.fromRGB(175, 175, 175),
    Popup      = Color3.fromRGB(22, 22, 22),
    Option     = Color3.fromRGB(30, 30, 30),
}

local CONTROL_W = 152 -- every right-side control is this wide, labels never overlap
local ROW_H = 24

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            local ok = pcall(function() o[k] = v end)
            if not ok then warn("[plain-menu] bad prop", k) end
        end
    end
    if parent then o.Parent = parent end
    if props.Parent then o.Parent = props.Parent end
    return o
end

local function isInside(guiObj, mousePos)
    if not guiObj or not guiObj:IsA("GuiObject") then return false end
    local pos = guiObj.AbsolutePosition
    local size = guiObj.AbsoluteSize
    return mousePos.X >= pos.X and mousePos.X <= pos.X + size.X
        and mousePos.Y >= pos.Y and mousePos.Y <= pos.Y + size.Y
end

-- // root guis // --
local gui = new("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
}, rootParent)

-- popups live here so ScrollingFrames never clip them
local popupLayer = new("Frame", {
    Name = "Popups",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 100,
}, gui)

local openPopup = nil
local function closePopup()
    if openPopup then
        pcall(function() openPopup:Destroy() end)
        openPopup = nil
    end
end

-- // main window // --
local main = new("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(835, 485),
    BackgroundColor3 = C.BG,
    BorderSizePixel = 0,
    Active = true,
}, gui)
new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, main)
new("UICorner", { CornerRadius = UDim.new(0, 2) }, main)

local top = new("Frame", {
    Name = "Top",
    Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = C.Top,
    BorderSizePixel = 0,
}, main)
new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -20, 1, 0),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.Text,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "Press 'Semicolon' to hide this menu",
}, top)
-- divider is parented to MAIN (not the sidebar) so UIListLayout can't eat it
new("Frame", { Name = "TopLine", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 26), BackgroundColor3 = C.Line, BorderSizePixel = 0, ZIndex = 2 }, main)

do -- drag
    local dragging, startPos, startInput = false, nil, nil
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startPos = main.Position
            startInput = input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement and startPos and startInput then
            local d = input.Position - startInput
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- // sidebar (FIXED: tabs live in their own container, divider is separate) // --
local SIDE_W = 150
local side = new("Frame", {
    Name = "Side",
    Position = UDim2.fromOffset(0, 27),
    Size = UDim2.new(0, SIDE_W, 1, -27),
    BackgroundColor3 = C.Side,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, main)

local tabList = new("Frame", {
    Name = "TabList",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
}, side)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabList)
new("UIPadding", {
    PaddingTop = UDim.new(0, 12),
    PaddingLeft = UDim.new(0, 14),
    PaddingRight = UDim.new(0, 14),
}, tabList)

-- vertical divider, parented to main so layout never touches it
new("Frame", {
    Name = "SideLine",
    Size = UDim2.new(0, 1, 1, -27),
    Position = UDim2.fromOffset(SIDE_W, 27),
    BackgroundColor3 = C.Line,
    BorderSizePixel = 0,
    ZIndex = 2,
}, main)

local content = new("Frame", {
    Name = "Content",
    Position = UDim2.fromOffset(SIDE_W + 1, 27),
    Size = UDim2.new(1, -(SIDE_W + 1), 1, -27),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, main)

-- // Menu object // --
local Menu = {
    Flags = {},
    Binds = {}, -- { Name, Key, Mode, GetState, Row }
    Tabs = {},
    _bindListFrame = nil,
    _bindListLayout = nil,
}
if getgenv then getgenv().PlainMenu = Menu; getgenv().PlainMenuFlags = Menu.Flags end

local tabButtons = {}
local pages = {}
local function selectTab(name)
    for n, b in pairs(tabButtons) do
        local on = (n == name)
        b.TextColor3 = on and C.Text or C.Faint
        b.BackgroundTransparency = 1
        b.Font = on and Enum.Font.GothamBold or Enum.Font.Gotham
    end
    for n, p in pairs(pages) do p.Visible = (n == name) end
end

-- column helper: each tab page holds 1-2 scrolling columns
local function makeScrollColumn(parent, xScale, wScale)
    local sc = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(xScale, 0, 0, 0),
        Size = UDim2.new(wScale, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.Button,
        ClipsDescendants = true,
    }, parent)
    local layout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, sc)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
    }, sc)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sc.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
    end)
    return sc
end

function Menu.CreateTab(name)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = C.Faint,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = name,
        LayoutOrder = #Menu.Tabs + 1,
        AutoButtonColor = false,
    }, tabList)
    tabButtons[name] = btn

    local page = new("Frame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
    }, content)
    pages[name] = page

    local tab = { Name = name, Page = page, Sections = {} }
    Menu.Tabs[#Menu.Tabs + 1] = tab

    function tab.CreateColumn(colIndex, width)
        -- relative widths so columns follow menu rescaling
        if colIndex == 1 then
            return makeScrollColumn(page, 0, 0.515)
        else
            return makeScrollColumn(page, 0.515, 0.485)
        end
    end

    -- section = header + rows container. Parent must be a scroll column.
    function tab.CreateSection(column, title)
        local holder = new("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
            AutomaticSize = Enum.AutomaticSize.Y,
        }, column)
        local l = new("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, holder)
        new("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Font = Enum.Font.GothamBold,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.Text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Text = title,
            LayoutOrder = 0,
        }, holder)
        local sec = { Holder = holder, Layout = l, Order = 1 }
        tab.Sections[#tab.Sections + 1] = sec

        -- one row: label left (truncated), control slot right (fixed width, never overlaps)
        local function baseRow(labelText, labelWidthNote)
            local row = new("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, ROW_H),
                LayoutOrder = sec.Order,
            }, holder)
            sec.Order = sec.Order + 1
            new("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.new(1, -(CONTROL_W + 8), 1, 0),
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = C.Text,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = labelText,
            }, row)
            local slot = new("Frame", {
                Name = "Slot",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(CONTROL_W, 20),
                BackgroundTransparency = 1,
            }, row)
            return row, slot
        end

        function sec.AddNote(text)
            local t = new("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = C.Dim,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = text,
                LayoutOrder = sec.Order,
            }, holder)
            sec.Order = sec.Order + 1
            return t
        end

        function sec.AddButton(opt)
            -- opt: { Name, Text, Callback }
            local _, slot = baseRow(opt.Name, true)
            local b = new("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = C.Button,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextColor3 = C.ButtonText,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = opt.Text or opt.Name,
                AutoButtonColor = false,
            }, slot)
            b.MouseEnter:Connect(function() b.BackgroundColor3 = C.Hover end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = C.Button end)
            b.MouseButton1Click:Connect(function()
                if opt.Callback then task.spawn(opt.Callback) end
            end)
            return b
        end

        function sec.AddToggle(opt)
            -- opt: { Name, Flag, Default=false, Callback(state) }
            local flag = opt.Flag or opt.Name
            Menu.Flags[flag] = (opt.Default == true)
            local _, slot = baseRow(opt.Name, true)
            local box = new("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(20, 20),
                BackgroundColor3 = C.Button,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
            }, slot)
            local inner = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(12, 12),
                BackgroundColor3 = C.Fill,
                BorderSizePixel = 0,
                Visible = Menu.Flags[flag],
            }, box)
            local function set(v, silent)
                Menu.Flags[flag] = v
                inner.Visible = v
                if not silent and opt.Callback then task.spawn(opt.Callback, v) end
                Menu.RefreshBinds()
            end
            box.MouseButton1Click:Connect(function() set(not Menu.Flags[flag]) end)
            return { Set = set, Box = box }
        end

        function sec.AddTextbox(opt)
            -- opt: { Name, Flag, Default="", Placeholder, Callback(value) }
            local flag = opt.Flag or opt.Name
            Menu.Flags[flag] = opt.Default or ""
            local _, slot = baseRow(opt.Name, true)
            local tb = new("TextBox", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = C.Button,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextColor3 = C.ButtonText,
                PlaceholderColor3 = C.Faint,
                PlaceholderText = opt.Placeholder or opt.Default or "",
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = tostring(opt.Default or ""),
                ClearTextOnFocus = false,
            }, slot)
            tb.FocusLost:Connect(function(enter)
                if enter then
                    Menu.Flags[flag] = tb.Text
                    if opt.Callback then task.spawn(opt.Callback, tb.Text) end
                end
            end)
            local api = {}
            function api.Set(v) tb.Text = tostring(v) Menu.Flags[flag] = tb.Text end
            return api
        end

        function sec.AddSlider(opt)
            -- opt: { Name, Flag, Min, Max, Default, Decimals=2, Suffix="", Callback(value) }
            local flag = opt.Flag or opt.Name
            local min, max = opt.Min or 0, (opt.Max == nil and 1 or opt.Max)
            local dec = opt.Decimals == nil and 2 or opt.Decimals
            local suffix = opt.Suffix or ""
            local val = opt.Default == nil and min or opt.Default
            Menu.Flags[flag] = val
            local _, slot = baseRow(opt.Name, true)
            -- value readout lives inside the label area? no - tooltip style: append to slider via small label above track
            local track = new("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(CONTROL_W, 8),
                BackgroundColor3 = C.Track,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
            }, slot)
            local fill = new("Frame", {
                Size = UDim2.new(0, 0, 1, 0),
                BackgroundColor3 = C.Fill,
                BorderSizePixel = 0,
            }, track)
            local function fmt(n)
                if dec <= 0 then return tostring(math.floor(n + 0.5)) end
                local mult = 10 ^ dec
                return string.format("%." .. dec .. "f", math.floor(n * mult + 0.5) / mult)
            end
            -- value readout centered on the bar, e.g. 54/100
            local valLabel = new("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextStrokeTransparency = 0.5,
                Text = "",
                ZIndex = 5,
            }, track)
            local function render()
                local a = (max - min) <= 0 and 0 or math.clamp((val - min) / (max - min), 0, 1)
                fill.Size = UDim2.new(a, 0, 1, 0)
                -- value keeps its decimals, max is always a straight number: 4.5/10
                valLabel.Text = fmt(val) .. "/" .. tostring(math.floor(max + 0.5))
            end
            local function set(v, silent)
                v = math.clamp(v, min, max)
                local mult = 10 ^ dec
                v = math.floor(v * mult + 0.5) / mult
                val = v
                Menu.Flags[flag] = v
                render()
                if not silent and opt.Callback then task.spawn(opt.Callback, v) end
            end
            render()
            local dragging = false
            local lastClick = 0
            local editor = nil
            local function fromX(x)
                local p, s = track.AbsolutePosition.X, track.AbsoluteSize.X
                if s <= 0 then return end
                set(min + math.clamp((x - p) / s, 0, 1) * (max - min))
            end
            -- double-click the bar to type an exact value
            local function openEditor()
                if editor then pcall(function() editor:Destroy() end) editor = nil end
                dragging = false
                editor = new("TextBox", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = C.Popup,
                    BorderSizePixel = 0,
                    Font = Enum.Font.Gotham,
                    TextSize = 11,
                    TextColor3 = C.Text,
                    Text = fmt(val),
                    ClearTextOnFocus = false,
                    ZIndex = 6,
                }, track)
                new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, editor)
                editor:CaptureFocus()
                editor.FocusLost:Connect(function(enter)
                    if enter and editor then
                        local num = tonumber(editor.Text)
                        if num then set(num) end
                    end
                    if editor then pcall(function() editor:Destroy() end) editor = nil end
                end)
            end
            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local now = os.clock()
                    if now - lastClick < 0.35 then
                        lastClick = 0
                        openEditor()
                        return
                    end
                    lastClick = now
                    if editor then return end
                    dragging = true
                    fromX(input.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    fromX(input.Position.X)
                end
            end)
            return { Set = set }
        end

        local function buildDropdownPopup(btn, current, options, multi, selectedSet, onPick)
            closePopup()
            local abs = btn.AbsolutePosition
            -- position in screen space; popupLayer is full-screen so fromOffset works
            local pop = new("Frame", {
                Position = UDim2.fromOffset(abs.X, abs.Y + btn.AbsoluteSize.Y + 2),
                Size = UDim2.fromOffset(btn.AbsoluteSize.X, math.min(22 * #options + 4, 176)),
                BackgroundColor3 = C.Popup,
                BorderSizePixel = 0,
                ZIndex = 200,
            }, popupLayer)
            new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pop)
            local list = new("ScrollingFrame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                CanvasSize = UDim2.new(0, 0, 0, 22 * #options + 4),
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = C.Button,
                ZIndex = 201,
            }, pop)
            new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)
            new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, list)
            for i, name in ipairs(options) do
                local isSel = multi and selectedSet[name] or (not multi and current == name)
                local ob = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = isSel and C.Button or C.Option,
                    BorderSizePixel = 0,
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextColor3 = isSel and C.Text or C.ButtonText,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = name,
                    LayoutOrder = i,
                    AutoButtonColor = false,
                    ZIndex = 202,
                }, list)
                ob.MouseButton1Click:Connect(function()
                    onPick(name, ob)
                    if not multi then closePopup() end
                end)
            end
            openPopup = pop
            return pop
        end

        function sec.AddDropdown(opt)
            -- opt: { Name, Flag, Options={}, Default, Callback(value) }
            local flag = opt.Flag or opt.Name
            local options = opt.Options or {}
            local cur = opt.Default or options[1] or ""
            Menu.Flags[flag] = cur
            local _, slot = baseRow(opt.Name, true)
            local b = new("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = C.Button,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                TextSize = 13,
                TextColor3 = C.ButtonText,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = tostring(cur),
                AutoButtonColor = false,
            }, slot)
            b.MouseButton1Click:Connect(function()
                if openPopup then closePopup() return end
                buildDropdownPopup(b, Menu.Flags[flag], options, false, nil, function(name)
                    Menu.Flags[flag] = name
                    b.Text = tostring(name)
                    if opt.Callback then task.spawn(opt.Callback, name) end
                end)
            end)
            local api = {}
            function api.Set(v) Menu.Flags[flag] = v b.Text = tostring(v) end
            return api
        end

        function sec.AddMultiDropdown(opt)
            -- opt: { Name, Flag, Options={}, Default={} , Callback(selectedTable) }
            local flag = opt.Flag or opt.Name
            local options = opt.Options or {}
            local set = {}
            for _, v in ipairs(opt.Default or {}) do set[v] = true end
            Menu.Flags[flag] = set
            local _, slot = baseRow(opt.Name, true)
            local b = new("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = C.Button,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextColor3 = C.ButtonText,
                TextTruncate = Enum.TextTruncate.AtEnd,
                AutoButtonColor = false,
            }, slot)
            local function renderBtn()
                local picked = {}
                for _, o in ipairs(options) do
                    if set[o] then picked[#picked + 1] = o end
                end
                -- fill the box, cut off with truncate (no "(+n)" suffix)
                b.Text = #picked == 0 and "None" or table.concat(picked, ", ")
            end
            renderBtn()
            b.MouseButton1Click:Connect(function()
                if openPopup then closePopup() return end
                local pop
                pop = buildDropdownPopup(b, nil, options, true, set, function(name, ob)
                    set[name] = not set[name]
                    local on = set[name]
                    ob.BackgroundColor3 = on and C.Button or C.Option
                    ob.TextColor3 = on and C.Text or C.ButtonText
                    renderBtn()
                    -- refresh other rows live without closing
                    if opt.Callback then task.spawn(opt.Callback, Menu.Flags[flag]) end
                end)
            end)
            return { Set = function(t) set = {} for _, v in ipairs(t) do set[v] = true end Menu.Flags[flag] = set renderBtn() end }
        end

        -- LIST: scrollable box with custom height (gs-menu skin-changer pattern).
        -- Click a value to select it (fires Callback). Pair with a TextBox + SetValues to filter.
        function sec.AddList(opt)
            -- opt: { Name, Flag, Height = 120, Values = {}, Default = nil, Callback(value) }
            local flag = opt.Flag or opt.Name
            local height = opt.Height or opt.Size or 120
            local current, currentBtn = nil, nil
            Menu.Flags[flag] = nil
            local wrap = new("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 24 + height),
                LayoutOrder = sec.Order,
            }, holder)
            sec.Order = sec.Order + 1
            new("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 20),
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = C.Text,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = opt.Name,
            }, wrap)
            local outline = new("Frame", {
                Position = UDim2.fromOffset(0, 24),
                Size = UDim2.new(1, 0, 0, height),
                BackgroundColor3 = C.Popup,
                BorderSizePixel = 0,
            }, wrap)
            new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, outline)
            local list = new("ScrollingFrame", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(1, 1),
                Size = UDim2.new(1, -2, 1, -2),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = C.Button,
            }, outline)
            local layout = new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, list)
            new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, list)
            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
            end)
            local api = {}
            local order = 0
            local function paint(btn, on)
                btn.BackgroundColor3 = on and C.Button or C.Popup
                for _, ch in ipairs(btn:GetChildren()) do
                    if ch:IsA("TextLabel") then ch.TextColor3 = on and C.Text or C.Dim break end
                end
            end
            function api.AddValue(value)
                value = tostring(value)
                if list:FindFirstChild(value) then return end
                order = order + 1
                local btn = new("TextButton", {
                    Name = value,
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundColor3 = C.Popup,
                    BorderSizePixel = 0,
                    LayoutOrder = order,
                    Text = "",
                    AutoButtonColor = false,
                }, list)
                new("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(10, 0),
                    Size = UDim2.new(1, -20, 1, 0),
                    Font = Enum.Font.Gotham,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextColor3 = C.Dim,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Text = value,
                }, btn)
                btn.MouseEnter:Connect(function()
                    if value ~= current then btn.BackgroundColor3 = C.Option end
                end)
                btn.MouseLeave:Connect(function()
                    if value ~= current then btn.BackgroundColor3 = C.Popup end
                end)
                btn.MouseButton1Click:Connect(function() api.Set(value) end)
            end
            function api.RemoveValue(value)
                local b = list:FindFirstChild(tostring(value))
                if b then b:Destroy() end
                if current == tostring(value) then current, currentBtn = nil, nil Menu.Flags[flag] = nil end
            end
            function api.Clear()
                for _, ch in ipairs(list:GetChildren()) do
                    if ch:IsA("TextButton") then ch:Destroy() end
                end
                order = 0
                current, currentBtn = nil, nil
                Menu.Flags[flag] = nil
            end
            function api.SetValues(values)
                api.Clear()
                for _, v in ipairs(values or {}) do api.AddValue(v) end
            end
            function api.Set(value)
                value = value ~= nil and tostring(value) or nil
                if currentBtn then paint(currentBtn, false) end
                current = value
                currentBtn = (value ~= nil) and list:FindFirstChild(value) or nil
                if currentBtn then paint(currentBtn, true) end
                Menu.Flags[flag] = value
                if value ~= nil and opt.Callback then task.spawn(opt.Callback, value) end
            end
            function api.Get() return current end
            for _, v in ipairs(opt.Values or {}) do api.AddValue(v) end
            if opt.Default ~= nil then api.Set(opt.Default) end
            return api
        end

        -- shared copy/paste buffer for color pickers (Color3, or false when empty)
        if Menu.ColorClipboard == nil then Menu.ColorClipboard = false end
        -- juju-style HSV box: saturation/value square + hue bar (pure GUI, no images)
        local function openColorEditor(anchorBox, getCur, onApply)
            local h, s, v = getCur():ToHSV()
            local abs = anchorBox.AbsolutePosition
            local PAD, SW, SH, HBH = 8, 190, 140, 10
            local pop = new("Frame", {
                Position = UDim2.fromOffset(math.max(0, abs.X - 150), abs.Y + 22),
                Size = UDim2.fromOffset(SW + PAD * 2, PAD * 3 + 20 + SH + 6 + HBH),
                BackgroundColor3 = C.Popup,
                BorderSizePixel = 0,
                ZIndex = 200,
            }, popupLayer)
            new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pop)
            local preview = new("Frame", {
                Position = UDim2.fromOffset(PAD, PAD),
                Size = UDim2.fromOffset(SW, 20),
                BackgroundColor3 = Color3.fromHSV(h, s, v),
                BorderSizePixel = 0,
                ZIndex = 201,
            }, pop)
            -- SV square: hue base + white->transparent (sat) + transparent->black (val)
            local svBg = new("TextButton", {
                Position = UDim2.fromOffset(PAD, PAD + 26),
                Size = UDim2.fromOffset(SW, SH),
                BackgroundColor3 = Color3.fromHSV(h, 1, 1),
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 201,
            }, pop)
            local satOverlay = new("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                ZIndex = 202,
            }, svBg)
            new("UIGradient", {
                Rotation = 0,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
            }, satOverlay)
            local valOverlay = new("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                ZIndex = 203,
            }, svBg)
            new("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0),
                }),
            }, valOverlay)
            local cursor = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(8, 8),
                BackgroundTransparency = 1,
                ZIndex = 204,
            }, svBg)
            new("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cursor)
            -- hue bar: rainbow gradient
            local hueBar = new("TextButton", {
                Position = UDim2.fromOffset(PAD, PAD + 26 + SH + 6),
                Size = UDim2.fromOffset(SW, HBH),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 201,
            }, pop)
            new("UIGradient", {
                Rotation = 0,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
                }),
            }, hueBar)
            local hueDrag = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(4, HBH + 4),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                ZIndex = 202,
            }, hueBar)
            new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, hueDrag)
            local function render()
                local col = Color3.fromHSV(h, s, v)
                preview.BackgroundColor3 = col
                svBg.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                cursor.Position = UDim2.new(s, 0, 1 - v, 0)
                hueDrag.Position = UDim2.new(h, 0, 0.5, 0)
                onApply(col)
            end
            local dragSV, dragH = false, false
            local function svFromPos(p)
                local ap, as = svBg.AbsolutePosition, svBg.AbsoluteSize
                if as.X <= 0 or as.Y <= 0 then return end
                s = math.clamp((p.X - ap.X) / as.X, 0, 1)
                v = math.clamp(1 - (p.Y - ap.Y) / as.Y, 0, 1)
                render()
            end
            local function hueFromX(x)
                local ap, as = hueBar.AbsolutePosition, hueBar.AbsoluteSize
                if as.X <= 0 then return end
                h = math.clamp((x - ap.X) / as.X, 0, 1)
                render()
            end
            svBg.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then dragSV = true svFromPos(i.Position) end
            end)
            hueBar.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then dragH = true hueFromX(i.Position.X) end
            end)
            UserInputService.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1 then dragSV, dragH = false, false end
            end)
            UserInputService.InputChanged:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.MouseMovement
                    and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    if dragSV then svFromPos(i.Position) end
                    if dragH then hueFromX(i.Position.X) end
                end
            end)
            render()
            openPopup = pop
        end

        function sec.AddColorPicker(opt)
            -- Single box: { Name, Flag, Default=Color3, Callback(color) }
            -- Multiple boxes in one row: { Name, Flags = {"A", "B"}, Defaults = {c1, c2}, Callback(color, index) }
            -- Left-click a box = HSV box editor. Right-click a box = Copy / Paste / Reset menu.
            local flags, defaults
            if opt.Flags then
                flags = opt.Flags
                defaults = opt.Defaults or {}
            else
                flags = { opt.Flag or opt.Name }
                defaults = { opt.Default or Color3.fromRGB(255, 255, 255) }
            end
            local n = #flags
            local curs = {}
            for i = 1, n do
                curs[i] = defaults[i] or Color3.fromRGB(255, 255, 255)
                Menu.Flags[flags[i]] = curs[i]
            end
            local _, slot = baseRow(opt.Name, true)
            local BOX_W, GAP = 34, 4
            local stripW = n * BOX_W + (n - 1) * GAP
            local strip = new("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(stripW, 20),
                BackgroundTransparency = 1,
            }, slot)
            local boxes = {}
            local function fire(i)
                if opt.Callbacks and opt.Callbacks[i] then
                    task.spawn(opt.Callbacks[i], curs[i])
                elseif opt.Callback then
                    task.spawn(opt.Callback, curs[i], i)
                end
            end
            local function setBox(i, col, silent)
                curs[i] = col
                Menu.Flags[flags[i]] = col
                boxes[i].BackgroundColor3 = col
                if not silent then fire(i) end
            end
            local function colorToString(col)
                return string.format("%d,%d,%d", math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255))
            end
            local function stringToColor(s)
                if type(s) ~= "string" then return nil end
                local r, g, b = s:match("(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
                if r then
                    return Color3.fromRGB(math.clamp(tonumber(r), 0, 255), math.clamp(tonumber(g), 0, 255), math.clamp(tonumber(b), 0, 255))
                end
                local hex = s:match("#?(%x%x%x%x%x%x)")
                if hex then
                    return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
                end
                return nil
            end
            for i = 1, n do
                local box = new("TextButton", {
                    Position = UDim2.fromOffset((i - 1) * (BOX_W + GAP), 0),
                    Size = UDim2.fromOffset(BOX_W, 20),
                    BackgroundColor3 = curs[i],
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                }, strip)
                new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
                boxes[i] = box
                box.MouseButton1Click:Connect(function()
                    if openPopup then closePopup() return end
                    openColorEditor(box, function() return curs[i] end, function(col) setBox(i, col) end)
                end)
                box.MouseButton2Click:Connect(function()
                    if openPopup then closePopup() return end
                    local m = UserInputService:GetMouseLocation()
                    local pop = new("Frame", {
                        Position = UDim2.fromOffset(m.X, m.Y - 30),
                        Size = UDim2.fromOffset(90, 70),
                        BackgroundColor3 = C.Popup,
                        BorderSizePixel = 0,
                        ZIndex = 300,
                    }, popupLayer)
                    new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pop)
                    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, pop)
                    new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, pop)
                    local actions = { "Copy", "Paste", "Reset" }
                    for ai, aname in ipairs(actions) do
                        local ob = new("TextButton", {
                            Size = UDim2.new(1, 0, 0, 20),
                            BackgroundColor3 = C.Option,
                            BorderSizePixel = 0,
                            Font = Enum.Font.Gotham,
                            TextSize = 12,
                            TextColor3 = C.ButtonText,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            Text = aname,
                            LayoutOrder = ai,
                            AutoButtonColor = false,
                            ZIndex = 301,
                        }, pop)
                        ob.MouseButton1Click:Connect(function()
                            if aname == "Copy" then
                                Menu.ColorClipboard = curs[i]
                                pcall(function() setclipboard(colorToString(curs[i])) end)
                            elseif aname == "Paste" then
                                local col = Menu.ColorClipboard
                                if type(col) ~= "Color3" then
                                    pcall(function() col = stringToColor(getclipboard()) end)
                                end
                                if type(col) == "Color3" then setBox(i, col) end
                            else -- Reset
                                setBox(i, defaults[i] or Color3.fromRGB(255, 255, 255))
                            end
                            closePopup()
                        end)
                    end
                    openPopup = pop
                end)
            end
            return {
                Set = function(c, idx)
                    setBox(idx or 1, c)
                end,
            }
        end

        -- KEYBIND: gates a feature. The linked toggle must be ON for the key to do anything.
        -- It never flips the checkbox itself; it only drives Active on/off.
        -- Left-click = rebind key. Right-click = mode menu (Always on / Toggle / Hold key).
        function sec.AddKeybind(opt)
            -- opt: { Name, Flag, DefaultKey=Enum.KeyCode.E, Mode="Hold key"|"Toggle"|"Always on", LinkedFlag=nil, Callback(active) }
            local flag = opt.Flag or (opt.Name .. "_Key")
            local key = opt.DefaultKey or Enum.KeyCode.E
            local mode = opt.Mode or "Hold key"
            if mode == "Hold" then mode = "Hold key" end
            if mode == "Always" then mode = "Always on" end
            local linked = opt.LinkedFlag -- string flag name of a toggle, optional
            local held, toggled = false, false
            -- short display names: LALT / RSHIFT / M1 / M2 ...
            local SHORT = {
                [Enum.KeyCode.LeftAlt] = "LALT",
                [Enum.KeyCode.RightAlt] = "RALT",
                [Enum.KeyCode.LeftShift] = "LSHIFT",
                [Enum.KeyCode.RightShift] = "RSHIFT",
                [Enum.KeyCode.LeftControl] = "LCTRL",
                [Enum.KeyCode.RightControl] = "RCTRL",
            }
            local MOUSE_SHORT = {
                [Enum.UserInputType.MouseButton1] = "M1",
                [Enum.UserInputType.MouseButton2] = "M2",
                [Enum.UserInputType.MouseButton3] = "M3",
            }
            local function shortName(k)
                if k == nil then return "None" end
                if SHORT[k] then return SHORT[k] end
                if MOUSE_SHORT[k] then return MOUSE_SHORT[k] end
                local ok, name = pcall(function() return k.Name end)
                if ok then return name end
                return "None"
            end
            local function keyMatches(input, k)
                if k == nil then return false end
                local ok, isKey = pcall(function() return k.EnumType == Enum.KeyCode end)
                if ok and isKey then
                    return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == k
                end
                return input.UserInputType == k
            end
            Menu.Flags[flag] = { Key = key, Mode = mode, Active = false }
            local _, slot = baseRow(opt.Name, true)
            local keyBtn = new("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = C.Button,
                BorderSizePixel = 0,
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextColor3 = C.ButtonText,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = "[" .. shortName(key) .. "]",
                AutoButtonColor = false,
            }, slot)

            local entry = { Name = opt.Name, Key = key, Mode = mode, Display = shortName(key), GetState = function() return false end }
            Menu.Binds[#Menu.Binds + 1] = entry

            local function linkedOn()
                if not linked then return true end
                return Menu.Flags[linked] == true
            end
            local function currentActive()
                if not linkedOn() then return false end
                if mode == "Always on" then return true end
                if mode == "Hold key" then return held end
                return toggled
            end
            local function push()
                local a = currentActive()
                Menu.Flags[flag].Active = a
                Menu.Flags[flag].Key = key
                Menu.Flags[flag].Mode = mode
                entry.Key = key
                entry.Mode = mode
                entry.Display = shortName(key)
                if opt.Callback then task.spawn(opt.Callback, a) end
                Menu.RefreshBinds()
            end
            entry.GetState = currentActive

            local capturing = false
            local suppressMenu = false -- right-click used to bind M2 shouldn't open the mode menu
            keyBtn.MouseButton1Click:Connect(function()
                capturing = true
                keyBtn.Text = "[...]"
            end)
            -- right-click opens the mode menu
            local MODES = { "Always on", "Toggle", "Hold key" }
            local function setMode(m)
                mode = m
                held, toggled = false, false
                push()
            end
            keyBtn.MouseButton2Click:Connect(function()
                if capturing then return end
                if suppressMenu then suppressMenu = false return end
                if openPopup then closePopup() return end
                local m = UserInputService:GetMouseLocation()
                local pop = new("Frame", {
                    Position = UDim2.fromOffset(m.X, m.Y - 30),
                    Size = UDim2.fromOffset(110, 22 * #MODES + 4),
                    BackgroundColor3 = C.Popup,
                    BorderSizePixel = 0,
                    ZIndex = 300,
                }, popupLayer)
                new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pop)
                new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, pop)
                new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, pop)
                for i, name in ipairs(MODES) do
                    local on = (name == mode)
                    local ob = new("TextButton", {
                        Size = UDim2.new(1, 0, 0, 20),
                        BackgroundColor3 = on and C.Button or C.Option,
                        BorderSizePixel = 0,
                        Font = Enum.Font.Gotham,
                        TextSize = 12,
                        TextColor3 = on and C.Text or C.ButtonText,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Text = name,
                        LayoutOrder = i,
                        AutoButtonColor = false,
                        ZIndex = 301,
                    }, pop)
                    ob.MouseButton1Click:Connect(function()
                        setMode(name)
                        closePopup()
                    end)
                end
                openPopup = pop
            end)
            UserInputService.InputBegan:Connect(function(input, gpe)
                if capturing then
                    local bound = nil
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        if input.KeyCode ~= Enum.KeyCode.Unknown then bound = input.KeyCode end
                    elseif input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.MouseButton2
                        or input.UserInputType == Enum.UserInputType.MouseButton3 then
                        bound = input.UserInputType
                        if bound == Enum.UserInputType.MouseButton2 then suppressMenu = true end
                    end
                    if bound then
                        capturing = false
                        key = bound
                        toggled, held = false, false
                        keyBtn.Text = "[" .. shortName(key) .. "]"
                        push()
                    elseif input.UserInputType == Enum.UserInputType.Keyboard then
                        capturing = false
                        keyBtn.Text = "[" .. shortName(key) .. "]"
                    end
                    return
                end
                if gpe then return end
                if keyMatches(input, key) then
                    if mode == "Hold key" then held = true push()
                    elseif mode == "Toggle" then toggled = not toggled push() end
                    -- "Always on" ignores the key, it follows the linked toggle
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if keyMatches(input, key) then
                    if mode == "Hold key" and held then held = false push() end
                end
            end)
            -- if the linked toggle turns off, force inactive + refresh list
            -- (polled cheaply via RefreshBinds caller; also hook via task)
            return {
                SetKey = function(k) key = k keyBtn.Text = "[" .. shortName(k) .. "]" toggled, held = false, false push() end,
                SetMode = function(m) setMode(m) end,
            }
        end

        return sec
    end

    btn.MouseButton1Click:Connect(function() selectTab(name) end)
    return tab
end

-- // keybind list window // --
local bindGui = new("Frame", {
    Name = "BindList",
    Position = UDim2.fromOffset(10, 60),
    Size = UDim2.fromOffset(190, 26),
    BackgroundColor3 = C.BG,
    BorderSizePixel = 0,
    Visible = true,
    ZIndex = 50,
}, gui)
new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bindGui)
new("UICorner", { CornerRadius = UDim.new(0, 2) }, bindGui)
new("TextLabel", {
    Name = "Title",
    BackgroundColor3 = C.Top,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 22),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextColor3 = C.Text,
    Text = "Keybinds",
    ZIndex = 51,
}, bindGui)
local bindHolder = new("Frame", {
    Name = "Rows",
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(0, 24),
    Size = UDim2.new(1, 0, 1, -26),
    ZIndex = 51,
}, bindGui)
local bindLayout = new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, bindHolder)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }, bindHolder)
Menu._bindListFrame = bindGui

do -- drag bind list
    local dragging, sp, si = false, nil, nil
    bindGui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true sp = bindGui.Position si = input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - si
            bindGui.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end

function Menu.RefreshBinds()
    if not Menu._bindListFrame then return end
    for _, ch in ipairs(bindHolder:GetChildren()) do
        if ch:IsA("TextLabel") then ch:Destroy() end
    end
    local n = 0
    for _, b in ipairs(Menu.Binds) do
        if b.Key then
            n = n + 1
            local on = false
            pcall(function() on = b.GetState() end)
            new("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 16),
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = on and C.Text or C.Faint,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = b.Name .. "  [" .. (b.Display or "?") .. "]  (" .. (b.Mode or "Hold key") .. ")  " .. (on and "ON" or "OFF"),
                LayoutOrder = n,
                ZIndex = 52,
            }, bindHolder)
        end
    end
    if n == 0 then
        new("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = C.Faint,
            Text = "none",
            ZIndex = 52,
        }, bindHolder)
    end
    bindGui.Size = UDim2.fromOffset(190, 28 + math.max(n, 1) * 18)
end

-- // watermark // --
local wm = new("Frame", {
    Name = "Watermark",
    Position = UDim2.fromOffset(10, 10),
    Size = UDim2.fromOffset(230, 22),
    BackgroundColor3 = C.BG,
    BorderSizePixel = 0,
    ZIndex = 50,
}, gui)
new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, wm)
new("UICorner", { CornerRadius = UDim.new(0, 2) }, wm)
local wmLabel = new("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = C.Dim,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "plain-menu",
    ZIndex = 51,
}, wm)

do -- drag watermark
    local dragging, sp, si = false, nil, nil
    wm.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true sp = wm.Position si = input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - si
            wm.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end

do
    local frames, last = 0, os.clock()
    local fps = 60
    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - last >= 0.5 then
            fps = math.floor(frames / (now - last) + 0.5)
            frames, last = 0, now
            local ping = "--"
            pcall(function()
                ping = tostring(math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())) .. " ms"
            end)
            local t = os.date("%H:%M:%S")
            wmLabel.Text = string.format("plain-menu  |  %d fps  |  %s  |  %s", fps, ping, t)
            -- auto-size watermark to text
            local s = TextService:GetTextSize(wmLabel.Text, 12, Enum.Font.Gotham, Vector2.new(2000, 22))
            wm.Size = UDim2.fromOffset(math.clamp(s.X + 20, 150, 400), 22)
        end
    end)
end

-- close popups on outside click (press-origin: a press starting INSIDE never closes,
-- so color-picker drags can leave the box without it disappearing)
local popupHeld = false
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and openPopup then
        local m = input.Position
        local p, s = openPopup.AbsolutePosition, openPopup.AbsoluteSize
        if m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y then
            popupHeld = true
        else
            local ref = openPopup
            task.delay(0.12, function()
                if openPopup == ref and not popupHeld then closePopup() end
            end)
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then popupHeld = false end
end)

-- // notifications (simple, gs-menu pattern: stacked per corner, slide in, auto-remove) // --
Menu.Notifications = { TopLeft = {}, TopRight = {}, BottomLeft = {}, BottomRight = {} }
local NOTIF_PAD, NOTIF_GAP, NOTIF_H = 10, 6, 26
local function notifViewport()
    local cam = workspace and workspace.CurrentCamera
    if cam then return cam.ViewportSize.X, cam.ViewportSize.Y end
    return 800, 600
end
local function notifSlot(pos, w, i)
    local vx, vy = notifViewport()
    if pos == "TopLeft" then
        return UDim2.fromOffset(NOTIF_PAD, NOTIF_PAD + (i - 1) * (NOTIF_H + NOTIF_GAP))
    elseif pos == "TopRight" then
        return UDim2.fromOffset(vx - w - NOTIF_PAD, NOTIF_PAD + (i - 1) * (NOTIF_H + NOTIF_GAP))
    elseif pos == "BottomLeft" then
        return UDim2.fromOffset(NOTIF_PAD, vy - NOTIF_H - NOTIF_PAD - (i - 1) * (NOTIF_H + NOTIF_GAP))
    else
        return UDim2.fromOffset(vx - w - NOTIF_PAD, vy - NOTIF_H - NOTIF_PAD - (i - 1) * (NOTIF_H + NOTIF_GAP))
    end
end
local function notifRestack(pos)
    local path = Menu.Notifications[pos]
    for i, n in ipairs(path) do
        local w = n.Frame.AbsoluteSize.X
        if w <= 0 then w = n.Width end
        TweenService:Create(n.Frame, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = notifSlot(pos, w, i) }):Play()
    end
end
function Menu.Notify(opt)
    -- Menu.Notify("text") or Menu.Notify({ Message, Delay = 3, Position = "TopLeft" })
    local msg = type(opt) == "string" and opt or ((type(opt) == "table" and opt.Message) or "Notification")
    local delay = (type(opt) == "table" and opt.Delay) or 3
    local pos = (type(opt) == "table" and opt.Position) or "TopLeft"
    pos = tostring(pos):lower():gsub("%s+", "")
    pos = ({ topleft = "TopLeft", topright = "TopRight", bottomleft = "BottomLeft", bottomright = "BottomRight" })[pos] or "TopLeft"
    local path = Menu.Notifications[pos]
    local tw = TextService:GetTextSize(tostring(msg), 12, Enum.Font.Gotham, Vector2.new(2000, NOTIF_H))
    local w = math.clamp(tw.X + 24, 80, 420)
    local frame = new("Frame", {
        Size = UDim2.fromOffset(w, NOTIF_H),
        BackgroundColor3 = C.BG,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
        ZIndex = 1000,
    }, gui)
    new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 1 }, frame)
    local label = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = C.Text,
        TextTransparency = 1,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = tostring(msg),
        ZIndex = 1001,
    }, frame)
    local n = { Frame = frame, Label = label, Width = w }
    path[#path + 1] = n
    local target = notifSlot(pos, w, #path)
    local vx = notifViewport()
    if pos == "TopLeft" or pos == "BottomLeft" then
        frame.Position = UDim2.fromOffset(-w - 20, target.Y.Offset)
    else
        frame.Position = UDim2.fromOffset(vx + 20, target.Y.Offset)
    end
    local twIn = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    TweenService:Create(frame, twIn, { Position = target, BackgroundTransparency = 0 }):Play()
    TweenService:Create(label, twIn, { TextTransparency = 0 }):Play()
    for _, st in ipairs(frame:GetChildren()) do
        if st:IsA("UIStroke") then TweenService:Create(st, twIn, { Transparency = 0 }):Play() end
    end
    local function remove()
        if not table.find(path, n) then return end
        local twOut = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        TweenService:Create(frame, twOut, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(label, twOut, { TextTransparency = 1 }):Play()
        for _, st in ipairs(frame:GetChildren()) do
            if st:IsA("UIStroke") then TweenService:Create(st, twOut, { Transparency = 1 }):Play() end
        end
        task.delay(0.25, function()
            local j = table.find(path, n)
            if j then table.remove(path, j) end
            pcall(function() frame:Destroy() end)
            notifRestack(pos)
        end)
    end
    n.Remove = remove
    if delay ~= math.huge then task.delay(delay, remove) end
    return n
end

-- hide
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Semicolon then
        main.Visible = not main.Visible
        if not main.Visible then closePopup() end
        -- watermark + bind list stay visible (standard)
    end
end)

-- ============================================================
-- BUILD: recreate the screenshot, now with real controls
-- ============================================================

local visualsTab = Menu.CreateTab("Visuals")
local gunsTab = Menu.CreateTab("Guns")

-- --- Visuals: demo every control so it's actually usable --- --
do
    local left = visualsTab.CreateColumn(1)
    local right = visualsTab.CreateColumn(2)

    local vMain = visualsTab.CreateSection(left, "Visuals")
    vMain.AddToggle({ Name = "Enable ESP", Flag = "ESPEnabled", Default = false })
    vMain.AddColorPicker({ Name = "ESP Color", Flag = "ESPColor", Default = Color3.fromRGB(175, 175, 175) })
    vMain.AddColorPicker({ Name = "Chams Colors", Flags = { "ChamsColor1", "ChamsColor2", "ChamsColor3" }, Defaults = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 255, 130), Color3.fromRGB(90, 160, 255) } })
    vMain.AddDropdown({ Name = "ESP Style", Flag = "ESPStyle", Options = { "Box", "Corner", "Skeleton" }, Default = "Box" })
    vMain.AddMultiDropdown({ Name = "ESP Parts", Flag = "ESPParts", Options = { "Head", "Torso", "Arms", "Legs" }, Default = { "Head", "Torso" } })
    vMain.AddSlider({ Name = "ESP Thickness", Flag = "ESPThickness", Min = 1, Max = 5, Default = 1, Decimals = 0, Suffix = "px" })
    vMain.AddTextbox({ Name = "ESP Prefix", Flag = "ESPPrefix", Default = "plain", Placeholder = "prefix..." })
    vMain.AddKeybind({ Name = "ESP Key", Flag = "ESPKey", DefaultKey = Enum.KeyCode.E, Mode = "Toggle", LinkedFlag = "ESPEnabled" })

    local vExtra = visualsTab.CreateSection(right, "Preview")
    vExtra.AddNote("Keybinds gate their toggle:")
    vExtra.AddNote("toggle OFF = key does nothing.")
    vExtra.AddNote("Left-click a bind to rebind it.")
    vExtra.AddNote("Right-click a bind for mode:")
    vExtra.AddNote("Always on / Toggle / Hold key.")
    vExtra.AddButton({ Name = "TestNotif", Text = "Test Notification", Callback = function()
        Menu.Notify({ Message = "plain-menu notification", Delay = 3, Position = "TopRight" })
    end })
    vExtra.AddButton({ Name = "Unload", Text = "Unload Menu", Callback = function()
        gui:Destroy()
    end })
end

-- --- Guns: the screenshot layout, fixed --- --
do
    local left = gunsTab.CreateColumn(1)
    local right = gunsTab.CreateColumn(2)

    local settings = gunsTab.CreateSection(left, "Settings")
    settings.AddDropdown({
        Name = "Gun To Mod", Flag = "GunToMod",
        Options = { "Gun Name", "XM177", "M4A1", "AK-47", "AWP" }, Default = "Gun Name",
    })
    settings.AddToggle({ Name = "Apply Modifications To All Guns", Flag = "ApplyToAll", Default = false })
    settings.AddToggle({ Name = "Auto-Detect On Equip", Flag = "AutoDetect", Default = false })

    local client = gunsTab.CreateSection(left, "Client Mods")
    client.AddTextbox({ Name = "Edit Display Name", Flag = "DisplayName", Default = "Display Name", Placeholder = "Display Name" })
    client.AddTextbox({ Name = "Edit Description", Flag = "Description", Default = "Description", Placeholder = "Description" })
    client.AddTextbox({ Name = "Edit Icon", Flag = "IconID", Default = "Image ID", Placeholder = "Image ID" })
    client.AddToggle({ Name = "Rare Item", Flag = "RareItem", Default = false })
    client.AddDropdown({
        Name = "Suppressed Fire Sound", Flag = "SuppSound",
        Options = { "XM177 Suppressed", "M4 Suppressed", "AK Suppressed", "None" }, Default = "XM177 Suppressed",
    })
    client.AddDropdown({
        Name = "Fire Sound", Flag = "FireSound",
        Options = { "XM177 Suppressed", "M4 Loud", "AK Loud", "None" }, Default = "XM177 Suppressed",
    })
    client.AddToggle({ Name = "Automatic Firemode (WIP)", Flag = "AutoFire", Default = false })
    client.AddKeybind({ Name = "Auto-Fire Key", Flag = "AutoFireKey", DefaultKey = Enum.KeyCode.F, Mode = "Hold", LinkedFlag = "AutoFire" })

    -- skin-changer pattern (gs-menu): dropdown + searchable list with custom height
    local changer = gunsTab.CreateSection(left, "Skin Changer")
    local allSkins = { "Default", "Redline", "Asiimov", "Dragon Lore", "Fade", "Slaughter", "Crimson Web", "Howl" }
    changer.AddDropdown({ Name = "Pick a Gun", Flag = "ChangerGun", Options = { "AK-47", "M4A1", "AWP", "Knife" }, Default = "AK-47" })
    local skinList = changer.AddList({ Name = "Skins", Flag = "ChangerSkin", Height = 140, Values = allSkins, Callback = function(v)
        Menu.Notify({ Message = "Applied " .. tostring(v) .. " to " .. tostring(Menu.Flags.ChangerGun), Delay = 2 })
    end })
    changer.AddTextbox({ Name = "Search Skins", Flag = "ChangerSearch", Placeholder = "type + Enter to filter...", Callback = function(q)
        q = string.lower(tostring(q))
        local out = {}
        for _, n in ipairs(allSkins) do
            if string.find(string.lower(n), q, 1, true) then out[#out + 1] = n end
        end
        skinList:SetValues(out)
    end })

    local perf = gunsTab.CreateSection(right, "Performance Mods")
    perf.AddNote("You can use EZ-Mod to quickly mod guns.")
    perf.AddNote("Select an option and the mods apply automatically.")
    perf.AddNote("Disclaimer: Rage will get you banned. Use wisely.")
    perf.AddDropdown({ Name = "EZ-Mod", Flag = "EZMod", Options = { "Legit", "Rage", "Blatant" }, Default = "Legit" })
    perf.AddSlider({ Name = "Fire-Rate", Flag = "FireRate", Min = 0, Max = 100, Default = 35, Decimals = 0 })
    perf.AddSlider({ Name = "Kick Up Multiplier", Flag = "KickUp", Min = 0, Max = 5, Default = 1, Decimals = 2, Suffix = "x" })
    perf.AddSlider({ Name = "Raise Multiplier", Flag = "RaiseMult", Min = 0, Max = 5, Default = 1, Decimals = 2, Suffix = "x" })
    perf.AddSlider({ Name = "Shift Multiplier", Flag = "ShiftMult", Min = 0, Max = 5, Default = 1, Decimals = 2, Suffix = "x" })
    perf.AddSlider({ Name = "Spread Base", Flag = "SpreadBase", Min = 0, Max = 10, Default = 3.5, Decimals = 2 })
    perf.AddSlider({ Name = "TP Spread Add", Flag = "TPSpread", Min = 0, Max = 10, Default = 3.5, Decimals = 2 })
    perf.AddSlider({ Name = "FP Spread Add", Flag = "FPSpread", Min = 0, Max = 10, Default = 3.5, Decimals = 2 })
    perf.AddSlider({ Name = "Burst Bullet Amount", Flag = "Burst", Min = 1, Max = 10, Default = 3, Decimals = 0 })
    perf.AddMultiDropdown({ Name = "Extra Mods", Flag = "ExtraMods", Options = { "No Recoil", "No Spread", "Unlock All" }, Default = { "No Recoil" } })
    perf.AddColorPicker({ Name = "Mod Tint", Flag = "ModTint", Default = Color3.fromRGB(175, 175, 175) })
    perf.AddKeybind({ Name = "Panic Key", Flag = "PanicKey", DefaultKey = Enum.KeyCode.P, Mode = "Toggle", LinkedFlag = "ApplyToAll" })
end

selectTab("Guns")
Menu.RefreshBinds()
Menu.Notify({ Message = "plain-menu loaded - Semicolon to hide", Delay = 3 })

return Menu
