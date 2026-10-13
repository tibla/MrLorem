----------------------------------------------------------------
-- ГЛОБАЛЬНАЯ ТАБЛИЦА И ОЧИСТКА
----------------------------------------------------------------
_G.GH_Cache = _G.GH_Cache or {}
_G.GH_Cache.events = _G.GH_Cache.events or {}
_G.GH_Cache.binds = _G.GH_Cache.binds or {}
_G.GH_Cache.gui = _G.GH_Cache.gui or {}
_G.GH_Cache.timers = _G.GH_Cache.timers or {}
_G.GH_Cache.settings = _G.GH_Cache.settings or {}

-- Единое хранилище настроек. Оно переживает повторный запуск этого кода.
-- Важно: отдельные разделы не перезаписывают друг друга.
local settingsCache = _G.GH_Cache.settings
settingsCache.binds = settingsCache.binds or {}

-- Настройки встроенного аимбота из переданного пользователем кода.
-- Отдельное окно F10 не создаём: управление находится во вкладках
-- «Приколы 2» и «Настройка 2».
local savedAimbotSettings = type(settingsCache.aimbot) == "table"
    and settingsCache.aimbot
    or {}

local aimbotEnabled = savedAimbotSettings.enabled == true
local AIM_FOV = math.max(10, math.min(2000, tonumber(savedAimbotSettings.fov) or 300))
local AIM_CORRECTION = tonumber(savedAimbotSettings.correction) or 2.2
local AIM_USE_CAMERA = savedAimbotSettings.useCamera ~= false
local aimbotRender
local aimbotStatusLabel
local aimbotSettingsStatus

local AIMBOT_CODE_TEMPLATE = [[
-- Встроенный аимбот из присланного кода.
-- Управление: вкладка «Приколы 2», настройки: «Настройка 2».

local function findRotation(x1, y1, x2, y2)
    local rot = -math.deg(math.atan2(x2 - x1, y2 - y1))
    if rot < 0 then rot = rot + 360 end
    return rot
end

local function getCrosshairPosition()
    local sw, sh = guiGetScreenSize()
    return sw * 0.535, sh * 0.400
end

local function getClosestPlayerToCrosshair()
    local cx, cy = getCrosshairPosition()
    local closestPlayer, targetPos
    local minDistance = AIM_FOV
    local interior = getElementInterior(localPlayer)
    local dimension = getElementDimension(localPlayer)

    for _, player in ipairs(getElementsByType("player", root, true)) do
        if player ~= localPlayer and not isPedDead(player)
            and getElementInterior(player) == interior
            and getElementDimension(player) == dimension then
            local success, hx, hy, hz = pcall(getPedBonePosition, player, 0)
            if not success or not hx then
                hx, hy, hz = getElementPosition(player)
                hz = hz + 0.2
            end

            local sx, sy = getScreenFromWorldPosition(hx, hy, hz)
            if sx and sy then
                local distance = math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2)
                if distance < minDistance then
                    minDistance = distance
                    closestPlayer = player
                    targetPos = { x = hx, y = hy, z = hz }
                end
            end
        end
    end

    return closestPlayer, targetPos
end
]]

local function saveSettings()
    _G.GH_Cache.settings = settingsCache
end

local function getSavedBind(bindId, defaultKey)
    local savedKey = settingsCache.binds[bindId]

    -- false означает, что пользователь специально удалил бинд.
    if savedKey == false then
        return nil
    end

    if type(savedKey) == "string" and savedKey ~= "" then
        return savedKey
    end

    return defaultKey
end

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
    if _G.GH_Cache.aimbotRender then
        removeEventHandler("onClientRender", root, _G.GH_Cache.aimbotRender)
        _G.GH_Cache.aimbotRender = nil
    end
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
    if not data then
        waitingForBind = nil
        return
    end

    if data.key then unbindKey(data.key, "down", data.fn) end
    
    if button == "escape" or button == "backspace" then
        data.key = nil
        guiSetText(waitingForBind, "?")
        settingsCache.binds[data.bindId] = false
        saveSettings()
        outputChatBox("Бинд удален", 255, 0, 0)
    else
        data.key = button
        guiSetText(waitingForBind, string.upper(button))
        bindKey(button, "down", data.fn)
        settingsCache.binds[data.bindId] = button
        saveSettings()
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

-- Создаём дополнительные вкладки сразу после TabPanel.
-- Поэтому они останутся видимыми даже если другая функция ниже даст ошибку.
local extraTabFun2 = guiCreateTab("Приколы 2", tabPanel)
local extraTabSettings2 = guiCreateTab("Настройка 2", tabPanel)

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
    defaultKey,
    bindId
)
    side = side or "left"
    bindId = bindId or name

    local savedKey = getSavedBind(bindId, defaultKey)

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
        savedKey and string.upper(savedKey) or "?",
        false,
        parent
    )

    bindsData[bindButton] = {
        fn = fn,
        key = savedKey,
        name = name,
        bindId = bindId
    }

    if savedKey then
        bindKey(
            savedKey,
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
    defaultKey,
    bindId
)
    addActionButton(
        scrollFun,
        colY,
        name,
        fn,
        side,
        defaultKey,
        bindId
    )
end
----------------------------------------------------------------
-- ВСТРОЕННЫЙ АИМБОТ ИЗ ПРИСЛАННОГО КОДА
----------------------------------------------------------------
local function findRotation(x1, y1, x2, y2)
    local rotation = -math.deg(math.atan2(x2 - x1, y2 - y1))
    if rotation < 0 then
        rotation = rotation + 360
    end
    return rotation
end

local function getCrosshairPosition()
    local sw, sh = guiGetScreenSize()
    return sw * 0.535, sh * 0.400
end

local function getClosestPlayerToCrosshair()
    local cx, cy = getCrosshairPosition()
    local closestPlayer
    local targetPosition
    local minDistance = AIM_FOV
    local currentInterior = getElementInterior(localPlayer)
    local currentDimension = getElementDimension(localPlayer)

    for _, player in ipairs(getElementsByType("player", root, true)) do
        if player ~= localPlayer and not isPedDead(player)
            and getElementInterior(player) == currentInterior
            and getElementDimension(player) == currentDimension then
            local success, hx, hy, hz = pcall(getPedBonePosition, player, 0)
            if not success or not hx then
                hx, hy, hz = getElementPosition(player)
                hz = hz + 0.2
            end

            local sx, sy = getScreenFromWorldPosition(hx, hy, hz)
            if sx and sy then
                local distance = math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2)
                if distance < minDistance then
                    minDistance = distance
                    closestPlayer = player
                    targetPosition = { x = hx, y = hy, z = hz }
                end
            end
        end
    end

    return closestPlayer, targetPosition
end

aimbotRender = function()
    if not aimbotEnabled
        or not getControlState("aim_weapon")
        or isCursorShowing()
        or not isElement(localPlayer)
        or isPedDead(localPlayer) then
        return
    end

    local target, targetPosition = getClosestPlayerToCrosshair()
    if not target or not targetPosition then
        return
    end

    local px, py = getElementPosition(localPlayer)
    local rotation = findRotation(px, py, targetPosition.x, targetPosition.y)
    rotation = rotation + AIM_CORRECTION

    setPedRotation(localPlayer, rotation)
    setElementRotation(localPlayer, 0, 0, rotation, "Z", true)

    if AIM_USE_CAMERA and setPedCameraRotation then
        setPedCameraRotation(localPlayer, rotation)
    end
end

addEventHandler("onClientRender", root, aimbotRender)
_G.GH_Cache.aimbotRender = aimbotRender

local function updateAimbotStatus()
    if isElement(aimbotStatusLabel) then
        guiSetText(
            aimbotStatusLabel,
            "Состояние: " .. (aimbotEnabled and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН")
        )
        guiLabelSetColor(
            aimbotStatusLabel,
            aimbotEnabled and 80 or 255,
            aimbotEnabled and 220 or 100,
            aimbotEnabled and 130 or 100
        )
    end
end

local function toggleAimbot()
    aimbotEnabled = not aimbotEnabled
    settingsCache.aimbot = settingsCache.aimbot or {}
    settingsCache.aimbot.enabled = aimbotEnabled
    saveSettings()
    updateAimbotStatus()

    outputChatBox(
        aimbotEnabled
            and "[Aimbot] #00FF00Включен. Наведение работает только при зажатой ПКМ."
            or "[Aimbot] #FF0000Выключен.",
        255,
        255,
        255,
        true
    )
end

local function teleportToBlip41()
    local targetBlip

    for _, blip in ipairs(getElementsByType("blip")) do
        if isElement(blip) and getBlipIcon(blip) == 41 then
            targetBlip = blip
            break
        end
    end

    if not targetBlip then
        outputChatBox("[Авс2] #FF0000Blip с иконкой 41 не найден.", 255, 255, 255, true)
        return
    end

    local x, y, z = getElementPosition(targetBlip)
    triggerServerEvent("RequestTeleport", localPlayer, x, y, z, 0, 0)
    outputChatBox("[Авс2] #00FF00Запрос на телепорт к blip 41 отправлен.", 255, 255, 255, true)
end

----------------------------------------------------------------
-- ВКЛАДКИ «ПРИКОЛЫ 2» И «НАСТРОЙКА 2»
----------------------------------------------------------------
local tabFun2 = extraTabFun2
local scrollFun2 = guiCreateScrollPane(
    5,
    5,
    windowW - 30,
    windowH - 80,
    false,
    tabFun2
)
guiScrollPaneSetScrollBars(scrollFun2, false, true)

local colYFun2 = { left = 10, center = 10, right = 10 }
local aimbotInfo = guiCreateLabel(
    10,
    10,
    math.max(300, windowW - 60),
    40,
    "Аимбот из присланного кода. Работает только при зажатой ПКМ и без открытого курсора.",
    false,
    scrollFun2
)
guiLabelSetHorizontalAlign(aimbotInfo, "left", true)
guiSetFont(aimbotInfo, "default-small")

aimbotStatusLabel = guiCreateLabel(
    10,
    55,
    300,
    24,
    "",
    false,
    scrollFun2
)
guiSetFont(aimbotStatusLabel, "default-bold-small")

colYFun2.left = 95
addActionButton(
    scrollFun2,
    colYFun2,
    "Aimbot: Вкл/Выкл",
    toggleAimbot,
    "left",
    nil,
    "aimbot_toggle"
)
updateAimbotStatus()

local avs2Button = guiCreateButton(
    10,
    140,
    225,
    35,
    "Авс2",
    false,
    scrollFun2
)
addEventHandler("onClientGUIClick", avs2Button, function(button)
    if button == "left" and not waitingForBind then
        teleportToBlip41()
    end
end, false)

local tabAimbotSettings = extraTabSettings2
local aimbotSettingsTitle = guiCreateLabel(
    18,
    12,
    450,
    22,
    "Настройка кода Aimbot",
    false,
    tabAimbotSettings
)
guiSetFont(aimbotSettingsTitle, "default-bold-small")
guiLabelSetColor(aimbotSettingsTitle, 85, 182, 255)

local aimbotSettingsHint = guiCreateLabel(
    18,
    35,
    math.max(400, windowW - 55),
    36,
    "Изменяй FOV и поправку ниже. Поле кода сохраняется в настройках; сам обработчик подключён один раз, чтобы не создавать дубли и не вызывать краш игры.",
    false,
    tabAimbotSettings
)
guiLabelSetHorizontalAlign(aimbotSettingsHint, "left", true)
guiSetFont(aimbotSettingsHint, "default-small")
guiLabelSetColor(aimbotSettingsHint, 140, 160, 185)

local checkAimbotEnabled = guiCreateCheckBox(
    20,
    82,
    300,
    24,
    "Включить Aimbot",
    aimbotEnabled,
    false,
    tabAimbotSettings
)

guiCreateLabel(20, 116, 160, 25, "Радиус захвата FOV:", false, tabAimbotSettings)
local editAimbotFov = guiCreateEdit(
    190,
    113,
    110,
    28,
    tostring(AIM_FOV),
    false,
    tabAimbotSettings
)

guiCreateLabel(330, 116, 160, 25, "Поправка угла:", false, tabAimbotSettings)
local editAimbotCorrection = guiCreateEdit(
    485,
    113,
    100,
    28,
    tostring(AIM_CORRECTION),
    false,
    tabAimbotSettings
)

local checkAimbotCamera = guiCreateCheckBox(
    605,
    116,
    120,
    24,
    "Камера",
    AIM_USE_CAMERA,
    false,
    tabAimbotSettings
)

local codeEditorTop = 158
local codeEditorHeight = math.max(180, windowH - 300)
local aimbotCodeMemo = guiCreateMemo(
    18,
    codeEditorTop,
    math.max(400, windowW - 56),
    codeEditorHeight,
    type(savedAimbotSettings.code) == "string"
        and savedAimbotSettings.code
        or AIMBOT_CODE_TEMPLATE,
    false,
    tabAimbotSettings
)
guiSetFont(aimbotCodeMemo, "default-small")

local aimbotSaveButton = guiCreateButton(
    18,
    windowH - 112,
    220,
    36,
    "Сохранить настройку 2",
    false,
    tabAimbotSettings
)
local aimbotResetButton = guiCreateButton(
    248,
    windowH - 112,
    170,
    36,
    "Сбросить код",
    false,
    tabAimbotSettings
)
local aimbotCheckButton = guiCreateButton(
    428,
    windowH - 112,
    170,
    36,
    "Проверить код",
    false,
    tabAimbotSettings
)

aimbotSettingsStatus = guiCreateLabel(
    18,
    windowH - 70,
    math.max(400, windowW - 56),
    22,
    "Настройки ещё не изменены.",
    false,
    tabAimbotSettings
)
guiLabelSetHorizontalAlign(aimbotSettingsStatus, "left", true)

local function setAimbotSettingsStatus(text, r, g, b)
    if isElement(aimbotSettingsStatus) then
        guiSetText(aimbotSettingsStatus, text)
        guiLabelSetColor(aimbotSettingsStatus, r, g, b)
    end
end

addEventHandler("onClientGUIClick", aimbotSaveButton, function(button)
    if button ~= "left" then return end

    local fov = tonumber(guiGetText(editAimbotFov))
    local correction = tonumber(guiGetText(editAimbotCorrection))
    if not fov or not correction then
        setAimbotSettingsStatus("Ошибка: FOV и поправка должны быть числами.", 255, 100, 100)
        return
    end

    AIM_FOV = math.max(10, math.min(2000, fov))
    AIM_CORRECTION = math.max(-180, math.min(180, correction))
    AIM_USE_CAMERA = guiCheckBoxGetSelected(checkAimbotCamera)
    aimbotEnabled = guiCheckBoxGetSelected(checkAimbotEnabled)

    local codeText = guiGetText(aimbotCodeMemo)
    if codeText == "" then
        codeText = AIMBOT_CODE_TEMPLATE
        guiSetText(aimbotCodeMemo, codeText)
    end

    settingsCache.aimbot = {
        enabled = aimbotEnabled,
        fov = AIM_FOV,
        correction = AIM_CORRECTION,
        useCamera = AIM_USE_CAMERA,
        code = codeText
    }
    saveSettings()

    guiSetText(editAimbotFov, tostring(AIM_FOV))
    guiSetText(editAimbotCorrection, tostring(AIM_CORRECTION))
    updateAimbotStatus()
    setAimbotSettingsStatus("Настройка 2 сохранена.", 80, 220, 130)
end, false)

addEventHandler("onClientGUIClick", aimbotResetButton, function(button)
    if button ~= "left" then return end
    guiSetText(aimbotCodeMemo, AIMBOT_CODE_TEMPLATE)
    setAimbotSettingsStatus("Код восстановлен. Нажми «Сохранить настройку 2», чтобы сохранить его.", 255, 188, 90)
end, false)

addEventHandler("onClientGUIClick", aimbotCheckButton, function(button)
    if button ~= "left" then return end

    local codeText = guiGetText(aimbotCodeMemo)
    local compiler = loadstring or load
    if not compiler then
        setAimbotSettingsStatus("Проверка недоступна в этой сборке MTA.", 255, 188, 90)
        return
    end

    local chunk, compileError = compiler(codeText, "@AimbotSettings2")
    if chunk then
        setAimbotSettingsStatus("Синтаксис кода корректен. Код не запускается повторно поверх встроенного обработчика.", 80, 220, 130)
    else
        setAimbotSettingsStatus("Ошибка синтаксиса: " .. tostring(compileError), 255, 100, 100)
    end
end, false)

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
    speedBoostMode = "press",
    tpTake = { x = 483.034, y = -1004.596, z = 21.436 },
    tpPut = { x = 776.723, y = -1581.878, z = 47.749 }
}

local purchaseConfig = {
    repairKit = 1,
    medKit = 1,
    lunch = 1,
    treasureMap = 1,
    chernobylMap = 1
}

-- Сохраняем настройки в общей таблице, чтобы они не сбрасывались при переинжекте.
local savedSettings = settingsCache
if type(savedSettings.fly) == "table" then
    for key, value in pairs(savedSettings.fly) do
        if flyConfig[key] ~= nil and type(value) == type(flyConfig[key]) then
            flyConfig[key] = value
        end
    end
end

if type(savedSettings.purchase) == "table" then
    for key, defaultValue in pairs(purchaseConfig) do
        local savedValue = tonumber(savedSettings.purchase[key])
        if savedValue then
            purchaseConfig[key] = math.floor(math.max(1, math.min(100, savedValue)))
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
    local amount = purchaseConfig.repairKit
    triggerServerEvent("Gasstation:BuyItems", root, amount, "gasstation_14")
    outputChatBox("[Engine] #00FF00Запрос на ремкомплект: x" .. amount, 255, 255, 255, true)
end

function buyMedKit()
    local amount = purchaseConfig.medKit
    triggerServerEvent("Shop:PlayerWantBuyItem", root, {basket={[5]=amount}, business_id="drugstore_5", type_pay=1, type_product=4})
    outputChatBox("[Engine] #00FF00Запрос на аптечку: x" .. amount, 255, 255, 255, true)
end
function buylunch()
 local amount = purchaseConfig.lunch
 triggerServerEvent ( "Shop:PlayerWantBuyItem", root, {
    basket = {
      [5] = amount
    },
    business_id = "shop_10",
    type_pay = 1,
    type_product = 1
  } )
    outputChatBox("[Engine] #00FF00Запрос на Ланч: x" .. amount, 255, 255, 255, true)
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

local purchaseTitle = guiCreateLabel(18, 505, 350, 18, "Количество покупок за одно нажатие", false, tabFlySettings)
guiSetFont(purchaseTitle, "default-bold-small")
guiLabelSetColor(purchaseTitle, 255, 188, 90)

local purchaseHint = guiCreateLabel(18, 525, 700, 18, "Значения от 1 до 100. Они используются кнопками покупки и их биндами.", false, tabFlySettings)
guiSetFont(purchaseHint, "default-small")
guiLabelSetColor(purchaseHint, 140, 160, 185)

guiCreateLabel(20, 555, 145, 25, "Ремкомплектов:", false, tabFlySettings)
local editRepairAmount = guiCreateEdit(170, 552, 75, 28, tostring(purchaseConfig.repairKit), false, tabFlySettings)

guiCreateLabel(270, 555, 105, 25, "Аптечек:", false, tabFlySettings)
local editMedKitAmount = guiCreateEdit(380, 552, 75, 28, tostring(purchaseConfig.medKit), false, tabFlySettings)

guiCreateLabel(480, 555, 75, 25, "Еды:", false, tabFlySettings)
local editLunchAmount = guiCreateEdit(560, 552, 75, 28, tostring(purchaseConfig.lunch), false, tabFlySettings)

guiCreateLabel(20, 590, 145, 25, "Карт клада:", false, tabFlySettings)
local editTreasureMapAmount = guiCreateEdit(170, 587, 75, 28, tostring(purchaseConfig.treasureMap), false, tabFlySettings)

guiCreateLabel(270, 590, 105, 25, "Карт Чернобыля:", false, tabFlySettings)
local editChernobylMapAmount = guiCreateEdit(380, 587, 75, 28, tostring(purchaseConfig.chernobylMap), false, tabFlySettings)

for _, edit in ipairs({
    editRepairAmount,
    editMedKitAmount,
    editLunchAmount,
    editTreasureMapAmount,
    editChernobylMapAmount
}) do
    guiSetFont(edit, "default-small")
end

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

    purchaseConfig.repairKit = math.floor(getNumberFromEdit(editRepairAmount, purchaseConfig.repairKit, 1, 100))
    purchaseConfig.medKit = math.floor(getNumberFromEdit(editMedKitAmount, purchaseConfig.medKit, 1, 100))
    purchaseConfig.lunch = math.floor(getNumberFromEdit(editLunchAmount, purchaseConfig.lunch, 1, 100))
    purchaseConfig.treasureMap = math.floor(getNumberFromEdit(editTreasureMapAmount, purchaseConfig.treasureMap, 1, 100))
    purchaseConfig.chernobylMap = math.floor(getNumberFromEdit(editChernobylMapAmount, purchaseConfig.chernobylMap, 1, 100))

    settingsCache.fly = {
        playerSpeed = flyConfig.playerSpeed,
        playerBoost = flyConfig.playerBoost,
        carSpeed = flyConfig.carSpeed,
        carBoost = flyConfig.carBoost,
        hidePlayer = flyConfig.hidePlayer,
        hideVehicle = flyConfig.hideVehicle,
        disableCarCollisions = flyConfig.disableCarCollisions,
        restorePosition = flyConfig.restorePosition
    }
    settingsCache.tools = {
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
    settingsCache.purchase = {
        repairKit = purchaseConfig.repairKit,
        medKit = purchaseConfig.medKit,
        lunch = purchaseConfig.lunch,
        treasureMap = purchaseConfig.treasureMap,
        chernobylMap = purchaseConfig.chernobylMap
    }
    saveSettings()

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
    guiSetText(editRepairAmount, tostring(purchaseConfig.repairKit))
    guiSetText(editMedKitAmount, tostring(purchaseConfig.medKit))
    guiSetText(editLunchAmount, tostring(purchaseConfig.lunch))
    guiSetText(editTreasureMapAmount, tostring(purchaseConfig.treasureMap))
    guiSetText(editChernobylMapAmount, tostring(purchaseConfig.chernobylMap))

    outputChatBox("[Настройка] #00FF00Параметры применены!", 255, 255, 255, true)
end, false)

----------------------------------------------------------------
-- ВКЛАДКА ТЕМА
----------------------------------------------------------------
local themeDefinitions = {
    midnight = {
        title = "Ночная",
        window = { 24, 30, 45 },
        text = { 225, 232, 245 },
        muted = { 145, 160, 185 },
        accent = { 85, 182, 255 },
        button = { 185, 215, 255 }
    },
    emerald = {
        title = "Изумрудная",
        window = { 20, 42, 38 },
        text = { 225, 246, 236 },
        muted = { 145, 190, 172 },
        accent = { 70, 225, 155 },
        button = { 180, 255, 220 }
    },
    violet = {
        title = "Фиолетовая",
        window = { 38, 28, 55 },
        text = { 241, 231, 255 },
        muted = { 180, 160, 205 },
        accent = { 190, 125, 255 },
        button = { 225, 200, 255 }
    },
    sunset = {
        title = "Закат",
        window = { 58, 33, 28 },
        text = { 255, 239, 222 },
        muted = { 205, 165, 140 },
        accent = { 255, 145, 75 },
        button = { 255, 215, 170 }
    }
}

local themeOrder = { "midnight", "emerald", "violet", "sunset" }
local selectedTheme = themeDefinitions[settingsCache.theme] and settingsCache.theme or "midnight"
local themeRadioButtons = {}
local themePreview

local function toGuiColour(rgb)
    return string.format("FF%02X%02X%02X", rgb[1], rgb[2], rgb[3])
end

local function setGuiPropertySafe(element, property, value)
    if isElement(element) then
        pcall(guiSetProperty, element, property, value)
    end
end

local function applyMainTheme(themeId)
    local theme = themeDefinitions[themeId] or themeDefinitions.midnight
    selectedTheme = themeId
    settingsCache.theme = themeId
    saveSettings()

    setGuiPropertySafe(mainWin, "TitlebarColour", toGuiColour(theme.window))
    setGuiPropertySafe(mainWin, "TitlebarTextColour", toGuiColour(theme.text))
    setGuiPropertySafe(mainWin, "CaptionColour", toGuiColour(theme.window))
    setGuiPropertySafe(mainWin, "BorderColour", toGuiColour(theme.accent))

    local function applyToElement(element)
        if not isElement(element) then
            return
        end

        local elementType = getElementType(element)
        if elementType == "gui-label" then
            guiLabelSetColor(element, theme.text[1], theme.text[2], theme.text[3])
        elseif elementType == "gui-button" then
            setGuiPropertySafe(element, "NormalTextColour", toGuiColour(theme.button))
            setGuiPropertySafe(element, "HoverTextColour", toGuiColour(theme.accent))
            setGuiPropertySafe(element, "PushedTextColour", toGuiColour(theme.text))
        elseif elementType == "gui-checkbox"
            or elementType == "gui-radiobutton"
        then
            setGuiPropertySafe(element, "NormalTextColour", toGuiColour(theme.text))
        elseif elementType == "gui-edit"
            or elementType == "gui-memo"
        then
            setGuiPropertySafe(element, "TextColour", toGuiColour(theme.text))
        end

        if type(getElementChildren) == "function" then
            local children = getElementChildren(element) or {}
            for _, child in ipairs(children) do
                applyToElement(child)
            end
        end
    end

    applyToElement(mainWin)

    for _, label in ipairs({ flyHint, purchaseHint }) do
        if isElement(label) then
            guiLabelSetColor(label, theme.muted[1], theme.muted[2], theme.muted[3])
        end
    end

    if isElement(themePreview) then
        guiLabelSetColor(themePreview, theme.accent[1], theme.accent[2], theme.accent[3])
        guiSetText(themePreview, "Текущая тема: " .. theme.title .. "\nЦвета применяются сразу и сохраняются в настройках.")
    end
end

local tabTheme = guiCreateTab("Тема", tabPanel)
local themeTitle = guiCreateLabel(20, 18, 500, 25, "Выбери оформление панели", false, tabTheme)
guiSetFont(themeTitle, "default-bold-small")

local themeHint = guiCreateLabel(20, 48, 700, 20, "Тема меняет цвета текста, кнопок и заголовка окна.", false, tabTheme)
guiSetFont(themeHint, "default-small")

local themeY = 95
for _, themeId in ipairs(themeOrder) do
    local theme = themeDefinitions[themeId]
    local currentThemeId = themeId
    local radio = guiCreateRadioButton(25, themeY, 300, 25, theme.title, false, tabTheme)
    themeRadioButtons[themeId] = radio
    guiRadioButtonSetSelected(radio, selectedTheme == themeId)
    setGuiPropertySafe(radio, "NormalTextColour", toGuiColour(theme.accent))

    local swatch = guiCreateLabel(340, themeY, 220, 25, "Акцент: RGB " .. table.concat(theme.accent, ", "), false, tabTheme)
    guiLabelSetColor(swatch, theme.accent[1], theme.accent[2], theme.accent[3])
    themeY = themeY + 42

    addEventHandler("onClientGUIClick", radio, function()
        if guiRadioButtonGetSelected(source) then
            applyMainTheme(currentThemeId)
        end
    end, false)
end

themePreview = guiCreateLabel(25, 290, 680, 55, "", false, tabTheme)
guiSetFont(themePreview, "default-bold-small")
guiLabelSetVerticalAlign(themePreview, "center")

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
   local amount = purchaseConfig.treasureMap
   triggerServerEvent("Shop:PlayerWantBuyItem", root, {basket = { [1] = amount }, business_id = "digging_shop_1", type_pay = 1, type_product = 5})
   outputChatBox("[Engine] #00FF00Запрос на карту клада: x" .. amount, 255, 255, 255, true)
end
cacheEvent("buymap", buymap)

function buymapx()
   local amount = purchaseConfig.chernobylMap
   triggerServerEvent("Shop:PlayerWantBuyItem", root, {basket = { [3] = amount }, business_id = "digging_shop_1", type_pay = 1, type_product = 5})
   outputChatBox("[Engine] #00FF00Запрос на карту Чернобыля: x" .. amount, 255, 255, 255, true)
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
    { name = "Купить карту клада", fn = buymap, side = "left" },
    { name = "Купить карту Чернобыля", fn = buymapx, side = "left" },
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
    addMenuButton(item.name, item.fn, item.side, item.key, item.id)
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

local function addJobButton(name, fn, side, defaultKey, bindId)
    addActionButton(scrollJobs, colYJobs, name, fn, side, defaultKey, bindId)
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
    addJobButton(item.name, item.fn, item.side, item.key, item.id)
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

-- Применяем сохранённую тему после создания всех элементов основной панели.
applyMainTheme(selectedTheme)

outputChatBox("[Engine] #00FF00Скрипт полностью загружен!", 255, 255, 255, true)


-- Standalone MTA:SA Event Dumper
-- Native MTA GUI only
-- F1  - open/close window
-- Esc - close window

local eventLines = {}
local dumperWindow
local eventMemo
local infoLabel
local clearButton
local copyLastButton
local copyButton
local closeButton

local hookInstalled = false
local LOG_MAX_LINES = 3000
local resourceStarted = false

local ignoredEvents = {
    ["CB:SetGroupHealthBuff"] = true,
    ["onCaloriesUpdate"] = true,
    ["lossHungryHealth"] = true,
    ["OnPlayerWantGetPromoStatistics"] = true,
    ["ChatStart"] = true,
    ["ChatStop"] = true,
    ["OnUpdateStaminaHandler"] = true,
    ["Trade:Destroy"] = true,
    ["loadVehicleDirtServer"] = true,
    ["saveWindowsPositionServer"] = true,
    ["afk:cancelByKey"] = true,
    ["onPlayerAFKStateChange"] = true,
}

local function logDebug(message, level)
    outputDebugString(
        "[EventDumper] " .. tostring(message),
        level or 3
    )
end

local function quoteString(value)
    return string.format("%q", tostring(value))
end

local function serializeArgument(value, depth, visited)
    depth = depth or 0
    visited = visited or {}

    if value == nil then
        return "nil"
    end

    if value == localPlayer then
        return "localPlayer"
    end

    if value == root then
        return "root"
    end

    if value == resourceRoot then
        return "resourceRoot"
    end

    if type(isElement) == "function" and isElement(value) then
        local elementType = getElementType(value)

        if elementType == "resource" or elementType == "root" then
            return "root"
        end

        if elementType == "vehicle"
            and type(getPedOccupiedVehicle) == "function"
            and value == getPedOccupiedVehicle(localPlayer)
        then
            return "localPlayer.vehicle"
        end

        if elementType == "player"
            and type(getPlayerName) == "function"
        then
            return "getPlayerFromName("
                .. quoteString(getPlayerName(value))
                .. ")"
        end

        return "elem:" .. tostring(elementType or "unknown")
    end

    local valueType = type(value)

    if valueType == "string" then
        return quoteString(value)

    elseif valueType == "number" or valueType == "boolean" then
        return tostring(value)

    elseif valueType == "table" then
        if depth >= 3 or visited[value] then
            return "{ ... }"
        end

        visited[value] = true

        local parts = {}

        for index, item in ipairs(value) do
            parts[#parts + 1] =
                serializeArgument(item, depth + 1, visited)
        end

        for key, item in pairs(value) do
            if type(key) ~= "number"
                or key < 1
                or key > #value
                or key % 1 ~= 0
            then
                parts[#parts + 1] =
                    "["
                    .. serializeArgument(key, depth + 1, visited)
                    .. "] = "
                    .. serializeArgument(item, depth + 1, visited)
            end
        end

        visited[value] = nil

        return "{ " .. table.concat(parts, ", ") .. " }"
    end

    return tostring(value)
end

local function buildEventCall(functionName, args)
    local serialized = {}

    for index = 1, #args do
        serialized[index] = serializeArgument(args[index])
    end

    return tostring(functionName)
        .. " ( "
        .. table.concat(serialized, ", ")
        .. " )"
end

local function getEventLogText()
    return table.concat(eventLines, "\n")
end

local function updateNativeGui()
    if not isElement(eventMemo) then
        return
    end

    guiSetText(eventMemo, getEventLogText())

    if isElement(infoLabel) then
        guiSetText(
            infoLabel,
            "Events: " .. tostring(#eventLines)
                .. " | F1: toggle | Esc: close"
        )
    end

    if #eventLines > 0 then
        guiMemoSetCaretIndex(
            eventMemo,
            #getEventLogText()
        )
    end
end

local function appendEventLine(text)
    eventLines[#eventLines + 1] = tostring(text or "")

    if #eventLines > LOG_MAX_LINES then
        table.remove(eventLines, 1)
    end

    updateNativeGui()
end

local function clearEventLog()
    eventLines = {}
    updateNativeGui()
end

local function copyAllEvents()
    if type(setClipboard) == "function"
        and #eventLines > 0
    then
        local ok = pcall(setClipboard, getEventLogText())

        if ok then
            logDebug("All events copied to clipboard.")
        end
    end
end

local function copyLastEvent()
    if type(setClipboard) == "function"
        and #eventLines > 0
    then
        local ok = pcall(
            setClipboard,
            eventLines[#eventLines]
        )

        if ok then
            logDebug("Last event copied to clipboard.")
        end
    end
end

-- Called by the preFunction debug hook.
local function eventDumper(
    sourceResource,
    functionName,
    isAllowedByACL,
    luaFilename,
    luaLineNumber,
    ...
)
    local args = { ... }

    if #args == 0 then
        return
    end

    local eventName = tostring(args[1])

    local resourceName = "unknown"

    if sourceResource and isElement(sourceResource) then
        local ok, name = pcall(
            getResourceName,
            sourceResource
        )

        if ok and name then
            resourceName = name
        end
    end

    if resourceName == "nrp_player_head"
        or ignoredEvents[eventName]
    then
        return
    end

    appendEventLine(
        buildEventCall(functionName, args)
    )
end

local function isDumperVisible()
    return isElement(dumperWindow)
        and guiGetVisible(dumperWindow)
end

local function setDumperVisible(state)
    if not isElement(dumperWindow) then
        return
    end

    state = state and true or false

    guiSetVisible(dumperWindow, state)
    showCursor(state)

    if state then
        guiBringToFront(dumperWindow)
        updateNativeGui()
    end
end

local function toggleDumper()
    setDumperVisible(not isDumperVisible())
end

local function createNativeGui()
    if isElement(dumperWindow) then
        return true
    end

    local screenWidth, screenHeight = guiGetScreenSize()

    local windowWidth = math.min(1100, screenWidth - 40)
    local windowHeight = math.min(700, screenHeight - 40)

    local windowX = math.floor(
        (screenWidth - windowWidth) / 2
    )

    local windowY = math.floor(
        (screenHeight - windowHeight) / 2
    )

    dumperWindow = guiCreateWindow(
        windowX,
        windowY,
        windowWidth,
        windowHeight,
        "Events Dumper",
        false
    )

    if not isElement(dumperWindow) then
        logDebug("Failed to create GUI window.", 1)
        return false
    end

    guiWindowSetSizable(dumperWindow, false)
    guiWindowSetMovable(dumperWindow, true)

    eventMemo = guiCreateMemo(
        10,
        28,
        windowWidth - 20,
        windowHeight - 92,
        "",
        false,
        dumperWindow
    )

    if isElement(eventMemo) then
        guiMemoSetReadOnly(eventMemo, true)
        guiSetFont(eventMemo, "default-small")
    else
        logDebug("Failed to create event memo.", 1)
    end

    infoLabel = guiCreateLabel(
        12,
        windowHeight - 58,
        windowWidth - 440,
        22,
        "Events: 0 | F1: toggle | Esc: close",
        false,
        dumperWindow
    )

    if isElement(infoLabel) then
        guiLabelSetVerticalAlign(infoLabel, "center")
    end

    clearButton = guiCreateButton(
        windowWidth - 410,
        windowHeight - 62,
        90,
        30,
        "Clear",
        false,
        dumperWindow
    )

    copyLastButton = guiCreateButton(
        windowWidth - 310,
        windowHeight - 62,
        90,
        30,
        "Copy Last",
        false,
        dumperWindow
    )

    copyButton = guiCreateButton(
        windowWidth - 210,
        windowHeight - 62,
        90,
        30,
        "Copy All",
        false,
        dumperWindow
    )

    closeButton = guiCreateButton(
        windowWidth - 110,
        windowHeight - 62,
        90,
        30,
        "Close",
        false,
        dumperWindow
    )

    if isElement(clearButton) then
        addEventHandler(
            "onClientGUIClick",
            clearButton,
            clearEventLog,
            false
        )
    end

    if isElement(copyLastButton) then
        addEventHandler(
            "onClientGUIClick",
            copyLastButton,
            copyLastEvent,
            false
        )
    end

    if isElement(copyButton) then
        addEventHandler(
            "onClientGUIClick",
            copyButton,
            copyAllEvents,
            false
        )
    end

    if isElement(closeButton) then
        addEventHandler(
            "onClientGUIClick",
            closeButton,
            function()
                setDumperVisible(false)
            end,
            false
        )
    end

    setDumperVisible(false)

    logDebug("GUI created successfully.")

    return true
end

local function installDebugHook()
    if hookInstalled then
        return true
    end

    if type(addDebugHook) ~= "function" then
        logDebug("addDebugHook is unavailable.", 1)
        return false
    end

    local callOK, result = pcall(
        addDebugHook,
        "preFunction",
        eventDumper,
        {
            "triggerServerEvent",
            "triggerLatentServerEvent"
        }
    )

    if not callOK then
        logDebug(
            "Hook installation raised an error: "
                .. tostring(result),
            1
        )

        return false
    end

    -- MTA debug-hook functions can return nil on success.
    -- A protected call only proves that no Lua error occurred.
    hookInstalled = true

    logDebug(
        "Hook installation call completed. "
            .. "Check whether events are being captured."
    )

    return true
end

local function removeDebugHook()
    if not hookInstalled then
        return
    end

    if type(removeDebugHook) == "function" then
        pcall(
            removeDebugHook,
            "preFunction",
            eventDumper,
            {
                "triggerServerEvent",
                "triggerLatentServerEvent"
            }
        )
    end

    hookInstalled = false
end

addEventHandler("onClientKey", root, function(button, press)
    if not press then
        return
    end

    if button == "F4" or button == "f4" then
        cancelEvent()
        toggleDumper()

    elseif isDumperVisible()
        and (button == "escape" or button == "ESC")
    then
        cancelEvent()
        setDumperVisible(false)
    end
end)

addEventHandler(
    "onClientResourceStart",
    resourceRoot,
    function()
        if resourceStarted then
            return
        end

        resourceStarted = true

        createNativeGui()
        installDebugHook()

        logDebug("Resource started.")
    end
)

-- Supports loading the file after the resource-start event.
if not resourceStarted then
    createNativeGui()
    installDebugHook()
    resourceStarted = true
end

addEventHandler(
    "onClientResourceStop",
    resourceRoot,
    function(stoppedResource)
        if stoppedResource ~= getThisResource() then
            return
        end

        removeDebugHook()

        if isElement(dumperWindow) then
            destroyElement(dumperWindow)
        end

        showCursor(false)

        logDebug("Resource stopped.")
    end
)






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
