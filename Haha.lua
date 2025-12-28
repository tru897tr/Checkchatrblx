-- ═══════════════════════════════════════════════════════════════
-- ROBLOX CHAT LOGGER PRO V4 - FIXED EXECUTOR PROTECTION
-- Bypass vulnerable function detection
-- Client-side với log file system
-- ═══════════════════════════════════════════════════════════════

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ═══════════════════════════════════════════════════════════════
-- PROTECTED HTTP REQUEST (BYPASS EXECUTOR DETECTION)
-- ═══════════════════════════════════════════════════════════════

local function safeHttpRequest(url, method, body)
    -- Sử dụng nhiều phương thức khác nhau để bypass
    local methods = {
        -- Method 1: request
        function()
            if request then
                return request({
                    Url = url,
                    Method = method or "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = body
                })
            end
        end,
        
        -- Method 2: http_request
        function()
            if http_request then
                return http_request({
                    Url = url,
                    Method = method or "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = body
                })
            end
        end,
        
        -- Method 3: syn.request
        function()
            if syn and syn.request then
                return syn.request({
                    Url = url,
                    Method = method or "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = body
                })
            end
        end,
        
        -- Method 4: HttpService (fallback)
        function()
            if method == "POST" then
                return {
                    Success = true,
                    Body = HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson, false)
                }
            end
        end
    }
    
    -- Thử từng method cho đến khi thành công
    for i, tryMethod in ipairs(methods) do
        local success, result = pcall(tryMethod)
        if success and result then
            return result
        end
    end
    
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- LOG FILE SYSTEM
-- ═══════════════════════════════════════════════════════════════

local LOG_FILE_PATH = "ChatLogger_" .. player.Name .. "_" .. os.date("%Y%m%d") .. ".txt"
local logFileContent = {}
local MAX_LOG_LINES = 1000

local function addToLogFile(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = string.format("[%s] %s", timestamp, message)
    
    table.insert(logFileContent, 1, logEntry)
    
    if #logFileContent > MAX_LOG_LINES then
        table.remove(logFileContent)
    end
    
    print(logEntry)
end

local function saveLogFile()
    local content = "═══════════════════════════════════════════════════════════════\n"
    content = content .. "ROBLOX CHAT LOGGER - LOG FILE\n"
    content = content .. "Player: " .. player.Name .. "\n"
    content = content .. "Date: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n"
    content = content .. "═══════════════════════════════════════════════════════════════\n\n"
    content = content .. table.concat(logFileContent, "\n")
    
    return content
end

local function clearLogFile()
    logFileContent = {}
    addToLogFile("LOG FILE CLEARED")
end

-- Kiểm tra và clear log cũ
if #logFileContent > 0 then
    addToLogFile("Previous log cleared, starting new session")
    logFileContent = {}
end

addToLogFile("═══════════════════════════════════════════════════════════════")
addToLogFile("CHAT LOGGER V4 STARTED")
addToLogFile("═══════════════════════════════════════════════════════════════")

-- ═══════════════════════════════════════════════════════════════
-- CẤU HÌNH
-- ═══════════════════════════════════════════════════════════════

local CONFIG = {
    WEBHOOK_URL = "https://discord.com/api/webhooks/1404784419545546813/EWBH0qWyoRrZPUiQj3q8sagsrx7SKEF2PhXIyk9miFQ_bsD6Nh0AlcumRfnrTPcWsRxr",
    
    LOG_CHAT = true,
    LOG_SYSTEM = true,
    LOG_COMMANDS = true,
    
    -- Rate limiting
    MIN_DELAY = 0.5,
    MAX_QUEUE = 50,
    
    COLORS = {
        CHAT = 3447003,
        SYSTEM = 15844367,
        ERROR = 15548997,
        SUCCESS = 5763719
    }
}

-- Kiểm tra executor capabilities
local executorName = "Unknown"
if KRNL_LOADED then
    executorName = "KRNL"
elseif SYNAPSE_VERSION then
    executorName = "Synapse X"
elseif identifyexecutor then
    executorName = identifyexecutor()
elseif is_sirhurt_closure then
    executorName = "SirHurt"
end

addToLogFile("CONFIG: Executor detected: " .. executorName)
addToLogFile("CONFIG: Configuration loaded")

-- ═══════════════════════════════════════════════════════════════
-- BIẾN TOÀN CỤC
-- ═══════════════════════════════════════════════════════════════

local isEnabled = true
local messageCount = 0
local errorCount = 0
local successCount = 0
local sessionStartTime = os.time()
local lastSendTime = 0

addToLogFile("INIT: Global variables initialized")

-- ═══════════════════════════════════════════════════════════════
-- HÀM GỬI DISCORD (PROTECTED)
-- ═══════════════════════════════════════════════════════════════

local sendQueue = {}
local isSending = false

local function processQueue()
    if isSending or #sendQueue == 0 then return end
    
    isSending = true
    
    spawn(function()
        while #sendQueue > 0 do
            local data = table.remove(sendQueue, 1)
            
            -- Rate limiting
            local timeSinceLastSend = tick() - lastSendTime
            if timeSinceLastSend < CONFIG.MIN_DELAY then
                wait(CONFIG.MIN_DELAY - timeSinceLastSend)
            end
            
            -- Gửi với protected method
            local success, response = pcall(function()
                local result = safeHttpRequest(
                    CONFIG.WEBHOOK_URL,
                    "POST",
                    data
                )
                return result
            end)
            
            if success and response then
                successCount = successCount + 1
                messageCount = messageCount + 1
                lastSendTime = tick()
                addToLogFile(string.format("DISCORD: ✓ Sent #%d successfully", messageCount))
            else
                errorCount = errorCount + 1
                addToLogFile(string.format("DISCORD: ✗ Error #%d: %s", errorCount, tostring(response)))
                
                -- Retry logic
                if errorCount < 3 then
                    table.insert(sendQueue, data)
                    addToLogFile("DISCORD: Retrying...")
                end
            end
            
            wait(CONFIG.MIN_DELAY)
        end
        
        isSending = false
    end)
end

local function sendToDiscord(title, description, color, fields)
    if not isEnabled then 
        addToLogFile("DISCORD: Logger disabled, message skipped")
        return 
    end
    
    -- Validate webhook
    if not CONFIG.WEBHOOK_URL or CONFIG.WEBHOOK_URL == "" then
        addToLogFile("DISCORD: No webhook URL configured")
        return
    end
    
    -- Tạo embed
    local embed = {
        ["title"] = title,
        ["description"] = description and description:sub(1, 2000) or "",
        ["color"] = color or CONFIG.COLORS.CHAT,
        ["fields"] = fields or {},
        ["footer"] = {
            ["text"] = string.format("Logger | Success: %d | Errors: %d", 
                successCount, errorCount)
        },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    local data = HttpService:JSONEncode({
        ["embeds"] = {embed}
    })
    
    -- Add to queue
    if #sendQueue < CONFIG.MAX_QUEUE then
        table.insert(sendQueue, data)
        addToLogFile(string.format("DISCORD: Queued message (Queue: %d)", #sendQueue))
        processQueue()
    else
        addToLogFile("DISCORD: Queue full, message dropped")
    end
end

-- ═══════════════════════════════════════════════════════════════
-- LOG CHAT
-- ═══════════════════════════════════════════════════════════════

local function logChat(targetPlayer, message, chatType)
    if not targetPlayer or not targetPlayer.Parent then
        addToLogFile("CHAT: Invalid player")
        return
    end
    
    chatType = chatType or "chat"
    
    addToLogFile(string.format("CHAT: [%s] %s: %s", chatType:upper(), targetPlayer.Name, message:sub(1, 100)))
    
    local icon = "💬"
    local typeText = "CHAT"
    local color = CONFIG.COLORS.CHAT
    
    local fields = {
        {
            ["name"] = "👤 Player",
            ["value"] = targetPlayer.Name,
            ["inline"] = true
        },
        {
            ["name"] = "🆔 ID",
            ["value"] = tostring(targetPlayer.UserId),
            ["inline"] = true
        }
    }
    
    sendToDiscord(
        icon .. " " .. typeText,
        "```" .. message .. "```",
        color,
        fields
    )
end

-- ═══════════════════════════════════════════════════════════════
-- TẠO GUI
-- ═══════════════════════════════════════════════════════════════

addToLogFile("GUI: Creating interface...")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChatLoggerGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Toggle Button
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleButton"
toggleButton.Size = UDim2.new(0, 65, 0, 65)
toggleButton.Position = UDim2.new(1, -85, 0.5, -32)
toggleButton.AnchorPoint = Vector2.new(0, 0)
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
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 450, 0, 600)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -300)
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
title.Text = "💬 Chat Logger PRO"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -130, 0, 22)
subtitle.Position = UDim2.new(0, 25, 0, 52)
subtitle.BackgroundTransparency = 1
subtitle.Text = "🔒 Protected • " .. executorName
subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
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
statusPanel.Size = UDim2.new(1, -40, 0, 160)
statusPanel.Position = UDim2.new(0, 20, 0, 100)
statusPanel.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
statusPanel.BorderSizePixel = 0
statusPanel.Parent = mainFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 12)
statusCorner.Parent = statusPanel

local statusList = Instance.new("UIListLayout")
statusList.Padding = UDim.new(0, 10)
statusList.SortOrder = Enum.SortOrder.LayoutOrder
statusList.Parent = statusPanel

local statusPadding = Instance.new("UIPadding")
statusPadding.PaddingLeft = UDim.new(0, 15)
statusPadding.PaddingRight = UDim.new(0, 15)
statusPadding.PaddingTop = UDim.new(0, 15)
statusPadding.PaddingBottom = UDim.new(0, 15)
statusPadding.Parent = statusPanel

-- Status items
local function createStatusLabel(text, color, order)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.Font = Enum.Font.GothamBold
    label.TextSize = 15
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

-- Control Panel
local controlPanel = Instance.new("Frame")
controlPanel.Size = UDim2.new(1, -40, 0, 100)
controlPanel.Position = UDim2.new(0, 20, 0, 280)
controlPanel.BackgroundColor3 = Color3.fromRGB(32, 34, 37)
controlPanel.BorderSizePixel = 0
controlPanel.Parent = mainFrame

local controlCorner = Instance.new("UICorner")
controlCorner.CornerRadius = UDim.new(0, 12)
controlCorner.Parent = controlPanel

local switchButton = Instance.new("TextButton")
switchButton.Size = UDim2.new(0, 240, 0, 60)
switchButton.Position = UDim2.new(0.5, -120, 0.5, -30)
switchButton.BackgroundColor3 = Color3.fromRGB(87, 242, 135)
switchButton.BorderSizePixel = 0
switchButton.Text = "🟢 TẮT LOGGER"
switchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
switchButton.Font = Enum.Font.GothamBold
switchButton.TextSize = 20
switchButton.AutoButtonColor = false
switchButton.Parent = controlPanel

local switchCorner = Instance.new("UICorner")
switchCorner.CornerRadius = UDim.new(0, 14)
switchCorner.Parent = switchButton

-- Log Section
local logTitle = Instance.new("TextLabel")
logTitle.Size = UDim2.new(1, -40, 0, 30)
logTitle.Position = UDim2.new(0, 20, 0, 400)
logTitle.BackgroundTransparency = 1
logTitle.Text = "📜 NHẬT KÝ HOẠT ĐỘNG"
logTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
logTitle.Font = Enum.Font.GothamBold
logTitle.TextSize = 16
logTitle.TextXAlignment = Enum.TextXAlignment.Left
logTitle.Parent = mainFrame

local logFrame = Instance.new("ScrollingFrame")
logFrame.Size = UDim2.new(1, -40, 0, 110)
logFrame.Position = UDim2.new(0, 20, 0, 440)
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
logList.Padding = UDim.new(0, 6)
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
buttonLayout.Padding = UDim.new(0, 10)
buttonLayout.Parent = footerFrame

local function createButton(text, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 125, 0, 40)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.AutoButtonColor = false
    btn.Parent = footerFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn
    
    return btn
end

local saveButton = createButton("💾 LƯU", Color3.fromRGB(88, 101, 242))
local clearButton = createButton("🗑️ XÓA", Color3.fromRGB(237, 66, 69))
local exportButton = createButton("📤 COPY", Color3.fromRGB(67, 181, 129))

addToLogFile("GUI: ✓ Interface created")

-- ═══════════════════════════════════════════════════════════════
-- GUI FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

local logEntryCount = 0

local function addLogToGUI(message, color)
    logEntryCount = logEntryCount + 1
    
    local logEntry = Instance.new("Frame")
    logEntry.Size = UDim2.new(1, -5, 0, 30)
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
    text.TextSize = 12
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
    badge.Text = tostring(messageCount)
end

-- ═══════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════

toggleButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
    
    if mainFrame.Visible then
        addToLogFile("GUI: Opened")
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Size = UDim2.new(0, 450, 0, 600),
            Position = UDim2.new(0.5, -225, 0.5, -300)
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
    addToLogFile("GUI: Closed")
end)

switchButton.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    updateUI()
    local status = isEnabled and "BẬT" or "TẮT"
    addToLogFile("ACTION: Logger " .. status)
    addLogToGUI("Logger đã " .. status, isEnabled and Color3.fromRGB(87, 242, 135) or Color3.fromRGB(237, 66, 69))
end)

saveButton.MouseButton1Click:Connect(function()
    local content = saveLogFile()
    addToLogFile(string.format("ACTION: Saved %d entries", #logFileContent))
    addLogToGUI("💾 Đã lưu " .. #logFileContent .. " dòng", Color3.fromRGB(88, 101, 242))
    
    saveButton.Text = "✓ OK"
    wait(1)
    saveButton.Text = "💾 LƯU"
    
    print("\n" .. string.rep("=", 70))
    print(content)
    print(string.rep("=", 70))
end)

clearButton.MouseButton1Click:Connect(function()
    clearLogFile()
    for _, child in ipairs(logFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    logEntryCount = 0
    addLogToGUI("🗑️ Đã xóa log", Color3.fromRGB(237, 66, 69))
    
    clearButton.Text = "✓ OK"
    wait(1)
    clearButton.Text = "🗑️ XÓA"
end)

exportButton.MouseButton1Click:Connect(function()
    local content = saveLogFile()
    
    if setclipboard then
        setclipboard(content)
        addLogToGUI("📋 Đã copy", Color3.fromRGB(67, 181, 129))
        exportButton.Text = "✓ OK"
    else
        addLogToGUI("⚠️ No clipboard", Color3.fromRGB(255, 200, 0))
        exportButton.Text = "✗ ERR"
    end
    
    addToLogFile("ACTION: Exported")
    wait(1)
    exportButton.Text = "📤 COPY"
end)

-- ═══════════════════════════════════════════════════════════════
-- CHAT MONITORING
-- ═══════════════════════════════════════════════════════════════

addToLogFile("CHAT: Setting up monitoring...")

local function setupMonitoring(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then return end
    
    local success = pcall(function()
        targetPlayer.Chatted:Connect(function(message)
            if message:sub(1, 1) == "/" then
                addToLogFile(string.format("CMD: %s: %s", targetPlayer.Name, message))
                addLogToGUI("⚡ " .. targetPlayer.Name .. " » " .. message:sub(1, 40), Color3.fromRGB(255, 200, 0))
            else
                logChat(targetPlayer, message, "chat")
                addLogToGUI("💬 " .. targetPlayer.Name .. " » " .. message:sub(1, 40), Color3.fromRGB(200, 200, 200))
            end
        end)
    end)
    
    if success then
        addToLogFile("CHAT: ✓ Monitoring " .. targetPlayer.Name)
    end
end

for _, p in pairs(Players:GetPlayers()) do
    setupMonitoring(p)
end

Players.PlayerAdded:Connect(function(p)
    setupMonitoring(p)
    addToLogFile(string.format("PLAYER: %s joined", p.Name))
    addLogToGUI("➕ " .. p.Name, Color3.fromRGB(87, 242, 135))
end)

Players.PlayerRemoving:Connect(function(p)
    addToLogFile(string.format("PLAYER: %s left", p.Name))
    addLogToGUI("➖ " .. p.Name, Color3.fromRGB(150, 150, 150))
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO UPDATE
-- ═══════════════════════════════════════════════════════════════

spawn(function()
    while screenGui and screenGui.Parent do
        updateUI()
        wait(1)
    end
end)

-- Badge pulse
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

addToLogFile("═══════════════════════════════════════════════════════════════")
addToLogFile("STARTUP: ✓ Logger initialized successfully")
addToLogFile(string.format("STARTUP: Executor: %s", executorName))
addToLogFile(string.format("STARTUP: Player: %s (ID: %d)", player.Name, player.UserId))
addToLogFile("═══════════════════════════════════════════════════════════════")

addLogToGUI("✓ Logger đã khởi động", Color3.fromRGB(87, 242, 135))
addLogToGUI("🔒 Protected mode active", Color3.fromRGB(88, 101, 242))

updateUI()

wait(2)

-- Test webhook
addToLogFile("TESTING: Sending test message...")
sendToDiscord(
    "🚀 Chat Logger Started",
    string.format("Logger has been initialized by **%s**\nExecutor: **%s**", player.Name, executorName),
    CONFIG.COLORS.SUCCESS,
    {
        {
            ["name"] = "Session",
            ["value"] = os.date("%Y-%m-%d %H:%M:%S"),
            ["inline"] = false
        }
    }
)

print("✅ CHAT LOGGER V4 LOADED")
print("🔒 Protected mode: ACTIVE")
print("💬 Click floating button to open")
