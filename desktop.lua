local ui = dofile("/ui.lua")
local REPO_RAW = "https://raw.githubusercontent.com/VEXGOS/1/main/"

-- Список додатків на робочому столі (сюди додаємо нові програми)
local apps = {
    {
        name = "MEDIA",
        file = "/music.lua",
        url = REPO_RAW .. "music.lua",
        drawIcon = function(x, y)
            -- Іконка Windows Media Player
            ui.fillRect(x + 2, y + 2, 16, 16, ui.C.LUNA_BLUE)
            ui.fillRect(x + 4, y + 4, 12, 12, ui.C.GOLD)
            ui.fillRect(x + 8, y + 7, 2, 6, ui.C.WHITE)
            ui.fillRect(x + 10, y + 8, 2, 4, ui.C.WHITE)
            ui.fillRect(x + 12, y + 9, 2, 2, ui.C.WHITE)
        end
    }
}

local buttons = {}
local startMenuOpen = false
local statusBanner = nil

local function downloadFile(url, path)
    local res = http.get(url .. "?t=" .. tostring(os.epoch("utc")))
    if not res then return false end
    local content = res.readAll()
    res.close()
    local f = fs.open(path, "w")
    f.write(content)
    f.close()
    return true
end

local function updateAll()
    statusBanner = "UPDATING SYSTEM..."
    ui.mon.setFrozen(true)
    ui.fillRect(20, 40, ui.w - 40, 20, ui.C.NAVY)
    ui.drawText(26, 48, statusBanner, ui.C.WHITE, 1)
    ui.mon.setFrozen(false)

    downloadFile(REPO_RAW .. "ui.lua", "/ui.lua")
    for _, app in ipairs(apps) do
        downloadFile(app.url, app.file)
    end
    if downloadFile(REPO_RAW .. "desktop.lua", "/startup.lua") then
        os.reboot()
    end
end

local function launchApp(app)
    startMenuOpen = false
    if not fs.exists(app.file) then
        ui.mon.setFrozen(true)
        ui.fillRect(20, 40, ui.w - 40, 20, ui.C.NAVY)
        ui.drawText(26, 48, "DOWNLOADING...", ui.C.WHITE, 1)
        ui.mon.setFrozen(false)
        downloadFile(app.url, app.file)
    end
    shell.run(app.file)
end

local function renderDesktop()
    buttons = {}
    ui.mon.setFrozen(true)

    ui.drawBlissWallpaper()

    -- Іконки на робочому столі
    local ix, iy = 10, 10
    for _, app in ipairs(apps) do
        app.drawIcon(ix, iy)
        local tw = ui.textWidth(app.name, 1)
        local tx = ix + math.floor((20 - tw) / 2)
        ui.drawText(tx + 1, iy + 22, app.name, ui.C.BLACK, 1)
        ui.drawText(tx, iy + 21, app.name, ui.C.WHITE, 1)

        table.insert(buttons, {
            x1 = ix, y1 = iy, x2 = ix + 20, y2 = iy + 28,
            onClick = function() launchApp(app) end
        })

        iy = iy + 36
        if iy > ui.h - 45 then
            iy = 10
            ix = ix + 34
        end
    end

    -- Панель задач
    ui.drawTaskbar(
        buttons,
        function() startMenuOpen = not startMenuOpen end,
        function() updateAll() end
    )

    -- Спливаюче меню Start (як у Windows XP)
    if startMenuOpen then
        local mw, mh = 86, 68
        local mx, my = 0, ui.h - 14 - mh

        ui.fillRect(mx, my, mw, mh, ui.C.LUNA_BLUE)
        ui.fillRect(mx + 1, my + 1, mw - 2, 12, ui.C.LUNA_BLUE)
        ui.drawText(mx + 5, my + 5, "VEXGOS", ui.C.WHITE, 1)

        ui.fillRect(mx + 2, my + 13, mw - 4, mh - 25, ui.C.WHITE)
        local itemY = my + 16
        for _, app in ipairs(apps) do
            ui.drawButton(buttons, mx + 4, itemY, mw - 8, 12, ui.C.WHITE, ui.C.BEIGE, app.name, ui.C.BLACK, function()
                launchApp(app)
            end)
            itemY = itemY + 13
        end

        -- Нижня смуга Start із кнопками Update та Reboot
        ui.drawButton(buttons, mx + 3, my + mh - 11, 38, 9, ui.C.GOLD, ui.C.GOLD, "UPDATE", ui.C.BLACK, updateAll)
        ui.drawButton(buttons, mx + 44, my + mh - 11, 39, 9, ui.C.RED, ui.C.RED, "REBOOT", ui.C.WHITE, os.reboot)
    end

    ui.mon.setFrozen(false)
end

ui.init()
local ok, err = pcall(function()
    local clockTimer = os.startTimer(5)
    while true do
        renderDesktop()
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "timer" and p1 == clockTimer then
            clockTimer = os.startTimer(5)
        elseif ev == "monitor_touch" then
            local px, py = ui.touchToPixel(p2, p3)
            local hit = false
            for _, btn in ipairs(buttons) do
                if px >= btn.x1 and px <= btn.x2 and py >= btn.y1 and py <= btn.y2 then
                    hit = true
                    btn.onClick()
                    break
                end
            end
            if not hit and startMenuOpen then
                startMenuOpen = false
            end
            clockTimer = os.startTimer(5)
        end
    end
end)

ui.shutdown()
if not ok then error(err) end
