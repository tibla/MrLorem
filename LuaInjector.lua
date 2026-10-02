
----------------------------------------------------------------
-- ГЛОБАЛЬНАЯ ТАБЛИЦА И ОЧИСТКА
----------------------------------------------------------------
_G.GH_Cache = _G.GH_Cache or {}
_G.GH_Cache.events = _G.GH_Cache.events or {}
_G.GH_Cache.binds = _G.GH_Cache.binds or {}
_G.GH_Cache.gui = _G.GH_Cache.gui or {}

local bindsData = {}
local waitingForBind = nil

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
    
    -- 3. Удаляем рендеры и события
    for eventName, data in pairs(_G.GH_Cache.events) do
        removeEventHandler(eventName, data.root, data.fn)
    end
    if _G.GH_Cache.keyHandler then
        removeEventHandler("onClientKey", root, _G.GH_Cache.keyHandler)
    end
    
    -- 4. Очистка кэша
    _G.GH_Cache.events = {}
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

            -- blip должен быть рядом с кладом
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
        -- ВКЛЮЧЕНИЕ
        camX, camY, camZ = getCameraMatrix() -- Начинаем полет от текущей камеры
        
        setElementFrozen(localPlayer, true)
        setElementAlpha(localPlayer, 0)
        showCursor(false)
        setCursorAlpha(0)
        toggleAllControls(false, true, false) -- Блокируем ходьбу, но оставляем чат

        addEventHandler("onClientRender", root, updateFreecam)
        addEventHandler("onClientCursorMove", root, freecamMouseMove)
        
        cacheEvent("freecamUpdate", updateFreecam)
        cacheEvent("freecamMouse", freecamMouseMove)
        
        outputChatBox("[Engine] #00FF00FreeCam ON", 255, 255, 255, true)
    else
        -- ВЫКЛЮЧЕНИЕ
        removeEventHandler("onClientRender", root, updateFreecam)
        removeEventHandler("onClientCursorMove", root, freecamMouseMove)
        
        _G.GH_Cache.events["freecamUpdate"] = nil
        _G.GH_Cache.events["freecamMouse"] = nil

        setElementFrozen(localPlayer, false)
        setElementAlpha(localPlayer, 255)
        setCursorAlpha(255)
        toggleAllControls(true) -- Разблокируем управление
        
        -- САМОЕ ВАЖНОЕ: Возвращаем камеру за спину игрока
        setCameraTarget(localPlayer) 
        
        outputChatBox("[Engine] #FF0000FreeCam OFF", 255, 255, 255, true)
    end
end

----------------------------------------------------------------
-- FLY НА ПЕРСОНАЖЕ
----------------------------------------------------------------

local noclip = false
local lastPos = {
    x = 0,
    y = 0,
    z = 0
}


function fly()
    local vehicle = getPedOccupiedVehicle(localPlayer)

    if vehicle then
        outputChatBox(
            "❌ Нельзя включить fly в машине!",
            255,
            0,
            0
        )

        return
    end

    noclip = not noclip

    if noclip then
        setElementFrozen(localPlayer, true)
        setElementCollisionsEnabled(localPlayer, false)

        setFlyHidden(
            localPlayer,
            flyConfig.hidePlayer
        )

        outputChatBox(
            "[Fly] #00FF00Включён!",
            255,
            255,
            255,
            true
        )
    else
        setElementFrozen(localPlayer, false)
        setElementCollisionsEnabled(localPlayer, true)
        setFlyHidden(localPlayer, false)

        if flyConfig.restorePosition then
            setElementPosition(
                localPlayer,
                lastPos.x,
                lastPos.y,
                lastPos.z
            )
        end

        outputChatBox(
            "[Fly] #FF0000Выключен!",
            255,
            255,
            255,
            true
        )
    end
end


local function flyRender()
    if not noclip then
        return
    end

    if not isElement(localPlayer) then
        return
    end

    local x, y, z = getElementPosition(localPlayer)

    lastPos.x = x
    lastPos.y = y
    lastPos.z = z

    setFlyHidden(
        localPlayer,
        flyConfig.hidePlayer
    )

    local camX, camY, camZ, lookX, lookY, lookZ =
        getCameraMatrix()

    local dx = lookX - camX
    local dy = lookY - camY
    local dz = lookZ - camZ

    local length = math.sqrt(
        dx * dx +
        dy * dy +
        dz * dz
    )

    if length <= 0 then
        return
    end

    dx = dx / length
    dy = dy / length
    dz = dz / length

    local currentSpeed = flyConfig.playerSpeed

    if getKeyState("lshift") then
        currentSpeed =
            currentSpeed * flyConfig.playerBoost
    end

    if getKeyState("w") then
        x = x + dx * currentSpeed
        y = y + dy * currentSpeed
        z = z + dz * currentSpeed
    end

    if getKeyState("s") then
        x = x - dx * currentSpeed
        y = y - dy * currentSpeed
        z = z - dz * currentSpeed
    end

    local rightX = dy
    local rightY = -dx

    if getKeyState("a") then
        x = x - rightX * currentSpeed
        y = y - rightY * currentSpeed
    end

    if getKeyState("d") then
        x = x + rightX * currentSpeed
        y = y + rightY * currentSpeed
    end

    if getKeyState("space") then
        z = z + currentSpeed
    end

    if getKeyState("lctrl") then
        z = z - currentSpeed
    end

    setElementPosition(
        localPlayer,
        x,
        y,
        z
    )

    local rotationZ =
        math.deg(math.atan2(dy, dx)) - 90

    setElementRotation(
        localPlayer,
        0,
        0,
        rotationZ
    )
end


addEventHandler(
    "onClientRender",
    root,
    flyRender
)

cacheEvent(
    "flyRender",
    flyRender
)
----------------------------------------------------------------
-- FLY НА МАШИНЕ
----------------------------------------------------------------

local flycarEnabled = false
local flycarVehicle = nil


local function stopFlyCar()
    if not flycarEnabled then
        return
    end

    if flycarVehicle and isElement(flycarVehicle) then
        setElementFrozen(flycarVehicle, false)
        setElementCollisionsEnabled(
            flycarVehicle,
            true
        )

        setFlyHidden(
            flycarVehicle,
            false
        )
    end

    setFlyHidden(localPlayer, false)

    flycarEnabled = false
    flycarVehicle = nil

    outputChatBox(
        "[FlyCar] #FF0000Выключен!",
        255,
        255,
        255,
        true
    )
end


function flycar()
    local vehicle = getPedOccupiedVehicle(localPlayer)

    if flycarEnabled then
        stopFlyCar()
        return
    end

    if not vehicle then
        outputChatBox(
            "❌ Вы должны находиться в машине!",
            255,
            0,
            0
        )

        return
    end

    if getVehicleController(vehicle) ~= localPlayer then
        outputChatBox(
            "❌ Вы должны быть водителем!",
            255,
            0,
            0
        )

        return
    end

    flycarEnabled = true
    flycarVehicle = vehicle

    setElementFrozen(vehicle, true)

    setElementCollisionsEnabled(
        vehicle,
        not flyConfig.disableCarCollisions
    )

    setFlyHidden(
        vehicle,
        flyConfig.hideVehicle
    )

    setFlyHidden(
        localPlayer,
        flyConfig.hidePlayer or flyConfig.hideVehicle
    )

    outputChatBox(
        "[FlyCar] #00FF00Включён!",
        255,
        255,
        255,
        true
    )
end


local function flyCarRender()
    if not flycarEnabled then
        return
    end

    local vehicle = getPedOccupiedVehicle(localPlayer)

    if not vehicle then
        stopFlyCar()
        return
    end

    if getVehicleController(vehicle) ~= localPlayer then
        stopFlyCar()
        return
    end

    if flycarVehicle ~= vehicle then
        if flycarVehicle and isElement(flycarVehicle) then
            setElementFrozen(flycarVehicle, false)
            setElementCollisionsEnabled(
                flycarVehicle,
                true
            )

            setFlyHidden(
                flycarVehicle,
                false
            )
        end

        flycarVehicle = vehicle
        setElementFrozen(vehicle, true)
    end

    setFlyHidden(
        vehicle,
        flyConfig.hideVehicle
    )

    setFlyHidden(
        localPlayer,
        flyConfig.hidePlayer or flyConfig.hideVehicle
    )

    setElementCollisionsEnabled(
        vehicle,
        not flyConfig.disableCarCollisions
    )

    local x, y, z = getElementPosition(vehicle)

    local camX, camY, camZ, lookX, lookY, lookZ =
        getCameraMatrix()

    local dx = lookX - camX
    local dy = lookY - camY
    local dz = lookZ - camZ

    local length = math.sqrt(
        dx * dx +
        dy * dy +
        dz * dz
    )

    if length <= 0 then
        return
    end

    dx = dx / length
    dy = dy / length
    dz = dz / length

    local currentSpeed = flyConfig.carSpeed

    if getKeyState("lshift") then
        currentSpeed =
            currentSpeed * flyConfig.carBoost
    end

    if getKeyState("w") then
        x = x + dx * currentSpeed
        y = y + dy * currentSpeed
        z = z + dz * currentSpeed
    end

    if getKeyState("s") then
        x = x - dx * currentSpeed
        y = y - dy * currentSpeed
        z = z - dz * currentSpeed
    end

    local rightX = dy
    local rightY = -dx

    if getKeyState("a") then
        x = x - rightX * currentSpeed
        y = y - rightY * currentSpeed
    end

    if getKeyState("d") then
        x = x + rightX * currentSpeed
        y = y + rightY * currentSpeed
    end

    if getKeyState("space") then
        z = z + currentSpeed
    end

    if getKeyState("lctrl") then
        z = z - currentSpeed
    end

    setElementPosition(
        vehicle,
        x,
        y,
        z
    )

    local rotationZ =
        -math.deg(math.atan2(dx, dy))

    local rotationX =
        math.deg(math.asin(dz))

    setElementRotation(
        vehicle,
        rotationX,
        0,
        rotationZ
    )

    setVehicleTurnVelocity(
        vehicle,
        0,
        0,
        0
    )
end


addEventHandler(
    "onClientRender",
    root,
    flyCarRender
)

cacheEvent(
    "flyCarRender",
    flyCarRender
)

local jeka  = 8575
local denis = 8854

function autoschool()
local duration = 5000 -- Длительность работы (5 сек)
local interval = 50   -- Как часто телепортировать (каждые 50 мс)
local heightOffset = 50 -- Высота над маркером

outputChatBox("Авто-телепорт включен на 5 секунд...")

-- Запускаем повторяющийся таймер
local teleportTimer = setTimer(function()
    local veh = getPedOccupiedVehicle(localPlayer)
    local found = false

    for _, marker in ipairs(getElementsByType("marker")) do
        if getMarkerType(marker) == "checkpoint" then
            local x, y, z = getElementPosition(marker)
            local targetZ = z + heightOffset

            -- Телепортируем транспорт
            if veh then
                setElementPosition(veh, x, y, targetZ)
                setElementVelocity(veh, 0, 0, 0)
                setVehicleTurnVelocity(veh, 0, 0, 0)
            end

            -- Телепортируем игрока
            setElementPosition(localPlayer, x, y, targetZ)

            found = true
            break -- Нашли первый маркер и работаем с ним
        end
    end

    if not found then
        outputChatBox("Маркер не найден!")
    end
end, interval, duration / interval)

-- Сообщение по окончании работы
setTimer(function()
    outputChatBox("Действие телепорта окончено.")
end, duration, 1)
end
cacheEvent("autoschool", autoschool)
----------------------------------------------------------------
-- Поиск игрока по текстовому ID (p + ID)
----------------------------------------------------------------
function getPlayerByTextID(id)
    local pid = "p" .. id

    for _, player in ipairs(getElementsByType("player")) do
        if getElementID(player) == pid then
            return player
        end
    end

    return false
end
----------------------------------------------------------------
-- ВКЛАДКА НАСТРОЕК FLY
----------------------------------------------------------------

local tabFlySettings = guiCreateTab("Настройки Fly", tabPanel)

guiCreateLabel(
    20, 20, 220, 25,
    "Скорость fly персонажа:",
    false,
    tabFlySettings
)

local editPlayerSpeed = guiCreateEdit(
    250, 17, 120, 28,
    tostring(flyConfig.playerSpeed),
    false,
    tabFlySettings
)

guiCreateLabel(
    20, 60, 220, 25,
    "Ускорение Shift:",
    false,
    tabFlySettings
)

local editPlayerBoost = guiCreateEdit(
    250, 57, 120, 28,
    tostring(flyConfig.playerBoost),
    false,
    tabFlySettings
)

guiCreateLabel(
    20, 110, 220, 25,
    "Скорость fly машины:",
    false,
    tabFlySettings
)

local editCarSpeed = guiCreateEdit(
    250, 107, 120, 28,
    tostring(flyConfig.carSpeed),
    false,
    tabFlySettings
)

guiCreateLabel(
    20, 150, 220, 25,
    "Ускорение машины на Shift:",
    false,
    tabFlySettings
)

local editCarBoost = guiCreateEdit(
    250, 147, 120, 28,
    tostring(flyConfig.carBoost),
    false,
    tabFlySettings
)

local checkHidePlayer = guiCreateCheckBox(
    20, 200, 350, 25,
    "Скрывать персонажа во время fly",
    flyConfig.hidePlayer,
    false,
    tabFlySettings
)

local checkHideVehicle = guiCreateCheckBox(
    20, 235, 350, 25,
    "Скрывать машину во время flycar",
    flyConfig.hideVehicle,
    false,
    tabFlySettings
)

local checkNoCollision = guiCreateCheckBox(
    20, 270, 350, 25,
    "Отключать столкновения машины",
    flyConfig.disableCarCollisions,
    false,
    tabFlySettings
)

local btnApplyFlySettings = guiCreateButton(
    20, 320, 350, 40,
    "Применить настройки",
    false,
    tabFlySettings
)


local function getNumberFromEdit(edit, oldValue, minValue, maxValue)
    local value = tonumber(guiGetText(edit))

    if not value then
        return oldValue
    end

    return math.max(
        minValue,
        math.min(maxValue, value)
    )
end


addEventHandler(
    "onClientGUIClick",
    btnApplyFlySettings,
    function()
        flyConfig.playerSpeed = getNumberFromEdit(
            editPlayerSpeed,
            flyConfig.playerSpeed,
            0.05,
            10
        )

        flyConfig.playerBoost = getNumberFromEdit(
            editPlayerBoost,
            flyConfig.playerBoost,
            1,
            20
        )

        flyConfig.carSpeed = getNumberFromEdit(
            editCarSpeed,
            flyConfig.carSpeed,
            0.05,
            10
        )

        flyConfig.carBoost = getNumberFromEdit(
            editCarBoost,
            flyConfig.carBoost,
            1,
            20
        )

        flyConfig.hidePlayer =
            guiCheckBoxGetSelected(checkHidePlayer)

        flyConfig.hideVehicle =
            guiCheckBoxGetSelected(checkHideVehicle)

        flyConfig.disableCarCollisions =
            guiCheckBoxGetSelected(checkNoCollision)

        guiSetText(
            editPlayerSpeed,
            tostring(flyConfig.playerSpeed)
        )

        guiSetText(
            editPlayerBoost,
            tostring(flyConfig.playerBoost)
        )

        guiSetText(
            editCarSpeed,
            tostring(flyConfig.carSpeed)
        )

        guiSetText(
            editCarBoost,
            tostring(flyConfig.carBoost)
        )

        outputChatBox(
            "[Fly] #00FF00Настройки применены!",
            255,
            255,
            255,
            true
        )
    end,
    false
)
----------------------------------------------------------------
-- Универсальный телепорт к игроку
----------------------------------------------------------------
function teleportToTextID(id, name)
    local targetPlayer = getPlayerByTextID(id)

    if targetPlayer then
        local x, y, z = getElementPosition(targetPlayer)
        local int = getElementInterior(targetPlayer)
        local dim = getElementDimension(targetPlayer)

        local target = getPedOccupiedVehicle(localPlayer) or localPlayer

        -- Ставим интерьер и dimension
        setElementInterior(target, int)
        setElementDimension(target, dim)

        -- Сначала вверх для прогрузки зоны
        setElementPosition(target, x, y, z + 50)

        outputChatBox("Загрузка зоны рядом с " .. name .. "...", 0, 255, 0)

        -- Потом безопасно вниз
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

                if not safeZ then
                    safeZ = gz + 1
                end

                setElementPosition(target, gx, gy, safeZ)

                outputChatBox("Телепорт к " .. name .. " завершен!", 0, 255, 0)
            end
        end, 200, 1)

    else
        outputChatBox(name .. " не найден.", 0, 255, 0)
    end
end

----------------------------------------------------------------
-- Отдельные функции
----------------------------------------------------------------
function tpJeka()
    teleportToTextID(jeka, "Jeka")
end

function tpDenis()
    teleportToTextID(denis, "Denis")
end



function smartMarketGhost()
    local target = getPedOccupiedVehicle(localPlayer) or localPlayer
    
    -- 1. Сохраняем позицию
    local x, y, z = getElementPosition(target)
    local rx, ry, rz = getElementRotation(target)

    -- 2. Летим на биржу (сервер дает Dim 50, Int 1)
    rielt() 
    outputChatBox("[Engine] #FFFF00Запрос отправлен. Ждем возврата...", 255, 255, 255, true)

    -- 3. Первый таймер: возвращаем тело на старые координаты через 150мс
    setTimer(function()
        if isElement(target) then
            setElementPosition(target, x, y, z)
            setElementRotation(target, rx, ry, rz)
            outputChatBox("[Engine] #00FF00Вернулись на точку. Ждем 2 сек до смены мира...", 255, 255, 255, true)

            -- 4. ВТОРОЙ ТАЙМЕР: меняем мир на 0:0 через 2 секунды после возврата
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
        -- Проверяем, является ли игрок водителем (сиденье 0)
        if getVehicleOccupant(vehicle, 0) == localPlayer then
            -- Считываем текущее состояние и инвертируем его
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

-- Регистрация в кэше
cacheEvent("smartMarketGhost", smartMarketGhost)
function snowblower()
    triggerServerEvent ( "SnowBlower.StartJob", localPlayer )
end
cacheEvent("snowblower", snowblower)
function buymap()
   triggerServerEvent ( "Shop:PlayerWantBuyItem", root, {
    basket = { 1 },
    business_id = "digging_shop_1",
    type_pay = 1,
    type_product = 5
  } )
end
cacheEvent("buymap", buymap)
function buymapx()
   triggerServerEvent ( "Shop:PlayerWantBuyItem", root, {
    basket = {
      [3] = 1
    },
    business_id = "digging_shop_1",
    type_pay = 1,
    type_product = 5
  } )
end
cacheEvent("buymapx", buymapx)

function sailor()
    triggerServerEvent ( "Jobs:SailorStart", localPlayer )
end
cacheEvent("sailor", sailor)

----------------------------------------------------------------
-- НАПОЛНЕНИЕ
----------------------------------------------------------------

local menuButtons = {
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

--2
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

function avtobus()
    -- 1. Проверяем, включен ли режим и есть ли машина
    if not autoMode then return end
    
    local veh = getPedOccupiedVehicle(localPlayer)
    if not isElement(veh) then 
        if isTimer(autoTimer) then killTimer(autoTimer) end
        autoMode = false
        return 
    end

    -- 2. Чиним и отключаем коллизию
    if getElementHealth(veh) < 950 then
        fixVehicle(veh)
    end
    
    if getElementCollisionsEnabled(veh) then
        setElementCollisionsEnabled(veh, false)
    end

    -- 3. Поиск блипа
    local waypoint = false
    local blips = getElementsByType("blip")
    for i = 1, #blips do
        if getBlipIcon(blips[i]) == 41 then 
            waypoint = blips[i]
            break 
        end
    end

    -- 4. Логика телепорта
    if waypoint then
        local wx, wy, wz = getElementPosition(waypoint)
        local px, py, pz = getElementPosition(veh)
        local dist = getDistanceBetweenPoints3D(px, py, pz, wx, wy, wz)
        
        if dist > 2 then
            -- Обнуляем скорость, чтобы не "выстреливать" в небо
            setElementVelocity(veh, 0, 0, 0)
            setElementPosition(veh, wx, wy, wz + 1.0)
        end
    end -- Этот end закрывает "if waypoint"
end -- Этот end закрывает "function autoLoop"


function eskavator()
    setTimer(function()
        outputChatBox("ЗАПРАВКА ЧЕЛА ПОШЛА", 0, 255, 0)
        triggerServerEvent ( "Jobs:TowTrucker", localPlayer, 1 )
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
-- ВКЛАДКА 3: LUA ИНЖЕКТОР (ТУТ ВСЁ, ЧТО ТЫ ИСКАЛ)

local tabLua = guiCreateTab("Lua инжектор", tabPanel)
local luaMemo = guiCreateMemo(10, 10, windowW - 40, windowH - 220, "-- Впишите сюда ваш код", false, tabLua)

local btnRunLua = guiCreateButton(10, windowH - 200, 200, 35, "Запустить код", false, tabLua)
local btnClearLua = guiCreateButton(220, windowH - 200, 200, 35, "Clear All (Очистить поле)", false, tabLua)
local btnReloadRemote = guiCreateButton(10, windowH - 155, 410, 45, "🔄 ВЫГРУЗИТЬ И ОБНОВИТЬ С GITHUB", false, tabLua)

-- Запуск
addEventHandler("onClientGUIClick", btnRunLua, function()
    local func, err = loadstring(guiGetText(luaMemo))
    if func then pcall(func) else outputChatBox("[Error] "..err, 255, 0, 0) end
end, false)

-- Очистка (CLEAR ALL)
addEventHandler("onClientGUIClick", btnClearLua, function() 
    guiSetText(luaMemo, "") 
    outputChatBox("Поле очищено", 255, 255, 0)
end, false)

-- Обновление (GITHUB)
addEventHandler("onClientGUIClick", btnReloadRemote, function()
    fetchRemote("https://raw.githubusercontent.com/tibla/MrLorem/refs/heads/main/LuaInjector.lua", function(data, err)
        if err == 0 then
            fullCleanup() -- Выгружаем старый
            local func, cErr = loadstring(data)
            if func then 
                pcall(func) 
                outputChatBox("Обновлено из GitHub!", 0, 255, 0)
            else
                outputChatBox("Ошибка компиляции: "..tostring(cErr))
            end
        else
            outputChatBox("Ошибка загрузки: "..tostring(err))
        end
    end)
end, false)
-- Удаляем старый бинд если был
-- Создаем кэш
_G.GH_Cache = _G.GH_Cache or {}
_G.GH_Cache.binds = _G.GH_Cache.binds or {}

-- Удаляем старый бинд
if _G.GH_Cache.binds["speedBoostBind"] then
    local old = _G.GH_Cache.binds["speedBoostBind"]

    if old.key and old.state and old.fn then
        unbindKey(old.key, old.state, old.fn)
    end

    _G.GH_Cache.binds["speedBoostBind"] = nil
end

-- Функция буста
local function speedBoost()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleController(veh) ~= localPlayer then
        return
    end

    local sx, sy, sz = getElementVelocity(veh)
    setElementVelocity(veh, sx * 1.2, sy * 1.2, sz)
end

-- Новый бинд
bindKey("lshift", "down", speedBoost)

-- Сохраняем
_G.GH_Cache.binds["speedBoostBind"] = {
    key = "lshift",
    state = "down",
    fn = speedBoost
}

---LUA f2
local screenW, screenH = guiGetScreenSize()

local windowW = 650
local windowH = 480

local windowX = (screenW - windowW) / 2
local windowY = (screenH - windowH) / 2

local DEFAULT_TEXT =
    "-- Вставь сюда Lua-код и нажми «Выполнить»"


local injectorWindow = guiCreateWindow(
    windowX,
    windowY,
    windowW,
    windowH,
    "MR.Lorem | Local Lua Console",
    false
)

guiWindowSetSizable(injectorWindow, false)
guiSetVisible(injectorWindow, false)


local luaMemo = guiCreateMemo(
    10,
    30,
    windowW - 20,
    windowH - 150,
    DEFAULT_TEXT,
    false,
    injectorWindow
)


local btnExecute = guiCreateButton(
    10,
    windowH - 105,
    195,
    40,
    "Выполнить",
    false,
    injectorWindow
)

local btnClear = guiCreateButton(
    220,
    windowH - 105,
    195,
    40,
    "Очистить",
    false,
    injectorWindow
)

local btnClose = guiCreateButton(
    430,
    windowH - 105,
    210,
    40,
    "Закрыть",
    false,
    injectorWindow
)


local lblStatus = guiCreateLabel(
    10,
    windowH - 58,
    windowW - 20,
    20,
    "Статус: Ожидание ввода...",
    false,
    injectorWindow
)

guiLabelSetHorizontalAlign(
    lblStatus,
    "left",
    true
)

guiSetFont(
    lblStatus,
    "default-bold"
)


local lblHelp = guiCreateLabel(
    10,
    windowH - 32,
    windowW - 20,
    20,
    "F2 — открыть/закрыть | Ctrl+Enter — выполнить",
    false,
    injectorWindow
)

guiLabelSetHorizontalAlign(
    lblHelp,
    "left",
    true
)


local function setStatus(text, r, g, b)
    guiSetText(
        lblStatus,
        "Статус: " .. text
    )

    guiLabelSetColor(
        lblStatus,
        r,
        g,
        b
    )
end


local function toggleConsole()
    local visible = not guiGetVisible(injectorWindow)

    guiSetVisible(
        injectorWindow,
        visible
    )

    showCursor(visible)

    if visible then
        guiBringToFront(injectorWindow)
        guiSetInputMode("no_binds_when_editing")
    else
        guiSetInputMode("allow_binds")
    end
end

bindKey(
    "f2",
    "down",
    toggleConsole
)


local function executeCode()
    local codeText = guiGetText(luaMemo)
    local cleanText = codeText:gsub("%s", "")

    if cleanText == "" or codeText == DEFAULT_TEXT then
        setStatus(
            "Ошибка: поле ввода пустое.",
            255,
            80,
            80
        )

        return
    end

    local compiledFunction
    local compileError

    if loadstring then
        compiledFunction, compileError =
            loadstring(
                codeText,
                "@LocalLuaConsole"
            )
    elseif load then
        compiledFunction, compileError =
            load(
                codeText,
                "@LocalLuaConsole"
            )
    else
        setStatus(
            "loadstring недоступен.",
            255,
            80,
            80
        )

        return
    end

    if not compiledFunction then
        setStatus(
            "Ошибка синтаксиса: "
                .. tostring(compileError),
            255,
            80,
            80
        )

        outputChatBox(
            "[Console] Ошибка синтаксиса: "
                .. tostring(compileError),
            255,
            0,
            0
        )

        return
    end

    local startTime = getTickCount()

    local success, runtimeError =
        pcall(compiledFunction)

    local executionTime =
        getTickCount() - startTime

    if success then
        setStatus(
            "Успешно выполнено за "
                .. executionTime
                .. " мс.",
            80,
            255,
            80
        )

        outputChatBox(
            "[Console] Код выполнен успешно.",
            0,
            255,
            0
        )
    else
        setStatus(
            "Ошибка выполнения: "
                .. tostring(runtimeError),
            255,
            80,
            80
        )

        outputChatBox(
            "[Console] Ошибка выполнения: "
                .. tostring(runtimeError),
            255,
            0,
            0
        )
    end
end


local function clearCode()
    guiSetText(
        luaMemo,
        ""
    )

    setStatus(
        "Поле очищено.",
        200,
        200,
        200
    )
end


local function closeConsole()
    guiSetVisible(
        injectorWindow,
        false
    )

    showCursor(false)
    guiSetInputMode("allow_binds")
end


addEventHandler(
    "onClientGUIClick",
    btnExecute,
    function()
        executeCode()
    end,
    false
)


addEventHandler(
    "onClientGUIClick",
    btnClear,
    function()
        clearCode()
    end,
    false
)


addEventHandler(
    "onClientGUIClick",
    btnClose,
    function()
        closeConsole()
    end,
    false
)


addEventHandler(
    "onClientKey",
    root,
    function(button, pressed)
        if not pressed then
            return
        end

        if not guiGetVisible(injectorWindow) then
            return
        end

        local ctrlPressed =
            getKeyState("lctrl")
            or getKeyState("rctrl")

        if button == "enter" and ctrlPressed then
            executeCode()
            cancelEvent()
        end
    end
)


addEventHandler(
    "onClientResourceStop",
    resourceRoot,
    function()
        guiSetVisible(
            injectorWindow,
            false
        )

        showCursor(false)
        guiSetInputMode("allow_binds")
    end
)


outputChatBox(
    "[Console] #00FF00Загружено!",
    255,
    255,
    255,
    true
)

outputChatBox(
    "[Console] Нажмите #FFFF00F2#FFFFFF для открытия.",
    255,
    255,
    255,
    true
)
