triggerEvent("ShowSuccess", root, "Тест уведомления")
triggerEvent("ShowError", root, "Тест уведомления")
triggerEvent("ShowWarning", root, "Тест уведомления")
----------------------------------------------------------------
-- SCREEN
----------------------------------------------------------------
local screenW, screenH = guiGetScreenSize()
local windowW, windowH = 750, 720
local x, y = (screenW - windowW) / 2, (screenH - windowH) / 2

----------------------------------------------------------------
-- GUI WINDOW
----------------------------------------------------------------
local mainWin = guiCreateWindow(x, y, windowW, windowH, "", false)
guiWindowSetSizable(mainWin, false)
guiSetVisible(mainWin, false)

----------------------------------------------------------------
-- ЗАГОЛОВОК
----------------------------------------------------------------
local titleLabel = guiCreateLabel(0, 0, windowW, 25, "MR.Lorem | By Lorem", false, mainWin)
guiLabelSetHorizontalAlign(titleLabel, "center", false)
guiLabelSetVerticalAlign(titleLabel, "center")
guiSetFont(titleLabel, "default-bold-small")
guiLabelSetColor(titleLabel, 255, 255, 255)

----------------------------------------------------------------
-- TAB PANEL
----------------------------------------------------------------
local tabPanel = guiCreateTabPanel(10, 25, windowW - 20, windowH - 40, false, mainWin)

----------------------------------------------------------------
-- TAB 1: ПРИКОЛЫ
----------------------------------------------------------------
local tabFun = guiCreateTab("Приколы", tabPanel)
local scrollFun = guiCreateScrollPane(5, 5, windowW - 30, windowH - 80, false, tabFun)

local currentY = 10
local function addMenuButton(name, fn)
    local btn = guiCreateButton(10, currentY, 250, 35, name, false, scrollFun)
    addEventHandler("onClientGUIClick", btn, fn, false)
    currentY = currentY + 40
end

----------------------------------------------------------------
-- TAB 2: LUA ИНЖЕКТОР
----------------------------------------------------------------
local tabLua = guiCreateTab("Lua инжектор", tabPanel)

-- Поле для ввода локального кода
local luaMemo = guiCreateMemo(10, 10, windowW - 40, windowH - 180, "-- Впишите сюда ваш Lua код", false, tabLua)

-- Кнопки управления локальным кодом
local btnRunLua = guiCreateButton(10, windowH - 160, 200, 35, "Запустить код из окна", false, tabLua)
local btnClearLua = guiCreateButton(220, windowH - 160, 200, 35, "Очистить", false, tabLua)

-- Кнопка для загрузки с GitHub
local btnReloadRemote = guiCreateButton(10, windowH - 115, 410, 45, "🔄 Перезагрузить скрипт с GitHub", false, tabLua)

-- Запуск локального кода
addEventHandler("onClientGUIClick", btnRunLua, function()
    local code = guiGetText(luaMemo)
    if code == "" then return end
    
    local func, err = loadstring(code)
    if func then
        local success, execErr = pcall(func)
        if success then
            outputChatBox("[Инжектор] #00FF00Скрипт успешно выполнен!", 255, 255, 255, true)
        else
            outputChatBox("[Инжектор] #FF0000Ошибка выполнения: " .. tostring(execErr), 255, 255, 255, true)
        end
    else
        outputChatBox("[Инжектор] #FF0000Ошибка синтаксиса: " .. tostring(err), 255, 255, 255, true)
    end
end, false)

-- Очистка поля
addEventHandler("onClientGUIClick", btnClearLua, function()
    guiSetText(luaMemo, "")
end, false)

-- Загрузка и запуск удаленного кода
addEventHandler("onClientGUIClick", btnReloadRemote, function()
    outputChatBox("[Инжектор] #FFFF00Загрузка скрипта с GitHub...", 255, 255, 255, true)
    
    fetchRemote("https://raw.githubusercontent.com/tibla/12321/refs/heads/main/freecam.txt", function(data, err)
        -- err == 0 означает, что ошибок при скачивании нет
        if err == 0 then
            local func, compileErr = loadstring(data)
            if func then
                local success, execErr = pcall(func)
                if success then
                    outputChatBox("[Инжектор] #00FF00Скрипт с GitHub успешно загружен и запущен!", 255, 255, 255, true)
                else
                    outputChatBox("[Инжектор] #FF0000Ошибка выполнения (GitHub): " .. tostring(execErr), 255, 255, 255, true)
                end
            else
                outputChatBox("[Инжектор] #FF0000Ошибка синтаксиса (GitHub): " .. tostring(compileErr), 255, 255, 255, true)
            end
        else
            outputChatBox("[Инжектор] #FF0000Ошибка сети! Код: " .. tostring(err), 255, 255, 255, true)
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

    if getKeyState("w") then
        camX = camX + fX * currentSpeed
        camY = camY + fY * currentSpeed
        camZ = camZ + fZ * currentSpeed
    end
    if getKeyState("s") then
        camX = camX - fX * currentSpeed
        camY = camY - fY * currentSpeed
        camZ = camZ - fZ * currentSpeed
    end
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
        camX, camY, camZ = getElementPosition(localPlayer)
        camRotX, camRotY = 0, 0

        setElementFrozen(localPlayer, true)
        setElementAlpha(localPlayer, 0)
        toggleAllControls(false, true, false)
        showCursor(false)
        setCursorAlpha(0)

        addEventHandler("onClientRender", root, updateFreecam)
        addEventHandler("onClientCursorMove", root, freecamMouseMove)
        outputChatBox("[Engine] #00FF00FreeCam ON", 255, 255, 255, true)
    else
        setElementFrozen(localPlayer, false)
        setElementAlpha(localPlayer, 255)
        setCameraTarget(localPlayer)
        toggleAllControls(true)
        setCursorAlpha(255)

        removeEventHandler("onClientRender", root, updateFreecam)
        removeEventHandler("onClientCursorMove", root, freecamMouseMove)
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

addEventHandler("onClientRender", root, function()
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
end)

local flycarEnabled = false
function flycar()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then return end
    flycarEnabled = not flycarEnabled
    setElementFrozen(veh, flycarEnabled)
    setVehicleTurnVelocity(veh, 0, 0, 0)
end

addEventHandler("onClientRender", root, function()
    if not flycarEnabled then return end
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleController(veh) ~= localPlayer then return end

    local x, y, z = getElementPosition(veh)
    local camX, camY, camZ, lookX, lookY, lookZ = getCameraMatrix()
    local dx, dy, dz = lookX - camX, lookY - camY, lookZ - camZ
    local len = math.sqrt(dx*dx + dy*dy + dz*dz)
    if len == 0 then return end

    dx, dy, dz = dx/len, dy/len, dz/len

    local speed = 0.8
    local boost = getKeyState("lshift") and 2.5 or 1.0
    local s = speed * boost

    if getKeyState("w") then x = x + dx * s; y = y + dy * s; z = z + dz * s end
    if getKeyState("s") then x = x - dx * s; y = y - dy * s; z = z - dz * s end

    local rightX, rightY = dy, -dx
    if getKeyState("a") then x = x - rightX * s; y = y - rightY * s end
    if getKeyState("d") then x = x + rightX * s; y = y + rightY * s end
    if getKeyState("space") then z = z + s end

    setElementPosition(veh, x, y, z)
    local rotZ = math.deg(math.atan2(dy, dx)) - 90
    local rotX = math.deg(math.asin(dz))
    setElementRotation(veh, rotX, 0, rotZ)
end)

----------------------------------------------------------------
-- НАПОЛНЕНИЕ МЕНЮ КНОПКАМИ (ВКЛАДКА "ПРИКОЛЫ")
----------------------------------------------------------------
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
bindKey("lshift", "down", function()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleController(veh) ~= localPlayer then return end
    local sx, sy, sz = getElementVelocity(veh)
    setElementVelocity(veh, sx*1.5, sy*1.5, sz)
end)
