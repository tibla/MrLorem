----------------------------------------------------------------
-- ГЛОБАЛЬНАЯ ТАБЛИЦА И ОЧИСТКА
----------------------------------------------------------------
_G.GH_Cache = _G.GH_Cache or {}
_G.GH_Cache.events = _G.GH_Cache.events or {}
_G.GH_Cache.binds = _G.GH_Cache.binds or {}
_G.GH_Cache.gui = _G.GH_Cache.gui or {}
_G.GH_Cache.timers = _G.GH_Cache.timers or {}

local cefActions = {}
local cefActionLists = { fun = {}, jobs = {} }
local cefJobs = {}
local nextCefActionId = 0
local waitingForBind = nil
local autoMode = false
local autoTimer = nil
local cefBrowser = nil
local cefBrowserReady = false
local cefVisible = false
local pushCefState

local function cacheEvent(name, fn)
    _G.GH_Cache.events[name] = { root = root, fn = fn }
end

function fullCleanup()
    -- 1. Удаляем CEF-окно
    cefVisible = false
    cefBrowserReady = false
    focusBrowser(nil)
    if isElement(cefBrowser) then
        destroyElement(cefBrowser)
        cefBrowser = nil
    end
    
    -- 2. Снимаем все бинды кнопок
    for _, data in pairs(cefActions) do
        if data.boundKey and data.bindFn then
            unbindKey(data.boundKey, "down", data.bindFn)
        end
    end
    unbindKey("f9", "down")
    unbindKey("]", "down")
    unbindKey("lshift", "down")
    
    -- 3. Очищаем активные таймеры
    if isTimer(autoTimer) then killTimer(autoTimer) end
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
    cefActions = {}
    cefActionLists = { fun = {}, jobs = {} }
    cefJobs = {}
    waitingForBind = nil
    
    showCursor(false)
    outputChatBox("[Engine] #FFFF00Скрипт полностью выгружен.", 255, 255, 255, true)
end

----------------------------------------------------------------
-- СВЯЗЬ ДЕЙСТВИЙ С CEF-ИНТЕРФЕЙСОМ
----------------------------------------------------------------
local function registerCefAction(tabName, name, fn, defaultKey, metadata)
    nextCefActionId = nextCefActionId + 1

    local id = "action_" .. tostring(nextCefActionId)
    local action = {
        id = id,
        name = name,
        fn = fn,
        key = defaultKey,
        boundKey = nil,
        bindFn = nil,
        metadata = metadata or {},
    }

    action.bindFn = function()
        if action.fn then
            action.fn()
        end
    end

    cefActions[id] = action
    table.insert(cefActionLists[tabName], action)

    if defaultKey and defaultKey ~= "" then
        bindKey(defaultKey, "down", action.bindFn)
        action.boundKey = defaultKey
    end

    return id
end

----------------------------------------------------------------
-- CEF-ИНТЕРФЕЙС
----------------------------------------------------------------
local screenW, screenH = guiGetScreenSize()
local windowW, windowH = 1120, 740

local function addMenuButton(name, fn, side, defaultKey)
    registerCefAction("fun", name, fn, defaultKey, {
        side = side or "left",
    })
end

local function addJobButton(name, fn, side, defaultKey)
    registerCefAction("jobs", name, fn, defaultKey, {
        side = side or "left",
    })
end

bindKey("f9", "down", function()
    if toggleCefUi then
        toggleCefUi()
    end
end)

outputChatBox("[Engine] CEF-панель готова. Открытие: F9", 0, 255, 0)
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
-- ФУНКЦИИ ESP
----------------------------------------------------------------
local ESP_MAX_DISTANCE = 300 
local COLOR_RED = tocolor(255, 0, 0, 255) 
local COLOR_STOKE = tocolor(0, 0, 0, 220) 
local espEnabled = true

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

local teleportLoadTimer = nil
local TELEPORT_LOAD_DELAY = 300

local function cancelTeleportLoad()
    if isTimer(teleportLoadTimer) then
        killTimer(teleportLoadTimer)
        teleportLoadTimer = nil
    end
end

local function getTeleportEntity()
    local vehicle = getPedOccupiedVehicle(localPlayer)

    if isElement(vehicle) then
        return vehicle
    end

    return localPlayer
end

local function preloadAndTeleport(x, y, z, finalZ)
    cancelTeleportLoad()

    -- Предварительно загружаем модели и коллизии области
    if type(enginePreloadWorldArea) == "function" then
        enginePreloadWorldArea(x, y, z, "all")
    end

    if not finalZ then
        local groundZ = getGroundPosition(x, y, z + 1000)

        if groundZ and groundZ > 0 then
            finalZ = groundZ + 1
        else
            finalZ = z + 5
        end
    end

    local entity = getTeleportEntity()

    if not isElement(entity) then
        return
    end

    -- Сначала переносим немного выше земли,
    -- чтобы объект успел прогрузиться без проваливания
    setElementVelocity(entity, 0, 0, 0)
    setElementPosition(entity, x, y, finalZ + 50)

    teleportLoadTimer = setTimer(function()
        teleportLoadTimer = nil

        local currentEntity = getTeleportEntity()

        if not isElement(currentEntity) then
            return
        end

        setElementVelocity(currentEntity, 0, 0, 0)
        setElementPosition(currentEntity, x, y, finalZ)
    end, TELEPORT_LOAD_DELAY, 1)
end

function teleportToWaypoint()
    local waypoint = nil

    for _, blip in ipairs(getElementsByType("blip")) do
        if getBlipIcon(blip) == 41 then
            waypoint = blip
            break
        end
    end

    if not waypoint then
        outputChatBox("Поставь метку на карте (ПКМ)", 255, 200, 0)
        return
    end

    local x, y, z = getElementPosition(waypoint)

    preloadAndTeleport(x, y, z)

    outputChatBox(
        "[Engine] Область перед телепортом загружается...",
        0,
        255,
        0
    )
end

function tpTake()
    preloadAndTeleport(
        483.034,
        -1004.596,
        21.436,
        21.436
    )

    outputChatBox(
        "[Engine] #00FF00ТП на точку 'Взять' (с машиной)!",
        255,
        255,
        255,
        true
    )
end

function tpPut()
    preloadAndTeleport(
        776.723,
        -1581.878,
        47.749,
        47.749
    )

    outputChatBox(
        "[Engine] #00FF00ТП на точку 'Положить' (с машиной)!",
        255,
        255,
        255,
        true
    )
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
-- НАСТРОЙКИ FLY ДЛЯ CEF
----------------------------------------------------------------
local function clampNumber(value, oldValue, minValue, maxValue)
    value = tonumber(value)
    if not value then
        return oldValue
    end

    return math.max(minValue, math.min(maxValue, value))
end

local function applyFlySettings(
    playerSpeed,
    playerBoost,
    carSpeed,
    carBoost,
    hidePlayer,
    hideVehicle,
    disableCarCollisions
)
    flyConfig.playerSpeed = clampNumber(playerSpeed, flyConfig.playerSpeed, 0.05, 10)
    flyConfig.playerBoost = clampNumber(playerBoost, flyConfig.playerBoost, 1, 20)
    flyConfig.carSpeed = clampNumber(carSpeed, flyConfig.carSpeed, 0.05, 10)
    flyConfig.carBoost = clampNumber(carBoost, flyConfig.carBoost, 1, 20)

    flyConfig.hidePlayer = hidePlayer == true
    flyConfig.hideVehicle = hideVehicle == true
    flyConfig.disableCarCollisions = disableCarCollisions == true

    outputChatBox("[Fly] #00FF00Настройки применены!", 255, 255, 255, true)
end

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
    { name = "🎯 ESP Игроки (Вкл/Выкл)", fn = toggleESP, side = "left" },
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
-- Рабочие кнопки регистрируются в CEF через addJobButton выше.

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
    local startId = registerCefAction(
        "jobs",
        string.format("%s (лвл %s)", job.name, job.level),
        job.start,
        nil,
        { kind = "job-start" }
    )

    local stopId = registerCefAction(
        "jobs",
        "Уволиться",
        function()
            if job.stop then
                job.stop()
                outputChatBox("Запрос на увольнение отправлен.", 255, 220, 0)
            end
        end,
        nil,
        { kind = "job-stop" }
    )

    table.insert(cefJobs, {
        name = job.name,
        level = job.level,
        location = job.location,
        startId = startId,
        stopId = stopId,
    })
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

local avtobusWaypoint = nil
local avtobusNextScan = 0
local avtobusPreloadTimer = nil
local avtobusPreloadPending = false
local avtobusLastPreload = nil

local WAYPOINT_SCAN_TIME = 300
local PRELOAD_DELAY = 150

local function stopAvtobusPreload()
    if isTimer(avtobusPreloadTimer) then
        killTimer(avtobusPreloadTimer)
    end

    avtobusPreloadTimer = nil
    avtobusPreloadPending = false
end

local function teleportAvtobusVehicle(vehicle)
    if not autoMode or not isElement(vehicle) then
        return
    end

    if not isElement(avtobusWaypoint) then
        return
    end

    local wx, wy, wz = getElementPosition(avtobusWaypoint)
    local px, py, pz = getElementPosition(vehicle)

    local dx = wx - px
    local dy = wy - py
    local dz = wz - pz

    if dx * dx + dy * dy + dz * dz <= 9 then
        return
    end

    setElementVelocity(vehicle, 0, 0, 0)
    setElementPosition(vehicle, wx, wy, wz + 1.0)
end

function avtobus()
    if not autoMode then
        stopAvtobusPreload()
        return
    end

    local veh = getPedOccupiedVehicle(localPlayer)

    if not isElement(veh) then
        if isTimer(autoTimer) then
            killTimer(autoTimer)
            autoTimer = nil
        end

        stopAvtobusPreload()
        avtobusWaypoint = nil
        avtobusLastPreload = nil
        autoMode = false
        if pushCefState then
            pushCefState()
        end
        return
    end

    if getElementHealth(veh) < 950 then
        fixVehicle(veh)
    end

    if getElementCollisionsEnabled(veh) then
        setElementCollisionsEnabled(veh, false)
    end

    local now = getTickCount()

    -- Ищем новый waypoint только раз в 300 мс
    if not isElement(avtobusWaypoint) or now >= avtobusNextScan then
        avtobusWaypoint = nil
        avtobusNextScan = now + WAYPOINT_SCAN_TIME

        for _, blip in ipairs(getElementsByType("blip")) do
            if getBlipIcon(blip) == 41 then
                avtobusWaypoint = blip
                break
            end
        end
    end

    if not isElement(avtobusWaypoint) then
        return
    end

    local wx, wy, wz = getElementPosition(avtobusWaypoint)
    local px, py, pz = getElementPosition(veh)

    local dx = wx - px
    local dy = wy - py
    local dz = wz - pz

    local distanceSquared = dx * dx + dy * dy + dz * dz

    if distanceSquared <= 9 then
        return
    end

    -- Если функция доступна в MTA 1.6+, сначала прогружаем область
    if type(enginePreloadWorldArea) == "function" then
        local needPreload = true

        if avtobusLastPreload then
            local lx = wx - avtobusLastPreload.x
            local ly = wy - avtobusLastPreload.y
            local lz = wz - avtobusLastPreload.z

            -- Не повторяем загрузку почти той же области
            if lx * lx + ly * ly + lz * lz < 2500 then
                needPreload = false
            end
        end

        if needPreload and not avtobusPreloadPending then
            enginePreloadWorldArea(wx, wy, wz, "all")

            avtobusLastPreload = {
                x = wx,
                y = wy,
                z = wz
            }

            avtobusPreloadPending = true

            stopAvtobusPreload()

            avtobusPreloadPending = true

            avtobusPreloadTimer = setTimer(function()
                avtobusPreloadTimer = nil
                avtobusPreloadPending = false

                if autoMode and isElement(veh) then
                    teleportAvtobusVehicle(veh)
                end
            end, PRELOAD_DELAY, 1)

            return
        end
    end

    teleportAvtobusVehicle(veh)
end

local function toggleBusFarm()
    if isTimer(autoTimer) then
        killTimer(autoTimer)
        autoTimer = nil
    end

    autoMode = not autoMode

    if autoMode then
        autoTimer = setTimer(avtobus, 100, 0)

        if _G.GH_Cache and _G.GH_Cache.timers then
            _G.GH_Cache.timers.busFarm = autoTimer
        end

        outputChatBox("[Engine] #00FF00Auto-Farm (Автобус): ON", 255, 255, 255, true)
    else
        stopAvtobusPreload()
        avtobusWaypoint = nil
        avtobusLastPreload = nil

        local vehicle = getPedOccupiedVehicle(localPlayer)
        if isElement(vehicle) then
            setElementCollisionsEnabled(vehicle, true)
        end

        outputChatBox("[Engine] #FF0000Auto-Farm (Автобус): OFF", 255, 255, 255, true)
    end

    if pushCefState then
        pushCefState()
    end
end
cacheEvent("toggleBusFarm", toggleBusFarm)

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
    { name = "🚀 ФАРМ АВТОБУС (вкл/выкл)", fn = toggleBusFarm, side = "center" },
    { name = "❄️ Очиститель снега", fn = snowblower, side = "left" },
    { name = "🚢 Теплоход", fn = sailor, side = "right" },
    { name = "🚀 ЭСКАВАТОР", fn = eskavator, side = "right" }
}

for _, item in ipairs(jobButtons) do
    addJobButton(item.name, item.fn, item.side, item.key)
end

for _, job in ipairs(jobDirectory) do
    addJobDirectoryRow(job)
end

bindKey("]", "down", toggleBusFarm)


-- СКОРОСТЬ МАШИНЫ (Shift)
_G.GH_Cache.binds = _G.GH_Cache.binds or {}
if _G.GH_Cache.binds["speedBoostBind"] then
    local old = _G.GH_Cache.binds["speedBoostBind"]
    if old.key and old.state and old.fn then
        unbindKey(old.key, old.state, old.fn)
    end
    _G.GH_Cache.binds["speedBoostBind"] = nil
end

local function speedBoost()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleController(veh) ~= localPlayer then return end

    local sx, sy, sz = getElementVelocity(veh)
    setElementVelocity(veh, sx * 1.2, sy * 1.2, sz)
end

bindKey("lshift", "down", speedBoost)
_G.GH_Cache.binds["speedBoostBind"] = { key = "lshift", state = "down", fn = speedBoost }

----------------------------------------------------------------
-- CEF / WEB UI
----------------------------------------------------------------
local function jsonEscape(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub('"', '\\"')
    value = value:gsub("\r", "\\r")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\t", "\\t")
    return value
end

local function jsonString(value)
    return '"' .. jsonEscape(value) .. '"'
end

local function jsonBoolean(value)
    return value and "true" or "false"
end

local function serializeAction(action)
    local kind = action.metadata and action.metadata.kind or ""

    return "{" ..
        "id:" .. jsonString(action.id) .. "," ..
        "name:" .. jsonString(action.name) .. "," ..
        "key:" .. jsonString(action.key or "") .. "," ..
        "kind:" .. jsonString(kind) ..
    "}"
end

local function serializeActionList(list)
    local result = {}

    for _, action in ipairs(list) do
        table.insert(result, serializeAction(action))
    end

    return "[" .. table.concat(result, ",") .. "]"
end

local function serializeJobs()
    local result = {}

    for _, job in ipairs(cefJobs) do
        table.insert(result, "{" ..
            "name:" .. jsonString(job.name) .. "," ..
            "level:" .. jsonString(job.level) .. "," ..
            "location:" .. jsonString(job.location) .. "," ..
            "startId:" .. jsonString(job.startId) .. "," ..
            "stopId:" .. jsonString(job.stopId) ..
        "}")
    end

    return "[" .. table.concat(result, ",") .. "]"
end

local function serializeFlyConfig()
    return "{" ..
        "playerSpeed:" .. tostring(flyConfig.playerSpeed) .. "," ..
        "playerBoost:" .. tostring(flyConfig.playerBoost) .. "," ..
        "carSpeed:" .. tostring(flyConfig.carSpeed) .. "," ..
        "carBoost:" .. tostring(flyConfig.carBoost) .. "," ..
        "hidePlayer:" .. jsonBoolean(flyConfig.hidePlayer) .. "," ..
        "hideVehicle:" .. jsonBoolean(flyConfig.hideVehicle) .. "," ..
        "disableCarCollisions:" .. jsonBoolean(flyConfig.disableCarCollisions) ..
    "}"
end

local function buildCefState()
    return "{" ..
        "fun:" .. serializeActionList(cefActionLists.fun) .. "," ..
        "jobs:" .. serializeActionList(cefActionLists.jobs) .. "," ..
        "jobDirectory:" .. serializeJobs() .. "," ..
        "fly:" .. serializeFlyConfig() .. "," ..
        "autoMode:" .. jsonBoolean(autoMode) ..
    "}"
end

pushCefState = function()
    if not cefBrowserReady or not isElement(cefBrowser) then
        return
    end

    executeBrowserJavascript(
        cefBrowser,
        "window.setLuaState(" .. buildCefState() .. ");"
    )
end

local function normalizeCefKey(key)
    key = tostring(key or ""):lower()

    local aliases = {
        ["bracketleft"] = "[",
        ["bracketright"] = "]",
        ["escape"] = "escape",
        ["backspace"] = "backspace",
        ["enter"] = "enter",
        [" "] = "space",
        ["shift"] = "lshift",
        ["control"] = "lctrl",
        ["alt"] = "lalt",
    }

    return aliases[key] or key
end

local function setCefActionKey(actionId, key)
    local action = cefActions[actionId]

    if not action then
        return
    end

    key = normalizeCefKey(key)

    if action.boundKey and action.bindFn then
        unbindKey(action.boundKey, "down", action.bindFn)
        action.boundKey = nil
    end

    if key == "escape" or key == "backspace" or key == "" then
        action.key = nil
        outputChatBox("Бинд удален", 255, 120, 0)
    else
        action.key = key
        action.boundKey = key
        bindKey(key, "down", action.bindFn)
        outputChatBox("Забинджено на: " .. string.upper(key), 0, 255, 0)
    end

    pushCefState()
end

addEvent("CEF:Action", true)
addEventHandler("CEF:Action", root, function(actionId)
    if source ~= cefBrowser then
        return
    end

    local action = cefActions[tostring(actionId)]
    if action and action.fn then
        action.fn()
    end

    pushCefState()
end)

addEvent("CEF:SetBind", true)
addEventHandler("CEF:SetBind", root, function(actionId, key)
    if source ~= cefBrowser then
        return
    end

    setCefActionKey(tostring(actionId), key)
end)

addEvent("CEF:ApplyFly", true)
addEventHandler("CEF:ApplyFly", root, function(
    playerSpeed,
    playerBoost,
    carSpeed,
    carBoost,
    hidePlayer,
    hideVehicle,
    disableCarCollisions
)
    if source ~= cefBrowser then
        return
    end

    applyFlySettings(
        playerSpeed,
        playerBoost,
        carSpeed,
        carBoost,
        hidePlayer,
        hideVehicle,
        disableCarCollisions
    )

    pushCefState()
end)

addEvent("CEF:Toggle", true)
addEventHandler("CEF:Toggle", root, function()
    if source ~= cefBrowser then
        return
    end

    toggleCefUi()
end)

local function drawCefBrowser()
    if cefVisible and isElement(cefBrowser) then
        dxDrawImage(
            0,
            0,
            screenW,
            screenH,
            cefBrowser,
            0,
            0,
            0,
            tocolor(255, 255, 255, 255),
            true
        )
    end
end

function toggleCefUi()
    cefVisible = not cefVisible
    showCursor(cefVisible)

    if cefVisible then
        focusBrowser(cefBrowser)
        pushCefState()
    else
        focusBrowser(nil)
    end
end

cefBrowser = createBrowser(screenW, screenH, true, true)

if isElement(cefBrowser) then
    addEventHandler("onClientBrowserCreated", cefBrowser, function()
        loadBrowserURL(source, "http://mta/local/index.html")
    end)

    addEventHandler("onClientBrowserDocumentReady", cefBrowser, function()
        cefBrowserReady = true
        pushCefState()
    end)

    addEventHandler("onClientRender", root, drawCefBrowser)
    cacheEvent("cefRender", drawCefBrowser)
else
    outputChatBox("[Engine] Не удалось создать CEF-браузер.", 255, 0, 0)
end

outputChatBox("[Engine] #00FF00Скрипт полностью загружен!", 255, 255, 255, true)
