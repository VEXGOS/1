local ui = dofile("/ui.lua")
local dfpwm = require("cc.audio.dfpwm")
local speakers = { peripheral.find("speaker") }

if #speakers == 0 then error("No speaker attached!") end
if not ui.mon then ui.init() end

local REFRESH_INTERVAL = 240
local apiUrl = "https://api.github.com/repos/VEXGOS/1/contents/"
local headers = { ["User-Agent"] = "CC-Tweaked-Player" }

local tracks = {}
local buttons = {}
local volume = 3.0
local statusMsg = "READY"
local currentTrack = nil
local exitApp = false

local function fetchTracks()
    statusMsg = "SYNCING..."
    local res = http.get(apiUrl .. "?t=" .. tostring(os.epoch("utc")), headers)
    if not res then
        statusMsg = "API ERROR"
        return
    end
    local data = textutils.unserializeJSON(res.readAll())
    res.close()

    local list = {}
    if type(data) == "table" then
        for _, item in ipairs(data) do
            if item.type == "file" and item.name:match("%.dfpwm$") then
                table.insert(list, {
                    name = item.name:gsub("%.dfpwm$", ""),
                    url = item.download_url
                })
            end
        end
    end
    tracks = list
    statusMsg = "TRACKS: " .. #tracks
end

local function renderPlayer(onSelect, onSync, onStop)
    buttons = {}
    ui.mon.setFrozen(true)

    local cx, cy, cw, ch = ui.drawWindow(buttons, "WINDOWS MEDIA PLAYER", function()
        exitApp = true
    end)

    -- Темний екран візуалізатора зверху (як у WMP)
    local vizH = 26
    ui.fillRect(cx + 2, cy + 1, cw - 4, vizH, ui.C.DARK)

    if currentTrack then
        ui.drawText(cx + 6, cy + 4, currentTrack.name:sub(1, 28), ui.C.HILL_LIGHT, 1)
        -- Анімовані стовпчики еквалайзера
        for i = 0, 14 do
            local barH = math.random(3, 12)
            ui.fillRect(cx + 6 + i * 5, cy + vizH - barH - 1, 3, barH, ui.C.LUNA_LIGHT)
        end
    else
        ui.drawText(cx + 6, cy + 6, "VEXGOS MEDIA PLAYER", ui.C.LUNA_LIGHT, 1)
        ui.drawText(cx + 6, cy + 15, statusMsg, ui.C.GRAY, 1)
    end

    -- Панель керування: повзунок гучності + кнопки SYNC / STOP
    local ctrlY = cy + vizH + 4
    ui.drawText(cx + 2, ctrlY + 3, "VOL", ui.C.BLACK, 1)

    local barX, barW = cx + 18, 42
    ui.fillRect(barX, ctrlY + 2, barW, 6, ui.C.GRAY)
    local fillW = math.floor((volume / 3.0) * barW)
    ui.fillRect(barX, ctrlY + 2, fillW, 6, ui.C.START_GREEN)

    -- Клік по самій шкалі змінює гучність
    table.insert(buttons, {
        x1 = barX, y1 = ctrlY, x2 = barX + barW, y2 = ctrlY + 10,
        onClick = function(px)
            local ratio = math.max(0.15, math.min(1.0, (px - barX) / barW))
            volume = math.floor(ratio * 6 + 0.5) * 0.5
        end
    })

    ui.drawButton(buttons, barX + barW + 4, ctrlY, 26, 10, ui.C.LUNA_BLUE, ui.C.NAVY, "SYNC", ui.C.WHITE, onSync)

    if currentTrack then
        ui.drawButton(buttons, cx + cw - 28, ctrlY, 26, 10, ui.C.RED, ui.C.BLACK, "STOP", ui.C.WHITE, onStop)
    end

    -- Список пісень
    local listY = ctrlY + 14
    ui.fillRect(cx + 2, listY, cw - 4, ch - (listY - cy) - 2, ui.C.WHITE)

    local itemY = listY + 2
    for i, tr in ipairs(tracks) do
        if itemY + 10 > cy + ch - 2 then break end
        local active = (currentTrack and currentTrack.name == tr.name)
        local bg = active and ui.C.LUNA_BLUE or ui.C.WHITE
        local fg = active and ui.C.WHITE or ui.C.BLACK
        local label = (active and "> " or (i .. ". ")) .. tr.name

        ui.drawButton(buttons, cx + 3, itemY, cw - 6, 10, bg, bg, label:sub(1, 30), fg, function()
            onSelect(tr)
        end)
        itemY = itemY + 11
    end

    ui.drawTaskbar(buttons, function() exitApp = true end, nil)
    ui.mon.setFrozen(false)
end

local function playTrack(track)
    currentTrack = track
    local stopReq = false

    local audioRes = http.get(track.url, headers)
    if not audioRes then
        statusMsg = "LOAD ERROR"
        currentTrack = nil
        return
    end

    local function stream()
        local decoder = dfpwm.make_decoder()
        while not stopReq and not exitApp do
            local chunk = audioRes.read(16 * 1024)
            if not chunk then break end
            local buffer = decoder(chunk)
            for _, sp in ipairs(speakers) do
                while not sp.playAudio(buffer, volume) do
                    if stopReq or exitApp then return end
                    os.pullEvent("speaker_audio_empty")
                end
            end
        end
    end

    local function uiLoop()
        local animTimer = os.startTimer(0.25)
        while not stopReq and not exitApp do
            renderPlayer(
                function() end,
                function() end,
                function() stopReq = true end
            )
            local ev, p1, p2, p3 = os.pullEvent()
            if ev == "timer" and p1 == animTimer then
                animTimer = os.startTimer(0.25)
            elseif ev == "monitor_touch" then
                local px, py = ui.touchToPixel(p2, p3)
                for _, btn in ipairs(buttons) do
                    if px >= btn.x1 and px <= btn.x2 and py >= btn.y1 and py <= btn.y2 then
                        btn.onClick(px, py)
                        break
                    end
                end
            end
        end
    end

    parallel.waitForAny(stream, uiLoop)
    audioRes.close()
    for _, sp in ipairs(speakers) do sp.stop() end
    currentTrack = nil
end

fetchTracks()
local syncTimer = os.startTimer(REFRESH_INTERVAL)

while not exitApp do
    local chosen = nil
    local needSync = false

    renderPlayer(
        function(tr) chosen = tr end,
        function() needSync = true end,
        function() end
    )

    local ev, p1, p2, p3 = os.pullEvent()
    if ev == "timer" and p1 == syncTimer then
        fetchTracks()
        syncTimer = os.startTimer(REFRESH_INTERVAL)
    elseif ev == "monitor_touch" then
        local px, py = ui.touchToPixel(p2, p3)
        for _, btn in ipairs(buttons) do
            if px >= btn.x1 and px <= btn.x2 and py >= btn.y1 and py <= btn.y2 then
                btn.onClick(px, py)
                break
            end
        end
        if exitApp then break end
        if needSync then
            fetchTracks()
            syncTimer = os.startTimer(REFRESH_INTERVAL)
        elseif chosen then
            playTrack(chosen)
            if not exitApp then
                fetchTracks()
                syncTimer = os.startTimer(REFRESH_INTERVAL)
            end
        end
    end
end
