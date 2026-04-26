triggerEvent("ShowSuccess", root, "Тест уведомления")
triggerEvent("ShowError", root, "Тест уведомления")
triggerEvent("ShowWarning", root, "Тест уведомления")
----------------------------------------------------------------
-- ГЛОБАЛЬНАЯ ТАБЛИЦА И ОЧИСТКА (ДЛЯ ОБНОВЛЕНИЯ)
----------------------------------------------------------------
_G.GH_Cache = _G.GH_Cache or { events = {}, binds = {}, gui = {} }

-- Функция полной выгрузки текущего скрипта
function fullCleanup()
    -- 1. Удаляем главное окно
    if isElement(mainWin) then destroyElement(mainWin) end
    
    -- 2. Снимаем все бинды, которые мы регистрировали
    local keys = {"f9", "x", "h", "[", "0", "9", "l", "k", "j", "f6", "f5", "lshift", "]"}
    for _, key in ipairs(keys) do unbindKey(key, "down") end
    
    -- 3. Удаляем все активные эвенты (рендеры и т.д.)
    for eventName, data in pairs(_G.GH_Cache.events) do
        removeEventHandler(eventName, data.root, data.fn)
    end
    
    -- 4. Сбрасываем кэш
    _G.GH_Cache.events = {}
    _G.GH_Cache.gui = {}
    
    showCursor(false)
    outputChatBox("[Engine] #FFFF00Скрипт полностью выгружен. Загрузка новой версии...", 255, 255, 255, true)
end
----------------------------------------------------------------
-- НАСТРОЙКИ ЭКРАНА И ОКНА
----------------------------------------------------------------
local screenW, screenH = guiGetScreenSize()
local windowW, windowH = 750, 720
local x, y = (screenW - windowW) / 2, (screenH - windowH) / 2

mainWin = guiCreateWindow(x, y, windowW, windowH, "MR.Lorem | Control Panel", false)
guiWindowSetSizable(mainWin, false)
guiSetVisible(mainWin, false)

local titleLabel = guiCreateLabel(0, 0, windowW, 25, "MR.Lorem | By Lorem", false, mainWin)
guiLabelSetHorizontalAlign(titleLabel, "center", false)
guiLabelSetVerticalAlign(titleLabel, "center")
guiSetFont(titleLabel, "default-bold-small")

local tabPanel = guiCreateTabPanel(10, 25, windowW - 20, windowH - 40, false, mainWin)

----------------------------------------------------------------
-- TAB 1: ПРИКОЛЫ (КНОПКИ)
----------------------------------------------------------------
local tabFun = guiCreateTab("Приколы", tabPanel)
local scrollFun = guiCreateScrollPane(5, 5, windowW - 30, windowH - 80, false, tabFun)

local currentY = 10
local function addMenuButton(name, fn)
    local btn = guiCreateButton(10, currentY, 250, 35, name, false, scrollFun)
    addEventHandler("onClientGUIClick", btn, fn, false)
    currentY = currentY + 40
    return btn
end

----------------------------------------------------------------
-- TAB 2: LUA ИНЖЕКТОР
----------------------------------------------------------------
local tabLua = guiCreateTab("Lua инжектор", tabPanel)
local luaMemo = guiCreateMemo(10, 10, windowW - 40, windowH - 180, "-- Впишите сюда ваш Lua код", false, tabLua)
local btnRunLua = guiCreateButton(10, windowH - 160, 200, 35, "Запустить код из окна", false, tabLua)
local btnClearLua = guiCreateButton(220, windowH - 160, 200, 35, "Clear All", false, tabLua)
local btnReloadRemote = guiCreateButton(10, windowH - 115, 410, 45, "🔄 ВЫГРУЗИТЬ И ОБНОВИТЬ С GITHUB", false, tabLua)

-- Запуск локального кода
addEventHandler("onClientGUIClick", btnRunLua, function()
    local code = guiGetText(luaMemo)
    local func, err = loadstring(code)
    if func then pcall(func) else outputChatBox("Ошибка: "..tostring(err)) end
end, false)

-- Очистка поля
addEventHandler("onClientGUIClick", btnClearLua, function() guiSetText(luaMemo, "") end, false)

-- ГЛАВНАЯ КНОПКА: ВЫГРУЗКА И ЗАГРУЗКА
addEventHandler("onClientGUIClick", btnReloadRemote, function()
    fetchRemote("https://raw.githubusercontent.com/tibla/MrLorem/refs/heads/main/LuaInjector.lua", function(data, err)
        if err == 0 then
            fullCleanup() -- Сначала стираем всё текущее (включая это меню)
            local func, compileErr = loadstring(data)
            if func then 
                pcall(func) -- Запускаем новый код из файла
                triggerEvent("ShowSuccess", root, "Скрипт успешно обновлен!")
            end
        else
            outputChatBox("[Error] Не удалось скачать файл: " .. tostring(err), 255, 0, 0)
        end
    end)
end, false)

----------------------------------------------------------------
-- ОБНОВЛЕННЫЕ ФУНКЦИИ ТЕЛЕПОРТАЦИИ (С ПРОВЕРКОЙ МАШИНЫ)
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

function buyRepairKit()
    triggerServerEvent("Gasstation:BuyItems", root, 1, "gasstation_14")
    outputChatBox("[Engine] #00FF00Запрос на ремкомплект отправлен!", 255, 255, 255, true)
end

function buyMedKit()
    triggerServerEvent("Shop:PlayerWantBuyItem", root, {basket={[5]=1}, business_id="drugstore_5", type_pay=1, type_product=4})
    outputChatBox("[Engine] #00FF00Запрос на аптечку отправлен!", 255, 255, 255, true)
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
        
        _G.GH_Cache.events["freecamUpdate"] = { root = root, fn = updateFreecam }
        _G.GH_Cache.events["freecamMouse"] = { root = root, fn = freecamMouseMove }
        
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
-- FLY ФУНКЦИИ
----------------------------------------------------------------
function rynok()
    triggerServerEvent("CentralMarket:AcceptEnter", root)
end

local noclip = false
local lastPos = {x = 0, y = 0, z = 0}

function fly()
    local veh = getPedOccupiedVehicle(localPlayer)
    if veh then
        outputChatBox("❌ Нельзя включить флай в машине!", 255, 0, 0)
        return
    end

    noclip = not noclip
    if noclip then
        setElementFrozen(localPlayer, true)
        setElementCollisionsEnabled(localPlayer, false)
    else
        setElementFrozen(localPlayer, false)
        setElementCollisionsEnabled(localPlayer, true)
        setElementPosition(localPlayer, lastPos.x, lastPos.y, lastPos.z)
    end
end

-- Даем функции имя, чтобы ее можно было выгрузить
local function flyRender()
    if not noclip then return end

    local x, y, z = getElementPosition(localPlayer)
    lastPos.x, lastPos.y, lastPos.z = x, y, z

    local camX, camY, camZ, lookX, lookY, lookZ = getCameraMatrix()
    local dx, dy, dz = lookX - camX, lookY - camY, lookZ - camZ
    local len = math.sqrt(dx*dx + dy*dy + dz*dz)
    if len == 0 then return end

    dx, dy, dz = dx/len, dy/len, dz/len

    local speed = 0.6
    local boost = getKeyState("lshift") and 2.5 or 1.0
    local s = speed * boost

    if getKeyState("w") then x = x + dx * s; y = y + dy * s; z = z + dz * s end
    if getKeyState("s") then x = x - dx * s; y = y - dy * s; z = z - dz * s end

    local rightX, rightY = dy, -dx
    if getKeyState("a") then x = x - rightX * s; y = y - rightY * s end
    if getKeyState("d") then x = x + rightX * s; y = y + rightY * s end
    if getKeyState("space") then z = z + s end

    setElementPosition(localPlayer, x, y, z)
    local rotZ = math.deg(math.atan2(dy, dx)) - 90
    setElementRotation(localPlayer, 0, 0, rotZ)
end
addEventHandler("onClientRender", root, flyRender)
_G.GH_Cache.events["flyRender"] = { root = root, fn = flyRender } -- СОХРАНЯЕМ В КЭШ

----------------------------------------------------------------
-- FLY ФУНКЦИИ (МАШИНА)
----------------------------------------------------------------
local flycarEnabled = false

function flycar()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then return end

    flycarEnabled = not flycarEnabled
    setElementFrozen(veh, flycarEnabled)
    setVehicleTurnVelocity(veh, 0, 0, 0)

    outputChatBox("[FlyCar] " .. (flycarEnabled and "#00FF00Включен" or "#FF0000Выключен"), 255,255,255,true)
end

local function flyCarRender()
    if not flycarEnabled then return end

    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleController(veh) ~= localPlayer then return end

    local x, y, z = getElementPosition(veh)
    local camX, camY, camZ, lookX, lookY, lookZ = getCameraMatrix()

    -- ВПЕРЕД
    local dx, dy, dz = lookX - camX, lookY - camY, lookZ - camZ
    local len = math.sqrt(dx*dx + dy*dy + dz*dz)
    if len == 0 then return end

    dx, dy, dz = dx / len, dy / len, dz / len

    -- ВПРАВО (исправлено)
    local rx = -dy
    local ry = dx

    local speed = 0.8
    local boost = getKeyState("lshift") and 2.5 or 1.0
    local s = speed * boost

    -- W / S
    if getKeyState("w") then
        x = x + dx * s
        y = y + dy * s
        z = z + dz * s
    end

    if getKeyState("s") then
        x = x - dx * s
        y = y - dy * s
        z = z - dz * s
    end

    -- A / D (теперь правильно)
    if getKeyState("a") then
        x = x + rx * s
        y = y + ry * s
    end

    if getKeyState("d") then
        x = x - rx * s
        y = y - ry * s
    end

    -- Вверх / вниз
    if getKeyState("space") then z = z + s end
    if getKeyState("lctrl") then z = z - s end

    setElementPosition(veh, x, y, z)

    -- Поворот машины
    local rotZ = -math.deg(math.atan2(dx, dy))
    local rotX = math.deg(math.asin(dz))
    setElementRotation(veh, rotX, 0, rotZ)
end

addEventHandler("onClientRender", root, flyCarRender)

if _G.GH_Cache and _G.GH_Cache.events then
    _G.GH_Cache.events["flyCarRender"] = { root = root, fn = flyCarRender }
end
local jeka  = 6719
local denis = 6555
local lexa  = 5131

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

        triggerEvent("ShowSuccess", root, "Загрузка зоны рядом с " .. name .. "...")

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

                triggerEvent("ShowSuccess", root, "Телепорт к " .. name .. " завершен!")
            end
        end, 200, 1)

    else
        triggerEvent("ShowSuccess", root, name .. " не найден.")
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

function tpLexa()
    teleportToTextID(lexa, "Lexa")
end

----------------------------------------------------------------
--ФАРМ АВТОБУС
----------------------------------------------------------------
local autoMode = false
function autoLoop()
    if not autoMode then return end
    local veh = getPedOccupiedVehicle(localPlayer)
    if veh then 
        fixVehicle(veh) 
        setElementCollisionsEnabled(veh, false)
    end
    local waypoint = false
    for _, v in ipairs(getElementsByType("blip")) do
        if getBlipIcon(v) == 41 then waypoint = v break end
    end
    if waypoint then
        local wx, wy, wz = getElementPosition(waypoint)
        setElementPosition(veh or localPlayer, wx, wy, wz + 1)
    end
end
addEventHandler("onClientRender", root, autoLoop)
_G.GH_Cache.events["autoLoop"] = { root = root, fn = autoLoop }

function smartMarketGhost()
    local target = getPedOccupiedVehicle(localPlayer) or localPlayer
    
    -- 1. Сохраняем позицию
    local x, y, z = getElementPosition(target)
    local rx, ry, rz = getElementRotation(target)

    -- 2. Летим на биржу (сервер дает Dim 50, Int 1)
    rynok() 
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
            end, 2000, 1)
        end
    end, 150, 1)
end

-- Регистрация в кэше
_G.GH_Cache.events["smartMarketGhost"] = { root = root, fn = smartMarketGhost }

----------------------------------------------------------------
-- НАПОЛНЕНИЕ МЕНЮ КНОПКАМИ (ВКЛАДКА "ПРИКОЛЫ")
----------------------------------------------------------------
addMenuButton("🚀 ФАРМ АВТОБУС(])", autoLoop)
addMenuButton("🚀 ЗАЙТИ В ДРУГОЙ МИР(ЧТО БЫ ТЕБЯ НЕБЫЛО ВИДНО)", smartMarketGhost)
addMenuButton("🚀 Телепорт к метке (X)", teleportToWaypoint)
addMenuButton("🔧 Починить авто (H)", repairVehicle)
addMenuButton("📷 FreeCam ([)", toggleFreecam)
addMenuButton("🛠️ Купить ремку (0)", buyRepairKit)
addMenuButton("🩹 Купить аптечку (9)", buyMedKit)
addMenuButton("📍 ТП: Взять (L)", tpTake)
addMenuButton("📍 ТП: Положить (K)", tpPut)
addMenuButton("📝 Копировать координаты (J)", copyCoords)
addMenuButton("🚀 Летать на машине (f6)", flycar)
addMenuButton("🚀 FLY НА ПЕРСОНАЖЕ!!! (f5)", fly)
addMenuButton("ТП НА БИРЖУ!!!", rynok)
addMenuButton("ТП К ДЕНИСУ(6555)", tpDenis)
addMenuButton("ТП К ЖЕКЕ(6719)", tpJeka)
addMenuButton("ТП К ЛЁХЕ(5131)", tpLexa)

----------------------------------------------------------------
-- БИНДЫ (ГОРЯЧИЕ КЛАВИШИ)
----------------------------------------------------------------
local isVisible = false
bindKey("f9", "down", function()
    isVisible = not isVisible
    guiSetVisible(mainWin, isVisible)
    showCursor(isVisible)
end)

bindKey("x", "down", teleportToWaypoint)
bindKey("h", "down", repairVehicle)
bindKey("[", "down", toggleFreecam)
bindKey("0", "down", buyRepairKit)
bindKey("9", "down", buyMedKit)
bindKey("l", "down", tpTake)
bindKey("k", "down", tpPut)
bindKey("j", "down", copyCoords)
bindKey("f6", "down", flycar)

bindKey("f5", "down", fly)
local function speedBoost()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleController(veh) ~= localPlayer then return end
    local sx, sy, sz = getElementVelocity(veh)
    setElementVelocity(veh, sx*1.5, sy*1.5, sz)
end
bindKey("lshift", "down", speedBoost)
bindKey("]", "down", function() 
    autoMode = not autoMode 
    local v = getPedOccupiedVehicle(localPlayer)
    if not autoMode and v then setElementCollisionsEnabled(v, true) end
    triggerEvent(autoMode and "ShowSuccess" or "ShowError", root, "Auto-Mode "..(autoMode and "ON" or "OFF"))
end)
