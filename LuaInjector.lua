----------------------------------------------------------------
-- ГЛОБАЛЬНАЯ ТАБЛИЦА И ОЧИСТКА
----------------------------------------------------------------
_G.GH_Cache = _G.GH_Cache or {}
_G.GH_Cache.events = _G.GH_Cache.events or {}
_G.GH_Cache.binds = _G.GH_Cache.binds or {}
_G.GH_Cache.gui = _G.GH_Cache.gui or {}
_G.GH_Cache.timers = _G.GH_Cache.timers or {}

local dxActions = {}
local dxActionLists = { fun = {}, jobs = {} }
local dxJobs = {}
local nextDxActionId = 0
local waitingForBind = nil
local autoMode = false
local autoTimer = nil
local dxVisible = false
local dxTab = "actions"
local dxScroll = { fun = 0, jobs = 0 }
local dxEditingField = nil
local dxFlyValues = {
    playerSpeed = "0.60",
    playerBoost = "2.50",
    carSpeed = "0.80",
    carBoost = "2.50"
}
local dxFlyChecks = {
    hidePlayer = false,
    hideVehicle = false,
    disableCarCollisions = false
}
local dxFlyChecksDirty = false

local function cacheEvent(name, fn)
    _G.GH_Cache.events[name] = { root = root, fn = fn }
end

function fullCleanup()
    -- 1. Снимаем все бинды кнопок
    for _, data in pairs(dxActions) do
        if data.boundKey and data.bindFn then
            unbindKey(data.boundKey, "down", data.bindFn)
        end
    end
    unbindKey("f9", "down")
    unbindKey("]", "down")
    unbindKey("lshift", "down")
    
    -- 2. Очищаем активные таймеры
    if isTimer(autoTimer) then killTimer(autoTimer) end
    for _, timer in pairs(_G.GH_Cache.timers) do
        if isTimer(timer) then killTimer(timer) end
    end
    
    -- 3. Удаляем рендеры и события
    for eventName, data in pairs(_G.GH_Cache.events) do
        removeEventHandler(eventName, data.root, data.fn)
    end
    if _G.GH_Cache.keyHandler then
        removeEventHandler("onClientKey", root, _G.GH_Cache.keyHandler)
    end
    
    -- 4. Очистка кэша
    _G.GH_Cache.events = {}
    _G.GH_Cache.timers = {}
    dxActions = {}
    dxActionLists = { fun = {}, jobs = {} }
    dxJobs = {}
    waitingForBind = nil
    dxEditingField = nil
    dxVisible = false
    
    showCursor(false)
    outputChatBox("[Engine] #FFFF00Скрипт полностью выгружен.", 255, 255, 255, true)
end

----------------------------------------------------------------
-- РЕЕСТР ДЕЙСТВИЙ DIRECTX-ИНТЕРФЕЙСА
----------------------------------------------------------------
local function registerDxAction(tabName, name, fn, defaultKey, metadata)
    nextDxActionId = nextDxActionId + 1

    local id = "action_" .. tostring(nextDxActionId)
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

    dxActions[id] = action
    table.insert(dxActionLists[tabName], action)

    if defaultKey and defaultKey ~= "" then
        bindKey(defaultKey, "down", action.bindFn)
        action.boundKey = defaultKey
    end

    return id
end

----------------------------------------------------------------
-- DIRECTX-ИНТЕРФЕЙС
----------------------------------------------------------------
local screenW, screenH = guiGetScreenSize()

local function addMenuButton(name, fn, side, defaultKey)
    registerDxAction("fun", name, fn, defaultKey, {
        side = side or "left",
    })
end

local function addJobButton(name, fn, side, defaultKey)
    registerDxAction("jobs", name, fn, defaultKey, {
        side = side or "left",
    })
end

bindKey("f9", "down", function()
    if toggleDxUi then
        toggleDxUi()
    end
end)

outputChatBox("[Engine] DirectX-панель готова. Открытие: F9", 0, 255, 0)
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
-- НАСТРОЙКИ FLY ДЛЯ DIRECTX
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
-- Рабочие кнопки регистрируются в DirectX через addJobButton выше.

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
    local startId = registerDxAction(
        "jobs",
        string.format("%s (лвл %s)", job.name, job.level),
        job.start,
        nil,
        { kind = "job-start" }
    )

    local stopId = registerDxAction(
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

    table.insert(dxJobs, {
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
-- DIRECTX / DRAWDX UI
----------------------------------------------------------------
local DX_BASE_W, DX_BASE_H = 1080, 650

local DX_COLOR = {
    overlay = tocolor(2, 5, 12, 175),
    background = tocolor(8, 13, 24, 250),
    sidebar = tocolor(7, 13, 23, 255),
    header = tocolor(11, 20, 35, 255),
    surface = tocolor(17, 29, 48, 255),
    surfaceHover = tocolor(24, 48, 76, 255),
    line = tocolor(75, 111, 158, 150),
    lineSoft = tocolor(75, 111, 158, 80),
    text = tocolor(237, 244, 255, 255),
    muted = tocolor(130, 151, 181, 255),
    blue = tocolor(85, 182, 255, 255),
    purple = tocolor(167, 120, 255, 255),
    green = tocolor(87, 228, 157, 255),
    red = tocolor(255, 113, 134, 255),
    white = tocolor(255, 255, 255, 255)
}

local function getDxMetrics()
    local scale = math.min(screenW / DX_BASE_W, screenH / DX_BASE_H)

    if scale > 1 then
        scale = 1
    end

    return scale,
        (screenW - DX_BASE_W * scale) / 2,
        (screenH - DX_BASE_H * scale) / 2
end

local function dxRect(scale, offsetX, offsetY, x, y, width, height, color)
    dxDrawRectangle(
        offsetX + x * scale,
        offsetY + y * scale,
        width * scale,
        height * scale,
        color,
        true
    )
end

local function dxLine(scale, offsetX, offsetY, x1, y1, x2, y2, color, width)
    dxDrawLine(
        offsetX + x1 * scale,
        offsetY + y1 * scale,
        offsetX + x2 * scale,
        offsetY + y2 * scale,
        color,
        (width or 1) * scale,
        true
    )
end

local function dxText(scale, offsetX, offsetY, text, x, y, width, height, color, size, font, align, vertical, wordBreak)
    dxDrawText(
        tostring(text or ""),
        offsetX + x * scale,
        offsetY + y * scale,
        offsetX + (x + width) * scale,
        offsetY + (y + height) * scale,
        color,
        (size or 10) * scale,
        font or "default",
        align or "left",
        vertical or "center",
        false,
        wordBreak or false,
        true,
        false,
        false
    )
end

local function dxContains(x, y, width, height, cursorX, cursorY)
    return cursorX >= x
        and cursorX <= x + width
        and cursorY >= y
        and cursorY <= y + height
end

local function getDxCursor(scale, offsetX, offsetY)
    local cursorX, cursorY = getCursorPosition()

    if not cursorX or not cursorY then
        return nil, nil
    end

    return (cursorX * screenW - offsetX) / scale,
        (cursorY * screenH - offsetY) / scale
end

local function normalizeDxKey(key)
    key = tostring(key or ""):lower()

    local aliases = {
        ["bracketleft"] = "[",
        ["bracketright"] = "]",
        ["escape"] = "escape",
        ["backspace"] = "backspace",
        ["delete"] = "delete",
        ["enter"] = "enter",
        [" "] = "space",
        ["shift"] = "lshift",
        ["control"] = "lctrl",
        ["alt"] = "lalt"
    }

    return aliases[key] or key
end

local function setDxActionKey(actionId, key)
    local action = dxActions[actionId]

    if not action then
        return
    end

    key = normalizeDxKey(key)

    if action.boundKey and action.bindFn then
        unbindKey(action.boundKey, "down", action.bindFn)
        action.boundKey = nil
    end

    if key == "escape"
        or key == "backspace"
        or key == "delete"
        or key == ""
    then
        action.key = nil
        outputChatBox("Бинд удален", 255, 120, 0)
    else
        action.key = key
        action.boundKey = key
        bindKey(key, "down", action.bindFn)
        outputChatBox("Забинджено на: " .. string.upper(key), 0, 255, 0)
    end
end

local function getDxQuickActions(tabName)
    local result = {}

    for _, action in ipairs(dxActionLists[tabName] or {}) do
        if not action.metadata or not action.metadata.kind then
            table.insert(result, action)
        end
    end

    return result
end

local function getDxActionLayout(index, topY, cardWidth, cardHeight, gap, scroll)
    local column = (index - 1) % 3
    local row = math.floor((index - 1) / 3)

    return 230 + column * (cardWidth + gap),
        topY + row * (cardHeight + gap) - scroll
end

local function drawDxActionCards(actions, topY, cardHeight, scroll, maxBottom)
    local scale, offsetX, offsetY = getDxMetrics()
    local cursorX, cursorY = getDxCursor(scale, offsetX, offsetY)
    local cardWidth = 260
    local gap = 10

    for index, action in ipairs(actions) do
        local x, y = getDxActionLayout(index, topY, cardWidth, cardHeight, gap, scroll)

        if y + cardHeight >= topY and y <= maxBottom then
            local hovered = cursorX
                and cursorY
                and dxContains(x, y, cardWidth, cardHeight, cursorX, cursorY)

            dxRect(
                scale,
                offsetX,
                offsetY,
                x,
                y,
                cardWidth,
                cardHeight,
                hovered and DX_COLOR.surfaceHover or DX_COLOR.surface
            )

            dxRect(scale, offsetX, offsetY, x, y, 3, cardHeight, DX_COLOR.blue)
            dxText(scale, offsetX, offsetY, action.name, x + 12, y + 8, cardWidth - 62, cardHeight - 16, DX_COLOR.text, 10, "default-bold", "left", "center", true)

            local keyText = action.key and string.upper(action.key) or "—"
            dxRect(scale, offsetX, offsetY, x + cardWidth - 46, y + 12, 34, cardHeight - 24, DX_COLOR.header)
            dxText(scale, offsetX, offsetY, keyText, x + cardWidth - 44, y + 12, 30, cardHeight - 24, DX_COLOR.blue, 8, "default-bold", "center", "center")
        end
    end
end

local function getDxActionAt(actions, topY, cardHeight, scroll, cursorX, cursorY)
    local cardWidth = 260
    local gap = 10

    for index, action in ipairs(actions) do
        local x, y = getDxActionLayout(index, topY, cardWidth, cardHeight, gap, scroll)

        if dxContains(x, y, cardWidth, cardHeight, cursorX, cursorY) then
            return action, cursorX >= x + cardWidth - 55
        end
    end

    return nil, false
end

local function drawDxSidebar(scale, offsetX, offsetY, cursorX, cursorY)
    dxRect(scale, offsetX, offsetY, 0, 0, 200, DX_BASE_H, DX_COLOR.sidebar)
    dxLine(scale, offsetX, offsetY, 199, 0, 199, DX_BASE_H, DX_COLOR.line)

    dxRect(scale, offsetX, offsetY, 25, 24, 30, 30, DX_COLOR.surfaceHover)
    dxText(scale, offsetX, offsetY, "M", 25, 24, 30, 30, DX_COLOR.blue, 13, "default-bold", "center", "center")
    dxText(scale, offsetX, offsetY, "MR.LOREM", 67, 22, 110, 15, DX_COLOR.text, 11, "default-bold")
    dxText(scale, offsetX, offsetY, "DIRECTX CONTROL", 67, 38, 110, 12, DX_COLOR.muted, 7, "default")

    local menu = {
        { id = "actions", title = "Быстрые действия", icon = "◈" },
        { id = "jobs", title = "Работы", icon = "▣" },
        { id = "fly", title = "Настройки Fly", icon = "△" }
    }

    for index, item in ipairs(menu) do
        local y = 85 + (index - 1) * 45
        local selected = dxTab == item.id
        local hovered = cursorX and cursorY and dxContains(15, y, 170, 36, cursorX, cursorY)

        dxRect(
            scale,
            offsetX,
            offsetY,
            15,
            y,
            170,
            36,
            selected and DX_COLOR.surfaceHover or (hovered and DX_COLOR.surface or DX_COLOR.sidebar)
        )

        dxText(scale, offsetX, offsetY, item.icon, 27, y, 18, 36, selected and DX_COLOR.blue or DX_COLOR.muted, 11, "default-bold", "center", "center")
        dxText(scale, offsetX, offsetY, item.title, 55, y, 120, 36, selected and DX_COLOR.text or DX_COLOR.muted, 9, "default-bold", "left", "center")
    end

    dxRect(scale, offsetX, offsetY, 22, 575, 156, 49, tocolor(87, 228, 157, 18))
    dxText(scale, offsetX, offsetY, "●  SYSTEM ONLINE", 34, 582, 135, 14, DX_COLOR.green, 8, "default-bold")
    dxText(scale, offsetX, offsetY, "Панель готова · F9", 34, 599, 135, 14, DX_COLOR.muted, 8, "default")
end

local function drawDxHeader(scale, offsetX, offsetY)
    dxRect(scale, offsetX, offsetY, 200, 0, 880, 70, DX_COLOR.header)
    dxLine(scale, offsetX, offsetY, 200, 69, 1080, 69, DX_COLOR.line)

    dxText(scale, offsetX, offsetY, "COMMAND CENTER / 01", 230, 16, 300, 14, DX_COLOR.blue, 8, "default-bold")
    dxText(scale, offsetX, offsetY, "Управление игроком", 230, 31, 400, 25, DX_COLOR.text, 16, "default-bold")
    dxText(scale, offsetX, offsetY, "03den", 990, 20, 45, 14, DX_COLOR.muted, 9, "default", "right")
    dxRect(scale, offsetX, offsetY, 1045, 18, 26, 26, DX_COLOR.purple)
    dxText(scale, offsetX, offsetY, "D", 1045, 18, 26, 26, DX_COLOR.white, 9, "default-bold", "center", "center")
    dxText(scale, offsetX, offsetY, "×", 1013, 18, 24, 26, DX_COLOR.muted, 16, "default-bold", "center", "center")
end

local function drawDxFooter(scale, offsetX, offsetY)
    dxRect(scale, offsetX, offsetY, 200, 625, 880, 25, DX_COLOR.header)
    dxLine(scale, offsetX, offsetY, 200, 625, 1080, 625, DX_COLOR.line)
    dxText(scale, offsetX, offsetY, "DXDRAW / UI CONCEPT", 230, 630, 250, 13, DX_COLOR.muted, 7, "default-bold")
    dxText(scale, offsetX, offsetY, "ESC закрывает · клик по клавише меняет бинд", 760, 630, 290, 13, DX_COLOR.muted, 7, "default", "right")
end

local function drawDxActionsPage(scale, offsetX, offsetY, cursorX, cursorY)
    local actions = getDxQuickActions("fun")
    local maxBottom = 615

    dxText(scale, offsetX, offsetY, "Быстрые действия", 230, 87, 400, 22, DX_COLOR.text, 14, "default-bold")
    dxText(scale, offsetX, offsetY, "Все основные функции доступны в один клик.", 230, 109, 420, 16, DX_COLOR.muted, 9, "default")
    dxText(scale, offsetX, offsetY, "KEY STATUS: READY", 895, 99, 155, 16, DX_COLOR.green, 8, "default-bold", "right")

    drawDxActionCards(actions, 135, 58, dxScroll.fun, maxBottom)
end

local function drawDxJobsPage(scale, offsetX, offsetY, cursorX, cursorY)
    local quickActions = getDxQuickActions("jobs")
    local quickCardHeight = 47
    local quickGap = 9
    local quickRows = math.max(1, math.ceil(#quickActions / 3))
    local directoryTop = 112 + quickRows * (quickCardHeight + quickGap) + 27
    local directoryRowHeight = 39
    local cursor = cursorX and cursorY

    dxText(scale, offsetX, offsetY, "Работы", 230, 87, 400, 22, DX_COLOR.text, 14, "default-bold")
    dxText(scale, offsetX, offsetY, "Выбор профессии и увольнение одним нажатием.", 230, 109, 450, 16, DX_COLOR.muted, 9, "default")
    dxText(scale, offsetX, offsetY, autoMode and "AUTO FARM: ON" or "AUTO FARM: OFF", 895, 99, 155, 16, autoMode and DX_COLOR.green or DX_COLOR.red, 8, "default-bold", "right")

    drawDxActionCards(quickActions, 112, quickCardHeight, 0, directoryTop - 12)

    dxLine(scale, offsetX, offsetY, 230, directoryTop - 3, 1050, directoryTop - 3, DX_COLOR.line)
    dxText(scale, offsetX, offsetY, "Справочник профессий", 230, directoryTop + 7, 300, 18, DX_COLOR.text, 11, "default-bold")
    dxText(scale, offsetX, offsetY, "название · уровень · место · увольнение", 760, directoryTop + 8, 290, 16, DX_COLOR.muted, 8, "default", "right")

    local listTop = directoryTop + 35

    for index, job in ipairs(dxJobs) do
        local y = listTop + (index - 1) * directoryRowHeight - dxScroll.jobs

        if y + directoryRowHeight >= listTop and y <= 615 then
            local hovered = cursor
                and dxContains(230, y, 820, directoryRowHeight, cursorX, cursorY)

            dxRect(scale, offsetX, offsetY, 230, y, 820, directoryRowHeight, hovered and DX_COLOR.surfaceHover or DX_COLOR.surface)
            dxRect(scale, offsetX, offsetY, 230, y, 3, directoryRowHeight, DX_COLOR.purple)

            dxText(scale, offsetX, offsetY, job.name, 245, y + 3, 245, 16, DX_COLOR.text, 9, "default-bold")
            dxText(scale, offsetX, offsetY, "лвл " .. tostring(job.level), 245, y + 19, 245, 13, DX_COLOR.blue, 7, "default")
            dxText(scale, offsetX, offsetY, job.location, 500, y + 1, 430, 36, DX_COLOR.muted, 8, "default", "left", "center", true)

            dxRect(scale, offsetX, offsetY, 955, y + 7, 84, 25, tocolor(255, 113, 134, 22))
            dxText(scale, offsetX, offsetY, "Уволиться", 955, y + 7, 84, 25, DX_COLOR.red, 7, "default-bold", "center", "center")
        end
    end
end

local function drawDxFlyPage(scale, offsetX, offsetY)
    if not dxEditingField then
        dxFlyValues.playerSpeed = string.format("%.2f", flyConfig.playerSpeed)
        dxFlyValues.playerBoost = string.format("%.2f", flyConfig.playerBoost)
        dxFlyValues.carSpeed = string.format("%.2f", flyConfig.carSpeed)
        dxFlyValues.carBoost = string.format("%.2f", flyConfig.carBoost)
    end

    if not dxFlyChecksDirty then
        dxFlyChecks.hidePlayer = flyConfig.hidePlayer
        dxFlyChecks.hideVehicle = flyConfig.hideVehicle
        dxFlyChecks.disableCarCollisions = flyConfig.disableCarCollisions
    end

    dxText(scale, offsetX, offsetY, "Настройки Fly", 230, 87, 400, 22, DX_COLOR.text, 14, "default-bold")
    dxText(scale, offsetX, offsetY, "Параметры движения и видимости.", 230, 109, 400, 16, DX_COLOR.muted, 9, "default")

    local fields = {
        { id = "playerSpeed", label = "Скорость персонажа", x = 230, y = 145 },
        { id = "playerBoost", label = "Ускорение Shift", x = 650, y = 145 },
        { id = "carSpeed", label = "Скорость машины", x = 230, y = 205 },
        { id = "carBoost", label = "Ускорение машины", x = 650, y = 205 }
    }

    for _, field in ipairs(fields) do
        dxText(scale, offsetX, offsetY, field.label, field.x, field.y, 230, 30, DX_COLOR.muted, 9, "default", "left", "center")

        local active = dxEditingField == field.id
        dxRect(scale, offsetX, offsetY, field.x + 245, field.y, 105, 30, active and DX_COLOR.surfaceHover or DX_COLOR.surface)
        dxText(scale, offsetX, offsetY, dxFlyValues[field.id], field.x + 253, field.y, 89, 30, DX_COLOR.text, 10, "default", "right", "center")
    end

    local checks = {
        { id = "hidePlayer", label = "Скрывать персонажа во время Fly", y = 280 },
        { id = "hideVehicle", label = "Скрывать машину во время FlyCar", y = 315 },
        { id = "disableCarCollisions", label = "Отключать столкновения машины", y = 350 }
    }

    for _, check in ipairs(checks) do
        dxRect(scale, offsetX, offsetY, 230, check.y + 8, 16, 16, DX_COLOR.surface)

        if dxFlyChecks[check.id] then
            dxRect(scale, offsetX, offsetY, 234, check.y + 12, 8, 8, DX_COLOR.blue)
        end

        dxText(scale, offsetX, offsetY, check.label, 258, check.y, 450, 30, DX_COLOR.muted, 9, "default", "left", "center")
    end

    dxRect(scale, offsetX, offsetY, 230, 405, 195, 35, DX_COLOR.blue)
    dxText(scale, offsetX, offsetY, "Применить настройки", 230, 405, 195, 35, DX_COLOR.white, 9, "default-bold", "center", "center")
end

local function drawDxUi()
    if not dxVisible then
        return
    end

    local scale, offsetX, offsetY = getDxMetrics()
    local cursorX, cursorY = getDxCursor(scale, offsetX, offsetY)

    dxRect(1, 0, 0, 0, 0, screenW, screenH, DX_COLOR.overlay)
    dxRect(scale, offsetX, offsetY, 0, 0, DX_BASE_W, DX_BASE_H, DX_COLOR.background)

    drawDxSidebar(scale, offsetX, offsetY, cursorX, cursorY)
    drawDxHeader(scale, offsetX, offsetY)
    drawDxFooter(scale, offsetX, offsetY)

    if dxTab == "actions" then
        drawDxActionsPage(scale, offsetX, offsetY, cursorX, cursorY)
    elseif dxTab == "jobs" then
        drawDxJobsPage(scale, offsetX, offsetY, cursorX, cursorY)
    else
        drawDxFlyPage(scale, offsetX, offsetY)
    end
end

local function executeDxAction(action)
    if action and action.fn then
        action.fn()
    end
end

local function applyDxFly()
    applyFlySettings(
        dxFlyValues.playerSpeed,
        dxFlyValues.playerBoost,
        dxFlyValues.carSpeed,
        dxFlyValues.carBoost,
        dxFlyChecks.hidePlayer,
        dxFlyChecks.hideVehicle,
        dxFlyChecks.disableCarCollisions
    )

    dxEditingField = nil
    dxFlyChecksDirty = false
end

local function handleDxJobClick(cursorX, cursorY)
    local quickActions = getDxQuickActions("jobs")
    local quickCardHeight = 47
    local quickGap = 9
    local quickRows = math.max(1, math.ceil(#quickActions / 3))
    local directoryTop = 112 + quickRows * (quickCardHeight + quickGap) + 27
    local directoryRowHeight = 39
    local listTop = directoryTop + 35

    local action, isBind = getDxActionAt(quickActions, 112, quickCardHeight, 0, cursorX, cursorY)

    if action then
        if isBind then
            waitingForBind = action.id
            outputChatBox("Нажмите клавишу для нового бинда или ESC для отмены.", 255, 220, 0)
        else
            executeDxAction(action)
        end
        return true
    end

    for index, job in ipairs(dxJobs) do
        local y = listTop + (index - 1) * directoryRowHeight - dxScroll.jobs

        if dxContains(230, y, 820, directoryRowHeight, cursorX, cursorY) then
            if dxContains(230, y, 265, directoryRowHeight, cursorX, cursorY) then
                executeDxAction(dxActions[job.startId])
                return true
            elseif dxContains(950, y, 105, directoryRowHeight, cursorX, cursorY) then
                executeDxAction(dxActions[job.stopId])
                return true
            end
        end
    end

    return false
end

local function handleDxClick(button, state, absoluteX, absoluteY)
    if button ~= "left" or state ~= "down" or not dxVisible then
        return
    end

    local scale, offsetX, offsetY = getDxMetrics()
    local cursorX = (absoluteX - offsetX) / scale
    local cursorY = (absoluteY - offsetY) / scale

    if dxContains(1028, 16, 30, 30, cursorX, cursorY) then
        toggleDxUi()
        cancelEvent()
        return
    end

    if dxContains(15, 85, 170, 36, cursorX, cursorY) then
        dxTab = "actions"
        dxScroll.fun = 0
        cancelEvent()
        return
    elseif dxContains(15, 130, 170, 36, cursorX, cursorY) then
        dxTab = "jobs"
        dxScroll.jobs = 0
        cancelEvent()
        return
    elseif dxContains(15, 175, 170, 36, cursorX, cursorY) then
        dxTab = "fly"
        dxEditingField = nil
        cancelEvent()
        return
    end

    if dxTab == "actions" then
        local action, isBind = getDxActionAt(
            getDxQuickActions("fun"),
            135,
            58,
            dxScroll.fun,
            cursorX,
            cursorY
        )

        if action then
            if isBind then
                waitingForBind = action.id
                outputChatBox("Нажмите клавишу для нового бинда или ESC для отмены.", 255, 220, 0)
            else
                executeDxAction(action)
            end
            cancelEvent()
        end
    elseif dxTab == "jobs" then
        if handleDxJobClick(cursorX, cursorY) then
            cancelEvent()
        end
    elseif dxTab == "fly" then
        local fields = {
            { id = "playerSpeed", x = 230, y = 145 },
            { id = "playerBoost", x = 650, y = 145 },
            { id = "carSpeed", x = 230, y = 205 },
            { id = "carBoost", x = 650, y = 205 }
        }

        for _, field in ipairs(fields) do
            if dxContains(field.x + 245, field.y, 105, 30, cursorX, cursorY) then
                dxEditingField = field.id
                waitingForBind = nil
                cancelEvent()
                return
            end
        end

        local checks = {
            { id = "hidePlayer", y = 280 },
            { id = "hideVehicle", y = 315 },
            { id = "disableCarCollisions", y = 350 }
        }

        for _, check in ipairs(checks) do
            if dxContains(230, check.y, 460, 30, cursorX, cursorY) then
                dxFlyChecks[check.id] = not dxFlyChecks[check.id]
                dxFlyChecksDirty = true
                cancelEvent()
                return
            end
        end

        if dxContains(230, 405, 195, 35, cursorX, cursorY) then
            applyDxFly()
            cancelEvent()
        end
    end
end

local function handleDxCharacter(character)
    if not dxVisible or not dxEditingField then
        return
    end

    if character and string.match(character, "[%d%.]") then
        if character == "." and string.find(dxFlyValues[dxEditingField], "%.", 1, true) then
            return
        end

        dxFlyValues[dxEditingField] = dxFlyValues[dxEditingField] .. character
    end
end

local function handleDxKey(button, press)
    if not press then
        return
    end

    if waitingForBind then
        cancelEvent()

        local action = dxActions[waitingForBind]

        if not action then
            waitingForBind = nil
            return
        end

        if button == "escape" then
            waitingForBind = nil
            outputChatBox("Изменение бинда отменено.", 255, 220, 0)
        elseif button == "backspace" or button == "delete" then
            setDxActionKey(action.id, "")
            waitingForBind = nil
        else
            setDxActionKey(action.id, button)
            waitingForBind = nil
        end

        return
    end

    if dxEditingField then
        if button == "backspace" then
            local value = dxFlyValues[dxEditingField]
            dxFlyValues[dxEditingField] = string.sub(value, 1, math.max(0, #value - 1))
            cancelEvent()
            return
        elseif button == "enter" or button == "escape" then
            dxEditingField = nil
            cancelEvent()
            return
        end
    end

    if not dxVisible then
        return
    end

    if button == "escape" then
        toggleDxUi()
        cancelEvent()
    elseif button == "mouse_wheel_up" and dxScroll[dxTab] then
        dxScroll[dxTab] = math.max(0, dxScroll[dxTab] - 45)
        cancelEvent()
    elseif button == "mouse_wheel_down" and dxScroll[dxTab] then
        dxScroll[dxTab] = dxScroll[dxTab] + 45
        cancelEvent()
    end
end

function toggleDxUi()
    dxVisible = not dxVisible
    showCursor(dxVisible)

    if not dxVisible then
        waitingForBind = nil
        dxEditingField = nil
    end
end

addEventHandler("onClientRender", root, drawDxUi)
cacheEvent("dxRender", drawDxUi)

addEventHandler("onClientClick", root, handleDxClick)
cacheEvent("dxClick", handleDxClick)

addEventHandler("onClientCharacter", root, handleDxCharacter)
cacheEvent("dxCharacter", handleDxCharacter)

addEventHandler("onClientKey", root, handleDxKey)
_G.GH_Cache.keyHandler = handleDxKey

outputChatBox("[Engine] #00FF00Скрипт полностью загружен! DirectX UI готов.", 255, 255, 255, true)

