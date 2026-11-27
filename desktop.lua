local ui = dofile("/ui.lua")
local REPO_RAW = "https://raw.githubusercontent.com/VEXGOS/1/main/"

local apps = {
    {
        name = "MEDIA",
        file = "/music.lua",
        url = REPO_RAW .. "music.lua",
        drawIcon = function(x, y, size)
            local p = math.max(2, math.floor(size / 10))
            ui.fillRect(x + p, y + p, size - p * 2, size - p * 2, ui.C.LUNA_BLUE)
            ui.fillRect(x + p * 2, y + p * 2, size - p * 4, size - p * 4, ui.C.GOLD)
            local cx = x + math.floor(size * 0.4)
            local cy = y + math.floor(size * 0.32)
            local ph = math.max(4, math.floor(size * 0.36))
            for i = 0, math.floor(ph / 2) do
                ui.fillRect(cx + i, cy + i, 2, ph - i * 2, ui.C.BLACK)
            end
        end
    },
    {
        name = "SNAKE",
        file = "/snake.lua",
        url = REPO_RAW .. "snake.lua",
        drawIcon = function(x, y, size)
            local p = math.max(2, math.floor(size / 10))
            ui.fillRect(x + p, y + p, size - p * 2, size - p * 2, ui.C.DARK)
            -- Тіло змійки
            ui.fillRect(x + p * 2, y + p * 3, math.floor(size * 0.5), p * 2, ui.C.START_GREEN)
            ui.fillRect(x + p * 2, y + p * 3, p * 2, math.floor(size * 0.45), ui.C.START_GREEN)
            ui.fillRect(x + p * 2, y + math.floor(size * 0.65), math.floor(size * 0.45), p * 2, ui.C.GOLD)
            -- Яблуко
            ui.fillRect(x + math.floor(size * 0.68), y + math.floor(size * 0.45), p * 2, p * 2, ui.C.RED)
        end
    }
}

local buttons = {}
local startMenuOpen = false

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

local function showPopup(msg)
    local s = ui.scale
    local pw = math.min(ui.w - 16, ui.textWidth(msg, s) + 20 * s)
    local ph = 14 * s
    local px = math.floor((ui.w - pw) / 2)
    local py = math.floor((ui.h - ph) / 2)

    ui.mon.setFrozen(true)
    ui.fillRect(px, py, pw, ph, ui.C.BLACK)
    ui.fillRect(px + 1, py + 1, pw - 2, ph - 2, ui.C.LUNA_BLUE)
    ui.drawText(px + math.floor((pw - ui.textWidth(msg, s)) / 2), py + math.floor((ph - 5 * s) / 2), msg, ui.C.WHITE, s)
    ui.mon.setFrozen(false)
end

local function updateAll()
    showPopup("UPDATING SYSTEM...")
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
        showPopup("DOWNLOADING...")
        downloadFile(app.url, app.file)
    end
    shell.run(app.file)
end

local function renderDesktop()
    buttons = {}
    local s = ui.scale
    ui.mon.setFrozen(true)

    ui.drawBlissWallpaper()

    local iconSize = 18 * s
    local cellW = math.max(iconSize + 10 * s, ui.textWidth("MEDIA", s) + 12 * s)
    local cellH = iconSize + 12 * s
    local startX = 6 * s
    local startY = 6 * s
    local ix, iy = startX, startY

    for _, app in ipairs(apps) do
        local iconX = ix + math.floor((cellW - iconSize) / 2)
        app.drawIcon(iconX, iy, iconSize)

        local tw = ui.textWidth(app.name, s)
        local tx = ix + math.floor((cellW - tw) / 2)
        ui.drawText(tx + 1, iy + iconSize + 3 * s + 1, app.name, ui.C.BLACK, s)
        ui.drawText(tx, iy + iconSize + 3 * s, app.name, ui.C.WHITE, s)

        table.insert(buttons, {
            x1 = ix, y1 = iy, x2 = ix + cellW - 1, y2 = iy + cellH - 1,
            onClick = function() launchApp(app) end
        })

        iy = iy + cellH + 4 * s
        if iy + cellH > ui.h - ui.taskH - 4 * s then
            iy = startY
            ix = ix + cellW + 4 * s
        end
    end

    ui.drawTaskbar(
        buttons,
        function() startMenuOpen = not startMenuOpen end,
        function() updateAll() end
    )

    if startMenuOpen then
        local mw = math.max(84 * s, ui.pctX(0.32))
        local headerH = 10 * s + 4
        local footerH = 10 * s + 4
        local itemH = 9 * s + 4
        local bodyH = math.max(itemH * 2, #apps * (itemH + 2) + 6 * s)
        local mh = headerH + bodyH + footerH
        local mx = 0
        local my = ui.h - ui.taskH - mh

        ui.fillRect(mx, my, mw, mh, ui.C.LUNA_BLUE)
        ui.drawText(mx + 4 * s, my + math.floor((headerH - 5 * s) / 2), "VEXGOS XP", ui.C.WHITE, s)

        ui.fillRect(mx + 2, my + headerH, mw - 4, bodyH, ui.C.WHITE)
        local itemY = my + headerH + 3 * s
        for _, app in ipairs(apps) do
            ui.drawButton(buttons, mx + 4, itemY, mw - 8, itemH, ui.C.BEIGE, ui.C.GRAY, app.name, ui.C.BLACK, function()
                launchApp(app)
            end, s)
            itemY = itemY + itemH + 2
        end

        local halfW = math.floor((mw - 8) / 2)
        ui.drawButton(buttons, mx + 3, my + mh - footerH + 2, halfW, footerH - 4, ui.C.GOLD, ui.C.GOLD, "UPDATE", ui.C.BLACK, updateAll, s)
        ui.drawButton(buttons, mx + 5 + halfW, my + mh - footerH + 2, mw - halfW - 8, footerH - 4, ui.C.RED, ui.C.RED, "REBOOT", ui.C.WHITE, os.reboot, s)
    end

    ui.mon.setFrozen(false)
end

ui.init()
local ok, err = pcall(function()
    local clockTimer = os.startTimer(5)
    while true do
        renderDesktop()
        local ev, p1, p2, p3 = os.pullEvent()
        if ev == "monitor_resize" then
            ui.init()
        elseif ev == "timer" and p1 == clockTimer then
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
