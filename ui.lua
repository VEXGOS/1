local ui = {}

-- Палітра кольорів Windows XP (16 кольорів для Mode 1)
ui.C = {
    WHITE = 0,
    BEIGE = 1,
    GRAY = 2,
    LUNA_BLUE = 3,
    LUNA_LIGHT = 4,
    NAVY = 5,
    START_GREEN = 6,
    START_LIGHT = 7,
    SKY = 8,
    CLOUD = 9,
    HILL_LIGHT = 10,
    HILL_DARK = 11,
    RED = 12,
    GOLD = 13,
    DARK = 14,
    BLACK = 15
}

local paletteHex = {
    [0] = 0xFFFFFF,  -- White
    [1] = 0xECE9D8,  -- XP Window Beige
    [2] = 0xACA899,  -- XP Border Gray
    [3] = 0x245EDC,  -- XP Luna Blue
    [4] = 0x4B8BF5,  -- XP Luna Highlight
    [5] = 0x003399,  -- XP Dark Blue
    [6] = 0x3C9A3C,  -- XP Start Green
    [7] = 0x62B862,  -- XP Start Highlight
    [8] = 0x5C9DED,  -- Bliss Sky
    [9] = 0xD6E8FC,  -- Bliss Cloud
    [10] = 0x68B028, -- Bliss Hill Light
    [11] = 0x468218, -- Bliss Hill Dark
    [12] = 0xE0433E, -- XP Close Red
    [13] = 0xF39C12, -- XP Gold / Accent
    [14] = 0x1A1D24, -- WMP Dark Screen
    [15] = 0x000000  -- Black
}

-- Компактний піксельний шрифт 3x5 для графічного режиму
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

function ui.init()
    local mon = peripheral.find("monitor")
    if not mon then error("Monitor not found!") end
    ui.mon = mon

    -- Визначаємо співвідношення клітинки та пікселів
    mon.setGraphicsMode(0)
    mon.setTextScale(1)
    local cw, ch = mon.getSize()

    mon.setGraphicsMode(1)
    ui.w, ui.h = mon.getSize()
    ui.cellW = ui.w / cw
    ui.cellH = ui.h / ch

    for idx, hex in pairs(paletteHex) do
        mon.setPaletteColor(2 ^ idx, hex)
    end
end

function ui.shutdown()
    if ui.mon then
        ui.mon.setFrozen(false)
        ui.mon.setGraphicsMode(0)
    end
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

    ui.mon.drawPixels(x, y, color, w, h)
end
function ui.drawText(x, y, text, color, scale)
    scale = scale or 1
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
    scale = scale or 1
    return #tostring(text) * 4 * scale - scale
end

function ui.drawButton(buttons, x, y, w, h, bg, border, label, txtColor, onClick)
    ui.fillRect(x, y, w, h, border or bg)
    ui.fillRect(x + 1, y + 1, w - 2, h - 2, bg)
    if label and #label > 0 then
        local tw = ui.textWidth(label, 1)
        local tx = x + math.max(2, math.floor((w - tw) / 2))
        local ty = y + math.floor((h - 5) / 2)
        ui.drawText(tx, ty, label, txtColor or ui.C.WHITE, 1)
    end
    if onClick then
        table.insert(buttons, { x1 = x, y1 = y, x2 = x + w - 1, y2 = y + h - 1, onClick = onClick })
    end
end

-- Класичні шпалери Windows XP (Bliss)
function ui.drawBlissWallpaper()
    local taskH = 14
    local deskH = ui.h - taskH
    ui.fillRect(0, 0, ui.w, deskH, ui.C.SKY)

    -- Хмаринка
    ui.fillRect(24, 16, 26, 6, ui.C.CLOUD)
    ui.fillRect(28, 13, 16, 10, ui.C.CLOUD)

    -- Зелений пагорб
    for x = 0, ui.w - 1 do
        local hillTop = math.floor(deskH * 0.62 + math.sin(x * 0.025) * 9)
        if hillTop < deskH then
            ui.fillRect(x, hillTop, 1, 2, ui.C.HILL_LIGHT)
            ui.fillRect(x, hillTop + 2, 1, deskH - hillTop - 2, ui.C.HILL_DARK)
        end
    end
end

-- Нижня панель задач Windows XP + кнопка Start
function ui.drawTaskbar(buttons, onStartClick, onUpdateClick)
    local taskH = 14
    local y = ui.h - taskH

    ui.fillRect(0, y, ui.w, 1, ui.C.LUNA_LIGHT)
    ui.fillRect(0, y + 1, ui.w, taskH - 1, ui.C.LUNA_BLUE)

    -- Зелена кнопка Start
    ui.drawButton(buttons, 0, y, 34, taskH, ui.C.START_GREEN, ui.C.START_LIGHT, "START", ui.C.WHITE, onStartClick)

    -- Системний трей праворуч (годинник + кнопка оновлення)
    local timeStr = textutils.formatTime(os.time(), true)
    local trayW = 54
    local trayX = ui.w - trayW
    ui.fillRect(trayX, y + 1, trayW, taskH - 1, ui.C.LUNA_LIGHT)
    ui.drawText(trayX + 4, y + 5, timeStr, ui.C.WHITE, 1)

    if onUpdateClick then
        ui.drawButton(buttons, trayX - 30, y + 2, 28, taskH - 4, ui.C.GOLD, ui.C.WHITE, "UPD", ui.C.BLACK, onUpdateClick)
    end
end

-- Рамка вікна Windows XP із червоною кнопкою закриття [X]
function ui.drawWindow(buttons, title, onClose)
    local taskH = 14
    local winH = ui.h - taskH
    local titleH = 13

    -- Рамка та тіло вікна
    ui.fillRect(0, 0, ui.w, winH, ui.C.LUNA_BLUE)
    ui.fillRect(2, titleH, ui.w - 4, winH - titleH - 2, ui.C.BEIGE)

    -- Синя шапка вікна
    ui.fillRect(2, 1, ui.w - 4, 1, ui.C.LUNA_LIGHT)
    ui.drawText(6, 4, title, ui.C.WHITE, 1)

    -- Червона кнопка закриття X
    ui.drawButton(buttons, ui.w - 13, 2, 11, 10, ui.C.RED, ui.C.WHITE, "X", ui.C.WHITE, onClose)

    return 4, titleH + 2, ui.w - 8, winH - titleH - 4
end

return ui
