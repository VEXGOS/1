local ui = {}

ui.C = {
    WHITE = 1,
    BEIGE = 2,
    GRAY = 3,
    LUNA_BLUE = 4,
    LUNA_LIGHT = 5,
    NAVY = 6,
    START_GREEN = 7,
    START_LIGHT = 8,
    SKY = 9,
    CLOUD = 10,
    HILL_LIGHT = 11,
    HILL_DARK = 12,
    RED = 13,
    GOLD = 14,
    DARK = 15,
    BLACK = 16
}

local paletteHex = {
    [1]  = 0xFFFFFF, -- White
    [2]  = 0xECE9D8, -- XP Window Beige
    [3]  = 0xACA899, -- XP Border Gray
    [4]  = 0x245EDC, -- XP Luna Blue
    [5]  = 0x4B8BF5, -- XP Luna Highlight
    [6]  = 0x003399, -- XP Dark Blue
    [7]  = 0x3C9A3C, -- XP Start Green
    [8]  = 0x62B862, -- XP Start Highlight
    [9]  = 0x5C9DED, -- Bliss Sky
    [10] = 0xD6E8FC, -- Bliss Cloud
    [11] = 0x68B028, -- Bliss Hill Light
    [12] = 0x468218, -- Bliss Hill Dark
    [13] = 0xE0433E, -- XP Close Red
    [14] = 0xF39C12, -- XP Gold
    [15] = 0x1A1D24, -- WMP Dark Screen
    [16] = 0x000000  -- Black
}

local font3x5 = {
    A={2,5,7,5,5}, B={6,5,6,5,6}, C={3,4,4,4,3}, D={6,5,5,5,6}, E={7,4,6,4,7},
    F={7,4,6,4,4}, G={3,4,5,5,3}, H={5,5,7,5,5}, I={7,2,2,2,7}, J={1,1,1,5,2},
    K={5,5,6,5,5}, L={4,4,4,4,7}, M={5,7,5,5,5}, N={5,7,7,5,5}, O={2,5,5,5,2},
    P={6,5,6,4,4}, Q={2,5,5,7,3}, R={6,5,6,5,5}, S={3,4,2,1,6}, T={7,2,2,2,2},
    U={5,5,5,5,7}, V={5,5,5,5,2}, W={5,5,5,7,5}, X={5,5,2,5,5}, Y={5,5,2,2,2},
    Z={7,1,2,4,7},
    ["0"]={7,5,5,5,7}, ["1"]={2,6,2,2,7}, ["2"]={7,1,7,4,7}, ["3"]={7,1,3,1,7},
    ["4"]={5,5,7,1,1}, ["5"]={7,4,7,1,7}, ["6"]={7,4,7,5,7}, ["7"]={7,1,1,2,2},
    ["8"]={7,5,7,5,7}, ["9"]={7,5,7,1,7},
    ["."]={0,0,0,0,2}, [":"]={0,2,0,2,0}, ["-"]={0,0,7,0,0}, ["+"]={0,2,7,2,0},
    ["/"]={1,1,2,4,4}, ["_"]={0,0,0,0,7}, ["!"]={2,2,2,0,2}, ["("]={2,4,4,4,2},
    [")"]={2,1,1,1,2}, ["["]={6,4,4,4,6}, ["]"]={3,1,1,1,3}, [">"]={4,2,1,2,4},
    [" "]={0,0,0,0,0}
}

ui.mon = nil
ui.w = 0
ui.h = 0
ui.cellW = 6
ui.cellH = 9
ui.scale = 1
ui.taskH = 14

function ui.init()
    local mon = peripheral.find("monitor")
    if not mon then error("Monitor not found!") end
    ui.mon = mon

    mon.setGraphicsMode(0)
    mon.setTextScale(0.5)
    local cw, ch = mon.getSize()

    mon.setGraphicsMode(1)
    ui.cellW = 6
    ui.cellH = 9
    ui.w = cw * ui.cellW
    ui.h = ch * ui.cellH

    -- Адаптивний коефіцієнт масштабу (для 2x2 -> 1, для 3x3 -> 2, для 4x4+ -> 3)
    local minSide = math.min(ui.w, ui.h)
    ui.scale = math.max(1, math.min(3, math.floor(minSide / 150)))
    ui.taskH = 12 * ui.scale + 4

    for idx, hex in pairs(paletteHex) do
        mon.setPaletteColor(2 ^ (idx - 1), hex)
    end
end

function ui.shutdown()
    if ui.mon then
        ui.mon.setFrozen(false)
        ui.mon.setGraphicsMode(0)
    end
end

-- Відносні координати у відсотках від розміру екрана (0.0 .. 1.0)
function ui.pctX(p)
    return math.floor(ui.w * p)
end

function ui.pctY(p)
    return math.floor(ui.h * p)
end

-- 12-колонкова адаптивна сітка всередині будь-якої області
function ui.gridCol(areaX, areaW, colStart, colSpan, gap)
    gap = gap or 2
    local colW = (areaW - gap * 11) / 12
    local x = math.floor(areaX + (colStart - 1) * (colW + gap))
    local w = math.floor(colSpan * colW + (colSpan - 1) * gap)
    return x, w
end

function ui.touchToPixel(tx, ty)
    local px = math.floor((tx - 0.5) * ui.cellW)
    local py = math.floor((ty - 0.5) * ui.cellH)
    return px, py
end

function ui.fillRect(x, y, w, h, color)
    if w <= 0 or h <= 0 then return end
    x = math.max(0, math.floor(x))
    y = math.max(0, math.floor(y))
    w = math.min(ui.w - x, math.floor(w))
    h = math.min(ui.h - y, math.floor(h))
    if w <= 0 or h <= 0 then return end

    local row = {}
    for i = 1, w do row[i] = color end
    local grid = {}
    for j = 1, h do grid[j] = row end

    ui.mon.drawPixels(x, y, grid, w, h)
end

function ui.drawText(x, y, text, color, scale)
    scale = scale or ui.scale
    text = tostring(text):upper()
    local cx = math.floor(x)
    local cy = math.floor(y)

    for i = 1, #text do
        local ch = text:sub(i, i)
        local glyph = font3x5[ch] or font3x5[" "]
        for row = 1, 5 do
            local bits = glyph[row]
            if bits >= 4 then
                ui.fillRect(cx, cy + (row - 1) * scale, scale, scale, color)
                bits = bits - 4
            end
            if bits >= 2 then
                ui.fillRect(cx + scale, cy + (row - 1) * scale, scale, scale, color)
                bits = bits - 2
            end
            if bits >= 1 then
                ui.fillRect(cx + 2 * scale, cy + (row - 1) * scale, scale, scale, color)
            end
        end
        cx = cx + 4 * scale
    end
end

function ui.textWidth(text, scale)
    scale = scale or ui.scale
    return #tostring(text) * 4 * scale - scale
end

function ui.drawButton(buttons, x, y, w, h, bg, border, label, txtColor, onClick, textScale)
    textScale = textScale or ui.scale
    ui.fillRect(x, y, w, h, border or bg)
    ui.fillRect(x + 1, y + 1, w - 2, h - 2, bg)
    if label and #label > 0 then
        local tw = ui.textWidth(label, textScale)
        local tx = x + math.max(2, math.floor((w - tw) / 2))
        local ty = y + math.floor((h - 5 * textScale) / 2)
        ui.drawText(tx, ty, label, txtColor or ui.C.WHITE, textScale)
    end
    if onClick then
        table.insert(buttons, { x1 = x, y1 = y, x2 = x + w - 1, y2 = y + h - 1, onClick = onClick })
    end
end

-- Адаптивні шпалери Windows XP (Bliss)
function ui.drawBlissWallpaper()
    local deskH = ui.h - ui.taskH
    ui.fillRect(0, 0, ui.w, deskH, ui.C.SKY)

    -- Адаптивна хмаринка
    local cloudX = ui.pctX(0.55)
    local cloudY = ui.pctY(0.12)
    local cloudW = math.max(24, ui.pctX(0.22))
    local cloudH = math.max(8, ui.pctY(0.06))
    ui.fillRect(cloudX, cloudY + math.floor(cloudH * 0.3), cloudW, math.floor(cloudH * 0.7), ui.C.CLOUD)
    ui.fillRect(cloudX + math.floor(cloudW * 0.18), cloudY, math.floor(cloudW * 0.6), cloudH, ui.C.CLOUD)

    -- Адаптивний зелений пагорб
    local waveAmp = math.max(8, ui.pctY(0.08))
    local waveFreq = (math.pi * 1.4) / math.max(1, ui.w)
    for x = 0, ui.w - 1 do
        local hillTop = math.floor(deskH * 0.60 + math.sin(x * waveFreq) * waveAmp)
        if hillTop < deskH then
            ui.fillRect(x, hillTop, 1, 2 * ui.scale, ui.C.HILL_LIGHT)
            ui.fillRect(x, hillTop + 2 * ui.scale, 1, deskH - hillTop - 2 * ui.scale, ui.C.HILL_DARK)
        end
    end
end

-- Адаптивна панель задач Windows XP
function ui.drawTaskbar(buttons, onStartClick, onUpdateClick)
    local y = ui.h - ui.taskH
    local s = ui.scale

    ui.fillRect(0, y, ui.w, 1, ui.C.LUNA_LIGHT)
    ui.fillRect(0, y + 1, ui.w, ui.taskH - 1, ui.C.LUNA_BLUE)

    local startW = ui.textWidth("START", s) + 12 * s
    ui.drawButton(buttons, 0, y, startW, ui.taskH, ui.C.START_GREEN, ui.C.START_LIGHT, "START", ui.C.WHITE, onStartClick, s)

    local timeStr = textutils.formatTime(os.time(), true)
    local trayW = ui.textWidth(timeStr, s) + 10 * s
    local trayX = ui.w - trayW
    ui.fillRect(trayX, y + 1, trayW, ui.taskH - 1, ui.C.LUNA_LIGHT)
    ui.drawText(trayX + 5 * s, y + math.floor((ui.taskH - 5 * s) / 2), timeStr, ui.C.WHITE, s)

    if onUpdateClick then
        local updW = ui.textWidth("UPD", s) + 8 * s
        ui.drawButton(buttons, trayX - updW - 2 * s, y + 2, updW, ui.taskH - 4, ui.C.GOLD, ui.C.WHITE, "UPD", ui.C.BLACK, onUpdateClick, s)
    end
end

-- Адаптивне вікно Windows XP
function ui.drawWindow(buttons, title, onClose)
    local s = ui.scale
    local winH = ui.h - ui.taskH
    local titleH = 9 * s + 4
    local border = math.max(2, s)

    ui.fillRect(0, 0, ui.w, winH, ui.C.LUNA_BLUE)
    ui.fillRect(border, titleH, ui.w - border * 2, winH - titleH - border, ui.C.BEIGE)

    ui.fillRect(border, 1, ui.w - border * 2, 1, ui.C.LUNA_LIGHT)
    ui.drawText(border + 4 * s, math.floor((titleH - 5 * s) / 2) + 1, title, ui.C.WHITE, s)

    local closeSize = titleH - 3
    ui.drawButton(buttons, ui.w - closeSize - border, 2, closeSize, closeSize, ui.C.RED, ui.C.WHITE, "X", ui.C.WHITE, onClose, s)

    return border + 2, titleH + 2, ui.w - (border + 2) * 2, winH - titleH - border - 4
end

return ui
