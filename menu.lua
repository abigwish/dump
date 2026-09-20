-- plain-menu.lua
-- Plain, dependency-free Roblox menu library. GitHub-ready.
-- Theme: dark 17/23/14 with 42 line, 835x485, Semicolon to hide, drag top bar.
--
-- == DEVELOPER SETUP ==
--   Change ROOT_FOLDER below to your project name. The library creates:    
--     ROOT_FOLDER/configs  -> JSON configs (flags + theme + toggles)
--     ROOT_FOLDER/lua      -> .lua / .luau addons loaded via Lua tab
--   Example: ROOT_FOLDER = "jonashook" creates jonashook/lua + jonashook/configs
--   Do NOT expose this to users via UI - set it here before publishing.
--
-- == QUICK START ==
--   local Menu = loadstring(game:HttpGet("https://raw.githubusercontent.com/<you>/plain-menu/main/plain-menu.lua"))()
--   -- or local Menu = loadstring(readfile("plain-menu.lua"))()
--   local tab = Menu.CreateTab("Visuals")
--   local col = tab.CreateColumn(1)          -- 1 = left  (51.5%), 2 = right (48.5%)
--   local sec = tab.CreateSection(col, "Section Title")
--
-- == API ==
--   Menu.CreateTab(name) -> tab
--   tab.CreateColumn(index) -> ScrollingFrame
--   tab.CreateSection(column, title) -> sec
--   sec.AddNote(text)                          -- small dim label
--   sec.AddButton({ Name, Text, Callback })
--   sec.AddToggle({ Name, Flag, Default=false, Callback(state) })
--   sec.AddTextbox({ Name, Flag, Default, Placeholder, Callback(value) }) -- Enter to commit
--   sec.AddMultiline({ Name, Flag, Height=110, Placeholder, Callback })   -- full-width code box
--   sec.AddSlider({ Name, Flag, Min, Max, Default, Decimals=2, Callback }) -- bar shows value/max (max integer), double-click to type
--   sec.AddDropdown({ Name, Flag, Options={}, Default, Callback(value) })
--   sec.AddMultiDropdown({ Name, Flag, Options={}, Default={}, Callback(dict) }) -- text joins with ", " and truncates
--   sec.AddList({ Name, Flag, Height=120, Values={}, Default, Callback(value) }) -- scrollable, clickable rows; :SetValues, :AddValue, :RemoveValue, :Clear, :Set, :Get, :SetValues
--   sec.AddColorPicker({ Name, Flag, Default=Color3, Callback(color) }) -- or { Flags={...}, Defaults={...} } for 2-4 swatches in one row
--       left-click swatch -> HSV box (SV square + hue bar), right-click -> Copy / Paste / Paste hex / Reset
--   sec.AddKeybind({ Name, Flag, DefaultKey=Enum.KeyCode.E, Mode="Hold key", LinkedFlag, Callback(active) })
--       Modes via right-click menu: "Always on" / "Toggle" / "Hold key" (gates LinkedFlag; never flips the checkbox)
--       Supports LeftAlt->LALT, RightShift->RSHIFT, M1/M2/M3. Left-click to rebind.
--   Menu.Notify(msg or { Message, Delay=3, Position="TopRight" }) -- TopLeft/TopRight/BottomLeft/BottomRight
--   Menu.SaveConfig(name), Menu.LoadConfig(name), Menu.UpdateConfigList(List)
--   Menu.ApplyThemePreset(name), Menu.ApplyThemeColors() -- presets: Dark/Midnight/Onyx/Slate/Carbon
--   Menu.get_addon_list() -> { names }, Menu.load_addon(name), Menu.unload_addon(name) -- Lua tab file loader
--   Flags live in Menu.Flags[Flag] and Menu.Registry[Flag]:Set(value) for programmatic control
--   Global: getgenv().PlainMenu == Menu, getgenv().PlainMenuFlags == Menu.Flags
--
-- == NOTES ==
--   - MultiDropdown Flag stores dict Set { [option]=true }; save/load flattens to array.
--   - Color Flag stores Color3; JSON uses { __color=true, c={r,g,b} } (0-1).
--   - Keybind Flag stores { Key=Enum, Mode=string, Active=bool }; JSON uses { __bind=true, key="E", mode="Toggle" }.
--   - Folder is developer-set only (ROOT_FOLDER below). No UI for it.

local ROOT_FOLDER = "plain-menu" -- << DEVELOPER: change this (e.g. "jonashook") before publishing

-- forward declare Menu so early hide-bind helpers can write to it
local Menu = { Flags = {}, Binds = {}, Tabs = {}, Registry = {}, KeybindControls = {}, _bindListFrame = nil }

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
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
        local oldCur = parent:FindFirstChild(GUI_NAME .. "_Cursor")
        if oldCur then pcall(function() oldCur:Destroy() end) end
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
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 1000,
    IgnoreGuiInset = true,
}, rootParent)

-- custom cursor always on top (game has custom cursor that hid menu)
local cursorGui = new("ScreenGui", {
    Name = GUI_NAME .. "_Cursor",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 10000,
    IgnoreGuiInset = true,
}, rootParent)
local cursor = nil
do
    local ok, cur = pcall(function()
        return new("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(20, 20),
            Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png",
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ZIndex = 10000,
            Visible = false,
        }, cursorGui)
    end)
    if ok and cur then cursor = cur else
        pcall(function()
            local c = Instance.new("ImageLabel")
            c.BackgroundTransparency = 1
            c.Size = UDim2.fromOffset(20, 20)
            c.Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png"
            c.ZIndex = 10000
            c.Visible = false
            c.Parent = cursorGui
            cursor = c
        end)
    end
end

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
local topLabel = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(1, -20, 1, 0),
    Font = Enum.Font.GothamBold,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = C.Text,
    TextTruncate = Enum.TextTruncate.AtEnd,
    Text = "press right shift to hide this menu",
}, top)
-- dynamic hide bind (rebindable in settings, persisted via Menu.Flags.MenuHideKey)
local function keyDisplayLower(k)
    if not k then return "semicolon" end
    local SHORT_LOWER = {
        [Enum.KeyCode.LeftAlt] = "left alt",
        [Enum.KeyCode.RightAlt] = "right alt",
        [Enum.KeyCode.LeftShift] = "left shift",
        [Enum.KeyCode.RightShift] = "right shift",
        [Enum.KeyCode.LeftControl] = "left ctrl",
        [Enum.KeyCode.RightControl] = "right ctrl",
        [Enum.KeyCode.CapsLock] = "caps lock",
        [Enum.KeyCode.Space] = "space",
        [Enum.KeyCode.Semicolon] = "semicolon",
        [Enum.KeyCode.Insert] = "insert",
        [Enum.UserInputType.MouseButton1] = "m1",
        [Enum.UserInputType.MouseButton2] = "m2",
        [Enum.UserInputType.MouseButton3] = "m3",
    }
    if SHORT_LOWER[k] then return SHORT_LOWER[k] end
    local ok, n = pcall(function() return k.Name end)
    if ok and n then return string.lower(n) end
    return "semicolon"
end
Menu.HideKey = Enum.KeyCode.RightShift
local function updateTopText(k)
    Menu.HideKey = k
    Menu.Flags.MenuHideKey = k
    pcall(function() topLabel.Text = "press " .. keyDisplayLower(k) .. " to hide this menu" end)
end
-- restore hide key from flag if present (handles KeyCode / MouseButton)
do
    local fk = Menu.Flags.MenuBind or Menu.Flags.MenuHideKey
    if fk then
        local parsed
        pcall(function()
            if typeof(fk) == "EnumItem" then parsed = fk
            elseif type(fk) == "table" and fk.Key then parsed = fk.Key
            elseif type(fk) == "string" and Enum.KeyCode[fk] then parsed = Enum.KeyCode[fk]
            elseif type(fk) == "string" and Enum.UserInputType[fk] then parsed = Enum.UserInputType[fk]
            elseif type(fk) == "table" and fk.Name and Enum.KeyCode[fk.Name] then parsed = Enum.KeyCode[fk.Name]
            elseif type(fk) == "table" and fk.Name and Enum.UserInputType[fk.Name] then parsed = Enum.UserInputType[fk.Name]
            end
        end)
        if parsed then updateTopText(parsed) end
    end
end
-- divider is parented to MAIN (not the sidebar) so UIListLayout can't eat it
new("Frame", { Name = "TopLine", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 26), BackgroundColor3 = C.Line, BorderSizePixel = 0, ZIndex = 2 }, main)

-- cursor always on top (after main exists)
do
    local function updateCursor()
        if not cursor or not main then return end
        local okPos, pos = pcall(function() return UserInputService:GetMouseLocation() end)
        if not okPos or not pos then return end
        pcall(function() cursor.Position = UDim2.fromOffset(pos.X, pos.Y) end)
        local shouldShow = false
        pcall(function() shouldShow = main.Visible and isInside(main, pos) end)
        if openPopup then shouldShow = true end
        pcall(function() if main.Visible then shouldShow = true end end)
        pcall(function() cursor.Visible = shouldShow end)
        pcall(function() UserInputService.MouseIconEnabled = not shouldShow end)
    end
    pcall(function() RunService.RenderStepped:Connect(updateCursor) end)
    pcall(function() main:GetPropertyChangedSignal("Visible"):Connect(updateCursor) end)
end

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

-- // Menu object // -- (already forward-declared above; just ensure globals)
Menu.Flags = Menu.Flags or {}
Menu.Binds = Menu.Binds or {}
Menu.Tabs = Menu.Tabs or {}
Menu.Registry = Menu.Registry or {}
Menu.KeybindControls = Menu.KeybindControls or {}
Menu._bindListFrame = Menu._bindListFrame
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
        -- separator between sections in same column
        local colCount = column:GetAttribute("SecCount") or 0
        if colCount > 0 then
            local sep = new("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = C.Line,
                BorderSizePixel = 0,
                LayoutOrder = colCount * 2 - 1,
            }, column)
            sep:SetAttribute("IsSeparator", true)
        end
        local holder = new("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 26),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = colCount * 2,
        }, column)
        column:SetAttribute("SecCount", colCount + 1)
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
                -- re-resolve keybinds gated by this toggle (Active follows the checkbox live)
                for _, kb in pairs(Menu.KeybindControls) do
                    if kb.Linked == flag then kb.Push() end
                end
                Menu.RefreshBinds()
            end
            box.MouseButton1Click:Connect(function() set(not Menu.Flags[flag]) end)
            local tApi = { Set = set, Box = box }
            Menu.Registry[flag] = tApi
            return tApi
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
            function api.Set(v) tb.Text = tostring(v) Menu.Flags[flag] = tb.Text if opt.Callback then task.spawn(opt.Callback, tb.Text) end end
            Menu.Registry[flag] = api
            return api
        end

        -- MULTILINE: full-width code/text area with custom height (for the Lua runner).
        function sec.AddMultiline(opt)
            -- opt: { Name, Flag, Height = 110, Default = "", Callback(value) }
            local flag = opt.Flag or opt.Name
            local height = opt.Height or 110
            Menu.Flags[flag] = opt.Default or ""
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
            local tb = new("TextBox", {
                Position = UDim2.fromOffset(0, 24),
                Size = UDim2.new(1, 0, 0, height),
                BackgroundColor3 = C.Popup,
                BorderSizePixel = 0,
                Font = Enum.Font.Code,
                TextSize = 13,
                TextColor3 = C.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                PlaceholderColor3 = C.Faint,
                PlaceholderText = opt.Placeholder or "",
                Text = tostring(opt.Default or ""),
                TextWrapped = false,
                MultiLine = true,
                ClearTextOnFocus = false,
            }, wrap)
            new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tb)
            tb.FocusLost:Connect(function(enter)
                if enter then
                    Menu.Flags[flag] = tb.Text
                    if opt.Callback then task.spawn(opt.Callback, tb.Text) end
                end
            end)
            local mApi = {}
            function mApi.Set(v) tb.Text = tostring(v) Menu.Flags[flag] = tb.Text end
            function mApi.Get() return tb.Text end
            Menu.Registry[flag] = mApi
            return mApi
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
            local sApi = { Set = set }
            Menu.Registry[flag] = sApi
            return sApi
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
            function api.Set(v) Menu.Flags[flag] = v b.Text = tostring(v) if opt.Callback then task.spawn(opt.Callback, v) end end
            Menu.Registry[flag] = api
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
            local mdApi = {}
            function mdApi.Set(t)
                set = {}
                if type(t) == "table" then
                    if t[1] ~= nil then -- array of names (config load)
                        for _, v in ipairs(t) do set[tostring(v)] = true end
                    else -- dict set
                        for k, v in pairs(t) do if v then set[tostring(k)] = true end end
                    end
                end
                Menu.Flags[flag] = set
                renderBtn()
            end
            Menu.Registry[flag] = mdApi
            return mdApi
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
            Menu.Registry[flag] = api
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
                local idx = i
                local box = new("TextButton", {
                    Position = UDim2.fromOffset((idx - 1) * (BOX_W + GAP), 0),
                    Size = UDim2.fromOffset(BOX_W, 20),
                    BackgroundColor3 = curs[idx],
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                }, strip)
                new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
                boxes[idx] = box
                box.MouseButton1Click:Connect(function()
                    if openPopup then closePopup() return end
                    openColorEditor(box, function() return curs[idx] end, function(col) setBox(idx, col) end)
                end)
                box.MouseButton2Click:Connect(function()
                    if openPopup then closePopup() return end
                    local m = UserInputService:GetMouseLocation()
                    local pop = new("Frame", {
                        Position = UDim2.fromOffset(m.X, m.Y - 30),
                        Size = UDim2.fromOffset(100, 92),
                        BackgroundColor3 = C.Popup,
                        BorderSizePixel = 0,
                        ZIndex = 300,
                    }, popupLayer)
                    new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pop)
                    new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, pop)
                    new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, pop)
                    local actions = { "copy", "paste", "paste hex", "reset" }
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
                            local cb = idx -- capture for closure safety
                            if aname == "copy" then
                                Menu.ColorClipboard = curs[cb]
                                local s = colorToString(curs[cb])
                                local hx = string.format("#%02X%02X%02X", math.floor(curs[cb].R * 255), math.floor(curs[cb].G * 255), math.floor(curs[cb].B * 255))
                                pcall(function() setclipboard(s) end)
                                -- also stash hex so paste hex can fallback
                                Menu.ColorClipboardHex = hx
                                Menu.Notify({ Message = "copied " .. string.lower(s) .. " (" .. string.lower(hx) .. ")", Delay = 1.5 })
                            elseif aname == "paste" then
                                local col = Menu.ColorClipboard
                                if typeof(col) ~= "Color3" then
                                    local clip
                                    pcall(function() clip = getclipboard and getclipboard() or "" end)
                                    col = stringToColor(clip)
                                    if not col and clip then
                                        -- try raw "r,g,b" with spaces
                                        pcall(function() col = stringToColor(tostring(clip)) end)
                                    end
                                end
                                if typeof(col) == "Color3" then
                                    setBox(cb, col)
                                    Menu.Notify({ Message = "Pasted " .. colorToString(col), Delay = 1.5 })
                                else
                                    Menu.Notify({ Message = "clipboard has no color", Delay = 2 })
                                end
                            elseif aname == "paste hex" then
                                local clip
                                pcall(function() clip = getclipboard and getclipboard() or "" end)
                                clip = tostring(clip or "")
                                -- hex like #FF00AA or FF00AA or 0xFF00AA
                                local hex = clip:match("#?(%x%x%x%x%x%x)") or clip:match("0x(%x%x%x%x%x%x)") or clip:match("(%x%x%x%x%x%x)")
                                local col = nil
                                if hex and #hex == 6 then
                                    col = Color3.fromRGB(tonumber(hex:sub(1,2),16), tonumber(hex:sub(3,4),16), tonumber(hex:sub(5,6),16))
                                else
                                    col = stringToColor(clip)
                                end
                                if typeof(col) == "Color3" then
                                    setBox(cb, col)
                                    Menu.Notify({ Message = "pasted hex " .. string.lower(string.format("#%02X%02X%02X", math.floor(col.R*255), math.floor(col.G*255), math.floor(col.B*255))), Delay = 1.5 })
                                else
                                    Menu.Notify({ Message = "no hex in clipboard", Delay = 2 })
                                end
                            else -- reset
                                setBox(cb, defaults[cb] or Color3.fromRGB(255, 255, 255))
                                Menu.Notify({ Message = "reset", Delay = 1.2 })
                            end
                            closePopup()
                        end)
                    end
                    openPopup = pop
                end)
            end
            for i = 1, n do
                local idx = i
                Menu.Registry[flags[idx]] = { Set = function(c) setBox(idx, c) end }
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
            if string.lower(mode) == "hold" then mode = "hold key" end
            if string.lower(mode) == "always" then mode = "always on" end
            local linked = opt.LinkedFlag -- string flag name of a toggle, optional
            local held, toggled = false, false
            -- short display names: lower caps per request (lalt / right shift / m1 ...)
            local SHORT = {
                [Enum.KeyCode.LeftAlt] = "left alt",
                [Enum.KeyCode.RightAlt] = "right alt",
                [Enum.KeyCode.LeftShift] = "left shift",
                [Enum.KeyCode.RightShift] = "right shift",
                [Enum.KeyCode.LeftControl] = "left ctrl",
                [Enum.KeyCode.RightControl] = "right ctrl",
            }
            local MOUSE_SHORT = {
                [Enum.UserInputType.MouseButton1] = "m1",
                [Enum.UserInputType.MouseButton2] = "m2",
                [Enum.UserInputType.MouseButton3] = "m3",
            }
            local function shortName(k)
                if k == nil then return "none" end
                if SHORT[k] then return SHORT[k] end
                if MOUSE_SHORT[k] then return MOUSE_SHORT[k] end
                local ok, name = pcall(function() return k.Name end)
                if ok then return string.lower(name) end
                return "none"
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
                if string.lower(mode) == "always on" then return true end
                if string.lower(mode) == "hold key" then return held end
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
            local kbControl = { Linked = linked, Push = function() end, Entry = entry }
            Menu.KeybindControls[flag] = kbControl
            local function _kbPush() push() end
            kbControl.Push = _kbPush
            keyBtn.MouseButton1Click:Connect(function()
                capturing = true
                keyBtn.Text = "[...]"
            end)
            -- right-click opens the mode menu
            local MODES = { "always on", "toggle", "hold key" }
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
                    if string.lower(mode) == "hold key" then held = true push()
                    elseif string.lower(mode) == "toggle" then toggled = not toggled push() end
                    -- "always on" ignores the key, it follows the linked toggle
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if keyMatches(input, key) then
                    if string.lower(mode) == "hold key" and held then held = false push() end
                end
            end)
            -- if the linked toggle turns off, force inactive + refresh list
            -- (polled cheaply via RefreshBinds caller; also hook via task)
            return {
                SetKey = function(k) key = k keyBtn.Text = "[" .. shortName(k) .. "]" toggled, held = false, false push() end,
                SetMode = function(m) setMode(m) end,
                Set = function(v)
                    -- for config load: v = { key, mode, active (ignored) } or { Key, Mode } pair
                    if type(v) == "table" then
                        if v.Key then
                            local ok, parsed = pcall(function()
                                if type(v.Key) == "UserData" then return v.Key end
                                local s = tostring(v.Key)
                                if Enum.KeyCode[s] then return Enum.KeyCode[s] end
                                if Enum.UserInputType[s] then return Enum.UserInputType[s] end
                                return nil
                            end)
                            if ok and parsed then key = parsed end
                        elseif v[1] ~= nil then
                            local ok, parsed = pcall(function()
                                local s = tostring(v[1])
                                if Enum.KeyCode[s] then return Enum.KeyCode[s] end
                                if Enum.UserInputType[s] then return Enum.UserInputType[s] end
                                return nil
                            end)
                            if ok and parsed then key = parsed end
                        end
                        if v.Mode and ({ ["Always on"] = true, ["Toggle"] = true, ["Hold key"] = true })[tostring(v.Mode)] then
                            mode = tostring(v.Mode)
                        elseif v[2] ~= nil and type(v[2]) == "string" then
                            local m = tostring(v[2])
                            if m == "Hold" then m = "Hold key" end
                            if ({ ["Always on"] = true, ["Toggle"] = true, ["Hold key"] = true })[m] then mode = m end
                        end
                        keyBtn.Text = "[" .. shortName(key) .. "]"
                        toggled, held = false, false
                        push()
                    end
                end,
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
    Text = "keybinds",
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
    -- all notifications forced to top right per request
    local msg = type(opt) == "string" and opt or ((type(opt) == "table" and opt.Message) or "notification")
    local delay = (type(opt) == "table" and opt.Delay) or 3
    local pos = "TopRight"
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
local function menuKeyMatches(input, k)
    if not k then return false end
    local ok, isKey = pcall(function() return k.EnumType == Enum.KeyCode end)
    if ok and isKey then
        return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == k
    end
    return input.UserInputType == k
end
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if menuKeyMatches(input, Menu.HideKey) then
        main.Visible = not main.Visible
        if not main.Visible then closePopup() end
        -- watermark + bind list stay visible (standard)
    end
end)

-- ============================================================
-- CONFIGS / THEMES / WATERMARK+KEYBIND LIST TOGGLES / LUA RUNNER
-- ============================================================

local function repaintMenu()
    pcall(function() main.BackgroundColor3 = C.BG end)
    pcall(function() top.BackgroundColor3 = C.Top or C.BG end)
    pcall(function() side.BackgroundColor3 = C.Side or C.BG end)
    pcall(function() bindGui.BackgroundColor3 = C.BG end)
    pcall(function() wm.BackgroundColor3 = C.BG end)
    pcall(function()
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("UIStroke") and d.Parent and d.Parent.Parent == main then
                d.Color = C.Line
            end
            if d:GetAttribute("IsWatermarkStroke") then d.Color = C.Line end
            if d:GetAttribute("IsBindStroke") then d.Color = C.Line end
            if d:GetAttribute("IsSeparator") then d.BackgroundColor3 = C.Line end
        end
    end)
end
-- tag main strokes so repaint can find them
pcall(function()
    for _, ch in ipairs(main:GetChildren()) do
        if ch:IsA("UIStroke") then ch:SetAttribute("IsMainStroke", true) end
    end
    for _, ch in ipairs(wm:GetChildren()) do
        if ch:IsA("UIStroke") then ch:SetAttribute("IsWatermarkStroke", true) end
    end
    for _, ch in ipairs(bindGui:GetChildren()) do
        if ch:IsA("UIStroke") then ch:SetAttribute("IsBindStroke", true) end
    end
end)

do
    -- root folder is developer-set (ROOT_FOLDER above) and contains <root>/lua + <root>/configs
    local function sanitizeFolder(s)
        s = tostring(s or ""):match("^%s*(.-)%s*$") or ""
        s = s:gsub("[\\/:*?\"<>|]", "")
        if s == "" then s = "plain-menu" end
        return s
    end
    local initialRoot = sanitizeFolder(ROOT_FOLDER)
    -- allow overrides via existing flag on reload
    if Menu.Flags.RootFolder and Menu.Flags.RootFolder ~= initialRoot then
        initialRoot = sanitizeFolder(Menu.Flags.RootFolder)
    end
    Menu.Flags.RootFolder = initialRoot
    Menu.RootFolder = initialRoot
    Menu.ConfigFolder = initialRoot .. "/configs"
    Menu.AddonFolder = initialRoot .. "/lua"
    local function ensureFolders(root)
        root = sanitizeFolder(root)
        pcall(function() if not isfolder(root) then makefolder(root) end end)
        pcall(function() if not isfolder(root .. "/configs") then makefolder(root .. "/configs") end end)
        pcall(function() if not isfolder(root .. "/lua") then makefolder(root .. "/lua") end end)
        -- keep legacy plain-menu/addons working by also ensuring old path once
        pcall(function() if isfolder("plain-menu/addons") then end end)
    end
    ensureFolders(initialRoot)
    function Menu.setRoot(name)
        local root = sanitizeFolder(name)
        Menu.Flags.RootFolder = root
        Menu.RootFolder = root
        Menu.ConfigFolder = root .. "/configs"
        Menu.AddonFolder = root .. "/lua"
        ensureFolders(root)
        -- refresh live lists if they exist
        if Menu._configsList then pcall(function() Menu.UpdateConfigList(Menu._configsList) end) end
        if Menu._addonList then pcall(function() Menu._addonList:SetValues(Menu.get_addon_list and Menu.get_addon_list() or {}) end) end
        Menu.Notify({ Message = "Folder: " .. root .. " (/lua + /configs)", Delay = 2 })
        return root
    end
    -- keep old names for compat (some addons read Menu.ConfigFolder)
    local CONFIG_FOLDER = initialRoot
    local CONFIG_CFG_FOLDER = initialRoot .. "/configs"

    local PRESET_THEMES = {
        ["dark"] = false,
        ["midnight"] = {
            BG = Color3.fromRGB(13, 13, 16), Top = Color3.fromRGB(18, 18, 22), Side = Color3.fromRGB(10, 10, 13),
            Popup = Color3.fromRGB(18, 18, 22), Button = Color3.fromRGB(48, 48, 56), Text = Color3.fromRGB(228, 228, 230),
            Line = Color3.fromRGB(42, 42, 48), Dim = Color3.fromRGB(165, 165, 175), Faint = Color3.fromRGB(110, 110, 120),
        },
        ["onyx"] = {
            BG = Color3.fromRGB(22, 22, 22), Top = Color3.fromRGB(28, 28, 28), Side = Color3.fromRGB(16, 16, 16),
            Popup = Color3.fromRGB(26, 26, 26), Button = Color3.fromRGB(60, 60, 60), Text = Color3.fromRGB(225, 225, 225),
            Line = Color3.fromRGB(48, 48, 48), Dim = Color3.fromRGB(165, 165, 165), Faint = Color3.fromRGB(120, 120, 120),
        },
        ["slate"] = {
            BG = Color3.fromRGB(28, 30, 34), Top = Color3.fromRGB(34, 36, 42), Side = Color3.fromRGB(20, 22, 26),
            Popup = Color3.fromRGB(33, 36, 42), Button = Color3.fromRGB(62, 66, 76), Text = Color3.fromRGB(230, 232, 236),
            Line = Color3.fromRGB(52, 56, 68), Dim = Color3.fromRGB(160, 168, 182), Faint = Color3.fromRGB(110, 118, 132),
        },
        ["carbon"] = {
            BG = Color3.fromRGB(18, 18, 18), Top = Color3.fromRGB(24, 24, 24), Side = Color3.fromRGB(14, 14, 14),
            Popup = Color3.fromRGB(22, 22, 22), Button = Color3.fromRGB(54, 54, 54), Text = Color3.fromRGB(232, 232, 232),
            Line = Color3.fromRGB(44, 44, 44), Dim = Color3.fromRGB(170, 170, 170), Faint = Color3.fromRGB(118, 118, 118),
        },
    }

    Menu.ConfigFolder = CONFIG_CFG_FOLDER
    Menu.ConfigFolder = Menu.ConfigFolder -- keep for compat
    Menu.Themes = PRESET_THEMES
    Menu._configsList = nil
    Menu._themesList = nil
    -- re-point ConfigFolder / AddonFolder after setRoot helper is ready (ensure request above didn't clobber)
    Menu.ConfigFolder = Menu.RootFolder .. "/configs"
    Menu.AddonFolder = Menu.RootFolder .. "/lua"

    local function tableToColor(t)
        if type(t) ~= "table" or t[1] == nil then return nil end
        return Color3.new(math.clamp(t[1], 0, 1), math.clamp(t[2], 0, 1), math.clamp(t[3], 0, 1))
    end

    -- if a config later restores RootFolder, re-apply folders (hook after LoadConfig below)

    function Menu.ApplyThemeColors(names)
        repaintMenu()
    end
    function Menu.ApplyThemePreset(name)
        name = string.lower(tostring(name))
        if not PRESET_THEMES[name] or PRESET_THEMES[name] == false then
            -- dark = default plain colors
            if name == "dark" then
                C.BG = Color3.fromRGB(17, 17, 17)
                C.Top = Color3.fromRGB(23, 23, 23)
                C.Side = Color3.fromRGB(14, 14, 14)
                C.Popup = Color3.fromRGB(22, 22, 22)
                C.Button = Color3.fromRGB(56, 56, 56)
                C.Text = Color3.fromRGB(225, 225, 225)
                C.Line = Color3.fromRGB(42, 42, 42)
                C.Dim = Color3.fromRGB(165, 165, 165)
                C.Faint = Color3.fromRGB(120, 120, 120)
                repaintMenu()
                for role, flag in pairs({ BG = "ThemeBG", Top = "ThemeTop", Side = "ThemeSide", Popup = "ThemePopup", Button = "ThemeButton", Text = "ThemeText", Line = "ThemeLine" }) do
                    local api = Menu.Registry[flag]
                    if api and C[role] then pcall(function() api.Set(C[role]) end) end
                end
            end
            return
        end
        local p = PRESET_THEMES[name]
        for k, v in pairs(p) do if C[k] ~= nil then C[k] = v end end
        repaintMenu()
        -- also push to the registered color controls (Keys below)
        for role, flag in pairs({ BG = "ThemeBG", Top = "ThemeTop", Side = "ThemeSide", Popup = "ThemePopup", Button = "ThemeButton", Text = "ThemeText", Line = "ThemeLine" }) do
            local api = Menu.Registry[flag]
            if api and C[role] then pcall(function() api.Set(C[role]) end) end
        end
    end
    Menu.ApplyTheme = Menu.ApplyThemePreset

    function Menu.GetConfigPayload()
        local payload = { flags = {}, toggles = {}, theme = {
            BG = { C.BG.R, C.BG.G, C.BG.B },
            Popup = { C.Popup.R, C.Popup.G, C.Popup.B },
            Button = { C.Button.R, C.Button.G, C.Button.B },
            Text = { C.Text.R, C.Text.G, C.Text.B },
            Line = { C.Line.R, C.Line.G, C.Line.B },
            Faint = { C.Faint.R, C.Faint.G, C.Faint.B },
            Dim = { C.Dim.R, C.Dim.G, C.Dim.B },
        }, watermark = nil, keybindList = nil }
        for k, v in pairs(Menu.Flags) do
            if typeof(v) == "Color3" then
                payload.flags[k] = { __color = true, c = { v.R, v.G, v.B } }
            elseif type(v) == "table" and v.Key ~= nil then
                local ok, nm = pcall(function() return v.Key and v.Key.Name end)
                payload.flags[k] = { __bind = true, key = ok and nm or "Unknown", mode = v.Mode }
            elseif type(v) == "table" and v[1] ~= nil then
                payload.flags[k] = v
            elseif type(v) == "table" and next(v) == nil then
                payload.flags[k] = {}
            elseif type(v) == "table" then
                -- dict-set from multi dropdown
                local out = {}
                for sk, sv in pairs(v) do if sv then out[#out + 1] = tostring(sk) end end
                payload.flags[k] = out
            else
                payload.flags[k] = v
            end
        end
        do
            local ok, v = pcall(function() return Menu.Flags.WatermarkEnabled end)
            if ok then payload.watermark = v else payload.watermark = true end
            ok, v = pcall(function() return Menu.Flags.KeybindListEnabled end)
            if ok then payload.keybindList = v end
        end
        return payload
    end
    function Menu.SaveConfig(name)
        local fn = Menu.ConfigFolder .. "/" .. tostring(name) .. ".json"
        local s = HttpService:JSONEncode(Menu.GetConfigPayload())
        pcall(function() writefile(fn, s) end)
        Menu.Notify({ Message = "Saved config '" .. tostring(name) .. "'", Delay = 2, Position = "TopRight" })
        if Menu._configsList then
            Menu._configsList:RemoveValue(tostring(name))
            Menu._configsList:AddValue(tostring(name))
        end
        return fn
    end
    function Menu.LoadConfig(name)
        local fn = Menu.ConfigFolder .. "/" .. tostring(name) .. ".json"
        local ok, raw = pcall(function() return readfile(fn) end)
        if not ok then Menu.Notify({ Message = "Config not found: " .. tostring(name), Delay = 2 }); return false end
        local ok2, payload = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok2 or type(payload) ~= "table" then Menu.Notify({ Message = "Bad config JSON", Delay = 2 }); return false end
        for k, v in pairs(payload.flags or {}) do
            -- RootFolder is handled below (after all other flags) so lists can refresh
            if k == "RootFolder" then continue end
            local mapped = v
            if type(v) == "table" and v.__color then
                mapped = Color3.new(math.clamp(v.c[1], 0, 1), math.clamp(v.c[2], 0, 1), math.clamp(v.c[3], 0, 1))
            elseif type(v) == "table" and v.__bind then
                local ek = v.key
                local parsed = nil
                pcall(function()
                    if Enum.KeyCode[ek] then parsed = Enum.KeyCode[ek]
                    elseif Enum.UserInputType[ek] then parsed = Enum.UserInputType[ek] end
                end)
                mapped = { Key = parsed or Enum.KeyCode.Unknown, Mode = v.mode or "Hold key", Active = false }
            end
            -- prefer registry to fire the UI callbacks (esp colors)
            local api = Menu.Registry[k]
            if api and api.Set then
                local s2, err = pcall(function() api.Set(mapped) end)
                if not s2 then warn("[plain-menu] skip flag " .. k .. ": " .. tostring(err)) end
            else
                Menu.Flags[k] = mapped
            end
        end
        if payload.theme then
            for role, tbl in pairs(payload.theme) do
                local col = tableToColor(tbl)
                if col and C[role] ~= nil then C[role] = col end
            end
            Menu.ApplyThemeColors()
            for role, flag in pairs({ BG = "ThemeBG", Popup = "ThemePopup", Button = "ThemeButton", Text = "ThemeText", Line = "ThemeLine" }) do
                local api = Menu.Registry[flag]
                if api and C[role] then pcall(function() api.Set(C[role]) end) end
            end
        end
        if payload.watermark ~= nil then
            local api = Menu.Registry.WatermarkEnabled
            if api then api.Set(payload.watermark and true or false) end
        end
        if payload.keybindList ~= nil then
            local api = Menu.Registry.KeybindListEnabled
            if api then api.Set(payload.keybindList and true or false) end
        end
        -- restore root folder last so config/addon lists point at the right place
        local rf = payload.flags and payload.flags.RootFolder
        if type(rf) == "string" and rf ~= "" then
            pcall(function() Menu.setRoot(rf) end)
            local api = Menu.Registry.RootFolder
            if api then pcall(function() api.Set(rf) end) end
        end
        Menu.RefreshBinds()
        Menu.Notify({ Message = "Loaded config '" .. tostring(name) .. "'", Delay = 2, Position = "TopRight" })
        return true
    end
    function Menu.UpdateConfigList(List)
        if not List then return end
        List:Clear()
        local ok, files = pcall(function() return listfiles(Menu.ConfigFolder) end)
        if not ok or type(files) ~= "table" then return end
        for _, f in ipairs(files) do
            local nm = tostring(f):gsub("\\", "/"):match(".*/([^/]+)%.json$") or tostring(f):match("([^/\\]+)%.json$")
            if nm then List:AddValue(nm) end
        end
    end
    function Menu.UpdateThemeList(List)
        if not List then return end
        List:Clear()
        for n in pairs(PRESET_THEMES) do List:AddValue(n) end
    end
end

-- ============================================================
-- EXAMPLE USAGE (commented - uncomment to test)
-- ============================================================
-- local visualsTab = Menu.CreateTab("visuals")
-- local gunsTab = Menu.CreateTab("guns")
-- do
--     local left = visualsTab.CreateColumn(1)
--     local sec = visualsTab.CreateSection(left, "visuals")
--     sec.AddToggle({ Name = "enable esp", Flag = "ESPEnabled", Default = false })
--     sec.AddColorPicker({ Name = "esp color", Flag = "ESPColor", Default = Color3.fromRGB(175,175,175) })
-- end
-- do
--     local left = gunsTab.CreateColumn(1)
--     local right = gunsTab.CreateColumn(2)
--     local sec = gunsTab.CreateSection(left, "settings")
--     sec.AddDropdown({ Name = "gun to mod", Flag = "GunToMod", Options = {"gun name","xm177","m4a1"}, Default = "gun name" })
-- end

-- built-in tab (single default page, lower caps) - keep for library, remove if you want blank slate
local settingsTab = Menu.CreateTab("settings")

-- --- settings: single default page (all lower caps) --- --
do
    -- two columns carry: interface + configs + themes + addons + colors
    local left = settingsTab.CreateColumn(1)
    local right = settingsTab.CreateColumn(2)
    -- keep refs so the addon loader (next block) reuses same columns instead of creating overlapping ones
    Menu._settingsLeft = left
    Menu._settingsRight = right

    -- interface + rebind menu
    local iface = settingsTab.CreateSection(left, "interface")
    do
        if Menu.Flags.WatermarkEnabled == nil then Menu.Flags.WatermarkEnabled = true end
        if Menu.Flags.KeybindListEnabled == nil then Menu.Flags.KeybindListEnabled = true end
        wm.Visible = Menu.Flags.WatermarkEnabled
        bindGui.Visible = Menu.Flags.KeybindListEnabled
        iface.AddToggle({
            Name = "watermark", Flag = "WatermarkEnabled", Default = true, Callback = function(v)
                wm.Visible = v
            end
        })
        iface.AddToggle({
            Name = "keybinds list", Flag = "KeybindListEnabled", Default = true, Callback = function(v)
                bindGui.Visible = v
                Menu.RefreshBinds()
            end
        })
        -- rebind menu: updates top bar text to "press <key> to hide this menu"
        iface.AddKeybind({
            Name = "menu bind", Flag = "MenuBind", DefaultKey = Menu.HideKey, Mode = "toggle",
            Callback = function()
                local k = Menu.Flags.MenuBind
                local key
                if typeof(k) == "EnumItem" then key = k
                elseif type(k) == "table" and k.Key then key = k.Key
                end
                if key then
                    -- persist simple Enum for GetConfigPayload + hide handler
                    Menu.Flags.MenuHideKey = key
                    updateTopText(key)
                end
            end
        })
        -- also watch flag directly for loadstring restores
        do
            local last = Menu.HideKey
            task.spawn(function()
                while settingsTab.Page.Parent do
                    local fk = Menu.Flags.MenuBind or Menu.Flags.MenuHideKey
                    local cur
                    if typeof(fk) == "EnumItem" then cur = fk
                    elseif type(fk) == "table" and fk.Key then cur = fk.Key end
                    if cur and cur ~= last then last = cur updateTopText(cur) Menu.Flags.MenuHideKey = cur end
                    task.wait(0.2)
                end
            end)
        end
    end

    -- configs (separate list)
    local cfgNameFlag = "ConfigName"
    Menu.Flags[cfgNameFlag] = Menu.Flags[cfgNameFlag] or "default"
    local cfgList
    do
        local sec = settingsTab.CreateSection(left, "configs")
        cfgList = sec.AddList({
            Name = "saved configs", Flag = "ConfigList", Height = 140, Values = {},
            Callback = function(name)
                local api = Menu.Registry[cfgNameFlag]
                if api then api.Set(name) end
            end
        })
        Menu._configsList = cfgList
        pcall(function() Menu.UpdateConfigList(cfgList) end)
        sec.AddTextbox({
            Name = "config name", Flag = cfgNameFlag, Default = "default", Placeholder = "name...",
            Callback = function(v) Menu.Flags[cfgNameFlag] = v end
        })
        sec.AddButton({ Name = "create", Text = "create", Callback = function()
            local name = tostring(Menu.Flags[cfgNameFlag] or "default")
            name = name:match("^%s*(.-)%s*$")
            if name == "" then return Menu.Notify({ Message = "enter a config name", Delay = 2 }) end
            local fn = Menu.ConfigFolder .. "/" .. name .. ".json"
            local exists = false
            pcall(function() exists = isfile(fn) end)
            if exists then return Menu.Notify({ Message = "'" .. name .. "' already exists (use save)", Delay = 2 }) end
            Menu.SaveConfig(name)
            Menu.Notify({ Message = "created '" .. name .. "'", Delay = 2, Position = "topright" })
        end })
        sec.AddButton({ Name = "save", Text = "save", Callback = function()
            local name = tostring(Menu.Flags[cfgNameFlag] or "default")
            name = name:match("^%s*(.-)%s*$")
            if name == "" then return Menu.Notify({ Message = "enter a config name", Delay = 2 }) end
            Menu.SaveConfig(name)
            local fn = Menu.ConfigFolder .. "/" .. name .. ".json"
            local exists = false
            pcall(function() exists = isfile(fn) end)
            if exists then Menu.Notify({ Message = "saved '" .. name .. "'", Delay = 2, Position = "topright" }) end
        end })
        sec.AddButton({ Name = "load", Text = "load", Callback = function()
            local name = tostring(Menu.Flags[cfgNameFlag] or "")
            name = name:match("^%s*(.-)%s*$")
            if name == "" then
                local cur = cfgList:Get()
                if cur then name = cur else return Menu.Notify({ Message = "pick a config first", Delay = 2 }) end
            end
            Menu.LoadConfig(name)
        end })
        sec.AddButton({ Name = "delete", Text = "delete", Callback = function()
            local name = cfgList:Get() or tostring(Menu.Flags[cfgNameFlag] or "")
            name = tostring(name):match("^%s*(.-)%s*$")
            if name == "" then return Menu.Notify({ Message = "pick a config to delete", Delay = 2 }) end
            local fn = Menu.ConfigFolder .. "/" .. name .. ".json"
            pcall(function() delfile(fn) end)
            cfgList:RemoveValue(name)
            Menu.Notify({ Message = "deleted '" .. name .. "'", Delay = 2 })
        end })
        sec.AddButton({ Name = "refresh", Text = "refresh", Callback = function()
            Menu.UpdateConfigList(cfgList)
            Menu.Notify({ Message = "refreshed", Delay = 1.5 })
        end })
    end

    -- themes: separate list for theme saving (presets + custom saves)
    local themeNameFlag = "ThemeName"
    Menu.Flags[themeNameFlag] = Menu.Flags[themeNameFlag] or "default"
    local themeList
    do
        local sec = settingsTab.CreateSection(left, "themes")
        themeList = sec.AddList({
            Name = "saved themes", Flag = "ThemeSaveList", Height = 110, Values = {},
            Callback = function(name)
                local api = Menu.Registry[themeNameFlag]
                if api then api.Set(name) end
            end
        })
        Menu._themesSaveList = themeList
        pcall(function() Menu.UpdateConfigList(themeList) end)
        sec.AddTextbox({
            Name = "theme name", Flag = themeNameFlag, Default = "default", Placeholder = "name...",
            Callback = function(v) Menu.Flags[themeNameFlag] = v end
        })
        sec.AddButton({ Name = "save theme", Text = "save theme", Callback = function()
            local name = tostring(Menu.Flags[themeNameFlag] or "default")
            name = name:match("^%s*(.-)%s*$")
            if name == "" then return Menu.Notify({ Message = "enter a theme name", Delay = 2 }) end
            -- theme save is just a config with same payload; reuse SaveConfig
            Menu.SaveConfig(name .. "_theme")
            Menu.UpdateConfigList(themeList)
            Menu.Notify({ Message = "saved theme '" .. name .. "'", Delay = 2 })
        end })
        sec.AddButton({ Name = "load theme", Text = "load theme", Callback = function()
            local name = tostring(Menu.Flags[themeNameFlag] or "")
            name = name:match("^%s*(.-)%s*$")
            if name == "" then
                local cur = themeList:Get()
                if cur then name = cur else return Menu.Notify({ Message = "pick a theme first", Delay = 2 }) end
            end
            if not name:match("_theme$") then name = name .. "_theme" end
            Menu.LoadConfig(name)
        end })
        sec.AddButton({ Name = "refresh", Text = "refresh", Callback = function()
            Menu.UpdateConfigList(themeList)
            Menu.Notify({ Message = "refreshed", Delay = 1.5 })
        end })
        -- presets also live here (quick preset picker)
        local presetList = sec.AddList({
            Name = "presets", Flag = "ThemePresetList", Height = 70,
            Values = { "dark", "midnight", "onyx", "slate", "carbon" },
            Callback = function(name) Menu.ApplyThemePreset(name) Menu.Notify({ Message = "theme: " .. tostring(name), Delay = 2 }) end
        })
        Menu._themesList = presetList
        sec.AddDropdown({
            Name = "apply preset", Flag = "ThemePresetDropdown",
            Options = { "dark", "midnight", "onyx", "slate", "carbon" }, Default = "dark",
            Callback = function(name) Menu.ApplyThemePreset(name) end
        })
    end

    -- menu colors (right column)
    local colors = settingsTab.CreateSection(right, "menu colors")
    do
        local function bindColor(role, flag, def)
            colors.AddColorPicker({
                Name = string.lower(role), Flag = flag, Default = def, Callback = function(col)
                    C[role] = col
                    repaintMenu()
                end
            })
        end
        bindColor("BG", "ThemeBG", C.BG)
        bindColor("Top", "ThemeTop", C.Top)
        bindColor("Side", "ThemeSide", C.Side)
        bindColor("Popup", "ThemePopup", C.Popup)
        bindColor("Button", "ThemeButton", C.Button)
        bindColor("Text", "ThemeText", C.Text)
        bindColor("Line", "ThemeLine", C.Line)
        bindColor("Faint", "ThemeFaint", C.Faint)
        bindColor("Dim", "ThemeDim", C.Dim)
    end
end

-- --- lua: file loader (juju / skeet pattern, no code box, now merged into settings) --- --
do
    local addonData = {} -- name -> { thread, addonsRef, conns, onUnload }
    if getgenv then getgenv().plainMenuAddons = addonData end
    if Menu.Flags.loaded_addons == nil then Menu.Flags.loaded_addons = {} end

    local function getAddonList()
        local folder = Menu.AddonFolder or (Menu.RootFolder .. "/lua")
        local out = {}
        local ok, files = pcall(function() return listfiles(folder) end)
        if ok and type(files) == "table" then
            for _, f in ipairs(files) do
                local s = tostring(f):gsub("\\", "/")
                local name = s:match(".*/([^/]+)%.lua$") or s:match(".*/([^/]+)%.luau$") or s:match("([^/\\]+)%.lua$") or s:match("([^/\\]+)%.luau$")
                if name then out[#out+1] = name end
            end
        end
        table.sort(out)
        return out
    end
    Menu.get_addon_list = getAddonList

    function Menu.unload_addon(name)
        local data = addonData[name]
        if not data then return end
        local thread, _, conns, onUnload = data[1], data[2], data[3], data[4]
        if onUnload then pcall(onUnload) end
        if data[2] and data[2].destroy then pcall(function() data[2].destroy(data[2]) end) end
        for _, c in ipairs(conns or {}) do pcall(function() c:Disconnect() end) end
        local loaded = Menu.Flags.loaded_addons
        for i = #loaded, 1, -1 do if loaded[i] == name then table.remove(loaded, i) end end
        pcall(function() coroutine.close(thread) end)
        pcall(function() task.cancel(thread) end)
        addonData[name] = nil
    end

    function Menu.load_addon(name)
        local folder = Menu.AddonFolder or (Menu.RootFolder .. "/lua")
        local pathLua = folder .. "/" .. name .. ".lua"
        local pathLuau = folder .. "/" .. name .. ".luau"
        local path = nil
        local ok = pcall(function() return isfile(pathLua) end)
        if ok and isfile(pathLua) then path = pathLua
        else
            local ok2 = pcall(function() return isfile(pathLuau) end)
            if ok2 and isfile(pathLuau) then path = pathLuau end
        end
        if not path then return "file does not exist: " .. name end
        local okR, data = pcall(function() return readfile(path) end)
        if not okR then return "readfile failed: " .. tostring(data) end
        local okC, chunk = pcall(function() return loadstring(data) end)
        if not okC then return "compile error: " .. tostring(chunk) end
        if type(chunk) ~= "function" then return "loadstring did not return function" end
        if addonData[name] then Menu.unload_addon(name) end
        local id = name
        local env = getfenv(chunk)
        if env then env.__IDENTIFIER = id end
        local thread = coroutine.create(chunk)
        addonData[name] = { thread, {}, {}, function() end, name }
        -- flag updated only on success so config persistence matches juju
        local loaded = Menu.Flags.loaded_addons
        loaded[#loaded+1] = name
        local s, err = pcall(function()
            -- run with Menu/Flags globals available like juju does
            local prev = getgenv and getgenv().Menu
            if getgenv then getgenv().Menu = Menu end
            local res = coroutine.resume(thread)
            if not res then error(debug.traceback(thread)) end
            if coroutine.status(thread) ~= "dead" then
                -- keep thread ref so unload can close it
            end
        end)
        if not s then
            Menu.unload_addon(name)
            return "runtime: " .. tostring(err)
        end
        return nil
    end

    local left = Menu._settingsLeft
    local right = Menu._settingsRight

    local addonList
    do
        local sec = settingsTab.CreateSection(right, "addons")
        addonList = sec.AddList({ Name = "addon list", Flag = "_plainAddonList", Height = 140, Values = getAddonList() })
        Menu._addonList = addonList
        sec.AddButton({ Name = "refresh", Text = "refresh", Callback = function()
            local cur = addonList:Get()
            addonList:SetValues(getAddonList())
            if cur then
                for _, n in ipairs(getAddonList()) do if n == cur then addonList:Set(cur) break end end
            end
            Menu.Notify({ Message = "addons refreshed", Delay = 1.5 })
        end })
    end
    do
        local sec = settingsTab.CreateSection(right, "controls")
        sec.AddButton({ Name = "load", Text = "load", Callback = function()
            local name = addonList:Get()
            if not name then return Menu.Notify({ Message = "select an addon first", Delay = 2 }) end
            local err = Menu.load_addon(name)
            if err then Menu.Notify({ Message = "load failed: " .. tostring(err):sub(1, 240), Delay = 4 })
            else Menu.Notify({ Message = "loaded " .. name, Delay = 2 }) end
        end })
        sec.AddButton({ Name = "unload", Text = "unload", Callback = function()
            local name = addonList:Get()
            if not name then return Menu.Notify({ Message = "select an addon first", Delay = 2 }) end
            if not addonData[name] then return Menu.Notify({ Message = name .. " not running", Delay = 2 }) end
            Menu.unload_addon(name)
            Menu.Notify({ Message = "unloaded " .. name, Delay = 2 })
        end })
        sec.AddButton({ Name = "unload all", Text = "unload all", Callback = function()
            local n = 0
            for k in pairs(addonData) do Menu.unload_addon(k) n = n + 1 end
            addonList:SetValues(getAddonList())
            Menu.Notify({ Message = "unloaded " .. tostring(n) .. " addon(s)", Delay = 2 })
        end })
    end
end

selectTab("settings")
Menu.RefreshBinds()
Menu.Notify({ Message = "plain-menu loaded - " .. keyDisplayLower(Menu.HideKey) .. " to hide", Delay = 3 })

return Menu
