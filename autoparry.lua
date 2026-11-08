-- Beyond Nen Auto Parry (Matcha) with Valentine UI
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/dare67320-sudo/beyondnenautoparry/main/autoparry.lua"))()
-- RightShift opens/closes the menu.

_G.BN_HEADLESS = true
do -- parry engine
-- Auto Parry + UI for Beyond Nen (Matcha)
-- RightShift = show/hide UI. Arrow keys + Enter also drive the UI.
-- Stop: _G.AutoParryUnload()  (or click "Unload")

if _G.AutoParryUnload then pcall(_G.AutoParryUnload) end

-- When a hub menu drives this script, skip the built-in menu.
local HEADLESS = _G.BN_HEADLESS == true
local Drawing = Drawing
if HEADLESS then
    local dummy = { __index = function() return function() end end }
    Drawing = { new = function() return setmetatable({}, dummy) end }
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ws = game:GetService("Workspace")
local lp = Players.LocalPlayer
local mouse = lp:GetMouse()
local humFolder = ws:FindFirstChild("Humanoids")
local npcFolder = ws:FindFirstChild("RoamingNpcs")

-- If mouse clicks land above/below the buttons, set this to 36 or 58
local MOUSE_OFFSET_Y = 0

local cfg = {
    enabled = true,
    players = true,
    npcs = true,
    facing = true,
    range = 14,   -- studs
    delay = 50,   -- ms between seeing the swing and pressing
    hold = 60,    -- ms the key is held
    keyName = "F",
    vk = 0x46,    -- Windows virtual key for F
}

local running = true
local conns = {}
local drawings = {}
local status = "Waiting..."
local parryCount = 0
local needLayout = true

local KC = {
    RightShift = Enum.KeyCode.RightShift.Value,
    Up = Enum.KeyCode.Up.Value,
    Down = Enum.KeyCode.Down.Value,
    Left = Enum.KeyCode.Left.Value,
    Right = Enum.KeyCode.Right.Value,
    Return = Enum.KeyCode.Return.Value,
    Escape = Enum.KeyCode.Escape.Value,
}

-- Roblox KeyCode value -> display name, Windows VK
local function mapKey(code)
    if code >= 97 and code <= 122 then return string.char(code - 32), code - 32 end
    if code >= 48 and code <= 57 then return string.char(code), code end
    return nil
end

---------------------------------------------------------------- UI
local C = {
    bg = Color3.fromRGB(20, 20, 26),
    bar = Color3.fromRGB(34, 34, 44),
    sel = Color3.fromRGB(40, 40, 52),
    accent = Color3.fromRGB(110, 165, 255),
    off = Color3.fromRGB(70, 70, 82),
    text = Color3.fromRGB(232, 232, 238),
    dim = Color3.fromRGB(150, 150, 162),
    red = Color3.fromRGB(220, 85, 85),
}
local W, TITLE, ROW = 250, 28, 26
local wx, wy = 80, 220
local visible = true
local sel = 1
local rebinding = false

local function D(kind, props)
    local d = Drawing.new(kind)
    for k, v in pairs(props) do d[k] = v end
    d.Visible = false
    drawings[#drawings + 1] = d
    return d
end
local function T(size, color, z)
    return D("Text", { Size = size, Color = color, Font = 0, Outline = false, Center = false, ZIndex = z or 4 })
end
local function S(color, z)
    return D("Square", { Filled = true, Color = color, Thickness = 1, ZIndex = z or 3 })
end

local bg = S(C.bg, 1)
local bar = S(C.bar, 2)
local selBox = S(C.sel, 2)
local title = T(15, C.text); title.Text = "Auto Parry"; title.Font = 2
local hint = T(12, C.dim); hint.Text = "RShift: hide"

local items = {}
local function addToggle(label, key)
    items[#items + 1] = { t = "toggle", label = label, key = key, box = S(C.off), lbl = T(13, C.text) }
    items[#items].lbl.Text = label
end
local function addSlider(label, key, min, max, step, unit)
    items[#items + 1] = { t = "slider", label = label, key = key, min = min, max = max, step = step, unit = unit,
        lbl = T(13, C.text), track = S(C.off), fill = S(C.accent, 4) }
end

addToggle("Enabled", "enabled")
addToggle("Parry players", "players")
addToggle("Parry NPCs", "npcs")
addToggle("Only if facing me", "facing")
addSlider("Range", "range", 4, 30, 1, " studs")
addSlider("Delay", "delay", 0, 400, 10, " ms")
addSlider("Hold", "hold", 30, 300, 10, " ms")
items[#items + 1] = { t = "key", lbl = T(13, C.text) }
items[#items + 1] = { t = "status", lbl = T(12, C.dim) }
items[#items + 1] = { t = "button", box = S(C.red), lbl = T(13, C.text) }

local function layout()
    local h = TITLE + #items * ROW + 8
    bg.Position = Vector2.new(wx, wy); bg.Size = Vector2.new(W, h)
    bar.Position = Vector2.new(wx, wy); bar.Size = Vector2.new(W, TITLE)
    title.Position = Vector2.new(wx + 10, wy + 6)
    hint.Position = Vector2.new(wx + W - 80, wy + 8)
    title.Color = cfg.enabled and C.accent or C.text

    for i, it in ipairs(items) do
        local y = wy + TITLE + (i - 1) * ROW + 4
        it.y = y
        if it.t == "toggle" then
            it.box.Position = Vector2.new(wx + 10, y + 5); it.box.Size = Vector2.new(14, 14)
            it.box.Color = cfg[it.key] and C.accent or C.off
            it.lbl.Position = Vector2.new(wx + 32, y + 5)
        elseif it.t == "slider" then
            local v = cfg[it.key]
            it.lbl.Text = it.label .. ": " .. tostring(v) .. it.unit
            it.lbl.Position = Vector2.new(wx + 10, y + 1)
            it.tx, it.tw = wx + 10, W - 20
            it.track.Position = Vector2.new(it.tx, y + 18); it.track.Size = Vector2.new(it.tw, 4)
            local f = (v - it.min) / (it.max - it.min)
            it.fill.Position = Vector2.new(it.tx, y + 18); it.fill.Size = Vector2.new(math.max(1, it.tw * f), 4)
        elseif it.t == "key" then
            it.lbl.Text = rebinding and "Parry key: press a key... (Esc cancels)" or ("Parry key: [" .. cfg.keyName .. "]  (click to change)")
            it.lbl.Color = rebinding and C.accent or C.text
            it.lbl.Position = Vector2.new(wx + 10, y + 5)
        elseif it.t == "status" then
            it.lbl.Text = status .. "   | parries: " .. parryCount
            it.lbl.Position = Vector2.new(wx + 10, y + 6)
        elseif it.t == "button" then
            it.box.Position = Vector2.new(wx + 10, y + 2); it.box.Size = Vector2.new(W - 20, ROW - 4)
            it.lbl.Text = "Unload"
            it.lbl.Position = Vector2.new(wx + W / 2 - 20, y + 6)
        end
    end

    local si = items[sel]
    selBox.Position = Vector2.new(wx + 2, si.y); selBox.Size = Vector2.new(W - 4, ROW)

    for _, d in ipairs(drawings) do d.Visible = visible end
end

local unload

local function adjust(it, dir)
    if it.t == "toggle" then
        cfg[it.key] = not cfg[it.key]
    elseif it.t == "slider" then
        cfg[it.key] = math.clamp(cfg[it.key] + dir * it.step, it.min, it.max)
    end
end

local function activate(it)
    if it.t == "toggle" then adjust(it, 1)
    elseif it.t == "key" then rebinding = true
    elseif it.t == "button" then task.spawn(unload)
    end
end

local function setSliderFromMouse(it, mx)
    local f = math.clamp((mx - it.tx) / it.tw, 0, 1)
    local raw = it.min + f * (it.max - it.min)
    local v = math.clamp(it.min + math.floor((raw - it.min) / it.step + 0.5) * it.step, it.min, it.max)
    if v ~= cfg[it.key] then cfg[it.key] = v; return true end
    return false
end

local function inside(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

-- mouse: click, drag window, drag sliders
local wasDown, dragging, dragDX, dragDY, activeSlider = false, false, 0, 0, nil
conns[#conns + 1] = RunService.RenderStepped:Connect(function()
    if HEADLESS then return end
    if visible then
        local mx, my = mouse.X, mouse.Y + MOUSE_OFFSET_Y
        local down = ismouse1pressed()
        if down and not wasDown then
            if inside(mx, my, wx, wy, W, TITLE) then
                dragging, dragDX, dragDY = true, mx - wx, my - wy
            else
                for i, it in ipairs(items) do
                    if it.y and inside(mx, my, wx, it.y, W, ROW) then
                        sel = i
                        if it.t == "slider" then
                            activeSlider = it
                            setSliderFromMouse(it, mx)
                        else
                            activate(it)
                        end
                        needLayout = true
                        break
                    end
                end
            end
        end
        if not down then dragging = false; activeSlider = nil end
        if dragging then
            local nx, ny = mx - dragDX, my - dragDY
            if nx ~= wx or ny ~= wy then wx, wy = nx, ny; needLayout = true end
        end
        if activeSlider and setSliderFromMouse(activeSlider, mx) then needLayout = true end
        wasDown = down
    end
    if needLayout and running then needLayout = false; layout() end
end)

-- keyboard: RightShift hide, arrows navigate, Enter activate, rebinding
conns[#conns + 1] = UIS.InputBegan:Connect(function(input)
    if HEADLESS then return end
    local k = input.KeyCode
    if rebinding then
        if k == KC.Escape then
            rebinding = false
        else
            local name, vk = mapKey(k)
            if name then cfg.keyName, cfg.vk = name, vk; rebinding = false end
        end
        needLayout = true
        return
    end
    if k == KC.RightShift then visible = not visible; needLayout = true; return end
    if not visible then return end
    if k == KC.Up then sel = sel > 1 and sel - 1 or #items
    elseif k == KC.Down then sel = sel < #items and sel + 1 or 1
    elseif k == KC.Left then adjust(items[sel], -1)
    elseif k == KC.Right then adjust(items[sel], 1)
    elseif k == KC.Return then activate(items[sel])
    else return end
    needLayout = true
end)

---------------------------------------------------------------- detection
-- Players: "LastM1" attribute changes on every swing.
-- NPCs:    "NpcSwingEndsAt" attribute changes on every swing.
local NONE = {}
local targets = {}
local lastSeen = {}
local myModel, myRoot = nil, nil
local nextAllowed = 0

-- collector: 4 Hz, does the expensive lookups
task.spawn(function()
    local prevSet = {}
    while running do
        local char = humFolder and humFolder:FindFirstChild(lp.Name)
        local root = char and char:FindFirstChild("HumanoidRootPart")
        myModel, myRoot = char, root
        local out, set = {}, {}
        if root then
            local myPos = root.Position
            local scan = cfg.range + 20
            local function consider(m, kind, attr)
                local r = m:FindFirstChild("HumanoidRootPart")
                if r and (r.Position - myPos).Magnitude <= scan then
                    local key = m.Address
                    set[key] = true
                    if not prevSet[key] then
                        -- just came into range: remember current value, don't fire
                        lastSeen[key] = m:GetAttribute(attr) or NONE
                    end
                    out[#out + 1] = { key = key, model = m, root = r, kind = kind, attr = attr, name = m.Name }
                end
            end
            if cfg.players and humFolder then
                for _, m in ipairs(humFolder:GetChildren()) do
                    if m.Name ~= lp.Name then consider(m, "player", "LastM1") end
                end
            end
            if cfg.npcs then
                for _, folder in ipairs({ ws, npcFolder }) do
                    if folder then
                        for _, m in ipairs(folder:GetChildren()) do
                            if m.ClassName == "Model" and m:GetAttribute("NPC") ~= nil then
                                consider(m, "npc", "NpcSwingEndsAt")
                            end
                        end
                    end
                end
            end
        end
        prevSet = set
        targets = out
        task.wait(0.25)
    end
end)

local function tryParry(t)
    local root, me = myRoot, myModel
    if not root or not me then return end
    local now = os.clock()
    if now < nextAllowed then return end
    if not isrbxactive() then return end          -- never press keys while tabbed out
    if iskeypressed(cfg.vk) then return end       -- you're already holding block
    if me:GetAttribute("ParryOnCooldown") == true then return end

    local diff = root.Position - t.root.Position
    local flat = Vector3.new(diff.X, 0, diff.Z)
    local dist = flat.Magnitude
    if dist > cfg.range then return end
    if cfg.facing and dist > 1 then
        local look = t.root.CFrame.LookVector
        local lookFlat = Vector3.new(look.X, 0, look.Z)
        if lookFlat.Magnitude > 0 and lookFlat.Unit:Dot(flat.Unit) < 0.35 then return end
    end

    nextAllowed = now + (cfg.delay + cfg.hold) / 1000 + 0.15
    parryCount = parryCount + 1
    status = string.format("%s (%.1f)", t.name, dist)
    needLayout = true

    local vk, delay, hold = cfg.vk, cfg.delay, cfg.hold
    task.spawn(function()
        if delay > 0 then task.wait(delay / 1000) end
        keypress(vk)
        task.wait(hold / 1000)
        keyrelease(vk)
    end)
end

-- watcher: every frame, only reads attributes of the few targets in range
conns[#conns + 1] = RunService.Heartbeat:Connect(function()
    if not cfg.enabled then return end
    local list = targets
    for i = 1, #list do
        local t = list[i]
        local v = t.model:GetAttribute(t.attr) or NONE
        if v ~= lastSeen[t.key] then
            lastSeen[t.key] = v
            if v ~= NONE then tryParry(t) end
        end
    end
end)

---------------------------------------------------------------- unload
unload = function()
    running = false
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    for _, d in ipairs(drawings) do pcall(function() d:Remove() end) end
    drawings = {}
    _G.AutoParryUnload = nil
    print("[AutoParry] unloaded")
end
_G.AutoParryUnload = unload
_G.AutoParryCfg = cfg
_G.AutoParryStats = function() return status, parryCount end

layout()
notify("Auto Parry", "Loaded. RightShift toggles the menu.", 4)
print("[AutoParry] loaded")

end

---------------------------------------------------------------- menu (Valentine UI)
local P = _G.AutoParryCfg
pcall(function() if _G.BN_Window then _G.BN_Window:Unload() end end)

local UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/dare67320-sudo/uilib/main/ui.lua"))() or _G.Valentine

-- the UI uses Roblox KeyCode numbers, the parry presses Windows key codes
local KC2VK = {
    [8] = 0x08, [9] = 0x09, [13] = 0x0D, [32] = 0x20, [127] = 0x2E,
    [273] = 0x26, [274] = 0x28, [275] = 0x27, [276] = 0x25, [277] = 0x2D, [278] = 0x24,
    [279] = 0x23, [280] = 0x21, [281] = 0x22, [301] = 0x14, [303] = 0xA1, [304] = 0xA0,
    [305] = 0xA3, [306] = 0xA2, [307] = 0xA5, [308] = 0xA4,
    [44] = 0xBC, [45] = 0xBD, [46] = 0xBE, [47] = 0xBF, [59] = 0xBA, [61] = 0xBB,
    [39] = 0xDE, [91] = 0xDB, [92] = 0xDC, [93] = 0xDD, [96] = 0xC0,
}
for i = 97, 122 do KC2VK[i] = i - 32 end
for i = 48, 57 do KC2VK[i] = i end
for i = 1, 12 do KC2VK[281 + i] = 0x6F + i end
local function kcOfVK(vk) for kc, v in pairs(KC2VK) do if v == vk then return kc end end return 102 end

local win = UI:Window({})
_G.BN_Window = win
local tab = win:Tab("Auto Parry", "Combat")

local main = tab:Section("Auto Parry", "Left")
local statusLbl = main:Label("Parries: 0")
local lastLbl = main:Label("Last: waiting...")
main:Toggle({ Name = "Enabled", Default = P.enabled, Callback = function(v) P.enabled = v end })
main:Toggle({ Name = "Parry players", Default = P.players, Callback = function(v) P.players = v end })
main:Toggle({ Name = "Parry NPCs", Default = P.npcs, Callback = function(v) P.npcs = v end })
main:Toggle({ Name = "Only if facing me", Default = P.facing, Callback = function(v) P.facing = v end })

local timing = tab:Section("Timing", "Right")
timing:Slider({ Name = "Range", Min = 4, Max = 30, Default = P.range, Decimals = 0, Suffix = " studs",
    Callback = function(v) P.range = v end })
timing:Slider({ Name = "Delay", Min = 0, Max = 400, Default = P.delay, Decimals = 0, Suffix = " ms",
    Callback = function(v) P.delay = v end })
timing:Slider({ Name = "Hold", Min = 30, Max = 300, Default = P.hold, Decimals = 0, Suffix = " ms",
    Callback = function(v) P.hold = v end })
timing:Keybind({ Name = "Parry key", Default = kcOfVK(P.vk),
    Changed = function(kc)
        local vk = kc and KC2VK[kc]
        if vk then P.vk = vk; P.keyName = tostring(kc) end
    end })

-- Unload lives in the built-in Interface tab
-- add to the existing "Interface" section (under Reset scale)
local unloadSec
pcall(function()
    for _, s in ipairs(win.settingsTab._default.cols.Left) do
        if s.name == "Interface" then unloadSec = s break end
    end
end)
unloadSec = unloadSec or (win.settingsTab or tab):Section("Interface", "Left")
unloadSec:Button({ Name = "Unload", Callback = function()
    pcall(_G.AutoParryUnload)
    pcall(function() win:Unload() end)
end })

task.spawn(function()
    while win.running ~= false and _G.AutoParryStats do
        pcall(function()
            local ps, pc = _G.AutoParryStats()
            statusLbl:Set("Parries: " .. tostring(pc))
            lastLbl:Set("Last: " .. tostring(ps))
        end)
        task.wait(0.5)
    end
end)

print("[BeyondNen] auto parry loaded (RightShift for the menu)")
