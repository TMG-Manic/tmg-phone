local TMGCore = exports['tmg-core']:GetCoreObject()

local PlayerJob = {}
local frontCam = false

local invalidCharPattern = '[?!@#]' 

local PhoneData = {
    MetaData = {},
    isOpen = false,
    PlayerData = nil,
    Contacts = {},
    Tweets = {},
    MentionedTweets = {},
    Hashtags = {},
    Chats = {},
    CallData = {},
    RecentCalls = {},
    Garage = {},
    Mails = {},
    Adverts = {},
    GarageVehicles = {},
    AnimationData = {
        lib = nil,
        anim = nil,
    },
    SuggestedContacts = {},
    CryptoTransactions = {},
    Images = {},
}

function string:split(delimiter)
    local result = {}
    for match in (self .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

local function escape_str(s)
    if type(s) ~= 'string' then return s end
    local htmlMap = {
        ['<'] = '&lt;', 
        ['>'] = '&gt;', 
        ['&'] = '&amp;', 
        ['"'] = '&quot;', 
        ["'"] = '&#39;'
    }
    return s:gsub('[<>&"\']', function(c) return htmlMap[c] end)
end

local function IsNumberInContacts(num)
    for _, v in ipairs(PhoneData.Contacts) do
        if num == v.number then
            return v.name 
        end
    end
    return num 
end

local function CalculateTimeToDisplay()
    return {
        hour = GetClockHours(),
        minute = string.format("%02d", GetClockMinutes())
    }
end

local function GetClosestPlayer()
    local closestPlayers = TMGCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local myId = PlayerId()

    for _, playerId in ipairs(closestPlayers) do
        if playerId ~= myId then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            
            local distance = #(targetCoords - myCoords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    
    return closestPlayer, closestDistance
end

local function GetKeyByDate(Number, Date)
    local chatData = PhoneData.Chats[Number]
    if not chatData or not chatData.messages then return nil end

    for key, chat in pairs(chatData.messages) do
        if chat.date == Date then
            return key
        end
    end

    return nil
end

local function GetKeyByNumber(Number)
    if not PhoneData.Chats then return nil end

    for k, v in pairs(PhoneData.Chats) do
        if v.number == Number then
            return k
        end
    end
    
    return nil
end

local function ReorganizeChats(key)
    if not PhoneData.Chats or not PhoneData.Chats[key] then return end

    local activeChat = PhoneData.Chats[key]

    table.remove(PhoneData.Chats, key)

    table.insert(PhoneData.Chats, 1, activeChat)
end

local function findVehFromPlateAndLocate(plate)
    if type(plate) ~= "string" or plate == "" then return false end
    
    local targetPlate = string.match(plate, "^%s*(.-)%s*$") 
    
    local gameVehicles = TMGCore.Functions.GetVehicles()

    for _, vehicle in ipairs(gameVehicles) do
        if DoesEntityExist(vehicle) then
            local rawPlate = TMGCore.Functions.GetPlate(vehicle) or ""
            local currentPlate = string.match(rawPlate, "^%s*(.-)%s*$")
            
            if currentPlate == targetPlate then
                local vehCoords = GetEntityCoords(vehicle)
                SetNewWaypoint(vehCoords.x, vehCoords.y)
                return true
            end
        end
    end
    
    return false 
end

local suppressedControls = {
    1, 2, 3, 4, 5, 6,       
    263, 264, 257,          
    140, 141, 142, 143,     
    177, 200, 202, 322,     
    245                     
}

local function DisableDisplayControlActions()
    for i = 1, #suppressedControls do
        DisableControlAction(0, suppressedControls[i], true)
    end
end

local function LoadPhone()
    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetPhoneData', function(pData)
        
        if type(pData) ~= "table" then 
            return print("^1[TMG Error]^7 Data Handshake failed. Mainframe payload is invalid.") 
        end

        local PlayerData = TMGCore.Functions.GetPlayerData()
        if not PlayerData then return end
        
        PhoneData.PlayerData = PlayerData
        PlayerJob = PlayerData.job
        
        local PhoneMeta = (PlayerData.metadata and type(PlayerData.metadata['phone']) == "table" and PlayerData.metadata['phone']) or { 
            profilepicture = "default",
            background = "default" 
        }
        PhoneData.MetaData = PhoneMeta

        if pData.InstalledApps and type(pData.InstalledApps) == "table" then
            for _, v in pairs(pData.InstalledApps) do
                local AppData = Config.StoreApps[v.app]
                if AppData then
                    Config.PhoneApplications[v.app] = {
                        app = v.app, color = AppData.color, icon = AppData.icon,
                        tooltipText = AppData.title, tooltipPos = 'right',
                        job = AppData.job, blockedjobs = AppData.blockedjobs,
                        slot = AppData.slot, Alerts = 0,
                    }
                end
            end
        end

        if pData.Applications and type(pData.Applications) == "table" then
            for k, v in pairs(pData.Applications) do
                if Config.PhoneApplications[k] then
                    Config.PhoneApplications[k].Alerts = tonumber(v) or 0
                end
            end
        end

        PhoneData.MentionedTweets = type(pData.MentionedTweets) == "table" and pData.MentionedTweets or {}
        PhoneData.Contacts = type(pData.PlayerContacts) == "table" and pData.PlayerContacts or {}
        PhoneData.Hashtags = type(pData.Hashtags) == "table" and pData.Hashtags or {}
        PhoneData.Tweets = type(pData.Tweets) == "table" and pData.Tweets or {}
        PhoneData.Mails = type(pData.Mails) == "table" and pData.Mails or {}
        PhoneData.Adverts = type(pData.Adverts) == "table" and pData.Adverts or {}
        PhoneData.CryptoTransactions = type(pData.CryptoTransactions) == "table" and pData.CryptoTransactions or {}
        PhoneData.Images = type(pData.Images) == "table" and pData.Images or {}

        PhoneData.Chats = {}
        if pData.Chats and type(pData.Chats) == "table" then
            for _, v in pairs(pData.Chats) do
                if type(v) == "table" and v.number then
                    PhoneData.Chats[v.number] = {
                        name = IsNumberInContacts(v.number),
                        number = v.number,
                        messages = type(v.messages) == "table" and v.messages or {} 
                    }
                end
            end
        end

        SendNUIMessage({
            action = 'LoadPhoneData',
            PhoneData = PhoneData,
            PlayerData = PhoneData.PlayerData,
            PlayerJob = PhoneData.PlayerData.job,
            applications = Config.PhoneApplications,
            PlayerId = GetPlayerServerId(PlayerId())
        })
        
        print("^5[TMG Mainframe]^7 Cellular Data Handshake Complete.")
    end)
end

local function OpenPhone()
    local hasPhone = TMGCore.Functions.HasItem('phone') 
    
    if not hasPhone then
        return TMGCore.Functions.Notify("Mainframe: No cellular hardware detected in inventory.", 'error')
    end

    PhoneData.isOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        Tweets = PhoneData.Tweets,
        AppData = Config.PhoneApplications,
        CallData = PhoneData.CallData,
        PlayerData = PhoneData.PlayerData,
    })

    CreateThread(function()
        while PhoneData.isOpen do
            DisableDisplayControlActions()
            Wait(0)
        end
    end)

    if not PhoneData.CallData.InCall then
        DoPhoneAnimation('cellphone_text_in')
    else
        DoPhoneAnimation('cellphone_call_to_text')
    end

    SetTimeout(250, function()
        newPhoneProp()
    end)

    TMGCore.Functions.TriggerCallback('tmg-garages:server:GetPlayerVehicles', function(vehicles)
        PhoneData.GarageVehicles = type(vehicles) == "table" and vehicles or {}
    end)
end

local function GenerateCallId(caller, target)
    local safeCaller = tonumber(caller) or math.random(1000, 9999)
    local safeTarget = tonumber(target) or math.random(1000, 9999)

    local salt = math.random(1000000, 9000000)
    
    local timeHash = os.time() % 10000
    
    local callId = math.floor(salt + timeHash + safeCaller)

    return callId
end

local function CancelCall()
    if PhoneData.CallData.CallType == 'ongoing' and PhoneData.CallData.CallId then
        exports['pma-voice']:removePlayerFromCall(PhoneData.CallData.CallId)
    end

    TriggerServerEvent('tmg-phone:server:CancelCall', PhoneData.CallData)
    TriggerServerEvent('tmg-phone:server:SetCallState', false)

    PhoneData.CallData = {
        CallType = nil,
        InCall = false,
        AnsweredCall = false,
        TargetData = {},
        CallId = nil
    }

    if not PhoneData.isOpen then
        StopAnimTask(PlayerPedId(), PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 2.5)
        deletePhone()
    end
    
    PhoneData.AnimationData.lib = nil
    PhoneData.AnimationData.anim = nil

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Cellular',
            text = 'Call Terminated.',
            icon = 'fas fa-phone-slash',
            color = '#e84118',
        },
    })

    if PhoneData.isOpen then
        SendNUIMessage({ action = 'SetupHomeCall', CallData = PhoneData.CallData })
        SendNUIMessage({ action = 'CancelOutgoingCall' })
    end
end

local function CallContact(CallData, AnonymousCall)
    PhoneData.CallData = {
        CallType = 'outgoing',
        InCall = true,
        TargetData = CallData,
        AnsweredCall = false,
        CallId = GenerateCallId(PhoneData.PlayerData.charinfo.phone, CallData.number)
    }

    TriggerServerEvent('tmg-phone:server:CallContact', PhoneData.CallData.TargetData, PhoneData.CallData.CallId, AnonymousCall)
    TriggerServerEvent('tmg-phone:server:SetCallState', true)

    CreateThread(function()
        local rings = 0
        local maxRings = Config.CallRepeats or 5
        local ringTimeout = Config.RepeatTimeout or 3000

        while PhoneData.CallData.InCall and not PhoneData.CallData.AnsweredCall do
            
            if rings >= maxRings then
                CancelCall()
                break
            end
            TriggerServerEvent('InteractSound_SV:PlayOnSource', 'demo', 0.1)
            rings = rings + 1
            
            Wait(ringTimeout)
        end
    end)
end

local function AnswerCall()
    local call = PhoneData.CallData
    local isValidCall = (call.CallType == 'incoming' or call.CallType == 'outgoing') and call.InCall and not call.AnsweredCall
    
    if not isValidCall then
        PhoneData.CallData.InCall = false
        PhoneData.CallData.CallType = nil
        PhoneData.CallData.AnsweredCall = false

        return SendNUIMessage({
            action = 'PhoneNotification',
            PhoneNotify = {
                title = 'Cellular',
                text = "No active connection detected.",
                icon = 'fas fa-phone-slash',
                color = '#e84118',
            },
        })
    end

    call.CallType = 'ongoing'
    call.AnsweredCall = true
    call.CallTime = 0

    if PhoneData.isOpen then
        DoPhoneAnimation('cellphone_text_to_call')
    else
        DoPhoneAnimation('cellphone_call_listen_base')
    end

    if call.CallId and type(call.CallId) == "number" then
        exports['pma-voice']:addPlayerToCall(call.CallId)
    else
        print("^3[TMG Warning]^7 Voice routing bypassed: CallId was null.")
    end

    TriggerServerEvent('tmg-phone:server:SetCallState', true)
    TriggerServerEvent('tmg-phone:server:AnswerCall', call)

    SendNUIMessage({ action = 'AnswerCall', CallData = call })
    SendNUIMessage({ action = 'SetupHomeCall', CallData = call })

    CreateThread(function()
        while PhoneData.CallData.AnsweredCall do
            Wait(1000)
            
            if PhoneData.CallData.AnsweredCall then
                PhoneData.CallData.CallTime = PhoneData.CallData.CallTime + 1
                SendNUIMessage({
                    action = 'UpdateCallTime',
                    Time = PhoneData.CallData.CallTime,
                    Name = PhoneData.CallData.TargetData.name,
                })
            end
        end
    end)
end

local function ToggleFrontCamera(activate)
    local state = (activate == true or activate == "true" or activate == 1)
    CellFrontCamActivate(state)
end

RegisterCommand('phone', function()
    if PhoneData.isOpen or not LocalPlayer.state.isLoggedIn or IsPauseMenuActive() then 
        return 
    end

    local PlayerData = TMGCore.Functions.GetPlayerData()
    
    if not PlayerData or type(PlayerData.metadata) ~= "table" then 
        return 
    end

    local meta = PlayerData.metadata

    if meta['ishandcuffed'] or meta['inlaststand'] or meta['isdead'] then
        return TMGCore.Functions.Notify('Action not available at the moment..', 'error')
    end

    OpenPhone()
end)

RegisterKeyMapping('phone', 'Open Phone', 'keyboard', Config.OpenPhone or Config.OpenKey or 'M')

local callActions = {
    ['CancelOutgoingCall'] = CancelCall,
    ['DenyIncomingCall']   = CancelCall,
    ['CancelOngoingCall']  = CancelCall,
    ['AnswerCall']         = AnswerCall
}

for actionName, executeFunction in pairs(callActions) do
    RegisterNUICallback(actionName, function(_, cb)
        executeFunction()
        cb('ok')
    end)
end

RegisterNUICallback('ClearRecentAlerts', function(_, cb)
    local targetApp = 'phone'

    if not Config.PhoneApplications[targetApp] then 
        print("^3[TMG Warning]^7 Attempted to purge alerts for unconfigured app: " .. targetApp)
        return cb('error') 
    end

    Config.PhoneApplications[targetApp].Alerts = 0

    TriggerServerEvent('tmg-phone:server:SetPhoneAlerts', targetApp, 0)

    SendNUIMessage({ 
        action = 'RefreshAppAlerts', 
        AppData = Config.PhoneApplications 
    })

    cb('ok')
end)

RegisterNUICallback('SetBackground', function(data, cb)
    if type(data) ~= "table" or type(data.background) ~= "string" then
        print("^3[TMG Security]^7 Background sync aborted: Malformed payload detected.")
        return cb('error')
    end

    if type(PhoneData.MetaData) ~= "table" then
        PhoneData.MetaData = {} 
    end

    PhoneData.MetaData.background = data.background

    TriggerServerEvent('tmg-phone:server:SaveMetaData', PhoneData.MetaData)

    cb('ok')
end)

local stateRetrievals = {
    ['GetMissedCalls']       = function() return PhoneData.RecentCalls or {} end,
    ['GetSuggestedContacts'] = function() return PhoneData.SuggestedContacts or {} end,
    ['SetupGarageVehicles']  = function() return PhoneData.GarageVehicles or {} end,
    ['GetGalleryData']       = function() return PhoneData.Images or {} end,
    ['GetMails']             = function() return PhoneData.Mails or {} end,
    ['GetBankContacts']      = function() return PhoneData.Contacts or {} end,
    ['GetCryptoTransactions'] = function() 
        return {
            CryptoTransactions = PhoneData.CryptoTransactions or {}
        }
    end,
    ['GetActiveJob'] = function() 
        return PlayerJob.name or "unemployed" 
    end,
    ['GetBatteryLevel'] = function() 
        return PhoneData.MetaData.battery or 100 
    end,
    ['GetPlayerPing'] = function()
        local myId = GetPlayerServerId(PlayerId())
        return myId
    end,
    ['LoadAdverts'] = function() 
        return PhoneData.Adverts or {} 
    end,
    ['GetMentionedTweets']   = function() 
        return PhoneData.MentionedTweets or {} 
    end,
    ['GetHashtags']          = function() 
        return PhoneData.Hashtags or {} 
    end,
    ['GetTweets'] = function() 
        return PhoneData.Tweets or {} 
    end
}

for actionName, getterFunction in pairs(stateRetrievals) do
    RegisterNUICallback(actionName, function(_, cb)
        cb(getterFunction())
    end)
end

RegisterNUICallback('HasPhone', function(_, cb)
    local hasPhone = TMGCore.Functions.HasItem('phone')
    cb(hasPhone)
end)

RegisterNUICallback('RemoveMail', function(data, cb)
    if type(data) ~= "table" or not data.mailId then
        print("^3[TMG Security]^7 Mail purge aborted: Malformed UI payload.")
        return cb('error')
    end

    TriggerServerEvent('tmg-phone:server:RemoveMail', data.mailId)
    cb('ok')
end)

RegisterNUICallback('Close', function(_, cb)
    SetNuiFocus(false, false)
    PhoneData.isOpen = false

    if not PhoneData.CallData.InCall then
        DoPhoneAnimation('cellphone_text_out')
        
        SetTimeout(400, function()
            StopAnimTask(PlayerPedId(), PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 2.5)
            deletePhone()
        end)
    else
        DoPhoneAnimation('cellphone_text_to_call')
    end

    PhoneData.AnimationData.lib = nil
    PhoneData.AnimationData.anim = nil

    cb('ok')
end)

RegisterNUICallback('AcceptMailButton', function(data, cb)
    if type(data) ~= "table" or not data.mailId then
        print("^3[TMG Security]^7 Mail action aborted: Malformed payload detected.")
        return cb('error')
    end

    if type(data.buttonEvent) == "string" then
        TriggerEvent(data.buttonEvent, data.buttonData)
    elseif data.buttonEvent ~= nil then
        print("^1[TMG Error]^7 Mail Dispatch failed: buttonEvent must be a string.")
    end

    TriggerServerEvent('tmg-phone:server:ClearButtonData', data.mailId)
    
    cb('ok')
end)

RegisterNUICallback('AddNewContact', function(data, cb)
    if type(data) ~= "table" or type(data.ContactName) ~= "string" or type(data.ContactNumber) ~= "string" then
        print("^3[TMG Security]^7 Contact creation aborted: Malformed UI payload.")
        return cb('error')
    end

    local newName = data.ContactName
    local newNumber = data.ContactNumber
    local newIban = type(data.ContactIban) == "string" and data.ContactIban or ""

    table.insert(PhoneData.Contacts, {
        name = newName,
        number = newNumber,
        iban = newIban
    })

    local activeChat = PhoneData.Chats[newNumber]
    if type(activeChat) == "table" then
        activeChat.name = newName
    end

    TriggerServerEvent('tmg-phone:server:AddNewContact', newName, newNumber, newIban)

    cb(PhoneData.Contacts)
end)

RegisterNUICallback('GetWhatsappChat', function(data, cb)
    if type(data) ~= "table" or not data.phone then
        return cb(false) 
    end

    local chat = PhoneData.Chats[data.phone]
    
    if type(chat) == "table" then
        cb(chat)
    else
        cb(false)
    end
end)

RegisterNUICallback('GetProfilePicture', function(data, cb)
    if type(data) ~= "table" or not data.number then
        return cb("default")
    end

    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetPicture', function(picture)
        cb(type(picture) == "string" and picture or "default")
    end, data.number)
end)

RegisterNUICallback('GetInvoices', function(_, cb)
    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetInvoices', function(resp)
        cb(type(resp) == "table" and resp or {})
    end)
end)

RegisterNUICallback('SharedLocation', function(data, cb)
    if type(data) ~= "table" or type(data.coords) ~= "table" then return cb('error') end

    local x, y = tonumber(data.coords.x), tonumber(data.coords.y)
    if not x or not y then 
        print("^1[TMG Error]^7 GPS routing aborted: Invalid coordinate matrix.")
        return cb('error') 
    end

    SetNewWaypoint(x + 0.0, y + 0.0)
    cb('ok')
end)

RegisterNUICallback('PostAdvert', function(data, cb)
    if type(data) ~= "table" or type(data.message) ~= "string" then
        print("^3[TMG Security]^7 Advert publication aborted: Malformed payload.")
        return cb('error')
    end

    local cleanMessage = string.match(data.message, "^%s*(.-)%s*$")
    
    if not cleanMessage or cleanMessage == "" then
        print("^3[TMG Warning]^7 Advert publication aborted: Message payload is empty.")
        return cb('error')
    end

    local safeUrl = type(data.url) == "string" and data.url or nil

    TriggerServerEvent('tmg-phone:server:AddAdvert', cleanMessage, safeUrl)

    cb('ok')
end)

local advertDeleteLock = false

RegisterNUICallback('DeleteAdvert', function(_, cb)
    if advertDeleteLock then
        print("^3[TMG Security]^7 Advert deletion blocked: Rate limit exceeded.")
        return cb('error')
    end

    advertDeleteLock = true

    TriggerServerEvent('tmg-phone:server:DeleteAdvert')

    SetTimeout(2500, function()
        advertDeleteLock = false
    end)

    cb('ok')
end)

RegisterNUICallback('ClearAlerts', function(data, cb)
    if type(data) ~= "table" or not data.number then
        print("^3[TMG Security]^7 Alert purge aborted: Malformed payload.")
        return cb('error')
    end

    local chatKey = GetKeyByNumber(data.number)
    local chatMatrix = chatKey and PhoneData.Chats[chatKey] or nil
    local appConfig = Config.PhoneApplications['whatsapp']

    if not chatMatrix or not appConfig then
        return cb('ok')
    end

    local unreadCount = tonumber(chatMatrix.Unread) or 0

    if unreadCount > 0 then
        local currentAlerts = tonumber(appConfig.Alerts) or 0
        local newAlerts = math.max(0, currentAlerts - unreadCount)
        
        appConfig.Alerts = newAlerts
        chatMatrix.Unread = 0

        TriggerServerEvent('tmg-phone:server:SetPhoneAlerts', 'whatsapp', newAlerts)

        SendNUIMessage({ action = 'RefreshWhatsappAlerts', Chats = PhoneData.Chats })
        SendNUIMessage({ action = 'RefreshAppAlerts', AppData = Config.PhoneApplications })
    end

    cb('ok')
end)

RegisterNUICallback('PayInvoice', function(data, cb)
    if type(data) ~= "table" then
        print("^3[TMG Security]^7 Transaction aborted: Malformed payload detected.")
        return cb(false)
    end

    local amount = tonumber(data.amount)
    local invoiceId = data.invoiceId
    local society = type(data.society) == "string" and data.society or nil
    local senderCitizenId = type(data.senderCitizenId) == "string" and data.senderCitizenId or data.sendercitizenid or nil

    if not amount or amount <= 0 or not invoiceId then
        print("^1[TMG Error]^7 Transaction failed: Invalid billing amount or Invoice ID.")
        return cb(false)
    end

    TMGCore.Functions.TriggerCallback('tmg-phone:server:PayInvoice', function(paymentSuccess)
        if paymentSuccess then
            TriggerServerEvent('tmg-phone:server:BillingEmail', data, true)
        end
        cb(paymentSuccess == true)
    end, society, amount, invoiceId, senderCitizenId)
end)

RegisterNUICallback('DeclineInvoice', function(data, cb)
    if type(data) ~= "table" then
        print("^3[TMG Security]^7 Invoice rejection aborted: Malformed payload detected.")
        return cb(false)
    end

    local amount = tonumber(data.amount)
    local invoiceId = data.invoiceId
    local society = type(data.society) == "string" and data.society or nil

    if not amount or amount <= 0 or not invoiceId then
        print("^1[TMG Error]^7 Invoice rejection failed: Invalid billing amount or Invoice ID.")
        return cb(false)
    end

    TMGCore.Functions.TriggerCallback('tmg-phone:server:DeclineInvoice', function(declineSuccess)
        if declineSuccess then
            TriggerServerEvent('tmg-phone:server:BillingEmail', data, false)
        end
        cb(declineSuccess == true)
    end, society, amount, invoiceId)
end)

RegisterNUICallback('EditContact', function(data, cb)
    if type(data) ~= "table" or type(data.CurrentContactName) ~= "string" or type(data.CurrentContactNumber) ~= "string" then
        print("^3[TMG Security]^7 Contact edit aborted: Malformed payload detected.")
        return cb(PhoneData.Contacts)
    end

    local newName = data.CurrentContactName
    local newNumber = data.CurrentContactNumber
    local newIban = type(data.CurrentContactIban) == "string" and data.CurrentContactIban or ""

    local oldName = type(data.OldContactName) == "string" and data.OldContactName or ""
    local oldNumber = type(data.OldContactNumber) == "string" and data.OldContactNumber or ""
    local oldIban = type(data.OldContactIban) == "string" and data.OldContactIban or ""

    for _, contact in pairs(PhoneData.Contacts) do
        if contact.name == oldName and contact.number == oldNumber then
            contact.name = newName
            contact.number = newNumber
            contact.iban = newIban
            break 
        end
    end

    local activeChat = PhoneData.Chats[newNumber]
    if type(activeChat) == "table" then
        activeChat.name = newName
    end

    local oldChat = PhoneData.Chats[oldNumber]
    if type(oldChat) == "table" and oldNumber ~= newNumber then
        oldChat.name = newName
    end

    TriggerServerEvent('tmg-phone:server:EditContact', newName, newNumber, newIban, oldName, oldNumber, oldIban)

    cb(PhoneData.Contacts)
end)

RegisterNUICallback('GetHashtagMessages', function(data, cb)
    if type(data) ~= "table" or type(data.hashtag) ~= "string" then
        print("^3[TMG Security]^7 Hashtag retrieval aborted: Malformed payload.")
        return cb({})
    end

    local hashtagData = PhoneData.Hashtags[data.hashtag]

    if type(hashtagData) == "table" then
        cb(hashtagData)
    else
        cb({})
    end
end)

RegisterNUICallback('UpdateProfilePicture', function(data, cb)
    if type(data) ~= "table" or type(data.profilepicture) ~= "string" then
        print("^3[TMG Security]^7 Avatar sync aborted: Malformed payload detected.")
        return cb('error')
    end

    if type(PhoneData.MetaData) ~= "table" then
        PhoneData.MetaData = {} 
    end

    PhoneData.MetaData.profilepicture = data.profilepicture

    TriggerServerEvent('tmg-phone:server:SaveMetaData', PhoneData.MetaData)

    cb('ok')
end)

local function GenerateTweetId()
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local id = "TWT-"
    for i = 1, 8 do
        local rand = math.random(1, #charset)
        id = id .. string.sub(charset, rand, rand)
    end
    return id
end

RegisterNUICallback('PostNewTweet', function(data, cb)
    if type(data) ~= "table" or type(data.Message) ~= "string" then
        print("^3[TMG Security]^7 Tweet aborted: Malformed payload.")
        return cb('error')
    end

    local cleanMessage = string.match(data.Message, "^%s*(.-)%s*$")
    if not cleanMessage or cleanMessage == "" then
        return cb('error')
    end

    local _, hashCount = string.gsub(cleanMessage, "#", "")
    if hashCount > 3 then
        SendNUIMessage({
            action = 'PhoneNotification',
            PhoneNotify = {
                title = 'Social Feed',
                text = 'Maximum 3 hashtags allowed.',
                icon = 'fab fa-twitter',
                color = '#1DA1F2',
                timeout = 2000,
            },
        })
        return cb(PhoneData.Tweets) 
    end

    local player = PhoneData.PlayerData
    local tweetMessage = {
        firstName = player.charinfo.firstname,
        lastName = player.charinfo.lastname,
        citizenid = player.citizenid,
        message = escape_str(cleanMessage),
        time = type(data.Date) == "string" and data.Date or "Just now",
        tweetId = GenerateTweetId(),
        picture = type(data.Picture) == "string" and data.Picture or nil,
        url = type(data.url) == "string" and data.url or nil
    }

    for tag in string.gmatch(cleanMessage, "#(%w+)") do
        TriggerServerEvent('tmg-phone:server:UpdateHashtags', tag, tweetMessage)
    end

    for mention in string.gmatch(cleanMessage, "@([A-Za-z0-9]+_[A-Za-z0-9]+)") do
        local first, last = string.match(mention, "^([^_]+)_([^_]+)$")
        if first and last then
            if first ~= player.charinfo.firstname or last ~= player.charinfo.lastname then
                TriggerServerEvent('tmg-phone:server:MentionedPlayer', first, last, tweetMessage)
            end
        end
    end

    table.insert(PhoneData.Tweets, tweetMessage)

    TriggerServerEvent('tmg-phone:server:UpdateTweets', PhoneData.Tweets, tweetMessage)

    cb(PhoneData.Tweets)
end)

local tweetDeleteLock = false

RegisterNUICallback('DeleteTweet', function(data, cb)
    if tweetDeleteLock then
        print("^3[TMG Security]^7 Tweet deletion blocked: Rate limit exceeded.")
        return cb('error')
    end

    if type(data) ~= "table" or not data.id then
        print("^3[TMG Security]^7 Tweet deletion aborted: Malformed payload.")
        return cb('error')
    end

    tweetDeleteLock = true

    TriggerServerEvent('tmg-phone:server:DeleteTweet', data.id)

    SetTimeout(1500, function()
        tweetDeleteLock = false
    end)

    cb('ok')
end)

local searchLock = false

RegisterNUICallback('FetchSearchResults', function(data, cb)
    if searchLock then 
        return cb({}) 
    end

    if type(data) ~= "table" or type(data.input) ~= "string" then
        print("^3[TMG Security]^7 Search aborted: Malformed UI payload.")
        return cb({})
    end

    local query = string.match(data.input, "^%s*(.-)%s*$")
    if not query or query == "" then
        return cb({})
    end

    searchLock = true

    TMGCore.Functions.TriggerCallback('tmg-phone:server:FetchResult', function(result)
        cb(type(result) == "table" and result or {})
    end, query)

    SetTimeout(500, function()
        searchLock = false
    end)
end)

local installLock = false

RegisterNUICallback('InstallApplication', function(data, cb)
    if installLock then
        return cb(false)
    end

    if type(data) ~= "table" or type(data.app) ~= "string" then
        print("^3[TMG Security]^7 Install aborted: Malformed UI payload.")
        return cb(false)
    end

    local appData = Config.StoreApps[data.app]
    if type(appData) ~= "table" then
        print("^1[TMG Error]^7 Install failed: App '" .. data.app .. "' does not exist.")
        return cb(false)
    end

    installLock = true

    TriggerServerEvent('tmg-phone:server:InstallApplication', {
        app = data.app,
    })

    SetTimeout(2000, function()
        installLock = false
    end)

    cb({
        app = data.app,
        data = appData
    })
end)

local uninstallLock = false

RegisterNUICallback('RemoveApplication', function(data, cb)
    if uninstallLock then
        print("^3[TMG Security]^7 Uninstall blocked: Rate limit exceeded.")
        return cb('error')
    end

    if type(data) ~= "table" or type(data.app) ~= "string" then
        print("^3[TMG Security]^7 Uninstall aborted: Malformed payload detected.")
        return cb('error')
    end

    uninstallLock = true

    TriggerServerEvent('tmg-phone:server:RemoveInstallation', data.app)

    SetTimeout(1500, function()
        uninstallLock = false
    end)

    cb('ok')
end)

RegisterNUICallback('GetTruckerData', function(_, cb)
    local player = TMGCore.Functions.GetPlayerData()
    local metadata = type(player) == "table" and player.metadata or {}
    local jobrep = type(metadata.jobrep) == "table" and metadata.jobrep or {}
    local truckerRep = tonumber(jobrep.trucker) or 0

    local success, tierData = pcall(function()
        return exports['tmg-trucker']:GetTier(truckerRep)
    end)

    if success and type(tierData) == "table" then
        cb(tierData)
    else
        cb({})
    end
end)

local imageDeleteLock = false

RegisterNUICallback('DeleteImage', function(data, cb)
    if imageDeleteLock then
        print("^3[TMG Security]^7 Image deletion blocked: Rate limit exceeded.")
        return cb(false)
    end

    local targetImage = type(data) == "table" and data.image or data
    
    if type(targetImage) ~= "string" or targetImage == "" then
        print("^3[TMG Security]^7 Image deletion aborted: Malformed URL payload.")
        return cb(false)
    end

    imageDeleteLock = true

    if type(PhoneData.Images) == "table" then
        for i, imgData in ipairs(PhoneData.Images) do
            local isMatch = (type(imgData) == "table" and imgData.image == targetImage) or 
                            (type(imgData) == "string" and imgData == targetImage)
            if isMatch then
                table.remove(PhoneData.Images, i)
                break 
            end
        end
    end

    TriggerServerEvent('tmg-phone:server:RemoveImageFromGallery', targetImage)

    SetTimeout(1000, function()
        imageDeleteLock = false
    end)

    cb(PhoneData.Images or true)
end)

local trackVehicleLock = false

RegisterNUICallback('track-vehicle', function(data, cb)
    if trackVehicleLock then return cb('error') end

    if type(data) ~= "table" or type(data.veh) ~= "table" or type(data.veh.plate) ~= "string" then
        print("^3[TMG Security]^7 Tracking aborted: Malformed payload matrix.")
        return cb('error')
    end

    local plate = string.upper(data.veh.plate)
    if plate == "" then return cb('error') end

    trackVehicleLock = true

    if findVehFromPlateAndLocate(plate) then
        TMGCore.Functions.Notify('GPS Protocol active: Vehicle location marked.', 'success')
    else
        TMGCore.Functions.Notify('GPS Error: Target vehicle signal lost.', 'error')
    end

    SetTimeout(2000, function()
        trackVehicleLock = false
    end)

    cb('ok')
end)

local contactDeleteLock = false

RegisterNUICallback('DeleteContact', function(data, cb)
    if contactDeleteLock then
        return cb(PhoneData.Contacts) 
    end

    if type(data) ~= "table" or type(data.CurrentContactName) ~= "string" or type(data.CurrentContactNumber) ~= "string" then
        print("^3[TMG Security]^7 Contact deletion aborted: Malformed payload detected.")
        return cb(PhoneData.Contacts)
    end

    local targetName = data.CurrentContactName
    local targetNumber = data.CurrentContactNumber

    contactDeleteLock = true

    if type(PhoneData.Contacts) == "table" then
        for i, contact in ipairs(PhoneData.Contacts) do
            if contact.name == targetName and contact.number == targetNumber then
                table.remove(PhoneData.Contacts, i)
                SendNUIMessage({
                    action = 'PhoneNotification',
                    PhoneNotify = {
                        title = 'Contacts',
                        text = 'Contact deleted.',
                        icon = 'fa fa-user-minus',
                        color = '#E74C3C',
                        timeout = 1500,
                    },
                })
                break 
            end
        end
    end

    local activeChat = PhoneData.Chats[targetNumber]
    if type(activeChat) == "table" then
        activeChat.name = targetNumber
    end

    TriggerServerEvent('tmg-phone:server:RemoveContact', targetName, targetNumber)

    SetTimeout(1000, function()
        contactDeleteLock = false
    end)

    cb(PhoneData.Contacts)
end)

local cryptoSyncLock = false

RegisterNUICallback('GetCryptoData', function(data, cb)
    if cryptoSyncLock then return cb({}) end

    if type(data) ~= "table" or type(data.crypto) ~= "string" then
        print("^3[TMG Security]^7 Crypto sync aborted: Malformed payload detected.")
        return cb({})
    end

    local cryptoIdentifier = string.lower(data.crypto)
    if cryptoIdentifier == "" then return cb({}) end

    cryptoSyncLock = true

    TMGCore.Functions.TriggerCallback('tmg-crypto:server:GetCryptoData', function(marketData)
        cb(type(marketData) == "table" and marketData or {})
    end, cryptoIdentifier)

    SetTimeout(1500, function()
        cryptoSyncLock = false
    end)
end)

local cryptoTransactionLock = false

RegisterNUICallback('BuyCrypto', function(data, cb)
    if cryptoTransactionLock then return cb(false) end

    local coins = tonumber(data.coins)
    if type(data) ~= "table" or type(data.crypto) ~= "string" or not coins or coins <= 0 then
        print("^3[TMG Security]^7 Buy order aborted: Malformed or negative payload.")
        return cb(false)
    end

    cryptoTransactionLock = true

    local cleanPayload = { crypto = string.lower(data.crypto), coins = coins }

    TMGCore.Functions.TriggerCallback('tmg-crypto:server:BuyCrypto', function(success)
        cryptoTransactionLock = false
        cb(success == true)
    end, cleanPayload)
end)

RegisterNUICallback('SellCrypto', function(data, cb)
    if cryptoTransactionLock then return cb(false) end

    local coins = tonumber(data.coins)
    if type(data) ~= "table" or type(data.crypto) ~= "string" or not coins or coins <= 0 then
        print("^3[TMG Security]^7 Sell order aborted: Malformed or negative payload.")
        return cb(false)
    end

    cryptoTransactionLock = true
    local cleanPayload = { crypto = string.lower(data.crypto), coins = coins }

    TMGCore.Functions.TriggerCallback('tmg-crypto:server:SellCrypto', function(success)
        cryptoTransactionLock = false
        cb(success == true)
    end, cleanPayload)
end)

RegisterNUICallback('TransferCrypto', function(data, cb)
    if cryptoTransactionLock then return cb(false) end

    local coins = tonumber(data.coins)
    if type(data) ~= "table" or type(data.crypto) ~= "string" or type(data.walletid) ~= "string" or not coins or coins <= 0 then
        print("^3[TMG Security]^7 Transfer aborted: Malformed payload or missing wallet ID.")
        return cb(false)
    end
    local walletId = string.match(data.walletid, "^%s*(.-)%s*$")
    if walletId == "" then return cb(false) end

    cryptoTransactionLock = true
    local cleanPayload = { crypto = string.lower(data.crypto), coins = coins, walletid = walletId }

    TMGCore.Functions.TriggerCallback('tmg-crypto:server:TransferCrypto', function(success)
        cryptoTransactionLock = false
        cb(success == true)
    end, cleanPayload)
end)

local raceSyncLock = false

RegisterNUICallback('GetAvailableRaces', function(_, cb)
    if raceSyncLock then return cb({}) end

    raceSyncLock = true

    TMGCore.Functions.TriggerCallback('tmg-lapraces:server:GetRaces', function(races)
        cb(type(races) == "table" and races or {})
    end)

    SetTimeout(1500, function()
        raceSyncLock = false
    end)
end)

local raceActionLock = false

RegisterNUICallback('JoinRace', function(data, cb)
    if raceActionLock then return cb('error') end

    if type(data) ~= "table" or type(data.RaceData) ~= "table" or not data.RaceData.RaceId then
        print("^3[TMG Security]^7 Join Race aborted: Malformed payload matrix.")
        return cb('error')
    end

    raceActionLock = true
    TriggerServerEvent('tmg-lapraces:server:JoinRace', data.RaceData)
    SetTimeout(1000, function() raceActionLock = false end)
    cb('ok')
end)

RegisterNUICallback('LeaveRace', function(data, cb)
    if raceActionLock then return cb('error') end

    if type(data) ~= "table" or type(data.RaceData) ~= "table" or not data.RaceData.RaceId then
        print("^3[TMG Security]^7 Leave Race aborted: Malformed payload matrix.")
        return cb('error')
    end

    raceActionLock = true
    TriggerServerEvent('tmg-lapraces:server:LeaveRace', data.RaceData)
    SetTimeout(1000, function() raceActionLock = false end)
    cb('ok')
end)

RegisterNUICallback('StartRace', function(data, cb)
    if raceActionLock then return cb('error') end

    if type(data) ~= "table" or type(data.RaceData) ~= "table" or not data.RaceData.RaceId then
        print("^3[TMG Security]^7 Start Race aborted: Malformed payload matrix.")
        return cb('error')
    end

    raceActionLock = true
    TriggerServerEvent('tmg-lapraces:server:StartRace', data.RaceData.RaceId)
    SetTimeout(1500, function() raceActionLock = false end)
    cb('ok')
end)

local waypointLock = false

RegisterNUICallback('SetAlertWaypoint', function(data, cb)
    if waypointLock then return cb('error') end

    if type(data) ~= "table" or type(data.alert) ~= "table" or type(data.alert.coords) ~= "table" then
        print("^3[TMG Security]^7 GPS Routing aborted: Malformed payload matrix.")
        return cb('error')
    end

    local coords = data.alert.coords
    local destX = tonumber(coords.x)
    local destY = tonumber(coords.y)
    local alertTitle = type(data.alert.title) == "string" and data.alert.title or "Unknown Alert"

    if not destX or not destY then return cb('error') end

    waypointLock = true
    SetNewWaypoint(destX, destY)
    TMGCore.Functions.Notify('GPS Protocol active: Routing to ' .. alertTitle, 'success')

    SetTimeout(1000, function() waypointLock = false end)
    cb('ok')
end)

local suggestionDeleteLock = false

RegisterNUICallback('RemoveSuggestion', function(payload, cb)
    if suggestionDeleteLock then return cb('error') end

    if type(payload) ~= "table" or type(payload.data) ~= "table" then
        print("^3[TMG Security]^7 Suggestion rejection aborted: Malformed payload matrix.")
        return cb('error')
    end

    local targetData = payload.data

    if type(targetData.name) ~= "table" or type(targetData.number) ~= "string" then
        return cb('error')
    end

    suggestionDeleteLock = true

    if type(PhoneData.SuggestedContacts) == "table" then
        for i, contact in ipairs(PhoneData.SuggestedContacts) do
            if type(contact.name) == "table" then
                local isNameMatch = (targetData.name[1] == contact.name[1] and targetData.name[2] == contact.name[2])
                local isNumberMatch = (targetData.number == contact.number)
                local isBankMatch = (targetData.bank == contact.bank)

                if isNameMatch and isNumberMatch and isBankMatch then
                    table.remove(PhoneData.SuggestedContacts, i)
                    break 
                end
            end
        end
    end

    SetTimeout(500, function() suggestionDeleteLock = false end)
    cb('ok')
end)

local vehicleSearchLock = false

RegisterNUICallback('FetchVehicleResults', function(data, cb)
    if vehicleSearchLock then return cb({}) end

    if type(data) ~= "table" or type(data.input) ~= "string" then
        print("^3[TMG Security]^7 Vehicle search aborted: Malformed UI payload.")
        return cb({})
    end

    local query = string.match(data.input, "^%s*(.-)%s*$")
    if not query or query == "" then return cb({}) end

    vehicleSearchLock = true

    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetVehicleSearchResults', function(result)
        if type(result) ~= "table" or #result == 0 then
            return cb({})
        end

        local pendingCallbacks = 0

        for i, veh in ipairs(result) do
            if type(veh) == "table" and type(veh.plate) == "string" then
                pendingCallbacks = pendingCallbacks + 1
                TMGCore.Functions.TriggerCallback('police:IsPlateFlagged', function(flagged)
                    veh.isFlagged = (flagged == true) 
                    pendingCallbacks = pendingCallbacks - 1
                end, veh.plate)
            end
        end

        CreateThread(function()
            local timeout = 0
            while pendingCallbacks > 0 and timeout < 30 do
                Wait(100)
                timeout = timeout + 1
            end
            cb(result)
        end)
    end, query)

    SetTimeout(1000, function() vehicleSearchLock = false end)
end)

local vehicleScanLock = false

RegisterNUICallback('FetchVehicleScan', function(_, cb)
    if vehicleScanLock then return cb(false) end

    local vehicle = TMGCore.Functions.GetClosestVehicle()
    if not vehicle or vehicle == 0 then
        TMGCore.Functions.Notify("Scanner Error: No vehicle detected in range.", "error")
        return cb(false) 
    end

    local plate = TMGCore.Functions.GetPlate(vehicle)
    if type(plate) ~= "string" or plate == "" then
        TMGCore.Functions.Notify("Scanner Error: Unreadable license plate.", "error")
        return cb(false)
    end

    vehicleScanLock = true

    local modelHash = GetEntityModel(vehicle)
    local vehName = string.lower(GetDisplayNameFromVehicleModel(modelHash))

    TMGCore.Functions.TriggerCallback('tmg-phone:server:ScanPlate', function(scanResult)
        if type(scanResult) ~= "table" then
            scanResult = { isOwned = false, plate = plate }
        end

        TMGCore.Functions.TriggerCallback('police:IsPlateFlagged', function(flagged)
            scanResult.isFlagged = (flagged == true)
            local sharedVehData = TMGCore.Shared.Vehicles[vehName]
            if type(sharedVehData) == "table" and type(sharedVehData.name) == "string" then
                scanResult.label = sharedVehData.name
            else
                scanResult.label = 'Unknown Brand'
            end
            cb(scanResult)
        end, plate)
    end, plate)

    SetTimeout(2000, function() vehicleScanLock = false end)
end)

local listedRacesLock = false

RegisterNUICallback('GetRaces', function(_, cb)
    if listedRacesLock then return cb({}) end
    listedRacesLock = true

    TMGCore.Functions.TriggerCallback('tmg-lapraces:server:GetListedRaces', function(races)
        cb(type(races) == "table" and races or {})
    end)

    SetTimeout(1500, function() listedRacesLock = false end)
end)

local trackDataLock = false

RegisterNUICallback('GetTrackData', function(data, cb)
    if trackDataLock then return cb({}) end

    if type(data) ~= "table" or type(data.RaceId) ~= "string" then
        print("^3[TMG Security]^7 Track data lookup aborted: Malformed payload matrix.")
        return cb({})
    end

    local raceId = string.match(data.RaceId, "^%s*(.-)%s*$")
    if not raceId or raceId == "" then return cb({}) end

    trackDataLock = true
    TMGCore.Functions.TriggerCallback('tmg-lapraces:server:GetTrackData', function(trackData, creatorData)
        if type(trackData) == "table" then
            trackData.CreatorData = type(creatorData) == "table" and creatorData or {}
            cb(trackData)
        else
            cb({})
        end
    end, raceId)

    SetTimeout(1000, function() trackDataLock = false end)
end)

local raceSetupLock = false
local creatorCheckLock = false

RegisterNUICallback('SetupRace', function(data, cb)
    if raceSetupLock then return cb('error') end

    if type(data) ~= "table" or type(data.RaceId) ~= "string" then
        print("^3[TMG Security]^7 Race setup aborted: Malformed payload matrix.")
        return cb('error')
    end

    local raceId = string.match(data.RaceId, "^%s*(.-)%s*$")
    local laps = tonumber(data.AmountOfLaps)

    if not raceId or raceId == "" or not laps or laps <= 0 then
        return cb('error')
    end

    raceSetupLock = true
    TriggerServerEvent('tmg-lapraces:server:SetupRace', raceId, laps)
    SetTimeout(1500, function() raceSetupLock = false end)
    cb('ok')
end)

RegisterNUICallback('HasCreatedRace', function(_, cb)
    if creatorCheckLock then return cb(false) end

    creatorCheckLock = true
    TMGCore.Functions.TriggerCallback('tmg-lapraces:server:HasCreatedRace', function(hasCreated)
        cb(hasCreated == true)
    end)

    SetTimeout(1000, function() creatorCheckLock = false end)
end)

local raceStatusLock = false

RegisterNUICallback('IsInRace', function(_, cb)
    if raceStatusLock then return cb(false) end
    raceStatusLock = true

    local success, inRace = pcall(function()
        return exports['tmg-lapraces']:IsInRace()
    end)

    SetTimeout(500, function() raceStatusLock = false end)
    cb(success and inRace == true)
end)

local raceAuthLock = false

RegisterNUICallback('IsAuthorizedToCreateRaces', function(payload, cb)
    if raceAuthLock then
        return cb({ IsAuthorized = false, IsBusy = false, IsNameAvailable = false })
    end

    if type(payload) ~= "table" or type(payload.TrackName) ~= "string" then
        print("^3[TMG Security]^7 Auth check aborted: Malformed payload matrix.")
        return cb({ IsAuthorized = false, IsBusy = false, IsNameAvailable = false })
    end

    local trackName = string.match(payload.TrackName, "^%s*(.-)%s*$")
    if not trackName or trackName == "" then
        return cb({ IsAuthorized = false, IsBusy = false, IsNameAvailable = false })
    end

    raceAuthLock = true

    TMGCore.Functions.TriggerCallback('tmg-lapraces:server:IsAuthorizedToCreateRaces', function(isAuthorized, nameAvailable)
        local success, inEditor = pcall(function()
            return exports['tmg-lapraces']:IsInEditor()
        end)

        cb({
            IsAuthorized = (isAuthorized == true),
            IsBusy = (success and inEditor == true),
            IsNameAvailable = (nameAvailable == true)
        })
    end, trackName)

    SetTimeout(1000, function() raceAuthLock = false end)
end)

local editorLock = false
local leaderboardLock = false

RegisterNUICallback('StartTrackEditor', function(data, cb)
    if editorLock then return cb('error') end

    if type(data) ~= "table" or type(data.TrackName) ~= "string" then
        print("^3[TMG Security]^7 Editor instantiation aborted: Malformed payload matrix.")
        return cb('error')
    end

    local trackName = string.match(data.TrackName, "^%s*(.-)%s*$")
    if not trackName or trackName == "" then return cb('error') end

    editorLock = true
    TriggerServerEvent('tmg-lapraces:server:CreateLapRace', trackName)
    SetTimeout(1500, function() editorLock = false end)
    cb('ok')
end)

RegisterNUICallback('GetRacingLeaderboards', function(_, cb)
    if leaderboardLock then return cb({}) end
    leaderboardLock = true

    TMGCore.Functions.TriggerCallback('tmg-lapraces:server:GetRacingLeaderboards', function(leaderboards)
        cb(type(leaderboards) == "table" and leaderboards or {})
    end)

    SetTimeout(2000, function() leaderboardLock = false end)
end)

local raceDistanceLock = false

RegisterNUICallback('RaceDistanceCheck', function(data, cb)
    if raceDistanceLock then return cb(false) end

    if type(data) ~= "table" or type(data.RaceId) ~= "string" then
        print("^3[TMG Security]^7 Distance check aborted: Malformed payload matrix.")
        return cb(false)
    end

    local raceId = string.match(data.RaceId, "^%s*(.-)%s*$")
    if not raceId or raceId == "" then return cb(false) end

    raceDistanceLock = true

    TMGCore.Functions.TriggerCallback('tmg-lapraces:server:GetRacingData', function(raceData)
        if type(raceData) ~= "table" or 
           type(raceData.Checkpoints) ~= "table" or 
           type(raceData.Checkpoints[1]) ~= "table" or 
           type(raceData.Checkpoints[1].coords) ~= "table" then
            return cb(false)
        end

        local cpCoords = raceData.Checkpoints[1].coords
        local cpX = tonumber(cpCoords.x)
        local cpY = tonumber(cpCoords.y)

        if not cpX or not cpY then return cb(false) end

        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)
        local dist = #(pCoords - vector3(cpX, cpY, tonumber(cpCoords.z) or 0.0))

        if dist <= 115.0 then
            if data.Joined == true then
                TriggerEvent('tmg-lapraces:client:WaitingDistanceCheck')
            end
            cb(true)
        else
            TMGCore.Functions.Notify("GPS Error: You are too far from the starting line.", "error", 5000)
            SetNewWaypoint(cpX, cpY)
            cb(false)
        end
    end, raceId)

    SetTimeout(2000, function() raceDistanceLock = false end)
end)

local busyCheckLock = false

RegisterNUICallback('IsBusyCheck', function(data, cb)
    if busyCheckLock then return cb(false) end

    if type(data) ~= "table" or type(data.check) ~= "string" then
        print("^3[TMG Security]^7 Busy check aborted: Malformed payload matrix.")
        return cb(false)
    end

    busyCheckLock = true
    local route = string.lower(data.check)
    local isBusy = false

    if route == 'editor' then
        local success, inEditor = pcall(function() return exports['tmg-lapraces']:IsInEditor() end)
        isBusy = (success and inEditor == true)
    else
        local success, inRace = pcall(function() return exports['tmg-lapraces']:IsInRace() end)
        isBusy = (success and inRace == true)
    end

    SetTimeout(500, function() busyCheckLock = false end)
    cb(isBusy)
end)

local setupAuthLock = false
local propertiesLock = false
local keysLock = false

RegisterNUICallback('CanRaceSetup', function(_, cb)
    if setupAuthLock then return cb(false) end
    setupAuthLock = true
    TMGCore.Functions.TriggerCallback('tmg-lapraces:server:CanRaceSetup', function(canSetup)
        cb(canSetup == true)
    end)
    SetTimeout(1000, function() setupAuthLock = false end)
end)

RegisterNUICallback('GetPlayerHouses', function(_, cb)
    if propertiesLock then return cb({}) end
    propertiesLock = true
    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetPlayerHouses', function(houses)
        cb(type(houses) == "table" and houses or {})
    end)
    SetTimeout(1500, function() propertiesLock = false end)
end)

RegisterNUICallback('GetPlayerKeys', function(_, cb)
    if keysLock then return cb({}) end
    keysLock = true
    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetHouseKeys', function(keys)
        cb(type(keys) == "table" and keys or {})
    end)
    SetTimeout(1500, function() keysLock = false end)
end)

local houseLocationLock = false
local removeKeyholderLock = false

RegisterNUICallback('SetHouseLocation', function(data, cb)
    if houseLocationLock then return cb('error') end

    if type(data) ~= "table" or 
       type(data.HouseData) ~= "table" or 
       type(data.HouseData.HouseData) ~= "table" or 
       type(data.HouseData.HouseData.coords) ~= "table" or 
       type(data.HouseData.HouseData.coords.enter) ~= "table" then
        return cb('error')
    end

    local targetHouse = data.HouseData.HouseData
    local destX = tonumber(targetHouse.coords.enter.x)
    local destY = tonumber(targetHouse.coords.enter.y)

    if not destX or not destY then return cb('error') end

    houseLocationLock = true
    SetNewWaypoint(destX, destY)
    TMGCore.Functions.Notify('GPS Protocol active: Routing to property', 'success')
    SetTimeout(1000, function() houseLocationLock = false end)
    cb('ok')
end)

RegisterNUICallback('RemoveKeyholder', function(data, cb)
    if removeKeyholderLock then return cb('error') end

    if type(data) ~= "table" or 
       type(data.HouseData) ~= "table" or 
       type(data.HolderData) ~= "table" or 
       type(data.HolderData.charinfo) ~= "table" then
        return cb('error')
    end

    local houseName = data.HouseData.name
    local targetCitizenId = data.HolderData.citizenid

    if type(houseName) ~= "string" or houseName == "" or type(targetCitizenId) ~= "string" or targetCitizenId == "" then
        return cb('error')
    end

    removeKeyholderLock = true
    local cleanHolderData = {
        citizenid = targetCitizenId,
        firstname = type(data.HolderData.charinfo.firstname) == "string" and data.HolderData.charinfo.firstname or "Unknown",
        lastname = type(data.HolderData.charinfo.lastname) == "string" and data.HolderData.charinfo.lastname or "Unknown",
    }

    TriggerServerEvent('tmg-houses:server:removeHouseKey', houseName, cleanHolderData)
    SetTimeout(1500, function() removeKeyholderLock = false end)
    cb('ok')
end)

local propertyTransferLock = false
local meosSearchLock = false

RegisterNUICallback('TransferCid', function(data, cb)
    if propertyTransferLock then return cb(false) end

    if type(data) ~= "table" or 
       type(data.newBsn) ~= "string" or 
       type(data.HouseData) ~= "table" or 
       type(data.HouseData.name) ~= "string" then
        return cb(false)
    end

    local targetCid = string.match(data.newBsn, "^%s*(.-)%s*$")
    if not targetCid or targetCid == "" then return cb(false) end

    propertyTransferLock = true
    TMGCore.Functions.TriggerCallback('tmg-phone:server:TransferCid', function(canTransfer)
        cb(canTransfer == true)
    end, targetCid, data.HouseData)

    SetTimeout(1500, function() propertyTransferLock = false end)
end)

RegisterNUICallback('FetchPlayerHouses', function(data, cb)
    if meosSearchLock then return cb({}) end

    if type(data) ~= "table" or type(data.input) ~= "string" then return cb({}) end

    local query = string.match(data.input, "^%s*(.-)%s*$")
    if not query or query == "" then return cb({}) end

    meosSearchLock = true
    TMGCore.Functions.TriggerCallback('tmg-phone:server:MeosGetPlayerHouses', function(result)
        cb(type(result) == "table" and result or {})
    end, query)

    SetTimeout(1000, function() meosSearchLock = false end)
end)

local gpsRoutingLock = false

RegisterNUICallback('SetGPSLocation', function(data, cb)
    if gpsRoutingLock then return cb('error') end

    if type(data) ~= "table" or type(data.coords) ~= "table" then return cb('error') end

    local destX = tonumber(data.coords.x)
    local destY = tonumber(data.coords.y)
    if not destX or not destY then return cb('error') end

    gpsRoutingLock = true
    SetNewWaypoint(destX, destY)
    TMGCore.Functions.Notify('GPS Protocol active: Destination set.', 'success')
    SetTimeout(1000, function() gpsRoutingLock = false end)
    cb('ok')
end)

RegisterNUICallback('SetApartmentLocation', function(data, cb)
    if gpsRoutingLock then return cb('error') end

    if type(data) ~= "table" or 
       type(data.data) ~= "table" or 
       type(data.data.appartmentdata) ~= "table" or 
       type(data.data.appartmentdata.type) ~= "string" then
        return cb('error')
    end

    local aptType = data.data.appartmentdata.type
    local typeData = Apartments and Apartments.Locations and Apartments.Locations[aptType]
    
    if type(typeData) ~= "table" or 
       type(typeData.coords) ~= "table" or 
       type(typeData.coords.enter) ~= "table" then
        return cb('error')
    end

    local destX = tonumber(typeData.coords.enter.x)
    local destY = tonumber(typeData.coords.enter.y)

    if not destX or not destY then return cb('error') end

    gpsRoutingLock = true
    SetNewWaypoint(destX, destY)
    TMGCore.Functions.Notify('GPS Protocol active: Routing to apartment.', 'success')
    SetTimeout(1000, function() gpsRoutingLock = false end)
    cb('ok')
end)

local lawyerSyncLock = false
local storeSetupLock = false

RegisterNUICallback('GetCurrentLawyers', function(_, cb)
    if lawyerSyncLock then return cb({}) end
    lawyerSyncLock = true

    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetCurrentLawyers', function(lawyers)
        cb(type(lawyers) == "table" and lawyers or {})
    end)

    SetTimeout(1500, function() lawyerSyncLock = false end)
end)

RegisterNUICallback('SetupStoreApps', function(_, cb)
    if storeSetupLock then return cb({}) end

    local player = TMGCore.Functions.GetPlayerData()

    if type(player) ~= "table" or type(player.metadata) ~= "table" then
        return cb({
            StoreApps = type(Config.StoreApps) == "table" and Config.StoreApps or {},
            PhoneData = {}
        })
    end

    storeSetupLock = true
    cb({
        StoreApps = type(Config.StoreApps) == "table" and Config.StoreApps or {},
        PhoneData = type(player.metadata['phonedata']) == "table" and player.metadata['phonedata'] or {}
    })

    SetTimeout(500, function() storeSetupLock = false end)
end)

local alertClearLock = false

RegisterNUICallback('ClearMentions', function(_, cb)
    if alertClearLock then return cb('error') end

    if type(Config) ~= "table" or type(Config.PhoneApplications) ~= "table" or type(Config.PhoneApplications['twitter']) ~= "table" then
        return cb('error')
    end

    alertClearLock = true
    Config.PhoneApplications['twitter'].Alerts = 0

    SendNUIMessage({
        action = 'RefreshAppAlerts',
        AppData = Config.PhoneApplications
    })

    TriggerServerEvent('tmg-phone:server:SetPhoneAlerts', 'twitter', 0)
    SetTimeout(1000, function() alertClearLock = false end)
    cb('ok')
end)

local generalAlertLock = false

RegisterNUICallback('ClearGeneralAlerts', function(data, cb)
    if generalAlertLock then return cb('error') end

    if type(data) ~= "table" or type(data.app) ~= "string" then return cb('error') end

    local targetApp = string.lower(data.app)
    if type(Config) ~= "table" or type(Config.PhoneApplications) ~= "table" or type(Config.PhoneApplications[targetApp]) ~= "table" then
        return cb('error')
    end

    generalAlertLock = true
    Config.PhoneApplications[targetApp].Alerts = 0

    SendNUIMessage({
        action = 'RefreshAppAlerts',
        AppData = Config.PhoneApplications
    })

    TriggerServerEvent('tmg-phone:server:SetPhoneAlerts', targetApp, 0)
    SetTimeout(500, function() generalAlertLock = false end)
    cb('ok')
end)

local bankTransferLock = false

RegisterNUICallback('TransferMoney', function(data, cb)
    if bankTransferLock then
        return cb({ CanTransfer = false, NewAmount = PhoneData.PlayerData.money.bank })
    end

    if type(data) ~= "table" or type(data.iban) ~= "string" or not tonumber(data.amount) then
        return cb({ CanTransfer = false, NewAmount = PhoneData.PlayerData.money.bank })
    end

    local transferAmount = tonumber(data.amount)
    local targetIban = string.match(data.iban, "^%s*(.-)%s*$") 
    local currentBankBalance = tonumber(PhoneData.PlayerData.money.bank) or 0

    if transferAmount <= 0 or targetIban == "" then
        return cb({ CanTransfer = false, NewAmount = currentBankBalance })
    end

    if currentBankBalance < transferAmount then
        TMGCore.Functions.Notify("Transaction Declined: Insufficient funds.", "error")
        return cb({ CanTransfer = false, NewAmount = currentBankBalance })
    end

    bankTransferLock = true
    local newBalance = currentBankBalance - transferAmount
    
    TriggerServerEvent('tmg-phone:server:TransferMoney', targetIban, transferAmount)

    cb({
        CanTransfer = true,
        NewAmount = newBalance
    })

    SetTimeout(1500, function() bankTransferLock = false end)
end)

local transferVerifyLock = false

RegisterNUICallback('CanTransferMoney', function(data, cb)
    if transferVerifyLock then return cb({ TransferedMoney = false }) end

    if type(data) ~= "table" or type(data.sendTo) ~= "string" or not tonumber(data.amountOf) then
        return cb({ TransferedMoney = false })
    end

    local transferAmount = tonumber(data.amountOf)
    local targetIban = string.match(data.sendTo, "^%s*(.-)%s*$") 

    if transferAmount <= 0 or not targetIban or targetIban == "" then
        return cb({ TransferedMoney = false })
    end

    local player = TMGCore.Functions.GetPlayerData()
    if type(player) ~= "table" or type(player.money) ~= "table" or not tonumber(player.money.bank) then
        return cb({ TransferedMoney = false })
    end

    local currentBankBalance = tonumber(player.money.bank)
    if (currentBankBalance - transferAmount) < 0 then
        return cb({ TransferedMoney = false })
    end

    transferVerifyLock = true

    TMGCore.Functions.TriggerCallback('tmg-phone:server:CanTransferMoney', function(isAuthorized)
        if isAuthorized == true then
            cb({ 
                TransferedMoney = true, 
                NewBalance = (currentBankBalance - transferAmount) 
            })
        else
            SendNUIMessage({ 
                action = 'PhoneNotification', 
                PhoneNotify = { 
                    timeout = 3000, 
                    title = 'Bank', 
                    text = 'Transaction Declined: Account does not exist.', 
                    icon = 'fas fa-university', 
                    color = '#E74C3C', 
                } 
            })
            cb({ TransferedMoney = false })
        end
    end, transferAmount, targetIban)

    SetTimeout(1000, function() transferVerifyLock = false end)
end)

local whatsappSyncLock = false

RegisterNUICallback('GetWhatsappChats', function(_, cb)
    if whatsappSyncLock then return cb({}) end
    if type(PhoneData.Chats) ~= "table" then return cb({}) end

    whatsappSyncLock = true
    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetContactPictures', function(hydratedChats)
        cb(type(hydratedChats) == "table" and hydratedChats or {})
    end, PhoneData.Chats)

    SetTimeout(2000, function() whatsappSyncLock = false end)
end)

local outboundCallLock = false

RegisterNUICallback('CallContact', function(data, cb)
    if outboundCallLock then
        return cb({ CanCall = false, IsOnline = false, InCall = true })
    end

    if type(data) ~= "table" or type(data.ContactData) ~= "table" or type(data.ContactData.number) ~= "string" then
        return cb({ CanCall = false, IsOnline = false, InCall = false })
    end

    if type(PhoneData) ~= "table" or 
       type(PhoneData.CallData) ~= "table" or 
       type(PhoneData.PlayerData) ~= "table" or 
       type(PhoneData.PlayerData.charinfo) ~= "table" then
        return cb({ CanCall = false, IsOnline = false, InCall = false })
    end

    local targetNumber = string.match(data.ContactData.number, "^%s*(.-)%s*$")
    local myNumber = PhoneData.PlayerData.charinfo.phone

    if not targetNumber or targetNumber == "" then
        return cb({ CanCall = false, IsOnline = false, InCall = false })
    end

    outboundCallLock = true

    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetCallState', function(canCall, isOnline)
        local targetAvailable = (canCall == true)
        local targetOnline = (isOnline == true)
        local currentCallState = (PhoneData.CallData.InCall == true)

        cb({
            CanCall = targetAvailable,
            IsOnline = targetOnline,
            InCall = currentCallState,
        })

        if targetAvailable and not currentCallState and (targetNumber ~= myNumber) then
            CallContact(data.ContactData, data.Anonymous == true)
        end
    end, data.ContactData)

    SetTimeout(2500, function() outboundCallLock = false end)
end)

local sendMessageLock = false

RegisterNUICallback('SendMessage', function(data, cb)
    if sendMessageLock then return cb('error') end

    if type(data) ~= "table" or type(data.ChatNumber) ~= "string" or type(data.ChatType) ~= "string" then
        return cb('error')
    end

    if type(PhoneData) ~= "table" or type(PhoneData.PlayerData) ~= "table" then
        return cb('error')
    end

    sendMessageLock = true

    local chatNumber = data.ChatNumber
    local chatType = data.ChatType
    local chatDate = type(data.ChatDate) == "string" and data.ChatDate or "Unknown Date"
    local chatTime = type(data.ChatTime) == "string" and data.ChatTime or "00:00"
    local citizenId = PhoneData.PlayerData.citizenid

    local newMessage = {
        message = type(data.ChatMessage) == "string" and data.ChatMessage or "",
        time = chatTime,
        sender = citizenId,
        type = chatType,
        data = {}
    }

    if chatType == 'location' then
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        newMessage.message = 'Shared Location'
        newMessage.data = { x = pos.x, y = pos.y }
    elseif chatType == 'picture' then
        newMessage.message = 'Photo'
        newMessage.data = { url = type(data.url) == "string" and data.url or "" }
    end

    PhoneData.Chats = type(PhoneData.Chats) == "table" and PhoneData.Chats or {}
    local numberKey = GetKeyByNumber(chatNumber)
    local isNewChat = false

    if not numberKey or type(PhoneData.Chats[numberKey]) ~= "table" then
        table.insert(PhoneData.Chats, {
            name = IsNumberInContacts(chatNumber),
            number = chatNumber,
            messages = {}
        })
        numberKey = GetKeyByNumber(chatNumber)
        isNewChat = true
    end

    local chatThread = PhoneData.Chats[numberKey]
    chatThread.messages = type(chatThread.messages) == "table" and chatThread.messages or {}
    local chatKey = GetKeyByDate(numberKey, chatDate)

    if not chatKey or type(chatThread.messages[chatKey]) ~= "table" then
        table.insert(chatThread.messages, {
            date = chatDate,
            messages = {}
        })
        chatKey = GetKeyByDate(numberKey, chatDate)
    end

    local messageArray = chatThread.messages[chatKey].messages
    chatThread.messages[chatKey].messages = type(messageArray) == "table" and messageArray or {}

    table.insert(chatThread.messages[chatKey].messages, newMessage)

    TriggerServerEvent('tmg-phone:server:UpdateMessages', chatThread.messages, chatNumber, isNewChat)
    ReorganizeChats(numberKey)

    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetContactPicture', function(hydratedChat)
        SendNUIMessage({
            action = 'UpdateChat',
            chatData = type(hydratedChat) == "table" and hydratedChat or chatThread,
            chatNumber = chatNumber,
        })
    end, PhoneData.Chats[GetKeyByNumber(chatNumber)])

    SetTimeout(500, function() sendMessageLock = false end)
    cb('ok')
end)

local photoCaptureLock = false

local function SaveToInternalGallery(cb)
    if photoCaptureLock then 
        if cb then cb(false, "Camera hardware is busy.") end
        return 
    end

    photoCaptureLock = true

    CreateThread(function()
        BeginTakeHighQualityPhoto()

        local timeout = 0
        local engineStatus = GetStatusOfTakeHighQualityPhoto()

        while engineStatus == 1 and timeout < 50 do
            Wait(100)
            engineStatus = GetStatusOfTakeHighQualityPhoto()
            timeout = timeout + 1
        end

        if engineStatus == 0 then
            SaveHighQualityPhoto(0)
            if cb then cb(true, "Photo captured successfully.") end
        else
            if cb then cb(false, "Hardware error: Failed to capture photo.") end
        end

        FreeMemoryForHighQualityPhoto()
        SetTimeout(1000, function() photoCaptureLock = false end)
    end)
end

local cameraActiveLock = false

RegisterNUICallback('TakePhoto', function(_, cb)
    if cameraActiveLock then 
        return cb(json.encode({ url = nil })) 
    end

    cameraActiveLock = true

    SetNuiFocus(false, false)
    CreateMobilePhone(1)
    CellCamActivate(true, true)

    local takePhoto = true
    local frontCam = false

    CreateThread(function()
        while takePhoto do
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(8)
            HideHudComponentThisFrame(9)
            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(19)
            HideHudAndRadarThisFrame()
            EnableAllControlActions(0)

            if IsControlJustPressed(1, 27) then 
                frontCam = not frontCam
                CellFrontCamActivate(frontCam)

            elseif IsControlJustPressed(1, 177) then 
                takePhoto = false
                DestroyMobilePhone()
                CellCamActivate(false, false)
                cb(json.encode({ url = nil }))
                cameraActiveLock = false
                Wait(500)
                OpenPhone()

            elseif IsControlJustPressed(1, 176) then 
                takePhoto = false 
                DestroyMobilePhone()
                CellCamActivate(false, false)
                ProcessNetworkUpload(cb)
            end
            
            Wait(0)
        end
    end)
end)

function ProcessNetworkUpload(cb)
    if Config.Fivemerr == true then
        TMGCore.Functions.TriggerCallback('tmg-phone:server:UploadToFivemerr', function(fivemerrData)
            if not fivemerrData then
                TMGCore.Functions.Notify("Upload Error: Server rejected the payload.", "error")
                return SafeCameraCleanup(cb)
            end

            SaveToInternalGallery(function() end)

            local success, imageData = pcall(json.decode, fivemerrData)
            if not success or type(imageData) ~= "table" or not imageData.url then
                TMGCore.Functions.Notify("Upload Error: Corrupted telemetry data.", "error")
                return SafeCameraCleanup(cb)
            end

            FinalizePhotoSuccess(imageData.url, cb)
        end)
        return
    end

    TMGCore.Functions.TriggerCallback('tmg-phone:server:GetWebhook', function(hook)
        if type(hook) ~= "string" or hook == "" then
            TMGCore.Functions.Notify('Camera Offline: Missing network webhook.', 'error')
            return SafeCameraCleanup(cb)
        end

        if GetResourceState('screenshot-basic') ~= 'started' then
            print("^1[TMG Error]^7 Camera pipeline failed: screenshot-basic is offline.")
            return SafeCameraCleanup(cb)
        end

        exports['screenshot-basic']:requestScreenshotUpload(hook, 'files[]', function(data)
            SaveToInternalGallery(function() end)

            local success, image = pcall(json.decode, data)
            if not success or type(image) ~= "table" or not image.attachments or not image.attachments[1] then
                TMGCore.Functions.Notify("Upload Error: Corrupted Discord response.", "error")
                return SafeCameraCleanup(cb)
            end

            FinalizePhotoSuccess(image.attachments[1].proxy_url, cb)
        end)
    end)
end

function SafeCameraCleanup(cb)
    cb(json.encode({ url = nil }))
    cameraActiveLock = false
    Wait(500)
    OpenPhone()
end

function FinalizePhotoSuccess(url, cb)
    TriggerServerEvent('tmg-phone:server:addImageToGallery', url)
    
    SetTimeout(500, function()
        TriggerServerEvent('tmg-phone:server:getImageFromGallery')
    end)

    cb(json.encode(url))
    cameraActiveLock = false
    Wait(500)
    OpenPhone()
end

local pingCommandLock = false

RegisterCommand('ping', function(_, args)
    if pingCommandLock then
        TMGCore.Functions.Notify('Network busy: Ping system is cooling down.', 'error')
        return
    end

    if type(args) ~= "table" or not args[1] then
        TMGCore.Functions.Notify('Syntax Error: /ping [Player ID]', 'error')
        return
    end

    local targetId = tonumber(args[1])

    if not targetId or targetId <= 0 or targetId ~= math.floor(targetId) then
        TMGCore.Functions.Notify('System Error: Target ID must be a valid positive integer.', 'error')
        return
    end

    local myServerId = GetPlayerServerId(PlayerId())
    if targetId == myServerId then
        TMGCore.Functions.Notify('System Error: You cannot ping your own device.', 'error')
        return
    end

    pingCommandLock = true
    TriggerServerEvent('tmg-phone:server:sendPing', targetId)
    TMGCore.Functions.Notify('Location ping dispatched to Server ID: ' .. targetId, 'success')

    SetTimeout(5000, function()
        pingCommandLock = false
    end)
end, false)

RegisterNetEvent('tmg-phone:client:ReceivePing', function(senderData)
    if type(senderData) ~= "table" then return end
    
    local safeName = (type(senderData.name) == "string" and senderData.name ~= "") and senderData.name or "A Player"
    
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'GPS Signal Received',
            text = safeName .. ' shared their location with you.',
            icon = 'fas fa-map-marker-alt',
            color = '#3498db',
            timeout = 5000,
        },
    })
    
    if type(senderData.coords) == "table" and senderData.coords.x and senderData.coords.y then
        SetNewWaypoint(senderData.coords.x + 0.0, senderData.coords.y + 0.0)
    end
end)

RegisterNetEvent('tmg-phone:client:CallContactError', function()
    CancelCall()
    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Phone',
            text = 'Subscriber unavailable or offline.',
            icon = 'fas fa-phone-slash',
            color = '#e84118',
            timeout = 3000,
        },
    })
end)

RegisterNetEvent('TMGCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        local PlayerData = TMGCore.Functions.GetPlayerData()
        local attempts = 0
        local maxAttempts = 15
        
        while (not PlayerData or type(PlayerData.metadata) ~= "table") and attempts < maxAttempts do
            attempts = attempts + 1
            Wait(1000) 
            PlayerData = TMGCore.Functions.GetPlayerData()
        end

        if type(PlayerData) == "table" and type(PlayerData.metadata) == "table" then 
            TriggerServerEvent('tmg-phone:server:GetPhoneData')
            print("^2[TMG System]^7 Cellular Interface Synchronized.")
        else
            print("^1[TMG Error]^7 Cellular boot aborted. BSON metadata failed to synchronize.")
        end
    end)
end)

RegisterNetEvent('TMGCore:Client:OnPlayerUnload', function()
    SetNuiFocus(false, false)
    DestroyMobilePhone()
    CellCamActivate(false, false)

    SendNUIMessage({
        action = "PhoneNotification",
        PhoneNotify = { timeout = 100, text = "Session Terminated", color = "#ff0000" }
    })

    if type(PhoneData) == "table" then
        for k, _ in pairs(PhoneData) do
            PhoneData[k] = nil
        end
    else
        PhoneData = {}
    end

    PhoneData.MetaData = {}
    PhoneData.isOpen = false
    PhoneData.PlayerData = nil
    PhoneData.Contacts = {}
    PhoneData.Tweets = {}
    PhoneData.MentionedTweets = {}
    PhoneData.Hashtags = {}
    PhoneData.Chats = {}
    PhoneData.CallData = {}
    PhoneData.RecentCalls = {}
    PhoneData.Garage = {}
    PhoneData.Mails = {}
    PhoneData.Adverts = {}
    PhoneData.GarageVehicles = {}
    PhoneData.AnimationData = { lib = nil, anim = nil }
    PhoneData.SuggestedContacts = {}
    PhoneData.CryptoTransactions = {}

    ReleaseAllMainframeLocks()
end)

function ReleaseAllMainframeLocks()
    vehicleSearchLock = false
    vehicleScanLock = false
    listedRacesLock = false
    trackDataLock = false
    raceSetupLock = false
    creatorCheckLock = false
    raceStatusLock = false
    raceAuthLock = false
    editorLock = false
    leaderboardLock = false
    raceDistanceLock = false
    busyCheckLock = false
    setupAuthLock = false
    propertiesLock = false
    keysLock = false
    houseLocationLock = false
    removeKeyholderLock = false
    propertyTransferLock = false
    meosSearchLock = false
    gpsRoutingLock = false
    lawyerSyncLock = false
    storeSetupLock = false
    alertClearLock = false
    generalAlertLock = false
    bankTransferLock = false
    transferVerifyLock = false
    whatsappSyncLock = false
    outboundCallLock = false
    sendMessageLock = false
    photoCaptureLock = false
    pingCommandLock = false
    cameraActiveLock = false
end

RegisterNetEvent('TMGCore:Client:OnJobUpdate', function(JobInfo)
    if type(JobInfo) ~= "table" or type(JobInfo.name) ~= "string" then return end

    local appMatrix = (type(Config) == "table" and type(Config.PhoneApplications) == "table") 
                      and Config.PhoneApplications 
                      or {}

    PlayerJob = JobInfo

    SendNUIMessage({
        action = 'UpdateApplications',
        JobData = PlayerJob,
        applications = appMatrix
    })
end)

RegisterNetEvent('tmg-phone:client:TransferMoney', function(amount, newBalance)
    SendNUIMessage({
        action = "UpdateBank",
        NewBalance = newBalance
    })
    TMGCore.Functions.Notify("Received $" .. amount .. " via bank transfer.", "success")
end)

RegisterNetEvent('tmg-phone:client:UpdateTweetsDel', function(senderSource, newTweetsMatrix)
    if type(senderSource) ~= "number" or type(newTweetsMatrix) ~= "table" then return end

    if type(PhoneData) ~= "table" then PhoneData = {} end
    PhoneData.Tweets = newTweetsMatrix

    local myServerId = GetPlayerServerId(PlayerId())
    if senderSource ~= myServerId then
        SendNUIMessage({
            action = "UpdateTweets",
            Tweets = PhoneData.Tweets
        })
    end
end)

RegisterNetEvent('tmg-phone:client:UpdateTweets', function(senderSource, newTweetsMatrix, newTweetData, isDeleted)
    if type(senderSource) ~= "number" or type(newTweetsMatrix) ~= "table" then return end

    if type(PhoneData) ~= "table" then PhoneData = {} end
    PhoneData.Tweets = newTweetsMatrix

    local myServerId = GetPlayerServerId(PlayerId())

    if isDeleted == true then
        if senderSource == myServerId then
            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    title = 'Twitter',
                    text = 'The Tweet has been deleted!',
                    icon = 'fab fa-twitter',
                    color = '#1DA1F2',
                    timeout = 1000,
                },
            })
        end

        SendNUIMessage({
            action = 'UpdateTweets',
            Tweets = PhoneData.Tweets
        })
    else
        if senderSource ~= myServerId then
            local fName = (type(newTweetData) == "table" and type(newTweetData.firstName) == "string") and newTweetData.firstName or "Unknown"
            local lName = (type(newTweetData) == "table" and type(newTweetData.lastName) == "string") and newTweetData.lastName or "User"

            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    title = string.format('New Tweet (@%s %s)', fName, lName),
                    text = 'A new tweet has been posted.',
                    icon = 'fab fa-twitter',
                    color = '#1DA1F2',
                },
            })

            SendNUIMessage({
                action = 'UpdateTweets',
                Tweets = PhoneData.Tweets
            })
        else
            SendNUIMessage({
                action = 'PhoneNotification',
                PhoneNotify = {
                    title = 'Twitter',
                    text = 'The Tweet has been posted!',
                    icon = 'fab fa-twitter',
                    color = '#1DA1F2',
                    timeout = 1000,
                },
            })
        end
    end
end)

RegisterNetEvent('tmg-phone:client:RaceNotify', function(message)
    local safeMessage = type(message) == "string" and message or "System Notice: Racing telemetry updated."

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Racing',
            text = safeMessage,
            icon = 'fas fa-flag-checkered',
            color = '#353b48',
            timeout = 3500,
        },
    })
end)

RegisterNetEvent('tmg-phone:client:AddRecentCall', function(callData, callTime, callDirection)
    if type(callData) ~= "table" or type(callData.number) ~= "string" then return end

    if type(PhoneData) ~= "table" then PhoneData = {} end
    if type(PhoneData.RecentCalls) ~= "table" then PhoneData.RecentCalls = {} end

    local safeNumber = string.match(callData.number, "^%s*(.-)%s*$")
    local safeTime = type(callTime) == "string" and callTime or "Unknown"
    local safeDirection = type(callDirection) == "string" and callDirection or "unknown"
    local isAnonymous = (callData.anonymous == true) 

    table.insert(PhoneData.RecentCalls, {
        name = IsNumberInContacts(safeNumber),
        time = safeTime,
        type = safeDirection,
        number = safeNumber,
        anonymous = isAnonymous
    })

    if type(Config) == "table" and type(Config.PhoneApplications) == "table" and type(Config.PhoneApplications['phone']) == "table" then
        local currentAlerts = tonumber(Config.PhoneApplications['phone'].Alerts) or 0
        Config.PhoneApplications['phone'].Alerts = currentAlerts + 1

        TriggerServerEvent('tmg-phone:server:SetPhoneAlerts', 'phone')

        SendNUIMessage({
            action = 'RefreshAppAlerts',
            AppData = Config.PhoneApplications
        })
    end
end)

RegisterNetEvent('tmg-phone-new:client:BankNotify', function(text)
    local safeText = type(text) == "string" and text or "System Notice: Financial transaction processed."

    SendNUIMessage({
        action = 'PhoneNotification',
        NotifyData = {
            title = 'Bank',
            content = safeText,
            icon = 'fas fa-university',
            timeout = 3500,
            color = '#ff002f',
        },
    })
end)

RegisterNetEvent('tmg-phone:client:NewMailNotify', function(MailData)
    if type(MailData) ~= "table" then return end

    local safeSender = (type(MailData.sender) == "string" and MailData.sender ~= "") and MailData.sender or "Unknown Sender"

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Mail',
            text = string.format('You received a new mail from %s', safeSender),
            icon = 'fas fa-envelope',
            color = '#ff002f',
            timeout = 1500,
        },
    })

    if type(Config) == "table" and type(Config.PhoneApplications) == "table" and type(Config.PhoneApplications['mail']) == "table" then
        local currentAlerts = tonumber(Config.PhoneApplications['mail'].Alerts) or 0
        Config.PhoneApplications['mail'].Alerts = currentAlerts + 1

        TriggerServerEvent('tmg-phone:server:SetPhoneAlerts', 'mail')

        SendNUIMessage({
            action = 'RefreshAppAlerts',
            AppData = Config.PhoneApplications
        })
    end
end)

RegisterNetEvent('tmg-phone:client:UpdateMails', function(NewMails)
    if type(NewMails) ~= "table" then return end
    if type(PhoneData) ~= "table" then PhoneData = {} end

    PhoneData.Mails = NewMails

    SendNUIMessage({
        action = 'UpdateMails',
        Mails = PhoneData.Mails
    })
end)

RegisterNetEvent('tmg-phone:client:UpdateAdvertsDel', function(AdvertsMatrix)
    if type(AdvertsMatrix) ~= "table" then return end
    if type(PhoneData) ~= "table" then PhoneData = {} end

    PhoneData.Adverts = AdvertsMatrix

    SendNUIMessage({
        action = 'RefreshAdverts',
        Adverts = PhoneData.Adverts
    })
end)

RegisterNetEvent('tmg-phone:client:UpdateAdverts', function(AdvertsMatrix, LastAdPublisher)
    if type(AdvertsMatrix) ~= "table" then return end
    if type(PhoneData) ~= "table" then PhoneData = {} end

    local safePublisher = (type(LastAdPublisher) == "string" and LastAdPublisher ~= "") and LastAdPublisher or "an anonymous user"
    PhoneData.Adverts = AdvertsMatrix

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Advertisement',
            text = string.format('A new ad has been posted by %s', safePublisher),
            icon = 'fas fa-ad',
            color = '#ff8f1a',
            timeout = 2500,
        },
    })

    SendNUIMessage({
        action = 'RefreshAdverts',
        Adverts = PhoneData.Adverts
    })
end)

RegisterNetEvent('tmg-phone:client:BillingEmail', function(data, isPaid, payerName)
    if type(data) ~= "table" then return end

    local safeName = (type(payerName) == "string" and payerName ~= "") and payerName or "an unknown citizen"
    local safeAmount = tonumber(data.amount) or 0
    local invoiceStatus = (isPaid == true) and "Paid" or "Declined"

    local emailSubject = string.format("Invoice %s", invoiceStatus)
    local emailMessage = string.format("Invoice has been %s by %s in the amount of $%s", string.lower(invoiceStatus), safeName, safeAmount)

    TriggerServerEvent('tmg-phone:server:sendNewMail', {
        sender = 'Billing Department',
        subject = emailSubject,
        message = emailMessage,
    })
end)

RegisterNetEvent('tmg-phone:client:CancelCall', function()
    if type(PhoneData) ~= "table" then PhoneData = {} end
    if type(PhoneData.CallData) ~= "table" then PhoneData.CallData = {} end
    if type(PhoneData.AnimationData) ~= "table" then PhoneData.AnimationData = {} end

    if PhoneData.CallData.CallType == 'ongoing' then
        SendNUIMessage({ action = 'CancelOngoingCall' })
        
        if GetResourceState('pma-voice') == 'started' then
            local callId = tonumber(PhoneData.CallData.CallId)
            if callId then exports['pma-voice']:removePlayerFromCall(callId) end
        end
    end

    PhoneData.CallData.CallType = nil
    PhoneData.CallData.InCall = false
    PhoneData.CallData.AnsweredCall = false
    PhoneData.CallData.TargetData = {}

    if not PhoneData.isOpen then
        if PhoneData.AnimationData.lib and PhoneData.AnimationData.anim then
            StopAnimTask(PlayerPedId(), PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 2.5)
        end
        deletePhone()
    end

    PhoneData.AnimationData.lib = nil
    PhoneData.AnimationData.anim = nil

    TriggerServerEvent('tmg-phone:server:SetCallState', false)

    local notificationMatrix = {
        title = 'Phone',
        text = 'The call has been ended',
        icon = 'fas fa-phone',
        color = '#e84118',
        timeout = 3500,
    }

    SendNUIMessage({
        action = 'PhoneNotification',
        NotifyData = notificationMatrix,
        PhoneNotify = notificationMatrix 
    })

    if PhoneData.isOpen then
        SendNUIMessage({ action = 'SetupHomeCall', CallData = PhoneData.CallData })
        SendNUIMessage({ action = 'CancelOutgoingCall' })
    end
end)

RegisterNetEvent('tmg-phone:client:GetCalled', function(CallerNumber, CallId, AnonymousCall)
    if type(CallerNumber) ~= "string" or not CallId then return end

    if type(PhoneData) ~= "table" then PhoneData = {} end
    if type(PhoneData.CallData) ~= "table" then PhoneData.CallData = {} end

    if PhoneData.CallData.InCall then return end

    local isAnonymous = (AnonymousCall == true)
    local safeName = isAnonymous and "Anonymous" or IsNumberInContacts(CallerNumber)

    local CallData = {
        number = CallerNumber,
        name = safeName,
        anonymous = isAnonymous
    }
    PhoneData.CallData.CallType = 'incoming'
    PhoneData.CallData.InCall = true
    PhoneData.CallData.AnsweredCall = false
    PhoneData.CallData.TargetData = CallData
    PhoneData.CallData.CallId = CallId

    TriggerServerEvent('tmg-phone:server:SetCallState', true)

    SendNUIMessage({
        action = 'SetupHomeCall',
        CallData = PhoneData.CallData,
    })

    local maxRings = (type(Config) == "table" and tonumber(Config.CallRepeats)) or 10
    local ringTimeout = (type(Config) == "table" and tonumber(Config.RepeatTimeout)) or 3000

    CreateThread(function()
        local currentRing = 0

        while PhoneData.CallData.InCall and not PhoneData.CallData.AnsweredCall and currentRing < maxRings do
            local callbackResolved = false
            local hasPhoneResult = false

            TMGCore.Functions.TriggerCallback('tmg-phone:server:HasPhone', function(HasPhone)
                hasPhoneResult = (HasPhone == true)
                callbackResolved = true
            end)

            while not callbackResolved do Wait(10) end

            if hasPhoneResult then
                if PhoneData.CallData.InCall and not PhoneData.CallData.AnsweredCall then
                    currentRing = currentRing + 1
                    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'ringing', 0.2)

                    if not PhoneData.isOpen then
                        SendNUIMessage({
                            action = 'IncomingCallAlert',
                            CallData = PhoneData.CallData.TargetData,
                            Canceled = false,
                            AnonymousCall = isAnonymous,
                        })
                    end
                end
            else
                break
            end

            Wait(ringTimeout)
        end

        if not PhoneData.CallData.AnsweredCall then
            SendNUIMessage({
                action = 'IncomingCallAlert',
                CallData = PhoneData.CallData.TargetData,
                Canceled = true,
                AnonymousCall = isAnonymous,
            })
            TriggerServerEvent('tmg-phone:server:AddRecentCall', 'missed', CallData)
        end
    end)
end)

RegisterNetEvent('tmg-phone:client:UpdateMessages', function(ChatMessages, SenderNumber, _)
    if type(ChatMessages) ~= "table" or type(SenderNumber) ~= "string" then return end

    if type(PhoneData) ~= "table" then PhoneData = {} end
    if type(PhoneData.Chats) ~= "table" then PhoneData.Chats = {} end

    local numberKey = GetKeyByNumber(SenderNumber)

    if not numberKey or type(PhoneData.Chats[numberKey]) ~= "table" then
        table.insert(PhoneData.Chats, {
            name = IsNumberInContacts(SenderNumber) or SenderNumber,
            number = SenderNumber,
            messages = {},
            Unread = 0
        })
        numberKey = GetKeyByNumber(SenderNumber)
    end

    local activeChat = PhoneData.Chats[numberKey]
    activeChat.messages = ChatMessages
    activeChat.Unread = (tonumber(activeChat.Unread) or 0) + 1

    local contactName = IsNumberInContacts(SenderNumber)
    local safeName = (type(contactName) == "string" and contactName ~= "") and contactName or SenderNumber
    
    local myNumber = (type(PhoneData.PlayerData) == "table" and type(PhoneData.PlayerData.charinfo) == "table") 
                     and PhoneData.PlayerData.charinfo.phone 
                     or "UNKNOWN_NUMBER"

    local isSelfMessage = (SenderNumber == myNumber)
    local notifText = isSelfMessage and 'Messaged yourself' or string.format('New message from %s!', safeName)
    local notifTimeout = isSelfMessage and 4000 or (PhoneData.isOpen and 1500 or 3500)

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Whatsapp',
            text = notifText,
            icon = 'fab fa-whatsapp',
            color = '#25D366',
            timeout = notifTimeout,
        },
    })

    ReorganizeChats(numberKey)

    if PhoneData.isOpen then
        CreateThread(function()
            Wait(100)
            TMGCore.Functions.TriggerCallback('tmg-phone:server:GetContactPictures', function(ChatsMatrix)
                if type(ChatsMatrix) == "table" then
                    SendNUIMessage({
                        action = 'UpdateChat',
                        chatData = ChatsMatrix[GetKeyByNumber(SenderNumber)],
                        chatNumber = SenderNumber,
                        Chats = ChatsMatrix,
                    })
                end
            end, PhoneData.Chats)
        end)
    else
        if type(Config) == "table" and type(Config.PhoneApplications) == "table" and type(Config.PhoneApplications['whatsapp']) == "table" then
            local currentAlerts = tonumber(Config.PhoneApplications['whatsapp'].Alerts) or 0
            Config.PhoneApplications['whatsapp'].Alerts = currentAlerts + 1

            TriggerServerEvent('tmg-phone:server:SetPhoneAlerts', 'whatsapp')

            SendNUIMessage({
                action = 'RefreshAppAlerts',
                AppData = Config.PhoneApplications
            })
        end
    end
end)

RegisterNetEvent('tmg-phone:client:RemoveBankMoney', function(amount)
    local transferAmount = tonumber(amount)
    if not transferAmount or transferAmount <= 0 then return end

    local formattedAmount = string.format("%d", transferAmount)
    local notificationText = string.format("$%s has been removed from your balance!", formattedAmount)

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Bank',
            text = notificationText,
            icon = 'fas fa-university',
            color = '#ff002f',
            timeout = 3500,
        },
    })
end)

local refreshPhoneLock = false

RegisterNetEvent('tmg-phone:RefreshPhone', function()
    if refreshPhoneLock then return end

    refreshPhoneLock = true
    LoadPhone()

    CreateThread(function()
        Wait(250)
        local safeAppMatrix = (type(Config) == "table" and type(Config.PhoneApplications) == "table") 
                              and Config.PhoneApplications 
                              or {}

        SendNUIMessage({
            action = 'RefreshAlerts',
            AppData = safeAppMatrix,
        })

        SetTimeout(2000, function() refreshPhoneLock = false end)
    end)
end)

RegisterNetEvent('tmg-phone:client:AddTransaction', function(_, _, Message, Title)
    local safeTitle = (type(Title) == "string" and Title ~= "") and Title or "System Notice"
    local safeMessage = (type(Message) == "string" and Message ~= "") and Message or "Cryptocurrency transaction processed."

    local transactionMatrix = {
        TransactionTitle = safeTitle,
        TransactionMessage = safeMessage,
    }

    if type(PhoneData) ~= "table" then PhoneData = {} end
    if type(PhoneData.CryptoTransactions) ~= "table" then PhoneData.CryptoTransactions = {} end

    table.insert(PhoneData.CryptoTransactions, transactionMatrix)

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Crypto',
            text = safeMessage,
            icon = 'fas fa-chart-pie',
            color = '#04b543',
            timeout = 1500,
        },
    })

    SendNUIMessage({
        action = 'UpdateTransactions',
        CryptoTransactions = PhoneData.CryptoTransactions
    })

    TriggerServerEvent('tmg-phone:server:AddTransaction', transactionMatrix)
end)

RegisterNetEvent('tmg-phone:client:AddNewSuggestion', function(SuggestionData)
    if type(SuggestionData) ~= "table" then return end

    if type(PhoneData) ~= "table" then PhoneData = {} end
    if type(PhoneData.SuggestedContacts) ~= "table" then PhoneData.SuggestedContacts = {} end

    table.insert(PhoneData.SuggestedContacts, SuggestionData)

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = 'Phone',
            text = 'You have a new suggested contact!',
            icon = 'fa fa-phone-alt',
            color = '#04b543',
            timeout = 1500,
        },
    })

    if type(Config) == "table" and type(Config.PhoneApplications) == "table" and type(Config.PhoneApplications['phone']) == "table" then
        local currentAlerts = tonumber(Config.PhoneApplications['phone'].Alerts) or 0
        Config.PhoneApplications['phone'].Alerts = currentAlerts + 1

        TriggerServerEvent('tmg-phone:server:SetPhoneAlerts', 'phone', Config.PhoneApplications['phone'].Alerts)

        SendNUIMessage({
            action = 'RefreshAppAlerts',
            AppData = Config.PhoneApplications
        })
    end
end)

RegisterNetEvent('tmg-phone:client:UpdateHashtags', function(Handle, msgData)
    if type(Handle) ~= "string" or Handle == "" or type(msgData) ~= "table" then return end

    if type(PhoneData) ~= "table" then PhoneData = {} end
    if type(PhoneData.Hashtags) ~= "table" then PhoneData.Hashtags = {} end

    if type(PhoneData.Hashtags[Handle]) ~= "table" then
        PhoneData.Hashtags[Handle] = {
            hashtag = Handle,
            messages = {}
        }
    end

    table.insert(PhoneData.Hashtags[Handle].messages, msgData)

    SendNUIMessage({
        action = 'UpdateHashtags',
        Hashtags = PhoneData.Hashtags,
    })
end)

RegisterNetEvent('tmg-phone:client:AnswerCall', function()
    if type(PhoneData) ~= "table" then PhoneData = {} end
    if type(PhoneData.CallData) ~= "table" then PhoneData.CallData = {} end

    local callData = PhoneData.CallData

    if (callData.CallType == 'incoming' or callData.CallType == 'outgoing') and callData.InCall and not callData.AnsweredCall then
        callData.CallType = 'ongoing'
        callData.AnsweredCall = true
        callData.CallTime = 0

        SendNUIMessage({ action = 'AnswerCall', CallData = callData })
        SendNUIMessage({ action = 'SetupHomeCall', CallData = callData })

        TriggerServerEvent('tmg-phone:server:SetCallState', true)

        if PhoneData.isOpen then
            DoPhoneAnimation('cellphone_text_to_call')
        else
            DoPhoneAnimation('cellphone_call_listen_base')
        end

        if GetResourceState('pma-voice') == 'started' then
            local callId = tonumber(callData.CallId)
            if callId then exports['pma-voice']:addPlayerToCall(callId) end
        end

        CreateThread(function()
            while PhoneData.CallData.AnsweredCall do
                PhoneData.CallData.CallTime = PhoneData.CallData.CallTime + 1
                local safeName = (type(PhoneData.CallData.TargetData) == "table" and type(PhoneData.CallData.TargetData.name) == "string") 
                                 and PhoneData.CallData.TargetData.name 
                                 or "Unknown Caller"

                SendNUIMessage({
                    action = 'UpdateCallTime',
                    Time = PhoneData.CallData.CallTime,
                    Name = safeName,
                })
                Wait(1000)
            end
        end)
    else
        callData.InCall = false
        callData.CallType = nil
        callData.AnsweredCall = false

        SendNUIMessage({
            action = 'PhoneNotification',
            PhoneNotify = {
                title = 'Phone',
                text = "You don't have an incoming call.",
                icon = 'fas fa-phone',
                color = '#e84118',
                timeout = 2500,
            },
        })
    end
end)

RegisterNetEvent('tmg-phone:client:addPoliceAlert', function(alertMatrix)
    if type(alertMatrix) ~= "table" then return end
    local playerData = TMGCore.Functions.GetPlayerData()

    if type(playerData) ~= "table" or type(playerData.job) ~= "table" then return end
    local localJobState = playerData.job

    if localJobState.name == 'police' and localJobState.onduty == true then
        SendNUIMessage({
            action = 'AddPoliceAlert',
            alert = alertMatrix,
        })
    end
end)

local contactShareLock = false

RegisterNetEvent('tmg-phone:client:GiveContactDetails', function()
    if contactShareLock then
        TMGCore.Functions.Notify('Hardware busy: NFC transfer is cooling down.', 'error')
        return
    end

    local player, distance = TMGCore.Functions.GetClosestPlayer()
    if player == -1 or distance == -1 or distance > 2.5 then
        TMGCore.Functions.Notify('Transfer failed: No compatible devices in range.', 'error')
        return
    end

    local targetServerId = GetPlayerServerId(player)
    if not targetServerId or targetServerId <= 0 then return end

    contactShareLock = true
    TriggerServerEvent('tmg-phone:server:GiveContactDetails', targetServerId)
    TMGCore.Functions.Notify('NFC Transfer Initiated...', 'success')

    SetTimeout(3000, function() contactShareLock = false end)
end)

local lapRaceSyncLock = false

RegisterNetEvent('tmg-phone:client:UpdateLapraces', function()
    if lapRaceSyncLock then return end
    lapRaceSyncLock = true

    SendNUIMessage({ action = 'UpdateRacingApp' })
    SetTimeout(250, function() lapRaceSyncLock = false end)
end)

RegisterNetEvent('tmg-phone:client:GetMentioned', function(TweetMatrix, AppAlerts)
    if type(TweetMatrix) ~= "table" then return end

    if type(PhoneData) ~= "table" then PhoneData = {} end
    if type(PhoneData.MentionedTweets) ~= "table" then PhoneData.MentionedTweets = {} end

    local rawMessage = (type(TweetMatrix.message) == "string") and TweetMatrix.message or "Unknown interaction."
    local safeMessage = escape_str(rawMessage)

    local safeTweet = {
        firstName = (type(TweetMatrix.firstName) == "string") and TweetMatrix.firstName or "Unknown",
        lastName  = (type(TweetMatrix.lastName) == "string") and TweetMatrix.lastName  or "User",
        message   = safeMessage,
        time      = (type(TweetMatrix.time) == "string") and TweetMatrix.time or "Just now",
        picture   = (type(TweetMatrix.picture) == "string") and TweetMatrix.picture or "default"
    }

    if type(Config) == "table" and type(Config.PhoneApplications) == "table" and type(Config.PhoneApplications['twitter']) == "table" then
        Config.PhoneApplications['twitter'].Alerts = tonumber(AppAlerts) or 1
        SendNUIMessage({ action = 'RefreshAppAlerts', AppData = Config.PhoneApplications })
    end

    table.insert(PhoneData.MentionedTweets, safeTweet)

    SendNUIMessage({ 
        action = 'PhoneNotification', 
        PhoneNotify = { 
            title = 'You have been mentioned in a Tweet!', 
            text = safeMessage, 
            icon = 'fab fa-twitter', 
            color = '#1DA1F2', 
            timeout = 2500,
        }, 
    })

    SendNUIMessage({ 
        action = 'UpdateMentionedTweets', 
        Tweets = PhoneData.MentionedTweets 
    })
end)

RegisterNetEvent('tmg-phone:refreshImages', function(imageMatrix)
    if type(imageMatrix) ~= "table" then return end
    if type(PhoneData) ~= "table" then PhoneData = {} end

    PhoneData.Images = imageMatrix

    SendNUIMessage({
        action = 'UpdateGallery', 
        Images = PhoneData.Images
    })
end)

RegisterNetEvent('tmg-phone:client:CustomNotification', function(title, text, icon, color, timeout)
    local safeTitle = (type(title) == "string" and title ~= "") and title or "System Notice"
    local safeText  = (type(text) == "string" and text ~= "") and text or "Incoming telemetry received."
    local safeIcon  = (type(icon) == "string" and icon ~= "") and icon or "fas fa-bell"
    local safeColor = (type(color) == "string" and color ~= "") and color or "#ffffff"
    local safeTimeout = tonumber(timeout) or 3500

    SendNUIMessage({
        action = 'PhoneNotification',
        PhoneNotify = {
            title = safeTitle,
            text = safeText,
            icon = safeIcon,
            color = safeColor,
            timeout = safeTimeout,
        },
    })
end)

CreateThread(function()
    while true do
        local threadSleep = 1000

        if type(PhoneData) == "table" and PhoneData.isOpen then
            local currentTime = CalculateTimeToDisplay()
            if currentTime then
                SendNUIMessage({
                    action = 'UpdateTime',
                    InGameTime = currentTime,
                })
            end
        else
            threadSleep = 2500 
        end

        Wait(threadSleep)
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        
        if LocalPlayer.state.isLoggedIn and type(PhoneData) == "table" then
            TMGCore.Functions.TriggerCallback('tmg-phone:server:GetPhoneData', function(pData)
                if type(pData) == "table" and type(pData.PlayerContacts) == "table" then
                    if next(pData.PlayerContacts) ~= nil then
                        PhoneData.Contacts = pData.PlayerContacts
                    end
                    
                    SendNUIMessage({
                        action = 'RefreshContacts',
                        Contacts = PhoneData.Contacts or {}
                    })
                end
            end)
        end
    end
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(500) end
    
    Wait(5000) 
    TMGCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData and PlayerData.metadata then
            print("^5[TMG]^7 Cellular matrix successfully anchored to Mainframe.")
            LoadPhone()
        end
    end)
end)