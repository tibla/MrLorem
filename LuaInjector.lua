----------------------------------------------------------------
-- ГЛОБАЛЬНАЯ ТАБЛИЦА И ОЧИСТКА
----------------------------------------------------------------
_G.GH_Cache = _G.GH_Cache or {}
_G.GH_Cache.events = _G.GH_Cache.events or {}
_G.GH_Cache.binds = _G.GH_Cache.binds or {}
_G.GH_Cache.gui = _G.GH_Cache.gui or {}
_G.GH_Cache.timers = _G.GH_Cache.timers or {}

local bindsData = {}
local waitingForBind = nil
local autoMode = false
local autoTimer = nil

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
    unbindKey("f1", "down")
    
    -- 3. Очищаем активные таймеры
    if isTimer(autoTimer) then killTimer(autoTimer) end
    if uiBootstrapTimer and isTimer(uiBootstrapTimer) then killTimer(uiBootstrapTimer) end
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
local windowW, windowH = 750, 720
local x, y = (screenW - windowW) / 2, (screenH - windowH) / 2

mainWin = guiCreateWindow(
    x,
    y,
    windowW,
    windowH,
    "MR.Lorem | Control Panel",
    false
)

guiWindowSetSizable(mainWin, false)
guiSetVisible(mainWin, false)

-- Создаём только одну панель вкладок
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

    local posX = columnX[side] or columnX.left
    local posY = columns[side] or columns.left

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

    columns[side] = posY + 40
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
-- ФУНКЦИИ
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
    teleportEntity(localPlayer, 483.034, -1004.596, 21.436)
    outputChatBox("[Engine] #00FF00ТП на точку 'Взять' (с машиной)!", 255, 255, 255, true)
end

function tpPut()
    teleportEntity(localPlayer, 776.723, -1581.878, 47.749)
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

----------------------------------------------------------------
-- PLAYER ESP
----------------------------------------------------------------
local espEnabled = false
local ESP_MAX_DISTANCE = 300
local COLOR_RED = tocolor(255, 0, 0, 255)
local COLOR_STOKE = tocolor(0, 0, 0, 220)

local function drawPlayerESP()
    if not espEnabled then return end
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

addEventHandler("onClientRender", root, drawPlayerESP)
cacheEvent("drawPlayerESP", drawPlayerESP)

function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        outputChatBox("[ESP] #00FF00Включено (0-300м)", 255, 255, 255, true)
    else
        outputChatBox("[ESP] #FF0000Выключено", 255, 255, 255, true)
    end
end
cacheEvent("toggleESP", toggleESP)

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
-- ВКЛАДКА НАСТРОЕК FLY
----------------------------------------------------------------
local tabFlySettings = guiCreateTab("Настройки Fly", tabPanel)

guiCreateLabel(20, 20, 220, 25, "Скорость fly персонажа:", false, tabFlySettings)
local editPlayerSpeed = guiCreateEdit(250, 17, 120, 28, tostring(flyConfig.playerSpeed), false, tabFlySettings)

guiCreateLabel(20, 60, 220, 25, "Ускорение Shift:", false, tabFlySettings)
local editPlayerBoost = guiCreateEdit(250, 57, 120, 28, tostring(flyConfig.playerBoost), false, tabFlySettings)

guiCreateLabel(20, 110, 220, 25, "Скорость fly машины:", false, tabFlySettings)
local editCarSpeed = guiCreateEdit(250, 107, 120, 28, tostring(flyConfig.carSpeed), false, tabFlySettings)

guiCreateLabel(20, 150, 220, 25, "Ускорение машины на Shift:", false, tabFlySettings)
local editCarBoost = guiCreateEdit(250, 147, 120, 28, tostring(flyConfig.carBoost), false, tabFlySettings)

local checkHidePlayer = guiCreateCheckBox(20, 200, 350, 25, "Скрывать персонажа во время fly", flyConfig.hidePlayer, false, tabFlySettings)
local checkHideVehicle = guiCreateCheckBox(20, 235, 350, 25, "Скрывать машину во время flycar", flyConfig.hideVehicle, false, tabFlySettings)
local checkNoCollision = guiCreateCheckBox(20, 270, 350, 25, "Отключать столкновения машины", flyConfig.disableCarCollisions, false, tabFlySettings)

local btnApplyFlySettings = guiCreateButton(20, 320, 350, 40, "Применить настройки", false, tabFlySettings)

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

    guiSetText(editPlayerSpeed, tostring(flyConfig.playerSpeed))
    guiSetText(editPlayerBoost, tostring(flyConfig.playerBoost))
    guiSetText(editCarSpeed, tostring(flyConfig.carSpeed))
    guiSetText(editCarBoost, tostring(flyConfig.carBoost))

    outputChatBox("[Fly] #00FF00Настройки применены!", 255, 255, 255, true)
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
-- НАПОЛНЕНИЕ
----------------------------------------------------------------
local menuButtons = {
    { name = "👀 Включить/Выключить ESP", fn = toggleESP, side = "left" },
    { name = "🚀 ЗАЙТИ В ДРУГОЙ МИР(ЧТО БЫ ТЕБЯ НЕБЫЛО ВИДНО)", fn = smartMarketGhost, side = "center" },
    { name = "🚀 Телепорт к метке (X)", fn = teleportToWaypoint, side = "right", key = "x" },
    { name = "🔧 Починить авто (H)", fn = repairVehicle, side = "left", key = "h" },
    { name = "📷 FreeCam ([)", fn = toggleFreecam, side = "left", key = "[" },
    { name = "🛠️ Купить ремку (0)", fn = buyRepairKit, side = "left", key = "0" },
    { name = "🩹 Купить аптечку (9)", fn = buyMedKit, side = "left", key = "9" },
    { name = "🩹 Купить Кушать 2к (8)", fn = buylunch, side = "left", key = "8" },
    { name = "КУПИТЬ КАРТУ КЛАДА 1ШТ", fn = buymap, side = "left", key = "8" },
    { name = "КУПИТЬ ЧЕРНОБЛЬ КАРТУ КЛАДА 1ШТ", fn = buymapx, side = "left", key = "8" },
    { name = "КЛАД ТП)", fn = treasuress, side = "left", key = "6" },
    { name = "📍 ТП: Взять ()", fn = tpTake, side = "left" },
    { name = "📍 ТП: БАЗА (k)", fn = tpPut, side = "left", key = "K" },
    { name = "📝 Копировать координаты (J)", fn = copyCoords, side = "left" },
	{ name = "🚀 Летать на машине (f6)", fn = flycar, side = "left", key = "f6" },
	{ name = "🚀 FLY НА ПЕРСОНАЖЕ!!! (f5)", fn = fly, side = "left", key = "f5" },
    { name = "ЗАПУСК ЧУЖОЙ ТАЧКИ", fn = toggleEngine, side = "center", key = "7" },
    { name = "ТП НА БИРЖУ!!!", fn = rynok, side = "left" },
    { name = "ТП К РИЕЛТОРУ!!!", fn = rielt, side = "left" },
    { name = "ТП К ДЕНИСУ(6555)", fn = tpDenis, side = "right" },
    { name = "ТП К ЖЕКЕ(6719)", fn = tpJeka, side = "right" },
    { name = "autoschool прохождение", fn = autoschool, side = "right" }
}

for _, item in ipairs(menuButtons) do
    addMenuButton(item.name, item.fn, item.side, item.key)
end

-- ВКЛАДКА: РАБОТЫ
local tabJobs = guiCreateTab("Работы", tabPanel)
local scrollJobs = guiCreateScrollPane(5, 5, windowW - 30, windowH - 80, false, tabJobs)
local colYJobs = { left = 10, center = 10, right = 10 }

local function addJobButton(name, fn, side, defaultKey)
    addActionButton(scrollJobs, colYJobs, name, fn, side, defaultKey)
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

-- ФУНКЦИЯ АВТОБУСА
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
    { name = "🚀 ЭСКАВАТОР починить", fn = repeirm, side = "center"},
    { name = "🚀 ЭСКАВАТОР заправить ", fn = gasz, side = "center"},
    { name = "🚀 ФАРМ АВТОБУС(]) ", fn = avtobus, side = "center", key="]"},
    { name = "❄️ Очиститель снега", fn = snowblower, side = "left" },
    { name = "🚢 Теплоход", fn = sailor, side = "right" },
    { name = "🚀 ЭСКАВАТОР", fn = eskavator, side = "right" }
}

for _, item in ipairs(jobButtons) do
    addJobButton(item.name, item.fn, item.side, item.key)
end

-- БИНД НА КЛАВИШУ ]
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

----------------------------------------------------------------
-- ВКЛАДКА: LUAINJECTOR (EVENTS DUMPER / MIRAGE IMGUI)
----------------------------------------------------------------
local tabLuaInjector = guiCreateTab("LuaInjector", tabPanel)

local isGUIOpen = false
local selfResource = getResourceName(getThisResource())

local LOG_MAX_LINES = 3000
local RENDER_MAX_LINES = 900
local eventLines = {}
local block_dumper = false
local uiRenderHookActive = false
local uiBootstrapReady = false
local uiBootstrapTimer = nil

local ui = {
    width = 900,
    height = 650,
    posInitialized = false,
    winX = nil,
    winY = nil,
    assetsReady = false,
    keyButtonFont = "mirage_cyber_buttons",
}

local setHiddenFunctionCall
local hiddenPcall

local function debugLog(text)
    if not mirageFunc then return end
    mirageFunc("debugLog", tostring(text or ""))
end

local function setupImGuiAssets(forceReload)
    if forceReload then ui.assetsReady = false end
    if ui.assetsReady then return end

    local base = mirageFunc("getLuaScriptsPath") or ""
    local captionFont = joinPath and joinPath(base, "Cyber Blast.otf") or (base .. "Cyber Blast.otf")

    if type(mirageFunc) == "function" then
        pcall(mirageFunc, "imgui.loadFont", captionFont, 36, ui.keyButtonFont)
        pcall(mirageFunc, "imgui.themeDark")
        pcall(mirageFunc, "imgui.setStyleRounding", 14.0, 10.0, 8.0, 10.0)
        pcall(mirageFunc, "imgui.enable", true)
    end

    ui.assetsReady = true
end

local function setUiVisible(state)
    isGUIOpen = state and true or false
    if isGUIOpen then
        ui.posInitialized = false
        ui.winX = nil
        ui.winY = nil
    end
    if type(mirageFunc) == "function" then
        pcall(mirageFunc, "blockScreen", isGUIOpen)
        pcall(mirageFunc, "imgui.captureInput", isGUIOpen)
        pcall(mirageFunc, "imgui.blockBinds", isGUIOpen)
        pcall(mirageFunc, "imgui.forceCursor", isGUIOpen)
        pcall(mirageFunc, "imgui.drawCursor", isGUIOpen)
    end
    if showCursor then showCursor(isGUIOpen, true) end
    if showChat then showChat(not isGUIOpen) end
end

setHiddenFunctionCall = function(state)
    if not mirageFunc then return end
    mirageFunc("hideFunctionCall", state and true or false)
end

hiddenPcall = function(func, ...)
    setHiddenFunctionCall(true)
    local results = { pcall(func, ...) }
    setHiddenFunctionCall(false)
    return unpack(results)
end

local function pushUiMessage(eventName, text)
    if not triggerEvent then return end
    hiddenPcall(triggerEvent, eventName, root, tostring(text or ""))
end

local function notifySuccess(text) pushUiMessage("ShowSuccess", text) end
local function notifyError(text) pushUiMessage("ShowError", text) end
local function notifyWarning(text) pushUiMessage("ShowWarning", text) end

local function appendEventLine(text)
    text = tostring(text or "")
    eventLines[#eventLines + 1] = text
    if #eventLines > LOG_MAX_LINES then
        table.remove(eventLines, 1)
    end
end

local function clearEventLog()
    eventLines = {}
end

local function getEventLogText()
    if #eventLines == 0 then return "" end
    return table.concat(eventLines, "\n")
end

local function copyToClipboard(text, successMessage)
    text = tostring(text or "")
    if text == "" then
        notifyWarning("Лог событий пуст")
        return
    end
    if not setClipboard then
        notifyError("Буфер обмена недоступен")
        return
    end
    local ok, copied = hiddenPcall(setClipboard, text)
    if ok and copied ~= false then
        notifySuccess(tostring(successMessage or "Скопировано"))
    else
        notifyError("Не удалось скопировать в буфер обмена")
    end
end

local function replaceResourceIdentifier(s)
    s = s:gsub("elem:resource%x%x%x%x%x%x%x%x", "root")
    s = s:gsub("elem:root%x%x%x%x%x%x%x%x", "root")
    return s
end

local function replacePlayerName(s, playerName)
    local escapedPlayerName = playerName:gsub("([^%w])", "%%%1")
    s = s:gsub("elem:player%[" .. escapedPlayerName .. "%]", "localPlayer")
    return s
end

local function replaceAnyVehicleIdentifier(s)
    return s:gsub("elem:vehicle%[%]%x%x%x%x%x%x%x%x", "localPlayer.vehicle")
end

local function bracesToParensOnce(s)
    local first = s:find("{", 1, true)
    if first then s = s:sub(1, first - 1) .. "(" .. s:sub(first + 1) end
    local last = s:match(".*()}")
    if last then s = s:sub(1, last - 1) .. ")" .. s:sub(last + 1) end
    return s
end

local function buildEventDumpArgs(args)
    local code_args = type(inspect) == "function" and inspect(args) or tostring(args)
    code_args = replaceResourceIdentifier(code_args)
    local my_elem = type(inspect) == "function" and inspect(localPlayer) or ""
    local playerName = my_elem:match("elem:player%[(.-)%]")
    if playerName and playerName ~= "" then
        code_args = replacePlayerName(code_args, playerName)
    end
    code_args = replaceAnyVehicleIdentifier(code_args)
    code_args = bracesToParensOnce(code_args)
    return code_args
end

local function evDumper(sourceResource, functionName, isAllowedByACL, luaFilename, luaLineNumber, ...)
    local args = { ... }
    local resname = sourceResource and getResourceName(sourceResource)
    
    if not block_dumper then
        local code_args = buildEventDumpArgs(args)
        appendEventLine("[" .. tostring(resname) .. "] " .. tostring(functionName) .. " " .. code_args)
    end
end

local originalTriggerServerEvent = triggerServerEvent
local originalTriggerLatentServerEvent = triggerLatentServerEvent

if originalTriggerServerEvent then
    triggerServerEvent = function(...)
        if not block_dumper then
            local args = { ... }
            local code_args = buildEventDumpArgs(args)
            appendEventLine("[" .. tostring(selfResource) .. "] triggerServerEvent " .. code_args)
        end
        return originalTriggerServerEvent(...)
    end
end

if originalTriggerLatentServerEvent then
    triggerLatentServerEvent = function(...)
        if not block_dumper then
            local args = { ... }
            local code_args = buildEventDumpArgs(args)
            appendEventLine("[" .. tostring(selfResource) .. "] triggerLatentServerEvent " .. code_args)
        end
        return originalTriggerLatentServerEvent(...)
    end
end

local function pushEventLineColor(line)
    if not mirageFunc then return end
    if line:find("triggerServerEvent", 1, true) then
        mirageFunc("imgui.pushStyleColor", 0, 250, 225, 120, 255)
    elseif line:find("localPlayer", 1, true) then
        mirageFunc("imgui.pushStyleColor", 0, 152, 230, 130, 255)
    elseif line:find("root", 1, true) then
        mirageFunc("imgui.pushStyleColor", 0, 132, 212, 255, 255)
    else
        mirageFunc("imgui.pushStyleColor", 0, 240, 200, 200, 255)
    end
end

local function popEventLineColor()
    if mirageFunc then
        mirageFunc("imgui.popStyleColor", 1)
    end
end

local function renderEventsUi()
    if type(mirageFunc) ~= "function" then return end
    local renderAllowed = mirageFunc("isImguiHotkeyRenderAllowed")
    if not renderAllowed or not isGUIOpen or not mirageFunc("imgui.isReady") then return end

    local sx, sy = guiGetScreenSize()
    ui.width = math.max(900, math.floor(sx * 0.60))
    ui.height = math.max(650, math.floor(sy * 0.70))

    local defaultX = math.floor((sx - ui.width) * 0.5)
    local defaultY = math.floor((sy - ui.height) * 0.5)

    ui.winX = mirageFunc("imgui.getFloat", "wnd_events_dumper#x", ui.winX or defaultX) or (ui.winX or defaultX)
    ui.winY = mirageFunc("imgui.getFloat", "wnd_events_dumper#y", ui.winY or defaultY) or (ui.winY or defaultY)

    if not ui.posInitialized then
        mirageFunc("imgui.setNextWindowPos", math.floor(ui.winX), math.floor(ui.winY), 0)
        ui.posInitialized = true
    end
    mirageFunc("imgui.setNextWindowSize", ui.width, ui.height, 0)

    local opened = mirageFunc("imgui.begin", "Events Dumper", true, 0, "wnd_events_dumper")
    if opened then
        local logW = ui.width - 30
        local logH = ui.height - 130

        mirageFunc("imgui.beginChild", "events_log_host", logW, logH, true, 16384, "events_log_host")
        local first = math.max(1, #eventLines - RENDER_MAX_LINES)
        for i = first, #eventLines do
            pushEventLineColor(eventLines[i])
            mirageFunc("imgui.text", eventLines[i])
            popEventLineColor()
        end
        mirageFunc("imgui.endChild")

        mirageFunc("imgui.setCursorPos", 14, ui.height - 55)
        if mirageFunc("imgui.button", "Копировать последний", 180, 35, "ev_btn_copy_last") then
            copyToClipboard(eventLines[#eventLines], "Скопирован последний евент")
        end
        mirageFunc("imgui.sameLine")
        if mirageFunc("imgui.button", "Копировать всё", 160, 35, "ev_btn_copy_all") then
            copyToClipboard(getEventLogText(), "Лог евентов скопирован")
        end
        mirageFunc("imgui.sameLine")
        if mirageFunc("imgui.button", "Очистить лог", 140, 35, "ev_btn_clear") then
            clearEventLog()
        end
    else
        isGUIOpen = false
        setUiVisible(false)
    end
    mirageFunc("imgui.end")
end

local function ToggleGUI()
    isGUIOpen = not isGUIOpen
    setUiVisible(isGUIOpen)
end

_G.MirageToggleInjectorMenu = ToggleGUI

local function bootstrapUi()
    if uiBootstrapReady then return true end
    if type(mirageFunc) ~= "function" then return false end

    local ok = pcall(function()
        setupImGuiAssets()
        setUiVisible(false)

        mirageFunc("hideFunctionCall", true)
        mirageFunc("setDbgHook", "preFunction", evDumper, { "triggerServerEvent", "triggerLatentServerEvent" })
        mirageFunc("hideFunctionCall", false)

        if not uiRenderHookActive then
            addEventHandler("onClientRender", root, renderEventsUi)
            uiRenderHookActive = true
        end
    end)

    if ok then
        uiBootstrapReady = true
        return true
    end
    return false
end

if not bootstrapUi() then
    uiBootstrapTimer = setTimer(function()
        if bootstrapUi() then
            if isTimer(sourceTimer) then killTimer(sourceTimer) end
        end
    end, 1000, 0)
end

addEventHandler("onClientKey", root, function(button, press)
    if button == "f1" and press then
        ToggleGUI()
        cancelEvent()
    end
    if isGUIOpen and press and button == "escape" then
        cancelEvent()
        isGUIOpen = false
        setUiVisible(false)
    end
end)

-- Создаем элементы управления внутри вкладки LuaInjector
local lblInfoLua = guiCreateLabel(20, 20, 500, 30, "Инжектор / Дампер событий (F1 - управление ImGui окном)", false, tabLuaInjector)
guiSetFont(lblInfoLua, "default-bold")

local btnToggleGui = guiCreateButton(20, 60, 250, 40, "Открыть/Закрыть Dumper (F1)", false, tabLuaInjector)
addEventHandler("onClientGUIClick", btnToggleGui, function()
    ToggleGUI()
end, false)

outputChatBox("[Engine] #00FF00Всё успешно загружено!", 255, 255, 255, true)
