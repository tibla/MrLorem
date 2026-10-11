----------------------------------------------------------------
-- ГЛОБАЛЬНАЯ ТАБЛИЦА И ОЧИСТКА
----------------------------------------------------------------
_G.GH_Cache = _G.GH_Cache or {}
_G.GH_Cache.events = _G.GH_Cache.events or {}
_G.GH_Cache.binds = _G.GH_Cache.binds or {}
_G.GH_Cache.gui = _G.GH_Cache.gui or {}
_G.GH_Cache.timers = _G.GH_Cache.timers or {}

-- Если ранее была загружена старая версия панели, аккуратно убираем её UI.
if type(fullCleanup) == "function" then
    pcall(fullCleanup)
end

local bindsData = {}
local waitingForBind = nil
local autoMode = false
local autoTimer = nil
local speedBoostTimer = nil
local speedBoostActive = false

local function cacheEvent(name, fn)
    _G.GH_Cache.events[name] = { root = root, fn = fn }
end

function fullCleanup()
    -- 1. Удаляем главное окно
    if isElement(mainWin) then destroyElement(mainWin) end
    
    -- 2. Снимаем все бинды кнопок
    for btn, data in pairs(bindsData) do
        if data.key then unbindKey(data.key, "down", data.fn) end
    end
    unbindKey("f9", "down")
    unbindKey("]", "down")
    unbindKey("lshift", "down")
    unbindKey("lshift", "up")
    
    -- 3. Очищаем активные таймеры
    if isTimer(autoTimer) then killTimer(autoTimer) end
    if isTimer(speedBoostTimer) then killTimer(speedBoostTimer) end
    speedBoostTimer = nil
    speedBoostActive = false
    for _, timer in pairs(_G.GH_Cache.timers) do
        if isTimer(timer) then killTimer(timer) end
    end
    
    -- 4. Удаляем рендеры и события
    for eventName, data in pairs(_G.GH_Cache.events) do
        removeEventHandler(eventName, data.root, data.fn)
    end
    if _G.GH_Cache.keyHandler then
        removeEventHandler("onClientKey", root, _G.GH_Cache.keyHandler)
    end
    
    -- 5. Очистка кэша
    _G.GH_Cache.events = {}
    _G.GH_Cache.timers = {}
    bindsData = {}
    waitingForBind = nil
    
    showCursor(false)
    outputChatBox("[Engine] #FFFF00Скрипт полностью выгружен.", 255, 255, 255, true)
end

----------------------------------------------------------------
-- ЛОГИКА БИНДЕРА (КЛИК ПО КВАДРАТУ)
----------------------------------------------------------------
local function keyBindInterceptor(button, press)
    if not press or not waitingForBind then return end
    cancelEvent()
    
    local data = bindsData[waitingForBind]
    if data.key then unbindKey(data.key, "down", data.fn) end
    
    if button == "escape" or button == "backspace" then
        data.key = nil
        guiSetText(waitingForBind, "?")
        outputChatBox("Бинд удален", 255, 0, 0)
    else
        data.key = button
        guiSetText(waitingForBind, string.upper(button))
        bindKey(button, "down", data.fn)
        outputChatBox("Забинджено на: " .. string.upper(button), 0, 255, 0)
    end
    waitingForBind = nil
end
addEventHandler("onClientKey", root, keyBindInterceptor)
_G.GH_Cache.keyHandler = keyBindInterceptor

----------------------------------------------------------------
-- ИНТЕРФЕЙС
----------------------------------------------------------------
local screenW, screenH = guiGetScreenSize()
-- Размер и расположение сделаны по дизайну из прикреплённого CEGUI-варианта.
-- Ограничение по экрану оставляем, чтобы окно не обрезалось на маленьком разрешении.
local windowW, windowH = 750, 720
windowW = math.min(windowW, screenW - 40)
windowH = math.min(windowH, screenH - 40)
local x = math.max(20, (screenW - windowW) / 2)
local y = math.max(20, (screenH - windowH) / 2)

mainWin = guiCreateWindow(
    x,
    y,
    windowW,
    windowH,
    "MR.Lorem | Control Panel",
    false
)

guiWindowSetSizable(mainWin, false)
guiWindowSetMovable(mainWin, true)
guiSetVisible(mainWin, false)

-- Создаём панель вкладок
local tabPanel = guiCreateTabPanel(
    10,
    25,
    windowW - 20,
    windowH - 40,
    false,
    mainWin
)

-- Вкладка «Приколы»
local tabFun = guiCreateTab(
    "Приколы",
    tabPanel
)

local scrollFun = guiCreateScrollPane(
    5,
    5,
    windowW - 30,
    windowH - 80,
    false,
    tabFun
)
guiScrollPaneSetScrollBars(scrollFun, false, true)
local colY = {
    left = 10,
    center = 10,
    right = 10
}

local columnX = {
    left = 10,
    center = 250,
    right = 490
}


local function addActionButton(
    parent,
    columns,
    name,
    fn,
    side,
    defaultKey
)
    side = side or "left"

    local layoutSide = side

    local posX = columnX[layoutSide] or columnX.left
    local posY = columns[layoutSide] or columns.left

    local actionButton = guiCreateButton(
        posX,
        posY,
        185,
        35,
        name,
        false,
        parent
    )

    local bindButton = guiCreateButton(
        posX + 190,
        posY,
        40,
        35,
        defaultKey and string.upper(defaultKey) or "?",
        false,
        parent
    )

    bindsData[bindButton] = {
        fn = fn,
        key = defaultKey,
        name = name
    }

    if defaultKey then
        bindKey(
            defaultKey,
            "down",
            fn
        )
    end

    addEventHandler(
        "onClientGUIClick",
        actionButton,
        function()
            if not waitingForBind then
                fn()
            end
        end,
        false
    )

    addEventHandler(
        "onClientGUIClick",
        bindButton,
        function()
            if waitingForBind
                and bindsData[waitingForBind]
            then
                local previous =
                    bindsData[waitingForBind].key

                guiSetText(
                    waitingForBind,
                    previous
                        and string.upper(previous)
                        or "?"
                )
            end

            waitingForBind = source
            guiSetText(source, "...")

            outputChatBox(
                "Нажми клавишу для бинда.",
                255,
                255,
                0
            )
        end,
        false
    )

    columns[layoutSide] = posY + 43
end


local function addMenuButton(
    name,
    fn,
    side,
    defaultKey
)
    addActionButton(
        scrollFun,
        colY,
        name,
        fn,
        side,
        defaultKey
    )
end
bindKey("f9", "down", function()
    local visible = not guiGetVisible(mainWin)

    guiSetVisible(mainWin, visible)
    showCursor(visible)
    guiSetInputEnabled(visible)
end)

outputChatBox(
    "[Engine] F9 готов!",
    0,
    255,
    0
)
----------------------------------------------------------------
-- НАСТРОЙКИ FLY
----------------------------------------------------------------

local flyConfig = {
    playerSpeed = 0.6,
    playerBoost = 2.5,

    carSpeed = 0.8,
    carBoost = 2.5,

    hidePlayer = false,
    hideVehicle = false,

    disableCarCollisions = false,
    restorePosition = true
}

local toolConfig = {
    speedBoostMultiplier = 1.20,
    speedBoostMode = "hold",
    tpTake = { x = 483.034, y = -1004.596, z = 21.436 },
    tpPut = { x = 776.723, y = -1581.878, z = 47.749 }
}

-- Сохраняем настройки в общей таблице, чтобы они не сбрасывались при переинжекте.
local savedSettings = _G.GH_Cache.settings or {}
if type(savedSettings.fly) == "table" then
    for key, value in pairs(savedSettings.fly) do
        if flyConfig[key] ~= nil and type(value) == type(flyConfig[key]) then
            flyConfig[key] = value
        end
    end
end

if type(savedSettings.tools) == "table" then
    if tonumber(savedSettings.tools.speedBoostMultiplier) then
        toolConfig.speedBoostMultiplier = tonumber(savedSettings.tools.speedBoostMultiplier)
    end

    if savedSettings.tools.speedBoostMode == "hold" or savedSettings.tools.speedBoostMode == "press" then
        toolConfig.speedBoostMode = savedSettings.tools.speedBoostMode
    end

    for _, pointName in ipairs({ "tpTake", "tpPut" }) do
        if type(savedSettings.tools[pointName]) == "table" then
            for _, axis in ipairs({ "x", "y", "z" }) do
                if tonumber(savedSettings.tools[pointName][axis]) then
                    toolConfig[pointName][axis] = tonumber(savedSettings.tools[pointName][axis])
                end
            end
        end
    end
end

local flySavedAlpha = {}

local function setFlyHidden(element, state)
    if not isElement(element) then
        return
    end

    if state then
        if flySavedAlpha[element] == nil then
            flySavedAlpha[element] = getElementAlpha(element)
        end

        setElementAlpha(element, 0)
    else
        if flySavedAlpha[element] ~= nil then
            setElementAlpha(element, flySavedAlpha[element])
            flySavedAlpha[element] = nil
        end
    end
end


----------------------------------------------------------------
-- ФУНКЦИИ ESP
----------------------------------------------------------------
local ESP_MAX_DISTANCE = 300 
local COLOR_RED = tocolor(255, 0, 0, 255) 
local COLOR_STOKE = tocolor(0, 0, 0, 220) 
local espEnabled = false

local function drawPlayerESP()
    local px, py, pz = getElementPosition(localPlayer)
    local sw, sh = guiGetScreenSize()
    local currentInterior = getElementInterior(localPlayer)
    local currentDimension = getElementDimension(localPlayer)

    for _, player in ipairs(getElementsByType("player", root, true)) do
        if player ~= localPlayer and not isPedDead(player) then
            if getElementInterior(player) == currentInterior and getElementDimension(player) == currentDimension then
                local x, y, z = getElementPosition(player)
                local dist = getDistanceBetweenPoints3D(px, py, pz, x, y, z)

                if dist <= ESP_MAX_DISTANCE and isElementOnScreen(player) then
                    local sx, sy = getScreenFromWorldPosition(x, y, z + 1.1)

                    if sx and sy then
                        local name = getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
                        local text = string.format("%s\n[%.0fm]", name, dist)

                        dxDrawText(text, sx + 1, sy + 1, sx + 1, sy + 1, COLOR_STOKE, 1, "default-bold", "center", "center")
                        dxDrawText(text, sx - 1, sy - 1, sx - 1, sy - 1, COLOR_STOKE, 1, "default-bold", "center", "center")
                        
                        dxDrawText(text, sx, sy, sx, sy, COLOR_RED, 1, "default-bold", "center", "center")
                        dxDrawLine(sw / 2, sh, sx, sy, COLOR_RED, 1)
                    end
                end
            end
        end
    end
end

function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        addEventHandler("onClientRender", root, drawPlayerESP)
        outputChatBox("[ESP] #00FF00Включен (0-300м)", 255, 255, 255, true)
    else
        removeEventHandler("onClientRender", root, drawPlayerESP)
        outputChatBox("[ESP] #FF0000Выключен", 255, 255, 255, true)
    end
end
cacheEvent("toggleESP", toggleESP)

----------------------------------------------------------------
-- ОСНОВНЫЕ ФУНКЦИИ
----------------------------------------------------------------
local function teleportEntity(entity, x, y, z)
    local target = getPedOccupiedVehicle(entity) or entity
    setElementPosition(target, x, y, z)
    if getElementType(target) == "vehicle" then
        setElementVelocity(target, 0, 0, 0)
    end
end

function teleportToWaypoint()
    local waypoint = false
    for _, v in ipairs(getElementsByType("blip")) do
        if getBlipIcon(v) == 41 then
            waypoint = v
            break
        end
    end

    if not waypoint then
        outputChatBox("Поставь метку на карте (ПКМ)")
        return
    end

    local x, y, z = getElementPosition(waypoint)
    local safeZ = nil
    local startZ = 1000

    for i = startZ, 0, -25 do
        local gz = getGroundPosition(x, y, i)
        if gz and gz > 0 then
            safeZ = gz + 1
            break
        end
    end

    if not safeZ then safeZ = z + 5 end

    if localPlayer.vehicle then
        setElementPosition(localPlayer.vehicle, x, y, safeZ + 50)
    else
        setElementPosition(localPlayer, x, y, safeZ + 50)
    end

    setTimer(function()
        if localPlayer.vehicle then
            setElementPosition(localPlayer.vehicle, x, y, safeZ)
        else
            setElementPosition(localPlayer, x, y, safeZ)
        end
    end, 200, 1)
end

function tpTake()
    teleportEntity(localPlayer, toolConfig.tpTake.x, toolConfig.tpTake.y, toolConfig.tpTake.z)
    outputChatBox("[Engine] #00FF00ТП на точку 'Взять' (с машиной)!", 255, 255, 255, true)
end

function tpPut()
    teleportEntity(localPlayer, toolConfig.tpPut.x, toolConfig.tpPut.y, toolConfig.tpPut.z)
    outputChatBox("[Engine] #00FF00ТП на точку 'Положить' (с машиной)!", 255, 255, 255, true)
end
function rielt()
    triggerServerEvent ( "PlayerEnterToRealtor", root, 1 )
    outputChatBox("[Engine] #00FF00ТП на rielt", 255, 255, 255, true)
end

function repairVehicle()
    local veh = getPedOccupiedVehicle(localPlayer)
    if veh then 
        fixVehicle(veh) 
        outputChatBox("[Engine] #00FF00Транспорт успешно починен!", 255, 255, 255, true)
    else
        outputChatBox("[Engine] #FF0000Вы должны быть в машине!", 255, 255, 255, true)
    end
end

function copyCoords()
    local px, py, pz = getElementPosition(localPlayer)
    local str = string.format("%.3f, %.3f, %.3f", px, py, pz)
    setClipboard(str)
    outputChatBox("[Engine] : " .. str, 255, 255, 255, true)
    outputChatBox("[Engine] #00FF00Координаты скопированы в буфер!", 255, 255, 255, true)
end

function treasuress()
local treasures = {
    { id = 1, x = -1585.68, y = -2906.87, z = 18.05 },
    { id = 2, x = -2431.30, y = -2730.91, z = 14.63 },
    { id = 3, x = -2772.66, y = 2623.64, z = 24.15 },
    { id = 4, x = -2824.86, y = 553.39, z = 29.91 },
    { id = 5, x = -2542.85, y = -147.93, z = 3.11 },
    { id = 6, x = -1960.69, y = 1280.13, z = 16.92 },
    { id = 7, x = -1657.90, y = 2625.20, z = 10.24 },
    { id = 8, x = 2224.21, y = 2852.88, z = 21.19 },
    { id = 9, x = 1106.93, y = 2081.60, z = 17.49 },
    { id = 10, x = 2743.70, y = 836.65, z = 1.94 },
    { id = 11, x = 2560.37, y = -28.48, z = 9.14 },
    { id = 12, x = 1398.96, y = -2793.51, z = 18.16 },
    { id = 13, x = 703.70, y = -2010.72, z = 23.12 },
    { id = 14, x = 2110.15, y = -473.74, z = 9.71 },
    { id = 15, x = 26.14, y = 2025.76, z = 28.84 },
    { id = 16, x = -2490.71, y = 4530.74, z = 3.14 },
    { id = 17, x = -2198.66, y = 4529.76, z = 3.29 },
    { id = 18, x = -2267.13, y = 4536.75, z = 3.25 },
    { id = 19, x = -2613.60, y = 3752.97, z = 2.78 },
    { id = 20, x = -2699.43, y = 4091.84, z = 3.00 },
    { id = 21, x = -2646.73, y = 3698.95, z = 3.00 },
    { id = 22, x = -2760.94, y = 3902.06, z = 3.01 },
    { id = 23, x = -2776.93, y = 3899.85, z = 3.00 },
    { id = 24, x = -2700.62, y = 3967.84, z = 3.37 },
    { id = 25, x = -2700.20, y = 3978.26, z = 3.35 },
    { id = 26, x = -2594.87, y = 3687.80, z = 3.00 },
    { id = 27, x = -2028.65, y = 3482.02, z = 10.32 },
    { id = 28, x = -2232.45, y = 4474.95, z = 3.25 },
    { id = 29, x = -2287.96, y = 4489.63, z = 3.35 },
    { id = 30, x = -2432.91, y = 3619.46, z = 3.00 },
}

local found = false

for _, blip in ipairs(getElementsByType("blip")) do
    if getBlipIcon(blip) == 38 then

        local bx, by, bz = getElementPosition(blip)

        for _, treasure in ipairs(treasures) do
            local dist = getDistanceBetweenPoints3D(
                bx, by, bz,
                treasure.x, treasure.y, treasure.z
            )

            if dist <= 40 then
                setElementPosition(
                    localPlayer,
                    treasure.x,
                    treasure.y,
                    treasure.z + 1
                )

                outputChatBox("Телепорт к кладу ID: " .. treasure.id)

                found = true
                break
            end
        end

        if found then
            break
        end
    end
end

if not found then
    outputChatBox("Клад рядом с blip 38 не найден")
end
end
cacheEvent("treasuress", treasuress)

function buyRepairKit()
    triggerServerEvent("Gasstation:BuyItems", root, 1, "gasstation_14")
    outputChatBox("[Engine] #00FF00Запрос на ремкомплект отправлен!", 255, 255, 255, true)
end

function buyMedKit()
    triggerServerEvent("Shop:PlayerWantBuyItem", root, {basket={[5]=1}, business_id="drugstore_5", type_pay=1, type_product=4})
    outputChatBox("[Engine] #00FF00Запрос на аптечку отправлен!", 255, 255, 255, true)
end
function buylunch()
 triggerServerEvent ( "Shop:PlayerWantBuyItem", root, {
    basket = {
      [5] = 1
    },
    business_id = "shop_10",
    type_pay = 1,
    type_product = 1
  } )
    outputChatBox("[Engine] #00FF00Запрос на Ланч отправлен!", 255, 255, 255, true)
end

----------------------------------------------------------------
-- FREECAM
----------------------------------------------------------------
local freecamEnabled = false
local camX, camY, camZ = 0, 0, 3
local camRotX, camRotY = 0, 0
local speed = 0.7
local sensitivity = 0.2

function freecamMouseMove(_, _, aX, aY)
    if not freecamEnabled then return end
    local screenW, screenH = guiGetScreenSize()
    local centerX, centerY = screenW / 2, screenH / 2
    local diffX = aX - centerX
    local diffY = aY - centerY

    camRotY = camRotY - diffX * sensitivity
    camRotX = camRotX - diffY * sensitivity

    if camRotX > 89 then camRotX = 89 end
    if camRotX < -89 then camRotX = -89 end

    setCursorPosition(centerX, centerY)
end

function updateFreecam()
    if not freecamEnabled then return end

    local currentSpeed = speed
    if getKeyState("lshift") then currentSpeed = speed * 1.5 end

    local radZ = math.rad(camRotY)
    local radX = math.rad(camRotX)

    local fX = math.cos(radX) * math.cos(radZ)
    local fY = math.cos(radX) * math.sin(radZ)
    local fZ = math.sin(radX)

    if getKeyState("w") then camX, camY, camZ = camX + fX * currentSpeed, camY + fY * currentSpeed, camZ + fZ * currentSpeed end
    if getKeyState("s") then camX, camY, camZ = camX - fX * currentSpeed, camY - fY * currentSpeed, camZ - fZ * currentSpeed end
    if getKeyState("a") then
        camX = camX + math.cos(radZ + math.rad(90)) * currentSpeed
        camY = camY + math.sin(radZ + math.rad(90)) * currentSpeed
    end
    if getKeyState("d") then
        camX = camX - math.cos(radZ + math.rad(90)) * currentSpeed
        camY = camY - math.sin(radZ + math.rad(90)) * currentSpeed
    end
    if getKeyState("space") then camZ = camZ + currentSpeed end
    if getKeyState("lctrl") then camZ = camZ - currentSpeed end

    setCameraMatrix(camX, camY, camZ, camX + fX, camY + fY, camZ + fZ)
end

function toggleFreecam()
    freecamEnabled = not freecamEnabled
    
    if freecamEnabled then
        camX, camY, camZ = getCameraMatrix()
        
        setElementFrozen(localPlayer, true)
        setElementAlpha(localPlayer, 0)
        showCursor(false)
        setCursorAlpha(0)
        toggleAllControls(false, true, false)

        addEventHandler("onClientRender", root, updateFreecam)
        addEventHandler("onClientCursorMove", root, freecamMouseMove)
        
        cacheEvent("freecamUpdate", updateFreecam)
        cacheEvent("freecamMouse", freecamMouseMove)
        
        outputChatBox("[Engine] #00FF00FreeCam ON", 255, 255, 255, true)
    else
        removeEventHandler("onClientRender", root, updateFreecam)
        removeEventHandler("onClientCursorMove", root, freecamMouseMove)
        
        _G.GH_Cache.events["freecamUpdate"] = nil
        _G.GH_Cache.events["freecamMouse"] = nil

        setElementFrozen(localPlayer, false)
        setElementAlpha(localPlayer, 255)
        setCursorAlpha(255)
        toggleAllControls(true)
        setCameraTarget(localPlayer) 
        
        outputChatBox("[Engine] #FF0000FreeCam OFF", 255, 255, 255, true)
    end
end

----------------------------------------------------------------
-- FLY НА ПЕРСОНАЖЕ
----------------------------------------------------------------

local noclip = false
local lastPos = { x = 0, y = 0, z = 0 }

function fly()
    local vehicle = getPedOccupiedVehicle(localPlayer)

    if vehicle then
        outputChatBox("❌ Нельзя включить fly в машине!", 255, 0, 0)
        return
    end

    noclip = not noclip

    if noclip then
        setElementFrozen(localPlayer, true)
        setElementCollisionsEnabled(localPlayer, false)
        setFlyHidden(localPlayer, flyConfig.hidePlayer)
        outputChatBox("[Fly] #00FF00Включён!", 255, 255, 255, true)
    else
        setElementFrozen(localPlayer, false)
        setElementCollisionsEnabled(localPlayer, true)
        setFlyHidden(localPlayer, false)

        if flyConfig.restorePosition then
            setElementPosition(localPlayer, lastPos.x, lastPos.y, lastPos.z)
        end

        outputChatBox("[Fly] #FF0000Выключен!", 255, 255, 255, true)
    end
end

local function flyRender()
    if not noclip or not isElement(localPlayer) then return end

    local x, y, z = getElementPosition(localPlayer)
    lastPos.x, lastPos.y, lastPos.z = x, y, z

    setFlyHidden(localPlayer, flyConfig.hidePlayer)

    local camX, camY, camZ, lookX, lookY, lookZ = getCameraMatrix()
    local dx, dy, dz = lookX - camX, lookY - camY, lookZ - camZ
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)

    if length <= 0 then return end
    dx, dy, dz = dx / length, dy / length, dz / length

    local currentSpeed = flyConfig.playerSpeed
    if getKeyState("lshift") then currentSpeed = currentSpeed * flyConfig.playerBoost end

    if getKeyState("w") then x, y, z = x + dx * currentSpeed, y + dy * currentSpeed, z + dz * currentSpeed end
    if getKeyState("s") then x, y, z = x - dx * currentSpeed, y - dy * currentSpeed, z - dz * currentSpeed end

    local rightX, rightY = dy, -dx
    if getKeyState("a") then x, y = x - rightX * currentSpeed, y - rightY * currentSpeed end
    if getKeyState("d") then x, y = x + rightX * currentSpeed, y + rightY * currentSpeed end
    if getKeyState("space") then z = z + currentSpeed end
    if getKeyState("lctrl") then z = z - currentSpeed end

    setElementPosition(localPlayer, x, y, z)
    setElementRotation(localPlayer, 0, 0, math.deg(math.atan2(dy, dx)) - 90)
end

addEventHandler("onClientRender", root, flyRender)
cacheEvent("flyRender", flyRender)

----------------------------------------------------------------
-- FLY НА МАШИНЕ
----------------------------------------------------------------

local flycarEnabled = false
local flycarVehicle = nil

local function stopFlyCar()
    if not flycarEnabled then return end

    if flycarVehicle and isElement(flycarVehicle) then
        setElementFrozen(flycarVehicle, false)
        setElementCollisionsEnabled(flycarVehicle, true)
        setFlyHidden(flycarVehicle, false)
    end

    setFlyHidden(localPlayer, false)
    flycarEnabled = false
    flycarVehicle = nil

    outputChatBox("[FlyCar] #FF0000Выключен!", 255, 255, 255, true)
end

function flycar()
    local vehicle = getPedOccupiedVehicle(localPlayer)

    if flycarEnabled then
        stopFlyCar()
        return
    end

    if not vehicle then
        outputChatBox("❌ Вы должны находиться в машине!", 255, 0, 0)
        return
    end

    if getVehicleController(vehicle) ~= localPlayer then
        outputChatBox("❌ Вы должны быть водителем!", 255, 0, 0)
        return
    end

    flycarEnabled = true
    flycarVehicle = vehicle

    setElementFrozen(vehicle, true)
    setElementCollisionsEnabled(vehicle, not flyConfig.disableCarCollisions)
    setFlyHidden(vehicle, flyConfig.hideVehicle)
    setFlyHidden(localPlayer, flyConfig.hidePlayer or flyConfig.hideVehicle)

    outputChatBox("[FlyCar] #00FF00Включён!", 255, 255, 255, true)
end

local function flyCarRender()
    if not flycarEnabled then return end

    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle or getVehicleController(vehicle) ~= localPlayer then
        stopFlyCar()
        return
    end

    if flycarVehicle ~= vehicle then
        if flycarVehicle and isElement(flycarVehicle) then
            setElementFrozen(flycarVehicle, false)
            setElementCollisionsEnabled(flycarVehicle, true)
            setFlyHidden(flycarVehicle, false)
        end
        flycarVehicle = vehicle
        setElementFrozen(vehicle, true)
    end

    setFlyHidden(vehicle, flyConfig.hideVehicle)
    setFlyHidden(localPlayer, flyConfig.hidePlayer or flyConfig.hideVehicle)
    setElementCollisionsEnabled(vehicle, not flyConfig.disableCarCollisions)

    local x, y, z = getElementPosition(vehicle)
    local camX, camY, camZ, lookX, lookY, lookZ = getCameraMatrix()
    local dx, dy, dz = lookX - camX, lookY - camY, lookZ - camZ
    local length = math.sqrt(dx * dx + dy * dy + dz * dz)

    if length <= 0 then return end
    dx, dy, dz = dx / length, dy / length, dz / length

    local currentSpeed = flyConfig.carSpeed
    if getKeyState("lshift") then currentSpeed = currentSpeed * flyConfig.carBoost end

    if getKeyState("w") then x, y, z = x + dx * currentSpeed, y + dy * currentSpeed, z + dz * currentSpeed end
    if getKeyState("s") then x, y, z = x - dx * currentSpeed, y - dy * currentSpeed, z - dz * currentSpeed end

    local rightX, rightY = dy, -dx
    if getKeyState("a") then x, y = x - rightX * currentSpeed, y - rightY * currentSpeed end
    if getKeyState("d") then x, y = x + rightX * currentSpeed, y + rightY * currentSpeed end
    if getKeyState("space") then z = z + currentSpeed end
    if getKeyState("lctrl") then z = z - currentSpeed end

    setElementPosition(vehicle, x, y, z)
    setElementRotation(vehicle, math.deg(math.asin(dz)), 0, -math.deg(math.atan2(dx, dy)))
    setVehicleTurnVelocity(vehicle, 0, 0, 0)
end

addEventHandler("onClientRender", root, flyCarRender)
cacheEvent("flyCarRender", flyCarRender)

local jeka  = 8575
local denis = 8854

function autoschool()
local duration = 5000 
local interval = 50   
local heightOffset = 50 

outputChatBox("Авто-телепорт включен на 5 секунд...")

local teleportTimer = setTimer(function()
    local veh = getPedOccupiedVehicle(localPlayer)
    local found = false

    for _, marker in ipairs(getElementsByType("marker")) do
        if getMarkerType(marker) == "checkpoint" then
            local x, y, z = getElementPosition(marker)
            local targetZ = z + heightOffset

            if veh then
                setElementPosition(veh, x, y, targetZ)
                setElementVelocity(veh, 0, 0, 0)
                setVehicleTurnVelocity(veh, 0, 0, 0)
            end

            setElementPosition(localPlayer, x, y, targetZ)
            found = true
            break
        end
    end

    if not found then
        outputChatBox("Маркер не найден!")
    end
end, interval, duration / interval)

setTimer(function()
    outputChatBox("Действие телепорта окончено.")
end, duration, 1)
end
cacheEvent("autoschool", autoschool)

function getPlayerByTextID(id)
    local pid = "p" .. id
    for _, player in ipairs(getElementsByType("player")) do
        if getElementID(player) == pid then return player end
    end
    return false
end

----------------------------------------------------------------
-- ВКЛАДКА НАСТРОЙКИ
----------------------------------------------------------------
local tabFlySettings = guiCreateTab("Настройка", tabPanel)

local flyTitle = guiCreateLabel(18, 12, 450, 22, "Настройка функций", false, tabFlySettings)
guiSetFont(flyTitle, "default-bold-small")
guiLabelSetColor(flyTitle, 85, 182, 255)

local flyHint = guiCreateLabel(18, 35, 730, 18, "Здесь можно изменить Fly, FlyCar, speedBoost и координаты телепортов. Координаты указаны в порядке X, Y, Z.", false, tabFlySettings)
guiSetFont(flyHint, "default-small")
guiLabelSetColor(flyHint, 140, 160, 185)

local flyPlayerTitle = guiCreateLabel(18, 70, 320, 18, "Персонаж", false, tabFlySettings)
guiSetFont(flyPlayerTitle, "default-bold-small")
guiLabelSetColor(flyPlayerTitle, 87, 228, 157)

guiCreateLabel(20, 100, 220, 25, "Скорость fly персонажа:", false, tabFlySettings)
local editPlayerSpeed = guiCreateEdit(250, 97, 120, 28, tostring(flyConfig.playerSpeed), false, tabFlySettings)
guiSetFont(editPlayerSpeed, "default-small")

guiCreateLabel(20, 140, 220, 25, "Ускорение Shift:", false, tabFlySettings)
local editPlayerBoost = guiCreateEdit(250, 137, 120, 28, tostring(flyConfig.playerBoost), false, tabFlySettings)
guiSetFont(editPlayerBoost, "default-small")

local flyCarTitle = guiCreateLabel(400, 70, 320, 18, "Машина", false, tabFlySettings)
guiSetFont(flyCarTitle, "default-bold-small")
guiLabelSetColor(flyCarTitle, 167, 120, 255)

guiCreateLabel(400, 100, 190, 25, "Скорость fly машины:", false, tabFlySettings)
local editCarSpeed = guiCreateEdit(610, 97, 110, 28, tostring(flyConfig.carSpeed), false, tabFlySettings)
guiSetFont(editCarSpeed, "default-small")

guiCreateLabel(400, 140, 190, 25, "Ускорение машины на Shift:", false, tabFlySettings)
local editCarBoost = guiCreateEdit(610, 137, 110, 28, tostring(flyConfig.carBoost), false, tabFlySettings)
guiSetFont(editCarBoost, "default-small")

local flyOptionsTitle = guiCreateLabel(18, 205, 320, 18, "Дополнительные опции", false, tabFlySettings)
guiSetFont(flyOptionsTitle, "default-bold-small")
guiLabelSetColor(flyOptionsTitle, 255, 188, 90)

local checkHidePlayer = guiCreateCheckBox(20, 235, 350, 25, "Скрывать персонажа во время fly", flyConfig.hidePlayer, false, tabFlySettings)
local checkHideVehicle = guiCreateCheckBox(20, 270, 350, 25, "Скрывать машину во время flycar", flyConfig.hideVehicle, false, tabFlySettings)
local checkNoCollision = guiCreateCheckBox(20, 305, 350, 25, "Отключать столкновения машины", flyConfig.disableCarCollisions, false, tabFlySettings)
local checkRestorePosition = guiCreateCheckBox(20, 340, 350, 25, "Возвращать позицию после выключения fly", flyConfig.restorePosition, false, tabFlySettings)

local speedBoostTitle = guiCreateLabel(400, 205, 300, 18, "speedBoost", false, tabFlySettings)
guiSetFont(speedBoostTitle, "default-bold-small")
guiLabelSetColor(speedBoostTitle, 255, 188, 90)

guiCreateLabel(400, 235, 190, 25, "Множитель скорости:", false, tabFlySettings)
local editSpeedBoost = guiCreateEdit(610, 232, 110, 28, tostring(toolConfig.speedBoostMultiplier), false, tabFlySettings)
guiSetFont(editSpeedBoost, "default-small")

local speedBoostHold = guiCreateRadioButton(400, 270, 250, 22, "Удерживать LShift", false, tabFlySettings)
local speedBoostPress = guiCreateRadioButton(400, 295, 250, 22, "Одно нажатие LShift", false, tabFlySettings)
guiRadioButtonSetSelected(speedBoostHold, toolConfig.speedBoostMode == "hold")
guiRadioButtonSetSelected(speedBoostPress, toolConfig.speedBoostMode == "press")

local teleportTitle = guiCreateLabel(18, 390, 350, 18, "Координаты телепортов", false, tabFlySettings)
guiSetFont(teleportTitle, "default-bold-small")
guiLabelSetColor(teleportTitle, 87, 228, 157)

guiCreateLabel(20, 420, 90, 25, "ТП Взять:", false, tabFlySettings)
local editTakeX = guiCreateEdit(115, 417, 75, 28, tostring(toolConfig.tpTake.x), false, tabFlySettings)
local editTakeY = guiCreateEdit(200, 417, 75, 28, tostring(toolConfig.tpTake.y), false, tabFlySettings)
local editTakeZ = guiCreateEdit(285, 417, 75, 28, tostring(toolConfig.tpTake.z), false, tabFlySettings)

guiCreateLabel(20, 455, 90, 25, "ТП База:", false, tabFlySettings)
local editPutX = guiCreateEdit(115, 452, 75, 28, tostring(toolConfig.tpPut.x), false, tabFlySettings)
local editPutY = guiCreateEdit(200, 452, 75, 28, tostring(toolConfig.tpPut.y), false, tabFlySettings)
local editPutZ = guiCreateEdit(285, 452, 75, 28, tostring(toolConfig.tpPut.z), false, tabFlySettings)

for _, edit in ipairs({ editTakeX, editTakeY, editTakeZ, editPutX, editPutY, editPutZ }) do
    guiSetFont(edit, "default-small")
end

local btnApplyFlySettings = guiCreateButton(400, 420, 320, 40, "Применить настройки", false, tabFlySettings)

local function getNumberFromEdit(edit, oldValue, minValue, maxValue)
    local value = tonumber(guiGetText(edit))
    if not value then return oldValue end
    return math.max(minValue, math.min(maxValue, value))
end

addEventHandler("onClientGUIClick", btnApplyFlySettings, function()
    flyConfig.playerSpeed = getNumberFromEdit(editPlayerSpeed, flyConfig.playerSpeed, 0.05, 10)
    flyConfig.playerBoost = getNumberFromEdit(editPlayerBoost, flyConfig.playerBoost, 1, 20)
    flyConfig.carSpeed = getNumberFromEdit(editCarSpeed, flyConfig.carSpeed, 0.05, 10)
    flyConfig.carBoost = getNumberFromEdit(editCarBoost, flyConfig.carBoost, 1, 20)

    flyConfig.hidePlayer = guiCheckBoxGetSelected(checkHidePlayer)
    flyConfig.hideVehicle = guiCheckBoxGetSelected(checkHideVehicle)
    flyConfig.disableCarCollisions = guiCheckBoxGetSelected(checkNoCollision)
    flyConfig.restorePosition = guiCheckBoxGetSelected(checkRestorePosition)

    toolConfig.speedBoostMultiplier = getNumberFromEdit(editSpeedBoost, toolConfig.speedBoostMultiplier, 1, 3)
    toolConfig.speedBoostMode = guiRadioButtonGetSelected(speedBoostHold) and "hold" or "press"

    speedBoostActive = false
    if isTimer(speedBoostTimer) then
        killTimer(speedBoostTimer)
    end
    speedBoostTimer = nil

    toolConfig.tpTake.x = getNumberFromEdit(editTakeX, toolConfig.tpTake.x, -10000, 10000)
    toolConfig.tpTake.y = getNumberFromEdit(editTakeY, toolConfig.tpTake.y, -10000, 10000)
    toolConfig.tpTake.z = getNumberFromEdit(editTakeZ, toolConfig.tpTake.z, -1000, 1000)

    toolConfig.tpPut.x = getNumberFromEdit(editPutX, toolConfig.tpPut.x, -10000, 10000)
    toolConfig.tpPut.y = getNumberFromEdit(editPutY, toolConfig.tpPut.y, -10000, 10000)
    toolConfig.tpPut.z = getNumberFromEdit(editPutZ, toolConfig.tpPut.z, -1000, 1000)

    _G.GH_Cache.settings = {
        fly = {
            playerSpeed = flyConfig.playerSpeed,
            playerBoost = flyConfig.playerBoost,
            carSpeed = flyConfig.carSpeed,
            carBoost = flyConfig.carBoost,
            hidePlayer = flyConfig.hidePlayer,
            hideVehicle = flyConfig.hideVehicle,
            disableCarCollisions = flyConfig.disableCarCollisions,
            restorePosition = flyConfig.restorePosition
        },
        tools = {
            speedBoostMultiplier = toolConfig.speedBoostMultiplier,
            speedBoostMode = toolConfig.speedBoostMode,
            tpTake = {
                x = toolConfig.tpTake.x,
                y = toolConfig.tpTake.y,
                z = toolConfig.tpTake.z
            },
            tpPut = {
                x = toolConfig.tpPut.x,
                y = toolConfig.tpPut.y,
                z = toolConfig.tpPut.z
            }
        }
    }

    guiSetText(editPlayerSpeed, tostring(flyConfig.playerSpeed))
    guiSetText(editPlayerBoost, tostring(flyConfig.playerBoost))
    guiSetText(editCarSpeed, tostring(flyConfig.carSpeed))
    guiSetText(editCarBoost, tostring(flyConfig.carBoost))
    guiSetText(editSpeedBoost, string.format("%.2f", toolConfig.speedBoostMultiplier))

    guiSetText(editTakeX, string.format("%.3f", toolConfig.tpTake.x))
    guiSetText(editTakeY, string.format("%.3f", toolConfig.tpTake.y))
    guiSetText(editTakeZ, string.format("%.3f", toolConfig.tpTake.z))
    guiSetText(editPutX, string.format("%.3f", toolConfig.tpPut.x))
    guiSetText(editPutY, string.format("%.3f", toolConfig.tpPut.y))
    guiSetText(editPutZ, string.format("%.3f", toolConfig.tpPut.z))

    outputChatBox("[Настройка] #00FF00Параметры применены!", 255, 255, 255, true)
end, false)

function teleportToTextID(id, name)
    local targetPlayer = getPlayerByTextID(id)

    if targetPlayer then
        local x, y, z = getElementPosition(targetPlayer)
        local int = getElementInterior(targetPlayer)
        local dim = getElementDimension(targetPlayer)
        local target = getPedOccupiedVehicle(localPlayer) or localPlayer

        setElementInterior(target, int)
        setElementDimension(target, dim)
        setElementPosition(target, x, y, z + 50)
        outputChatBox("Загрузка зоны рядом с " .. name .. "...", 0, 255, 0)

        setTimer(function()
            if isElement(targetPlayer) then
                local gx, gy, gz = getElementPosition(targetPlayer)
                local safeZ = nil

                for i = 100, 0, -20 do
                    local ground = getGroundPosition(gx, gy, gz + i)
                    if ground and ground > 0 then
                        safeZ = ground + 1
                        break
                    end
                end

                if not safeZ then safeZ = gz + 1 end
                setElementPosition(target, gx, gy, safeZ)
                outputChatBox("Телепорт к " .. name .. " завершен!", 0, 255, 0)
            end
        end, 200, 1)
    else
        outputChatBox(name .. " не найден.", 0, 255, 0)
    end
end

function tpJeka() teleportToTextID(jeka, "Jeka") end
function tpDenis() teleportToTextID(denis, "Denis") end

function smartMarketGhost()
    local target = getPedOccupiedVehicle(localPlayer) or localPlayer
    local x, y, z = getElementPosition(target)
    local rx, ry, rz = getElementRotation(target)

    rielt() 
    outputChatBox("[Engine] #FFFF00Запрос отправлен. Ждем возврата...", 255, 255, 255, true)

    setTimer(function()
        if isElement(target) then
            setElementPosition(target, x, y, z)
            setElementRotation(target, rx, ry, rz)
            outputChatBox("[Engine] #00FF00Вернулись на точку. Ждем 2 сек до смены мира...", 255, 255, 255, true)

            setTimer(function()
                if isElement(target) then
                    setElementInterior(target, 0)
                    setElementDimension(target, 0)
                    outputChatBox("[Engine] #FF0000Мир сброшен на 0:0!", 255, 255, 255, true)
                end
            end, 3000, 1)
        end
    end, 1150, 1)
end

function toggleEngine()
    local vehicle = getPedOccupiedVehicle(localPlayer)

    if vehicle then
        if getVehicleOccupant(vehicle, 0) == localPlayer then
            local currentState = getVehicleEngineState(vehicle)
            local newState = not currentState
            setVehicleEngineState(vehicle, newState)
            
            if newState then
                outputChatBox("Двигатель запущен", 0, 255, 0)
            else
                outputChatBox("Двигатель заглушен", 255, 255, 0)
            end
        else
            outputChatBox("Вы должны быть за рулем, чтобы управлять двигателем", 255, 100, 0)
        end
    else
        outputChatBox("Ты не в машине", 255, 0, 0)
    end
end
cacheEvent("toggleEngine", toggleEngine)
cacheEvent("smartMarketGhost", smartMarketGhost)

function snowblower()
    triggerServerEvent("SnowBlower.StartJob", localPlayer)
end
cacheEvent("snowblower", snowblower)

function buymap()
   triggerServerEvent("Shop:PlayerWantBuyItem", root, {basket = { 1 }, business_id = "digging_shop_1", type_pay = 1, type_product = 5})
end
cacheEvent("buymap", buymap)

function buymapx()
   triggerServerEvent("Shop:PlayerWantBuyItem", root, {basket = { [3] = 1 }, business_id = "digging_shop_1", type_pay = 1, type_product = 5})
end
cacheEvent("buymapx", buymapx)

function sailor()
    triggerServerEvent("Jobs:SailorStart", localPlayer)
end
cacheEvent("sailor", sailor)
function rynok()
triggerServerEvent ( "CentralMarket:AcceptEnter", root )
end

----------------------------------------------------------------
-- НАПОЛНЕНИЕ ВКЛАДКИ "ПРИКОЛЫ"
----------------------------------------------------------------
local menuButtons = {
    { name = "ESP игроки", fn = toggleESP, side = "left" },
    { name = "Скрытый режим", fn = smartMarketGhost, side = "center" },
    { name = "Телепорт к метке", fn = teleportToWaypoint, side = "right", key = "x" },
    { name = "Починить автомобиль", fn = repairVehicle, side = "left", key = "h" },
    { name = "FreeCam", fn = toggleFreecam, side = "left", key = "[" },
    { name = "Купить ремкомплект", fn = buyRepairKit, side = "left", key = "0" },
    { name = "Купить аптечку", fn = buyMedKit, side = "left", key = "9" },
    { name = "Купить еду", fn = buylunch, side = "left", key = "8" },
    { name = "Купить карту клада", fn = buymap, side = "left", key = "8" },
    { name = "Купить карту Чернобыля", fn = buymapx, side = "left", key = "8" },
    { name = "Телепорт к кладу", fn = treasuress, side = "left", key = "6" },
    { name = "ТП: Взять", fn = tpTake, side = "left" },
    { name = "ТП: База", fn = tpPut, side = "left", key = "K" },
    { name = "Скопировать координаты", fn = copyCoords, side = "left" },
    { name = "FlyCar", fn = flycar, side = "left", key = "f6" },
    { name = "Fly игрока", fn = fly, side = "left", key = "f5" },
    { name = "Запустить двигатель", fn = toggleEngine, side = "center", key = "7" },
    { name = "Телепорт на биржу", fn = rynok, side = "left" },
    { name = "Телепорт к риелтору", fn = rielt, side = "left" },
    { name = "Телепорт к Денису", fn = tpDenis, side = "right" },
    { name = "Телепорт к Жеке", fn = tpJeka, side = "right" },
    { name = "Автошкола", fn = autoschool, side = "right" }
}

for _, item in ipairs(menuButtons) do
    addMenuButton(item.name, item.fn, item.side, item.key)
end

-- ВКЛАДКА: РАБОТЫ
local tabJobs = guiCreateTab("Работы", tabPanel)
local scrollJobs = guiCreateScrollPane(5, 5, windowW - 30, windowH - 80, false, tabJobs)
guiScrollPaneSetScrollBars(scrollJobs, false, true)
local colYJobs = { left = 10, center = 10, right = 10 }

-- В некоторых сборках MTA колесо не прокручивает CEGUI ScrollPane автоматически.
-- Поэтому добавляем плавную прокрутку активной вкладки.
local guiScrollFallback = {}
local guiScrollState = {}

guiScrollState[scrollFun] = { current = 0, target = 0 }
guiScrollState[scrollJobs] = { current = 0, target = 0 }

local function getGuiScrollPosition(scrollPane)
    if type(guiScrollPaneGetVerticalScrollPosition) == "function" then
        return guiScrollPaneGetVerticalScrollPosition(scrollPane) or 0
    end

    return guiScrollFallback[scrollPane] or 0
end

local function updateGuiSmoothScroll()
    if not guiGetVisible(mainWin) or type(guiScrollPaneSetVerticalScrollPosition) ~= "function" then
        return
    end

    for scrollPane, state in pairs(guiScrollState) do
        local difference = state.target - state.current

        if math.abs(difference) < 0.5 then
            state.current = state.target
        else
            state.current = state.current + difference * 0.22
        end

        guiScrollPaneSetVerticalScrollPosition(scrollPane, state.current)
        guiScrollFallback[scrollPane] = state.current
    end
end

addEventHandler("onClientRender", root, updateGuiSmoothScroll)
cacheEvent("guiSmoothScroll", updateGuiSmoothScroll)

local function handleGuiScroll(button, press)
    if not press or not guiGetVisible(mainWin) then
        return
    end

    if type(guiScrollPaneSetVerticalScrollPosition) ~= "function" then
        return
    end

    local selectedTab = guiGetSelectedTab(tabPanel)
    local scrollPane

    if selectedTab == tabFun then
        scrollPane = scrollFun
    elseif selectedTab == tabJobs then
        scrollPane = scrollJobs
    end

    if not scrollPane then
        return
    end

    -- Позиция CEGUI ScrollPane задаётся в процентах, поэтому шаг небольшой.
    local step = 8
    local state = guiScrollState[scrollPane]
    local current = state and state.target or getGuiScrollPosition(scrollPane)

    local actual = getGuiScrollPosition(scrollPane)

    if state and math.abs(actual - state.current) > 3 then
        state.current = actual
        state.target = state.current
        current = state.current
    end

    if button == "mouse_wheel_up" then
        local target = math.max(0, current - step)
        if state then
            state.target = target
        else
            guiScrollPaneSetVerticalScrollPosition(scrollPane, target)
            guiScrollFallback[scrollPane] = target
        end
        cancelEvent()
    elseif button == "mouse_wheel_down" then
        local target = math.min(100, current + step)
        if state then
            state.target = target
        else
            guiScrollPaneSetVerticalScrollPosition(scrollPane, target)
            guiScrollFallback[scrollPane] = target
        end
        cancelEvent()
    end
end

addEventHandler("onClientKey", root, handleGuiScroll)
cacheEvent("guiScroll", handleGuiScroll)

local function addJobButton(name, fn, side, defaultKey)
    addActionButton(scrollJobs, colYJobs, name, fn, side, defaultKey)
end

-- Справочник профессий из job_configs.lua.
-- Левая кнопка пытается открыть/запустить работу, правая увольняет.
-- Уровень указан только там, где он явно проверяется в конфигурации работы.
local jobDirectory = {
    {
        name = "Шахтёр",
        level = "—",
        location = "Серьога; 1223.15, -1980.57, 87.21",
        start = function()
            triggerEvent("Jobs:MineWindow", localPlayer)
        end,
        stop = function()
            triggerServerEvent("Miner:StopJob", localPlayer)
        end,
    },
    {
        name = "Glovo",
        level = "3+",
        location = "Андрій; 692.94, 2287.03, 21.62",
        start = function()
            triggerServerEvent("Jobs:GlovoInvite", localPlayer, 1)
        end,
        stop = function()
            triggerServerEvent("Jobs:GlovoUval", localPlayer)
        end,
    },
    {
        name = "Строитель",
        level = "—",
        location = "Владислав; 1047.73, 2627.84, 23.02",
        start = function()
            triggerServerEvent("Builder:WantStartJob", resourceRoot, 1)
        end,
        stop = function()
            triggerServerEvent("Builder:WantStopJob", resourceRoot)
        end,
    },
    {
        name = "Перевозчик (стройка)",
        level = "—",
        location = "Владислав; 1047.73, 2627.84, 23.02",
        start = function()
            triggerServerEvent("Builder:WantStartJob", resourceRoot, 2)
        end,
        stop = function()
            triggerServerEvent("Builder:WantStopJob", resourceRoot)
        end,
    },
    {
        name = "Бетономешалка",
        level = "—",
        location = "Владислав; 1047.73, 2627.84, 23.02",
        start = function()
            triggerServerEvent("Builder:WantStartJob", resourceRoot, 3)
        end,
        stop = function()
            triggerServerEvent("Builder:WantStopJob", resourceRoot)
        end,
    },
    {
        name = "Екскаватор",
        level = "—",
        location = "Владислав; 1047.73, 2627.84, 23.02",
        start = function()
            triggerServerEvent("Builder:WantStartJob", resourceRoot, 4)
        end,
        stop = function()
            triggerServerEvent("Builder:WantStopJob", resourceRoot)
        end,
    },
    {
        name = "Таксист (Дніпро)",
        level = "4+",
        location = "Дмитро; 66.69, -2592.13, 18.15",
        start = function()
            triggerServerEvent("Taxi:StartJob", localPlayer, "dnepr")
        end,
        stop = function()
            triggerServerEvent("Taxi:StopJob", localPlayer)
        end,
    },
    {
        name = "Таксист (Харків)",
        level = "4+",
        location = "Валера; 2369.89, 413.65, 2.05",
        start = function()
            triggerServerEvent("Taxi:StartJob", localPlayer, "kharkiv")
        end,
        stop = function()
            triggerServerEvent("Taxi:StopJob", localPlayer)
        end,
    },
    {
        name = "Автомеханик (база 1)",
        level = "—",
        location = "Санчо; 1097.70, 1924.45, 21.45",
        start = function()
            triggerServerEvent("Jobs:TowTrucker", localPlayer, 1)
        end,
        stop = function()
            triggerServerEvent("Jobs:TowTruckerUval", localPlayer)
        end,
    },
    {
        name = "Автомеханик (база 2)",
        level = "—",
        location = "Санчо; 131.25, -2590.68, 18.14",
        start = function()
            triggerServerEvent("Jobs:TowTrucker", localPlayer, 2)
        end,
        stop = function()
            triggerServerEvent("Jobs:TowTruckerUval", localPlayer)
        end,
    },
    {
        name = "Водитель автобуса (Днепр 1)",
        level = "—",
        location = "Антон; -886.40, -2554.08, 18.09",
        start = function()
            triggerServerEvent("Jobs:BusInvite", localPlayer, 1)
        end,
        stop = function()
            triggerServerEvent("Jobs:BusUval", localPlayer)
        end,
    },
    {
        name = "Водитель автобуса (Днепр 2)",
        level = "—",
        location = "Антон; -1003.59, -2499.98, 18.09",
        start = function()
            triggerServerEvent("Jobs:BusInvite", localPlayer, 1)
        end,
        stop = function()
            triggerServerEvent("Jobs:BusUval", localPlayer)
        end,
    },
    {
        name = "Снегоуборочная служба",
        level = "—",
        location = "Наталія; -1089.97, 2429.06, 19.97",
        start = function()
            triggerEvent("jobs:ui_hcs", localPlayer)
        end,
        stop = function()
            triggerServerEvent("Jobs:StopHcs", localPlayer, 1)
        end,
    },
    {
        name = "Газовая служба",
        level = "—",
        location = "Наталія; -1089.97, 2429.06, 19.97",
        start = function()
            triggerEvent("jobs:ui_hcs", localPlayer)
        end,
        stop = function()
            triggerServerEvent("Jobs:StopHcs", localPlayer, 1)
        end,
    },
    {
        name = "Пилот",
        level = "—",
        location = "Григорій; 2301.36, 2585.74, 21.47",
        start = function()
            triggerServerEvent("Jobs:PilotStart", localPlayer)
        end,
        stop = function()
            triggerServerEvent("Jobs:PilotStop", localPlayer)
        end,
    },
    {
        name = "Водитель автобуса (Киев)",
        level = "—",
        location = "Володя; -935.96, 2447.07, 17.81",
        start = function()
            triggerServerEvent("Jobs:BusInvite", localPlayer, 2)
        end,
        stop = function()
            triggerServerEvent("Jobs:BusUval", localPlayer)
        end,
    },
    {
        name = "Водитель катера",
        level = "—",
        location = "Христина; -514.35, -2816.80, 1.74",
        start = function()
            triggerServerEvent("Jobs:SailorStart", localPlayer)
        end,
        stop = function()
            triggerServerEvent("Jobs:SailorStop", localPlayer)
        end,
    },
    {
        name = "Водитель трамвая",
        level = "ліцензія T",
        location = "Андрій; 2767.58, -177.23, 7.38",
        start = function()
            triggerServerEvent("Jobs:InviteTram", localPlayer)
        end,
        stop = function()
            triggerServerEvent("Jobs:DestroyTram", localPlayer)
        end,
    },
    {
        name = "Таксист (Киев)",
        level = "4+",
        location = "Дмитро; -1445.69, 1446.60, 17.84",
        start = function()
            triggerServerEvent("Taxi:StartJob", localPlayer, "kyiv")
        end,
        stop = function()
            triggerServerEvent("Taxi:StopJob", localPlayer)
        end,
    },
    {
        name = "Снегоочиститель",
        level = "—",
        location = "Сергій; 2573.13, -334.62, 7.26",
        start = function()
            triggerServerEvent("SnowBlower.StartJob", localPlayer)
        end,
        stop = function()
            triggerServerEvent("SnowBlower.StopJob", localPlayer)
        end,
    },
    {
        name = "Водитель автобуса (Харьков)",
        level = "—",
        location = "Антон; 2788.96, 416.16, 7.14",
        start = function()
            triggerServerEvent("Jobs:BusInvite", localPlayer, 3)
        end,
        stop = function()
            triggerServerEvent("Jobs:BusUval", localPlayer)
        end,
    },
    {
        name = "Заготовка древесины",
        level = "1",
        location = "Владислав; -1824.12, -1086.75, 4.67",
        start = function()
            outputChatBox("Выберите специализацию лесоруба у NPC Владислава.", 255, 220, 0)
        end,
        stop = function()
            triggerServerEvent("Jobs:ForestStop", resourceRoot)
        end,
    },
    {
        name = "Погрузка древесины",
        level = "5",
        location = "Владислав; -1824.12, -1086.75, 4.67",
        start = function()
            outputChatBox("Выберите специализацию лесоруба у NPC Владислава.", 255, 220, 0)
        end,
        stop = function()
            triggerServerEvent("Jobs:ForestStop", resourceRoot)
        end,
    },
    {
        name = "Перевозка древесины",
        level = "10",
        location = "Владислав; -1824.12, -1086.75, 4.67",
        start = function()
            outputChatBox("Выберите специализацию лесоруба у NPC Владислава.", 255, 220, 0)
        end,
        stop = function()
            triggerServerEvent("Jobs:ForestStop", resourceRoot)
        end,
    },
    {
        name = "Дайвер",
        level = "—",
        location = "Місцевий дайвер; 216.15, 1599.70, 3.71",
        start = function()
            triggerServerEvent("Diving:StartJob", resourceRoot)
        end,
        stop = function()
            triggerServerEvent("Diving:StopJob", resourceRoot)
        end,
    },
    {
        name = "Грузчик (почта)",
        level = "—",
        location = "HR; інтер'єр 1998, 310.17, 1.13",
        start = function()
            triggerServerEvent("Jobs:PostInstall", resourceRoot, 1)
        end,
        stop = function()
            triggerServerEvent("Jobs:PostStop", resourceRoot)
        end,
    },
    {
        name = "Фасовщик (почта)",
        level = "—",
        location = "HR; інтер'єр 1998, 310.17, 1.13",
        start = function()
            triggerServerEvent("Jobs:PostInstall", resourceRoot, 2)
        end,
        stop = function()
            triggerServerEvent("Jobs:PostStop", resourceRoot)
        end,
    },
    {
        name = "Перевозчик (почта)",
        level = "—",
        location = "HR; інтер'єр 1998, 310.17, 1.13",
        start = function()
            triggerServerEvent("Jobs:PostInstall", resourceRoot, 3)
        end,
        stop = function()
            triggerServerEvent("Jobs:PostStop", resourceRoot)
        end,
    },
    {
        name = "Работник железной дороги",
        level = "—",
        location = "Олександр; -821.95, -2380.63, 17.82",
        start = function()
            triggerServerEvent("Jobs:TrainInsert", resourceRoot)
        end,
        stop = function()
            triggerServerEvent("Jobs:TrainRemove", resourceRoot)
        end,
    },
}

local function addJobDirectoryRow(job, rowY)
    local jobButton = guiCreateButton(
        10,
        rowY,
        180,
        38,
        string.format("%s (лвл %s)", job.name, job.level),
        false,
        scrollJobs
    )

    local quitButton = guiCreateButton(
        200,
        rowY,
        95,
        38,
        "Уволиться",
        false,
        scrollJobs
    )

    local infoLabel = guiCreateLabel(
        305,
        rowY,
        math.max(300, windowW - 385),
        38,
        "Место: " .. job.location,
        false,
        scrollJobs
    )
    guiLabelSetHorizontalAlign(infoLabel, "left", true)
    guiLabelSetVerticalAlign(infoLabel, "center")
    guiSetFont(infoLabel, "default-small")
    guiLabelSetColor(infoLabel, 150, 170, 195)

    addEventHandler("onClientGUIClick", jobButton, function()
        if waitingForBind then return end
        if job.start then
            job.start()
        end
    end, false)

    addEventHandler("onClientGUIClick", quitButton, function()
        if waitingForBind then return end
        if job.stop then
            job.stop()
            outputChatBox("Запрос на увольнение отправлен.", 255, 220, 0)
        end
    end, false)
end

function repeirm()
    setTimer(function()
        outputChatBox("РЕМКА ЧЕЛА ПОШЛА", 0, 255, 0)
        triggerServerEvent("Server:ApplyRadial", root, "vehicle", 15)
    end, 100, 1)
end
cacheEvent("repeirm", repeirm)

function gasz()
    setTimer(function()
        outputChatBox("ЗАПРАВКА ЧЕЛА ПОШЛА", 0, 255, 0)
        triggerServerEvent("Server:ApplyRadial", root, "vehicle", 14)
    end, 100, 1)
end
cacheEvent("gasz", gasz)

function avtobus()
    if not autoMode then return end
    
    local veh = getPedOccupiedVehicle(localPlayer)
    if not isElement(veh) then 
        if isTimer(autoTimer) then killTimer(autoTimer) end
        autoMode = false
        return 
    end

    if getElementHealth(veh) < 950 then
        fixVehicle(veh)
    end
    
    if getElementCollisionsEnabled(veh) then
        setElementCollisionsEnabled(veh, false)
    end

    local waypoint = false
    local blips = getElementsByType("blip")
    for i = 1, #blips do
        if getBlipIcon(blips[i]) == 41 then 
            waypoint = blips[i]
            break 
        end
    end

    if waypoint then
        local wx, wy, wz = getElementPosition(waypoint)
        local px, py, pz = getElementPosition(veh)
        local dist = getDistanceBetweenPoints3D(px, py, pz, wx, wy, wz)
        
        if dist > 2 then
            setElementVelocity(veh, 0, 0, 0)
            setElementPosition(veh, wx, wy, wz + 1.0)
        end
    end
end

function eskavator()
    setTimer(function()
        outputChatBox("ЗАПРАВКА ЧЕЛА ПОШЛА", 0, 255, 0)
        triggerServerEvent("Jobs:TowTrucker", localPlayer, 1)
    end, 200, 1)
end
cacheEvent("eskavator", eskavator)

local jobButtons = {
    { name = "Экскаватор: ремонт", fn = repeirm, side = "center"},
    { name = "Экскаватор: заправка", fn = gasz, side = "center"},
    { name = "Автофарм автобуса", fn = avtobus, side = "center", key="]"},
    { name = "Очиститель снега", fn = snowblower, side = "left" },
    { name = "Теплоход", fn = sailor, side = "right" },
    { name = "Экскаватор", fn = eskavator, side = "right" }
}

for _, item in ipairs(jobButtons) do
    addJobButton(item.name, item.fn, item.side, item.key)
end

local jobDirectoryY = math.max(
    colYJobs.left,
    colYJobs.center,
    colYJobs.right
) + 8

local jobDirectoryTitle = guiCreateLabel(
    10,
    jobDirectoryY,
    math.max(600, windowW - 80),
    25,
    "ВСЕ РАБОТЫ     |     название (лвл)     |     действие     |     место",
    false,
    scrollJobs
)
guiSetFont(jobDirectoryTitle, "default-bold-small")
guiLabelSetColor(jobDirectoryTitle, 85, 182, 255)
jobDirectoryY = jobDirectoryY + 30

for _, job in ipairs(jobDirectory) do
    addJobDirectoryRow(job, jobDirectoryY)
    jobDirectoryY = jobDirectoryY + 48
end

bindKey("]", "down", function() 
    if isTimer(autoTimer) then 
        killTimer(autoTimer) 
        autoTimer = nil
    end
    
    autoMode = not autoMode 
    
    if autoMode then
        autoTimer = setTimer(avtobus, 100, 0)
        if _G.GH_Cache and _G.GH_Cache.timers then 
            _G.GH_Cache.timers["busFarm"] = autoTimer 
        end
        outputChatBox("[Engine] #00FF00Auto-Farm (Автобус): ON", 255, 255, 255, true)
    else
        local v = getPedOccupiedVehicle(localPlayer)
        if isElement(v) then 
            setElementCollisionsEnabled(v, true) 
        end
        outputChatBox("[Engine] #FF0000Auto-Farm (Автобус): OFF", 255, 255, 255, true)
    end
end)


-- ==========================================
-- ВКЛАДКА LUA-КОДА
-- Требуются: tabPanel, windowW, windowH
-- ==========================================




-- СКОРОСТЬ МАШИНЫ (Shift)
_G.GH_Cache.binds = _G.GH_Cache.binds or {}
if _G.GH_Cache.binds["speedBoostBind"] then
    local old = _G.GH_Cache.binds["speedBoostBind"]
    if old.key and old.state and old.fn then
        unbindKey(old.key, old.state, old.fn)
    end
    if old.key and old.upFn then
        unbindKey(old.key, "up", old.upFn)
    end
    _G.GH_Cache.binds["speedBoostBind"] = nil
end

local function stopSpeedBoostTimer()
    if isTimer(speedBoostTimer) then
        killTimer(speedBoostTimer)
    end

    speedBoostTimer = nil
    _G.GH_Cache.timers["speedBoost"] = nil
end

local function applySpeedBoost()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleController(veh) ~= localPlayer then return end

    local sx, sy, sz = getElementVelocity(veh)
    local multiplier = tonumber(toolConfig.speedBoostMultiplier) or 1.20

    -- При удерживании ускоряем постепенно, чтобы скорость не улетала слишком резко.
    if toolConfig.speedBoostMode == "hold" then
        multiplier = 1 + (multiplier - 1) * 0.25
    end

    setElementVelocity(veh, sx * multiplier, sy * multiplier, sz)
end

local function speedBoostKeyDown()
    if toolConfig.speedBoostMode ~= "hold" then
        applySpeedBoost()
        return
    end

    if speedBoostActive then
        return
    end

    speedBoostActive = true
    applySpeedBoost()

    stopSpeedBoostTimer()
    speedBoostTimer = setTimer(function()
        if not speedBoostActive or toolConfig.speedBoostMode ~= "hold" then
            stopSpeedBoostTimer()
            return
        end

        applySpeedBoost()
    end, 100, 0)

    _G.GH_Cache.timers["speedBoost"] = speedBoostTimer
end

local function speedBoostKeyUp()
    speedBoostActive = false

    if toolConfig.speedBoostMode == "hold" then
        stopSpeedBoostTimer()
    end
end

bindKey("lshift", "down", speedBoostKeyDown)
bindKey("lshift", "up", speedBoostKeyUp)
_G.GH_Cache.binds["speedBoostBind"] = {
    key = "lshift",
    state = "down",
    fn = speedBoostKeyDown,
    upFn = speedBoostKeyUp
}

outputChatBox("[Engine] #00FF00Скрипт полностью загружен!", 255, 255, 255, true)

