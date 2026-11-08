-- Beyond Nen: Auto Parry with a JDUI menu (Matcha)
-- Run: loadstring(readfile("beyondnen.lua"))()
-- RightShift opens/closes the menu.

_G.BN_HEADLESS = true
loadstring(readfile("autoparry.lua"))()

local P = _G.AutoParryCfg
local ui = loadstring(game:HttpGet("https://raw.githubusercontent.com/jdev-studio/jdui/refs/heads/main/JDUI"))() or _G.JDUI

local tab = ui:AddTab({ Title = "Auto Parry", Icon = "script", Columns = 2 })

local main = tab:AddIsland({ Title = "Auto Parry", Description = "Blocks when something swings at you", Column = 1 })
local statusLbl = main:AddLabel({ Title = "Parries: 0", Description = "Waiting..." })
main:AddToggle({ Title = "Enabled", Default = P.enabled, Callback = function(v) P.enabled = v end })
main:AddToggle({ Title = "Parry players", Default = P.players, Callback = function(v) P.players = v end })
main:AddToggle({ Title = "Parry NPCs", Default = P.npcs, Callback = function(v) P.npcs = v end })
main:AddToggle({ Title = "Only if facing me", Default = P.facing, Callback = function(v) P.facing = v end })

local timing = tab:AddIsland({ Title = "Timing", Column = 2 })
timing:AddSlider({ Title = "Range", Min = 4, Max = 30, Step = 1, Default = P.range, Suffix = " studs",
    Callback = function(v) P.range = v end })
timing:AddSlider({ Title = "Delay", Description = "Raise if you parry too early",
    Min = 0, Max = 400, Step = 10, Default = P.delay, Suffix = " ms", Callback = function(v) P.delay = v end })
timing:AddSlider({ Title = "Hold", Min = 30, Max = 300, Step = 10, Default = P.hold, Suffix = " ms",
    Callback = function(v) P.hold = v end })
timing:AddKeybind({
    Title = "Parry key", Description = "Your block key in game",
    Default = P.vk,
    Callback = function(vk) if vk then P.vk = vk; P.keyName = tostring(vk) end end,
})

main:AddButton({
    Title = "Unload", Description = "Stops auto parry and closes this menu",
    ButtonText = "Unload",
    Callback = function()
        pcall(_G.AutoParryUnload)
        pcall(function() ui:Destroy() end)
    end,
})

task.spawn(function()
    while ui.Alive ~= false and _G.AutoParryStats do
        pcall(function()
            local ps, pc = _G.AutoParryStats()
            statusLbl:SetText("Parries: " .. tostring(pc))
            statusLbl:SetDescription("Last: " .. tostring(ps))
        end)
        task.wait(0.5)
    end
end)

-- drop JDUI's built-in "Home" welcome tab
pcall(function()
    for i = #ui.Tabs, 1, -1 do
        if ui.Tabs[i] == ui.Home then table.remove(ui.Tabs, i) end
    end
    -- Auto Parry first, Settings after
    for i = #ui.Tabs, 1, -1 do
        if ui.Tabs[i] == tab then table.remove(ui.Tabs, i) end
    end
    table.insert(ui.Tabs, 1, tab)
end)
pcall(function() tab:Select() end)
print("[BeyondNen] auto parry loaded (RightShift for the menu)")
