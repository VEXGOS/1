local ui = {}

ui.C = {
    WHITE = 1,          -- 2^0
    BEIGE = 2,          -- 2^1
    GRAY = 4,           -- 2^2
    LUNA_BLUE = 8,      -- 2^3
    LUNA_LIGHT = 16,    -- 2^4
    NAVY = 32,          -- 2^5
    START_GREEN = 64,   -- 2^6
    START_LIGHT = 128,  -- 2^7
    SKY = 256,          -- 2^8
    CLOUD = 512,        -- 2^9
    HILL_LIGHT = 1024,  -- 2^10
    HILL_DARK = 2048,   -- 2^11
    RED = 4096,         -- 2^12
    GOLD = 8192,        -- 2^13
    DARK = 16384,       -- 2^14
    BLACK = 32768       -- 2^15
}

local paletteHex = {
    [ui.C.WHITE]       = 0xFFFFFF,
    [ui.C.BEIGE]       = 0xECE9D8,
    [ui.C.GRAY]        = 0xACA899,
    [ui.C.LUNA_BLUE]   = 0x245EDC,
    [ui.C.LUNA_LIGHT]  = 0x4B8BF5,
    [ui.C.NAVY]        = 0x003399,
    [ui.C.START_GREEN] = 0x3C9A3C,
    [ui.C.START_LIGHT] = 0x62B862,
    [ui.C.SKY]         = 0x5C9DED,
    [ui.C.CLOUD]       = 0xD6E8FC,
    [ui.C.HILL_LIGHT]  = 0x68B028,
    [ui.C.HILL_DARK]   = 0x468218,
    [ui.C.RED]         = 0xE0433E,
    [ui.C.GOLD]        = 0xF39C12,
    [ui.C.DARK]        = 0x1A1D24,
    [ui.C.BLACK]       = 0x000000
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

function ui.init()
    local mon = peripheral.find("monitor")
    if not mon then error("Monitor not found!") end
    ui.mon = mon

    mon.setGraphicsMode(0)
    mon.setTextScale(1)
    local cw, ch = mon.getSize()

    mon.setGraphicsMode(1)
    ui.w, ui.h = mon.getSize()
    ui.cellW = ui.w / cw
    ui.cellH = ui.h / ch

    for colorMask, hex in pairs(paletteHex) do
        mon.setPaletteColor(colorMask, hex)
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

function ui.drawBlissWallpaper()
    local taskH = 14
    local deskH = ui.h - taskH
    ui.fillRect(0, 0, ui.w, deskH, ui.C.SKY)

    ui.fillRect(24, 16, 26, 6, ui.C.CLOUD)
    ui.fillRect(28, 13, 16, 10, ui.C.CLOUD)

    for x = 0, ui.w - 1 do
        local hillTop = math.floor(deskH * 0.62 + math.sin(x * 0.025) * 9)
        if hillTop < deskH then
            ui.fillRect(x, hillTop, 1, 2, ui.C.HILL_LIGHT)
            ui.fillRect(x, hillTop + 2, 1, deskH - hillTop - 2, ui.C.HILL_DARK)
        end
    end
end

function ui.drawTaskbar(buttons, onStartClick, onUpdateClick)
    local taskH = 14
    local y = ui.h - taskH

    ui.fillRect(0, y, ui.w, 1, ui.C.LUNA_LIGHT)
    ui.fillRect(0, y + 1, ui.w, taskH - 1, ui.C.LUNA_BLUE)

    ui.drawButton(buttons, 0, y, 34, taskH, ui.C.START_GREEN, ui.C.START_LIGHT, "START", ui.C.WHITE, onStartClick)

    local timeStr = textutils.formatTime(os.time(), true)
    local trayW = 54
    local trayX = ui.w - trayW
    ui.fillRect(trayX, y + 1, trayW, taskH - 1, ui.C.LUNA_LIGHT)
    ui.drawText(trayX + 4, y + 5, timeStr, ui.C.WHITE, 1)

    if onUpdateClick then
        ui.drawButton(buttons, trayX - 30, y + 2, 28, taskH - 4, ui.C.GOLD, ui.C.WHITE, "UPD", ui.C.BLACK, onUpdateClick)
    end
end

function ui.drawWindow(buttons, title, onClose)
    local taskH = 14
    local winH = ui.h - taskH
    local titleH = 13

    ui.fillRect(0, 0, ui.w, winH, ui.C.LUNA_BLUE)
    ui.fillRect(2, titleH, ui.w - 4, winH - titleH - 2, ui.C.BEIGE)

    ui.fillRect(2, 1, ui.w - 4, 1, ui.C.LUNA_LIGHT)
    ui.drawText(6, 4, title, ui.C.WHITE, 1)

    ui.drawButton(buttons, ui.w - 13, 2, 11, 10, ui.C.RED, ui.C.WHITE, "X", ui.C.WHITE, onClose)

    return 4, titleH + 2, ui.w - 8, winH - titleH - 4
end

return ui
