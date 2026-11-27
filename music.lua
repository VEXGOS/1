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
    local s = ui.scale
    ui.mon.setFrozen(true)

    local cx, cy, cw, ch = ui.drawWindow(buttons, "WINDOWS MEDIA PLAYER", function()
        exitApp = true
    end)

    -- Адаптивний візуалізатор (22% висоти вікна)
    local vizH = math.max(20 * s, math.floor(ch * 0.24))
    local vizX = cx + 2 * s
    local vizW = cw - 4 * s
    ui.fillRect(vizX, cy + s, vizW, vizH, ui.C.DARK)

    local maxTitleChars = math.max(8, math.floor((vizW - 8 * s) / (4 * s)))
    if currentTrack then
        ui.drawText(vizX + 4 * s, cy + 3 * s, currentTrack.name:sub(1, maxTitleChars), ui.C.HILL_LIGHT, s)
        local barW = 3 * s
        local barGap = 2 * s
        local bars = math.floor((vizW - 8 * s) / (barW + barGap))
        local maxBarH = math.max(4, vizH - 11 * s)
        for i = 0, bars - 1 do
            local barH = math.random(2, maxBarH)
            ui.fillRect(vizX + 4 * s + i * (barW + barGap), cy + s + vizH - barH - 2 * s, barW, barH, ui.C.LUNA_LIGHT)
        end
    else
        ui.drawText(vizX + 4 * s, cy + 4 * s, ("VEXGOS PLAYER"):sub(1, maxTitleChars), ui.C.LUNA_LIGHT, s)
        ui.drawText(vizX + 4 * s, cy + 11 * s, statusMsg:sub(1, maxTitleChars), ui.C.GRAY, s)
    end

    -- Адаптивна панель керування на 12-колонковій сітці
    local ctrlY = cy + vizH + 3 * s
    local ctrlH = 8 * s + 4

    local c1x, c1w = ui.gridCol(vizX, vizW, 1, 2, 2 * s)
    ui.drawText(c1x, ctrlY + math.floor((ctrlH - 5 * s) / 2), "VOL", ui.C.BLACK, s)

    local barX, barW = ui.gridCol(vizX, vizW, 3, 5, 2 * s)
    local barH = math.max(4, 5 * s)
    local barY = ctrlY + math.floor((ctrlH - barH) / 2)
    ui.fillRect(barX, barY, barW, barH, ui.C.GRAY)
    local fillW = math.floor((volume / 3.0) * barW)
    ui.fillRect(barX, barY, fillW, barH, ui.C.START_GREEN)

    table.insert(buttons, {
        x1 = barX, y1 = ctrlY, x2 = barX + barW, y2 = ctrlY + ctrlH,
        onClick = function(px)
            local ratio = math.max(0.15, math.min(1.0, (px - barX) / barW))
            volume = math.floor(ratio * 6 + 0.5) * 0.5
        end
    })

    local syncX, syncW = ui.gridCol(vizX, vizW, 8, 2, 2 * s)
    ui.drawButton(buttons, syncX, ctrlY, syncW, ctrlH, ui.C.LUNA_BLUE, ui.C.NAVY, "SYNC", ui.C.WHITE, onSync, s)

    if currentTrack then
        local stopX, stopW = ui.gridCol(vizX, vizW, 10, 3, 2 * s)
        ui.drawButton(buttons, stopX, ctrlY, stopW, ctrlH, ui.C.RED, ui.C.BLACK, "STOP", ui.C.WHITE, onStop, s)
    end

    -- Адаптивний список треків
    local listY = ctrlY + ctrlH + 3 * s
    local listH = ch - (listY - cy) - 2 * s
    ui.fillRect(vizX, listY, vizW, listH, ui.C.WHITE)

    local itemY = listY + 2 * s
    local itemH = 7 * s + 4
    local maxChars = math.max(8, math.floor((vizW - 8 * s) / (4 * s)))

    for i, tr in ipairs(tracks) do
        if itemY + itemH > listY + listH - s then break end
        local active = (currentTrack and currentTrack.name == tr.name)
        local bg = active and ui.C.LUNA_BLUE or ui.C.WHITE
        local fg = active and ui.C.WHITE or ui.C.BLACK
        local label = (active and "> " or (i .. ". ")) .. tr.name

        ui.drawButton(buttons, vizX + s, itemY, vizW - 2 * s, itemH, bg, bg, label:sub(1, maxChars), fg, function()
            onSelect(tr)
        end, s)
        itemY = itemY + itemH + s
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
            if ev == "monitor_resize" then
                ui.init()
            elseif ev == "timer" and p1 == animTimer then
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
    if ev == "monitor_resize" then
        ui.init()
    elseif ev == "timer" and p1 == syncTimer then
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
