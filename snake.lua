local ui = dofile("/ui.lua")
if not ui.mon then ui.init() end

local buttons = {}
local exitApp = false

local snake = {}
local dir = { x = 1, y = 0 }
local nextDir = { x = 1, y = 0 }
local food = { x = 5, y = 5 }
local score = 0
local bestScore = 0
local gameOver = false
local paused = false

local cols, rows = 20, 20
local cellSize = 8
local boardX, boardY, boardW, boardH = 0, 0, 0, 0

local function calcLayout(cx, cy, cw, ch)
    local s = ui.scale
    -- Ліва частина вікна (8 колонок) під поле, права (4 колонки) під панель керування
    local areaX, areaW = ui.gridCol(cx + 2 * s, cw - 4 * s, 1, 8, 2 * s)
    local areaY = cy + 2 * s
    local areaH = ch - 4 * s

    cellSize = math.max(4, 5 * s)
    cols = math.max(10, math.floor(areaW / cellSize))
    rows = math.max(10, math.floor(areaH / cellSize))

    boardW = cols * cellSize
    boardH = rows * cellSize
    boardX = areaX + math.floor((areaW - boardW) / 2)
    boardY = areaY + math.floor((areaH - boardH) / 2)
end

local function spawnFood()
    local free = {}
    for x = 1, cols do
        for y = 1, rows do
            local occupied = false
            for _, seg in ipairs(snake) do
                if seg.x == x and seg.y == y then
                    occupied = true
                    break
                end
            end
            if not occupied then
                table.insert(free, { x = x, y = y })
            end
        end
    end
    if #free > 0 then
        food = free[math.random(1, #free)]
    end
end

local function resetGame()
    local startX = math.max(4, math.floor(cols / 2))
    local startY = math.max(4, math.floor(rows / 2))
    snake = {
        { x = startX,     y = startY },
        { x = startX - 1, y = startY },
        { x = startX - 2, y = startY }
    }
    dir = { x = 1, y = 0 }
    nextDir = { x = 1, y = 0 }
    score = 0
    gameOver = false
    paused = false
    spawnFood()
end

local function setDirection(dx, dy)
    if gameOver or paused then return end
    if dir.x + dx == 0 and dir.y + dy == 0 then return end
    nextDir = { x = dx, y = dy }
end

local function stepGame()
    if gameOver or paused then return end

    dir = { x = nextDir.x, y = nextDir.y }
    local head = snake[1]
    local nx = head.x + dir.x
    local ny = head.y + dir.y

    -- Перевірка зіткнення зі стінами
    if nx < 1 or nx > cols or ny < 1 or ny > rows then
        gameOver = true
        return
    end

    -- Перевірка зіткнення із хвостом
    for i = 1, #snake - 1 do
        if snake[i].x == nx and snake[i].y == ny then
            gameOver = true
            return
        end
    end

    table.insert(snake, 1, { x = nx, y = ny })

    if nx == food.x and ny == food.y then
        score = score + 10
        if score > bestScore then bestScore = score end
        spawnFood()
    else
        table.remove(snake)
    end
end

local function renderGame()
    buttons = {}
    local s = ui.scale
    ui.mon.setFrozen(true)

    local cx, cy, cw, ch = ui.drawWindow(buttons, "SNAKE XP", function()
        exitApp = true
    end)

    -- Рамка ігрового поля
    ui.fillRect(boardX - 2, boardY - 2, boardW + 4, boardH + 4, ui.C.LUNA_BLUE)
    ui.fillRect(boardX, boardY, boardW, boardH, ui.C.DARK)

    -- Яблуко
    local fx = boardX + (food.x - 1) * cellSize
    local fy = boardY + (food.y - 1) * cellSize
    ui.fillRect(fx + 1, fy + 1, cellSize - 2, cellSize - 2, ui.C.RED)

    -- Змійка
    for i, seg in ipairs(snake) do
        local sx = boardX + (seg.x - 1) * cellSize
        local sy = boardY + (seg.y - 1) * cellSize
        local col = (i == 1) and ui.C.GOLD or ui.C.START_GREEN
        ui.fillRect(sx + 1, sy + 1, cellSize - 2, cellSize - 2, col)
    end

    -- Клік по самому ігровому полю повертає змійку в бік курсора
    table.insert(buttons, {
        x1 = boardX, y1 = boardY, x2 = boardX + boardW - 1, y2 = boardY + boardH - 1,
        onClick = function(px, py)
            if gameOver then
                resetGame()
                return
            end
            local head = snake[1]
            local hx = boardX + (head.x - 0.5) * cellSize
            local hy = boardY + (head.y - 0.5) * cellSize
            if dir.x ~= 0 then
                if py < hy then setDirection(0, -1) else setDirection(0, 1) end
            else
                if px < hx then setDirection(-1, 0) else setDirection(1, 0) end
            end
        end
    })

    -- Повідомлення поверх поля при програші або паузі
    if gameOver or paused then
        local msg = gameOver and "GAME OVER" or "PAUSED"
        local bw = ui.textWidth(msg, s) + 12 * s
        local bh = 14 * s
        local bx = boardX + math.floor((boardW - bw) / 2)
        local by = boardY + math.floor((boardH - bh) / 2)
        ui.fillRect(bx, by, bw, bh, ui.C.WHITE)
        ui.fillRect(bx + 1, by + 1, bw - 2, bh - 2, gameOver and ui.C.RED or ui.C.LUNA_BLUE)
        ui.drawText(bx + math.floor((bw - ui.textWidth(msg, s)) / 2), by + math.floor((bh - 5 * s) / 2), msg, ui.C.WHITE, s)
    end

    -- Права панель: рахунок та кнопки керування
    local sideX, sideW = ui.gridCol(cx + 2 * s, cw - 4 * s, 9, 4, 2 * s)
    local curY = cy + 2 * s

    ui.fillRect(sideX, curY, sideW, 24 * s, ui.C.WHITE)
    ui.drawText(sideX + 3 * s, curY + 3 * s, "SCORE:" .. score, ui.C.BLACK, s)
    ui.drawText(sideX + 3 * s, curY + 12 * s, "BEST:" .. bestScore, ui.C.LUNA_BLUE, s)
    curY = curY + 28 * s

    -- Допоміжна функція для малювання піксельних трикутників-стрілок
    local function drawArrow(bx, by, bw, bh, dirName)
        local acx = bx + math.floor(bw / 2)
        local acy = by + math.floor(bh / 2)
        local sz = 3 * s
        local half = math.floor(sz / 2)
        for i = 0, sz - 1 do
            if dirName == "up" then
                ui.fillRect(acx - i, acy - half + i, i * 2 + 1, 1, ui.C.WHITE)
            elseif dirName == "down" then
                ui.fillRect(acx - i, acy + half - i, i * 2 + 1, 1, ui.C.WHITE)
            elseif dirName == "left" then
                ui.fillRect(acx - half + i, acy - i, 1, i * 2 + 1, ui.C.WHITE)
            elseif dirName == "right" then
                ui.fillRect(acx + half - i, acy - i, 1, i * 2 + 1, ui.C.WHITE)
            end
        end
    end

    -- Хрестовина керування (D-Pad)
    local btnW = math.floor((sideW - 4) / 3)
    local btnH = 12 * s

    local upX, upY = sideX + btnW + 2, curY
    ui.drawButton(buttons, upX, upY, btnW, btnH, ui.C.LUNA_BLUE, ui.C.NAVY, "", ui.C.WHITE, function()
        setDirection(0, -1)
    end, s)
    drawArrow(upX, upY, btnW, btnH, "up")
    curY = curY + btnH + 2

    local leftX, leftY = sideX, curY
    ui.drawButton(buttons, leftX, leftY, btnW, btnH, ui.C.LUNA_BLUE, ui.C.NAVY, "", ui.C.WHITE, function()
        setDirection(-1, 0)
    end, s)
    drawArrow(leftX, leftY, btnW, btnH, "left")

    local rightX, rightY = sideX + btnW * 2 + 4, curY
    ui.drawButton(buttons, rightX, rightY, btnW, btnH, ui.C.LUNA_BLUE, ui.C.NAVY, "", ui.C.WHITE, function()
        setDirection(1, 0)
    end, s)
    drawArrow(rightX, rightY, btnW, btnH, "right")
    curY = curY + btnH + 2

    local downX, downY = sideX + btnW + 2, curY
    ui.drawButton(buttons, downX, downY, btnW, btnH, ui.C.LUNA_BLUE, ui.C.NAVY, "", ui.C.WHITE, function()
        setDirection(0, 1)
    end, s)
    drawArrow(downX, downY, btnW, btnH, "down")
    curY = curY + btnH + 6 * s

    -- Кнопки NEW та PAUSE
    local actH = 10 * s + 2
    ui.drawButton(buttons, sideX, curY, sideW, actH, ui.C.START_GREEN, ui.C.START_LIGHT, "NEW", ui.C.WHITE, function()
        resetGame()
    end, s)
    curY = curY + actH + 3 * s

    ui.drawButton(buttons, sideX, curY, sideW, actH, ui.C.GOLD, ui.C.WHITE, paused and "PLAY" or "PAUSE", ui.C.BLACK, function()
        if not gameOver then paused = not paused end
    end, s)

    ui.drawTaskbar(buttons, function() exitApp = true end, nil)
    ui.mon.setFrozen(false)
end

-- Початкова ініціалізація розмірів поля
local initCx, initCy, initCw, initCh = ui.drawWindow({}, "SNAKE XP", nil)
calcLayout(initCx, initCy, initCw, initCh)
resetGame()

local tickDelay = 0.22
local gameTimer = os.startTimer(tickDelay)

while not exitApp do
    renderGame()
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "monitor_resize" then
        ui.init()
        local ncx, ncy, ncw, nch = ui.drawWindow({}, "SNAKE XP", nil)
        calcLayout(ncx, ncy, ncw, nch)
        resetGame()
    elseif ev == "timer" and p1 == gameTimer then
        stepGame()
        local speed = math.max(0.09, tickDelay - math.floor(score / 50) * 0.02)
        gameTimer = os.startTimer(speed)
    elseif ev == "monitor_touch" then
        local px, py = ui.touchToPixel(p2, p3)
        for _, btn in ipairs(buttons) do
            if px >= btn.x1 and px <= btn.x2 and py >= btn.y1 and py <= btn.y2 then
                btn.onClick(px, py)
                break
            end
        end
    elseif ev == "key" then
        if p1 == keys.up or p1 == keys.w then setDirection(0, -1)
        elseif p1 == keys.down or p1 == keys.s then setDirection(0, 1)
        elseif p1 == keys.left or p1 == keys.a then setDirection(-1, 0)
        elseif p1 == keys.right or p1 == keys.d then setDirection(1, 0)
        elseif p1 == keys.space then
            if gameOver then resetGame() else paused = not paused end
        end
    end
end
