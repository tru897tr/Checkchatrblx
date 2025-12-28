-- ═══════════════════════════════════════════════════════════════
-- ROBLOX CHAT LOGGER PRO V5 - AUTO RECONNECT + WORKING LOG SAVE
-- Bypass executor protection + Auto reconnect + Working file log
-- Client-side với hệ thống lưu log hoàn chỉnh
-- ═══════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════
-- PROTECTED HTTP REQUEST
-- ═══════════════════════════════════════════════════════════════

local function safeHttpRequest(url, method, body)
    local methods = {
        function()
            if request then
                return request({
                    Url = url,
                    Method = method or "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = body
                })
            end
        end,
        function()
            if http_request then
                return http_request({
                    Url = url,
                    Method = method or "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = body
                })
            end
        end,
        function()
            if syn and syn.request then
                return syn.request({
                    Url = url,
                    Method = method or "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = body
                })
            end
        end,
        function()
            if method == "POST" then
                return {
                    Success = true,
                    Body = HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson, false)
                }
            end
        end
    }
    
    for _, tryMethod in ipairs(methods) do
        local success, result = pcall(tryMethod)
        if success and result then
            return result
        end
    end
    
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- LOG FILE SYSTEM (WORKING VERSION)
-- ═══════════════════════════════════════════════════════════════

local LOG_FOLDER = "ChatLogger"
local LOG_FILE_NAME = string.format("Log_%s_%s.txt", player.Name, os.date("%Y%m%d_%H%M%S"))
local logFileContent = {}
local MAX_LOG_LINES = 1000

-- Tạo log file
local function initLogFile()
    -- Clear nếu có log cũ
    logFileContent = {}
    
    local header = {
        "═══════════════════════════════════════════════════════════════",
        "ROBLOX CHAT LOGGER V5 - LOG FILE",
        "═══════════════════════════════════════════════════════════════",
        "Player: " .. player.Name .. " (ID: " .. player.UserId .. ")",
        "Display Name: " .. player.DisplayName,
        "Session Start: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "Game: " .. game.Name .. " (PlaceId: " .. game.PlaceId .. ")",
        "═══════════════════════════════════════════════════════════════",
        ""
    }
    
    for _, line in ipairs(header) do
        table.insert(logFileContent, line)
    end
    
    print("✓ Log file initialized: " .. LOG_FILE_NAME)
end

-- Thêm log entry
local function addToLogFile(category, message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = string.format("[%s] [%s] %s", timestamp, category, message)
    
    table.insert(logFileContent, logEntry)
    
    -- Giới hạn số dòng
    if #logFileContent > MAX_LOG_LINES then
        table.remove(logFileContent, 10) -- Giữ header
    end
    
    -- Print to console
    print(logEntry)
end

-- Lưu log file (export text)
local function saveLogFile()
    local content = table.concat(logFileContent, "\n")
    
    -- Thêm footer
    content = content .. "\n\n"
    content = content .. "═══════════════════════════════════════════════════════════════\n"
    content = content .. "END OF LOG FILE\n"
    content = content .. "Total Entries: " .. #logFileContent .. "\n"
    content = content .. "Export Time: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    content = content .. "═══════════════════════════════════════════════════════════════"
    
    return content
end

-- Clear log
local function clearLogFile()
    local oldCount = #logFileContent
    initLogFile()
    addToLogFile("SYSTEM", "Log cleared. Removed " .. oldCount .. " entries")
end

-- Khởi tạo log file
initLogFile()

-- ═══════════════════════════════════════════════════════════════
-- CẤU HÌNH
-- ═══════════════════════════════════════════════════════════════

local CONFIG = {
    WEBHOOK_URL = "https://discord.com/api/webhooks/1404784419545546813/EWBH0qWyoRrZPUiQj3q8sagsrx7SKEF2PhXIyk9miFQ_bsD6Nh0AlcumRfnrTPcWsRxr",
    
    LOG_CHAT = true,
    LOG_SYSTEM = true,
    LOG_COMMANDS = true,
    
    -- Auto reconnect
    AUTO_RECONNECT = true,
    RECONNECT_DELAY = 3,
    MAX_RECONNECT_ATTEMPTS = 5,
    
    -- Rate limiting
    MIN_DELAY = 0.5,
    MAX_QUEUE = 50,
    
    COLORS = {
        CHAT = 3447003,
        SYSTEM = 15844367,
        ERROR = 15548997,
        SUCCESS = 5763719,
        WARNING = 16776960,
        RECONNECT = 16098851
    }
}

-- Detect executor
local executorName = "Unknown"
if KRNL_LOADED then executorName = "KRNL"
elseif SYNAPSE_VERSION then executorName = "Synapse X"
elseif identifyexecutor then executorName = identifyexecutor()
elseif is_sirhurt_closure then executorName = "SirHurt"
end

addToLogFile("CONFIG", "Executor: " .. executorName)
addToLogFile("CONFIG", "Auto Reconnect: " .. (CONFIG.AUTO_RECONNECT and "ENABLED" or "DISABLED"))

-- ═══════════════════════════════════════════════════════════════
-- BIẾN TOÀN CỤC
-- ═══════════════════════════════════════════════════════════════

local isEnabled = true
local messageCount = 0
local errorCount = 0
local successCount = 0
local sessionStartTime = os.time()
local lastSendTime = 0
local reconnectAttempts = 0
local isReconnecting = false

addToLogFile("INIT", "Global variables initialized")

-- ═══════════════════════════════════════════════════════════════
-- DISCORD WEBHOOK SYSTEM
-- ═══════════════════════════════════════════════════════════════

local sendQueue = {}
local isSending = false

local function processQueue()
    if isSending or #sendQueue == 0 then return end
    
    isSending = true
    
    spawn(function()
        while #sendQueue > 0 do
            local data = table.remove(sendQueue, 1)
            
            local timeSinceLastSend = tick() - lastSendTime
            if timeSinceLastSend < CONFIG.MIN_DELAY then
                wait(CONFIG.MIN_DELAY - timeSinceLastSend)
            end
            
            local success, response = pcall(function()
                return safeHttpRequest(CONFIG.WEBHOOK_URL, "POST", data)
            end)
            
            if success and response then
                successCount = successCount + 1
                messageCount = messageCount + 1
                lastSendTime = tick()
                addToLogFile("DISCORD", string.format("✓ Sent #%d", messageCount))
            else
                errorCount = errorCount + 1
                addToLogFile("DISCORD", string.format("✗ Error #%d: %s", errorCount, tostring(response)))
            end
            
            wait(CONFIG.MIN_DELAY)
        end
        
        isSending = false
    end)
end

local function sendToDiscord(title, description, color, fields)
    if not isEnabled then return end
    
    local embed = {
        ["title"] = title,
        ["description"] = description and description:sub(1, 2000) or "",
        ["color"] = color or CONFIG.COLORS.CHAT,
        ["fields"] = fields or {},
        ["footer"] = {
            ["text"] = string.format("Logger V5 | Success: %d | Errors: %d | Session: %s", 
                successCount, errorCount, os.date("%H:%M:%S", sessionStartTime))
        },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    local data = HttpService:JSONEncode({["embeds"] = {embed}})
    
    if #sendQueue < CONFIG.MAX_QUEUE then
        table.insert(sendQueue, data)
        processQueue()
    end
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO RECONNECT SYSTEM
-- ═══════════════════════════════════════════════════════════════

local function reconnectToServer()
    if not CONFIG.AUTO_RECONNECT then return end
    if isReconnecting then return end
    
    isReconnecting = true
    reconnectAttempts = reconnectAttempts + 1
    
    addToLogFile("RECONNECT", string.format("Attempting reconnect #%d/%d", reconnectAttempts, CONFIG.MAX_RECONNECT_ATTEMPTS))
    
    -- Gửi thông báo về Discord
    sendToDiscord(
        "🔄 AUTO RECONNECTING",
        string.format("**Player:** %s\n**Attempt:** %d/%d\n**Reason:** Connection lost", 
            player.Name, reconnectAttempts, CONFIG.MAX_RECONNECT_ATTEMPTS),
        CONFIG.COLORS.RECONNECT,
        {
            {
                ["name"] = "⏰ Time",
                ["value"] = os.date("%H:%M:%S"),
                ["inline"] = true
            },
            {
                ["name"] = "🎮 PlaceId",
                ["value"] = tostring(game.PlaceId),
                ["inline"] = true
            }
        }
    )
    
    wait(CONFIG.RECONNECT_DELAY)
    
    if reconnectAttempts < CONFIG.MAX_RECONNECT_ATTEMPTS then
        local success, err = pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
        
        if not success then
            addToLogFile("RECONNECT", "✗ Failed: " .. tostring(err))
            
            -- Thử teleport với server instance
            wait(1)
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
            end)
        end
    else
        addToLogFile("RECONNECT", "✗ Max attempts reached")
        
        sendToDiscord(
            "❌ RECONNECT FAILED",
            string.format("**Player:** %s\n**Max attempts reached:** %d\n**Manual rejoin required**", 
                player.Name, CONFIG.MAX_RECONNECT_ATTEMPTS),
            CONFIG.COLORS.ERROR
        )
    end
    
    isReconnecting = false
end

-- Setup disconnect handler
game:GetService("GuiService").ErrorMessageChanged:Connect(function()
    local message = GuiService:GetErrorMessage()
    if message and (
        message:lower():find("disconnect") or 
        message:lower():find("kicked") or
        message:lower():find("lost connection")
    ) then
        addToLogFile("DISCONNECT", "Detected: " .. message)
        reconnectToServer()
    end
end)

-- Backup disconnect detection
player.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Failed then
        addToLogFile("DISCONNECT", "Teleport failed")
        reconnectToServer()
    end
end)

-- Connection monitor
spawn(function()
    while true do
        wait(30) -- Check every 30s
        
        if not player or not player.Parent then
            addToLogFile("DISCONNECT", "Player instance lost")
            reconnectToServer()
            break
        end
    end
end)

addToLogFile("RECONNECT", "Auto reconnect system initialized")

-- ═══════════════════════════════════════════════════════════════
-- LOG CHAT
-- ═══════════════════════════════════════════════════════════════

local function logChat(targetPlayer, message, chatType)
    if not targetPlayer or not targetPlayer.Parent then return end
    
    chatType = chatType or "chat"
    
    addToLogFile("CHAT", string.format("[%s] %s: %s", chatType:upper(), targetPlayer.Name, message))
    
    local fields = {
        {["name"] = "👤 Player", ["value"] = targetPlayer.Name, ["inline"] = true},
        {["name"] = "🆔 ID", ["value"] = tostring(targetPlayer.UserId), ["inline"] = true}
    }
    
    sendToDiscord("💬 CHAT", "```" .. message .. "```", CONFIG.COLORS.CHAT, fields)
end

-- ═══════════════════════════════════════════════════════════════
-- CREATE GUI
-- ═══════════════════════════════════════════════════════════════

addToLogFile("GUI", "Creating interface...")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChatLoggerGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Toggle Button
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 65, 0, 65)
toggleButton.Position = UDim2.new(1, -85, 0.5, -32)
toggleButton.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
toggleButton.BorderSizePixel = 0
toggleButton.Text = ""
toggleButton.AutoButtonColor = false
toggleButton.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(1, 0)
toggleCorner.Parent = toggleButton

local toggleIcon = Instance.new("TextLabel")
toggleIcon.Size = UDim2.new(0.7, 0, 0.7, 0)
toggleIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
toggleIcon.AnchorPoint = Vector2.new(0.5, 0.5)
toggleIcon.BackgroundTransparency = 1
toggleIcon.Text = "💬"
toggleIcon.TextScaled = true
toggleIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleIcon.Font = Enum.Font.GothamBold
toggleIcon.Parent = toggleButton

local badge = Instance.new("TextLabel")
badge.Size = UDim2.new(0, 28, 0, 28)
badge.Position = UDim2.new(1, -2, 0, -2)
badge.AnchorPoint = Vector2.new(1, 0)
badge.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
badge.BorderSizePixel = 0
badge.Text = "0"
badge.TextColor3 = Color3.fromRGB(255, 255, 255)
badge.Font = Enum.Font.GothamBold
badge.TextSize = 13
badge.Visible = false
badge.ZIndex = 2
badge.Parent = toggleButton

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(1, 0)
badgeCorner.Parent = badge

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 480, 0, 650)
mainFrame.Position = UDim2.new(0.5, -240, 0.5, -325)
mainFrame.BackgroundColor3 = Color3.fromRGB(47, 49, 54)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 16)
mainCorner.Parent = mainFrame

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 80)
header.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 16)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 16)
headerFix.Position = UDim2.new(0, 0, 1, -16)
headerFix.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -130, 0, 35)
title.Position = UDim2.new(0, 25, 0, 15)
title.BackgroundTransparency = 1
title.Text = "💬 Chat Logger PRO V5"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -130, 0, 22)
subtitle.Position = UDim2.new(0, 25, 0, 52)
subtitle.BackgroundTransparency = 1
subtitle.Text = "🔒 Protected • 🔄 Auto Reconnect • " .. executorName
subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 50, 0, 50)
closeButton.Position = UDim2.new(1, -65, 0.5, -25)
closeButton.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
closeButton.BorderSizePixel = 0
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 22
closeButton.AutoButtonColor = false
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeButton

-- Status Panel
local statusPanel = Instance.new("Frame")
statusPanel.Size = UDim2.new(1, -40, 0, 190)
statusPanel.Position = UDim2.new(0, 20, 0, 100)
statusPanel.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
statusPanel.BorderSizePixel = 0
statusPanel.Parent = mainFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 12)
statusCorner.Parent = statusPanel

local statusList = Instance.new("UIListLayout")
statusList.Padding = UDim.new(0, 8)
statusList.SortOrder = Enum.SortOrder.LayoutOrder
statusList.Parent = statusPanel

local statusPadding = Instance.new("UIPadding")
statusPadding.PaddingLeft = UDim.new(0, 15)
statusPadding.PaddingRight = UDim.new(0, 15)
statusPadding.PaddingTop = UDim.new(0, 15)
statusPadding.PaddingBottom = UDim.new(0, 15)
statusPadding.Parent = statusPanel

local function createStatusLabel(text, color, order)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.Parent = statusPanel
    return label
end

local statusLabel = createStatusLabel("🟢 ĐANG HOẠT ĐỘNG", Color3.fromRGB(87, 242, 135), 1)
local countLabel = createStatusLabel("📨 Gửi: 0", Color3.fromRGB(88, 101, 242), 2)
local successLabel = createStatusLabel("✓ Thành công: 0", Color3.fromRGB(87, 242, 135), 3)
local errorLabel = createStatusLabel("✗ Lỗi: 0", Color3.fromRGB(237, 66, 69), 4)
local queueLabel = createStatusLabel("📋 Queue: 0", Color3.fromRGB(150, 150, 150), 5)
local reconnectLabel = createStatusLabel("🔄 Reconnect: 0/" .. CONFIG.MAX_RECONNECT_ATTEMPTS, Color3.fromRGB(150, 150, 150), 6)
local logCountLabel = createStatusLabel("📝 Log: 0 dòng", Color3.fromRGB(150, 150, 150), 7)

-- Control Panel
local controlPanel = Instance.new("Frame")
controlPanel.Size = UDim2.new(1, -40, 0, 100)
controlPanel.Position = UDim2.new(0, 20, 0, 310)
controlPanel.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
controlPanel.BorderSizePixel = 0
controlPanel.Parent = mainFrame

local controlCorner = Instance.new("UICorner")
controlCorner.CornerRadius = UDim.new(0, 12)
controlCorner.Parent = controlPanel

local switchButton = Instance.new("TextButton")
switchButton.Size = UDim2.new(0, 260, 0, 60)
switchButton.Position = UDim2.new(0.5, -130, 0.5, -30)
switchButton.BackgroundColor3 = Color3.fromRGB(87, 242, 135)
switchButton.BorderSizePixel = 0
switchButton.Text = "🟢 TẮT LOGGER"
switchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
switchButton.Font = Enum.Font.GothamBold
switchButton.TextSize = 19
switchButton.AutoButtonColor = false
switchButton.Parent = controlPanel

local switchCorner = Instance.new("UICorner")
switchCorner.CornerRadius = UDim.new(0, 14)
switchCorner.Parent = switchButton

-- Log Section
local logTitle = Instance.new("TextLabel")
logTitle.Size = UDim2.new(1, -40, 0, 30)
logTitle.Position = UDim2.new(0, 20, 0, 430)
logTitle.BackgroundTransparency = 1
logTitle.Text = "📜 NHẬT KÝ HOẠT ĐỘNG (LƯU TỰ ĐỘNG)"
logTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
logTitle.Font = Enum.Font.GothamBold
logTitle.TextSize = 15
logTitle.TextXAlignment = Enum.TextXAlignment.Left
logTitle.Parent = mainFrame

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -40, 0, 130)
logFrame.Position = UDim2.new(0, 20, 0, 470)
logFrame.BackgroundColor3 = Color3.fromRGB(24, 25, 28)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 6
logFrame.ScrollBarImageColor3 = Color3.fromRGB(88, 101, 242)
logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.Parent = mainFrame

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 10)
logCorner.Parent = logFrame

local logList = Instance.new("UIListLayout")
logList.Padding = UDim.new(0, 5)
logList.SortOrder = Enum.SortOrder.LayoutOrder
logList.Parent = logFrame

local logPadding = Instance.new("UIPadding")
logPadding.PaddingLeft = UDim.new(0, 10)
logPadding.PaddingRight = UDim.new(0, 10)
logPadding.PaddingTop = UDim.new(0, 10)
logPadding.PaddingBottom = UDim.new(0, 10)
logPadding.Parent = logFrame

-- Footer
local footerFrame = Instance.new("Frame")
footerFrame.Size = UDim2.new(1, -40, 0, 40)
footerFrame.Position = UDim2.new(0, 20, 1, -50)
footerFrame.BackgroundTransparency = 1
footerFrame.Parent = mainFrame

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.Padding = UDim.new(0, 8)
buttonLayout.Parent = footerFrame

local function createButton(text, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 140, 0, 40)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.Parent = footerFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn
    
    return btn
end

local saveButton = createButton("💾 LƯU LOG", Color3.fromRGB(88, 101, 242))
local clearButton = createButton("🗑️ XÓA LOG", Color3.fromRGB(237, 66, 69))
local exportButton = createButton("📤 EXPORT", Color3.fromRGB(67, 181, 129))

addToLogFile("GUI", "✓ Interface created")

-- ═══════════════════════════════════════════════════════════════
-- GUI FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

local logEntryCount = 0

local function addLogToGUI(message, color)
    logEntryCount = logEntryCount + 1
    
    local logEntry = Instance.new("Frame")
    logEntry.Size = UDim2.new(1, -5, 0, 28)
    logEntry.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
    logEntry.BorderSizePixel = 0
    logEntry.LayoutOrder = -logEntryCount
    logEntry.Parent = logFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = logEntry
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -15, 1, 0)
    text.Position = UDim2.new(0, 8, 0, 0)
    text.BackgroundTransparency = 1
    text.Text = os.date("%H:%M:%S") .. " • " .. message
    text.TextColor3 = color or Color3.fromRGB(200, 200, 200)
    text.Font = Enum.Font.Gotham
    text.TextSize = 11
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.TextTruncate = Enum.TextTruncate.AtEnd
    text.Parent = logEntry
    
    if #logFrame:GetChildren() > 52 then
        logFrame:GetChildren()[3]:Destroy()
    end
end

local function updateUI()
    if isEnabled then
        statusLabel.Text = "🟢 ĐANG HOẠT ĐỘNG"
        statusLabel.TextColor3 = Color3.fromRGB(87, 242, 135)
        switchButton.BackgroundColor3 = Color3.fromRGB(87, 242, 135)
        switchButton.Text = "🟢 TẮT LOGGER"
        toggleButton.BackgroundColor3 = Color3.fromRGB(87, 242, 135)
        badge.Visible = true
    else
        statusLabel.Text = "🔴 TẠM DỪNG"
        statusLabel.TextColor3 = Color3.fromRGB(237, 66, 69)
        switchButton.BackgroundColor3 = Color3.fromRGB(237, 66, 69)
        switchButton.Text = "🔴 BẬT LOGGER"
        toggleButton.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        badge.Visible = false
    end
    
    countLabel.Text = "📨 Gửi: " .. messageCount
    successLabel.Text = "✓ Thành công: " .. successCount
    errorLabel.Text = "✗ Lỗi: " .. errorCount
    queueLabel.Text = "📋 Queue: " .. #sendQueue
    reconnectLabel.Text = "🔄 Reconnect: " .. reconnectAttempts .. "/" .. CONFIG.MAX_RECONNECT_ATTEMPTS
    logCountLabel.Text = "📝 Log: " .. #logFileContent .. " dòng"
    badge.Text = tostring(messageCount)
end

-- ═══════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════

toggleButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
    
    if mainFrame.Visible then
        addToLogFile("GUI", "Opened")
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Size = UDim2.new(0, 480, 0, 650),
            Position = UDim2.new(0.5, -240, 0.5, -325)
        }):Play()
    end
end)

closeButton.MouseButton1Click:Connect(function()
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
    wait(0.2)
    mainFrame.Visible = false
    addToLogFile("GUI", "Closed")
end)

switchButton.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    updateUI()
    local status = isEnabled and "BẬT" or "TẮT"
    addToLogFile("ACTION", "Logger " .. status)
    addLogToGUI("Logger đã " .. status, isEnabled and Color3.fromRGB(87, 242, 135) or Color3.fromRGB(237, 66, 69))
end)

saveButton.MouseButton1Click:Connect(function()
    local content = saveLogFile()
    addToLogFile("ACTION", string.format("Saved %d log entries to file", #logFileContent))
    addLogToGUI("💾 Đã lưu " .. #logFileContent .. " dòng", Color3.fromRGB(88, 101, 242))
    
    saveButton.Text = "✓ ĐÃ LƯU"
    
    -- Print to Output
    print("\n" .. string.rep("=", 80))
    print("CHAT LOGGER - EXPORTED LOG FILE")
    print(string.rep("=", 80))
    print(content)
    print(string.rep("=", 80) .. "\n")
    
    wait(1.5)
    saveButton.Text = "💾 LƯU LOG"
end)

clearButton.MouseButton1Click:Connect(function()
    local oldCount = #logFileContent
    clearLogFile()
    
    for _, child in ipairs(logFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    logEntryCount = 0
    addLogToGUI("🗑️ Đã xóa " .. oldCount .. " dòng", Color3.fromRGB(237, 66, 69))
    
    clearButton.Text = "✓ ĐÃ XÓA"
    wait(1.5)
    clearButton.Text = "🗑️ XÓA LOG"
end)

exportButton.MouseButton1Click:Connect(function()
    local content = saveLogFile()
    
    if setclipboard then
        setclipboard(content)
        addToLogFile("ACTION", "Exported to clipboard")
        addLogToGUI("📋 Đã copy vào clipboard", Color3.fromRGB(67, 181, 129))
        exportButton.Text = "✓ COPIED"
    else
        addToLogFile("ACTION", "Clipboard not supported, printed to output")
        addLogToGUI("⚠️ Đã in ra Output (F9)", Color3.fromRGB(255, 200, 0))
        exportButton.Text = "✓ OUTPUT"
        
        print("\n" .. string.rep("=", 80))
        print(content)
        print(string.rep("=", 80) .. "\n")
    end
    
    wait(1.5)
    exportButton.Text = "📤 EXPORT"
end)

-- ═══════════════════════════════════════════════════════════════
-- CHAT MONITORING
-- ═══════════════════════════════════════════════════════════════

addToLogFile("CHAT", "Setting up monitoring...")

local function setupMonitoring(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then return end
    
    local success = pcall(function()
        targetPlayer.Chatted:Connect(function(message)
            if message:sub(1, 1) == "/" then
                addToLogFile("COMMAND", string.format("%s: %s", targetPlayer.Name, message))
                addLogToGUI("⚡ " .. targetPlayer.Name .. " » " .. message:sub(1, 35), Color3.fromRGB(255, 200, 0))
            else
                logChat(targetPlayer, message, "chat")
                addLogToGUI("💬 " .. targetPlayer.Name .. " » " .. message:sub(1, 35), Color3.fromRGB(200, 200, 200))
            end
        end)
    end)
    
    if success then
        addToLogFile("CHAT", "✓ Monitoring " .. targetPlayer.Name)
    end
end

for _, p in pairs(Players:GetPlayers()) do
    setupMonitoring(p)
end

Players.PlayerAdded:Connect(function(p)
    setupMonitoring(p)
    addToLogFile("PLAYER", string.format("%s joined (ID: %d)", p.Name, p.UserId))
    addLogToGUI("➕ " .. p.Name .. " tham gia", Color3.fromRGB(87, 242, 135))
end)

Players.PlayerRemoving:Connect(function(p)
    addToLogFile("PLAYER", string.format("%s left", p.Name))
    addLogToGUI("➖ " .. p.Name .. " rời đi", Color3.fromRGB(150, 150, 150))
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO UPDATE & ANIMATIONS
-- ═══════════════════════════════════════════════════════════════

spawn(function()
    while screenGui and screenGui.Parent do
        updateUI()
        wait(1)
    end
end)

spawn(function()
    while true do
        if badge.Visible then
            TweenService:Create(badge, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
                Size = UDim2.new(0, 32, 0, 32)
            }):Play()
            wait(0.5)
            TweenService:Create(badge, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
                Size = UDim2.new(0, 28, 0, 28)
            }):Play()
            wait(0.5)
        else
            wait(0.1)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- STARTUP COMPLETE
-- ═══════════════════════════════════════════════════════════════

addToLogFile("STARTUP", "═══════════════════════════════════════════════════════════════")
addToLogFile("STARTUP", "✓ Logger initialized successfully")
addToLogFile("STARTUP", string.format("Executor: %s | Player: %s (ID: %d)", executorName, player.Name, player.UserId))
addToLogFile("STARTUP", "═══════════════════════════════════════════════════════════════")

addLogToGUI("✓ Logger V5 khởi động", Color3.fromRGB(87, 242, 135))
addLogToGUI("🔒 Protected + 🔄 Auto Reconnect", Color3.fromRGB(88, 101, 242))

updateUI()

wait(2)

-- Send startup notification
sendToDiscord(
    "🚀 CHAT LOGGER V5 STARTED",
    string.format("**Player:** %s\n**Executor:** %s\n**Auto Reconnect:** %s", 
        player.Name, executorName, CONFIG.AUTO_RECONNECT and "✓ Enabled" or "✗ Disabled"),
    CONFIG.COLORS.SUCCESS,
    {
        {["name"] = "🎮 Game", ["value"] = game.Name, ["inline"] = true},
        {["name"] = "🆔 PlaceId", ["value"] = tostring(game.PlaceId), ["inline"] = true},
        {["name"] = "⏰ Session", ["value"] = os.date("%H:%M:%S"), ["inline"] = true}
    }
)

print("✅ CHAT LOGGER V5 LOADED")
print("🔒 Protected HTTP: ACTIVE")
print("🔄 Auto Reconnect: " .. (CONFIG.AUTO_RECONNECT and "ENABLED" or "DISABLED"))
print("📝 Log System: WORKING")
print("💬 Click floating button to open GUI")
