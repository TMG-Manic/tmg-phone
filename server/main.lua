local TMGCore = exports['tmg-core']:GetCoreObject()
local QBPhone = {}
local DatabaseReady = false

AddEventHandler('TMGNoSQL:DatabaseReady', function()
    DatabaseReady = true
    print("^5[TMG]^7 Phone -> NoSQL Voice Bridge Established.")
end)

local AppAlerts = {}
local MentionedTweets = {}
local Hashtags = {}


local Calls, Adverts, GeneratedPlates = {}, {}, {}
local TWData = {}

local function GetOnlineStatus(number)
    return TMGCore.Functions.GetPlayerByPhone(number) ~= nil
end

function QBPhone.AddMentionedTweet(citizenid, TweetData)
    local Player = TMGCore.Functions.GetPlayerByCitizenId(citizenid)
    
    if Player then
        local currentMentions = Player.PlayerData.metadata["phone_mentions"] or {}
        currentMentions[#currentMentions + 1] = TweetData
        Player.Functions.SetMetaData("phone_mentions", currentMentions)
        
        TriggerClientEvent('tmg-phone:client:GetMentioned', Player.PlayerData.source, TweetData)
    else
        exports['tmgnosql']:UpdateOne('players', 
            { citizenid = citizenid }, 
            { ["$push"] = { ["metadata.phone_mentions"] = TweetData } }
        )
    end
end

function QBPhone.SetPhoneAlerts(citizenid, app, alerts)
    if not citizenid or not app then return end
    
    local Player = TMGCore.Functions.GetPlayerByCitizenId(citizenid)
    local newAlertCount = alerts or 1

    if Player then
        local currentAlerts = Player.PlayerData.metadata["phone_alerts"] or {}
        
        if not alerts then
            currentAlerts[app] = (currentAlerts[app] or 0) + 1
        else
            currentAlerts[app] = alerts
        end

        Player.Functions.SetMetaData("phone_alerts", currentAlerts)
        TriggerClientEvent('tmg-phone:client:UpdateAlerts', Player.PlayerData.source, currentAlerts)
    else
        local updateQuery = alerts and { ["$set"] = { ["metadata.phone_alerts."..app] = alerts } } 
                            or { ["$inc"] = { ["metadata.phone_alerts."..app] = 1 } }
                            
        exports['tmgnosql']:UpdateOne('players', { citizenid = citizenid }, updateQuery)
    end
end


function QBPhone.SetPhoneAlerts(citizenid, app, alerts)
    if not citizenid or not app then return end

    local updateQuery = {}
    if alerts == nil then
        updateQuery = { ["$inc"] = { ["metadata.phone_alerts."..app] = 1 } }
    else
        updateQuery = { ["$set"] = { ["metadata.phone_alerts."..app] = alerts } }
    end

    exports['tmgnosql']:UpdateOne('players', { citizenid = citizenid }, updateQuery)

    local Player = TMGCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player then
        local currentAlerts = Player.PlayerData.metadata["phone_alerts"] or {}
        
        if alerts == nil then
            currentAlerts[app] = (currentAlerts[app] or 0) + 1
        else
            currentAlerts[app] = alerts
        end

        Player.Functions.SetMetaData("phone_alerts", currentAlerts)
        TriggerClientEvent('tmg-phone:client:UpdateAlerts', Player.PlayerData.source, currentAlerts)
    end
end


local function SplitStringToArray(str)
    if not str or type(str) ~= "string" then return {} end
    
    local retval = {}
    for i in string.gmatch(str, '%S+') do
        retval[#retval + 1] = i:gsub('[%c]', '') 
    end
    
    return retval
end




local npcNames = {
    { name = 'Bailey Sykes', citizenid = 'DSH091G93' },
    { name = 'Aroush Goodwin', citizenid = 'AVH09M193' },
    { name = 'Tom Warren', citizenid = 'DVH091T93' },
    { name = 'Abdallah Friedman', citizenid = 'GZP091G93' },
    { name = 'Lavinia Powell', citizenid = 'DRH09Z193' },
    { name = 'Andrew Delarosa', citizenid = 'KGV091J93' },
    { name = 'Skye Cardenas', citizenid = 'ODF09S193' },
    { name = 'Amelia-Mae Walter', citizenid = 'KSD0919H3' },
    { name = 'Elisha Cote', citizenid = 'NDX091D93' },
    { name = 'Janice Rhodes', citizenid = 'ZAL0919X3' },
    { name = 'Justin Harris', citizenid = 'ZAK09D193' },
    { name = 'Montel Graves', citizenid = 'POL09F193' },
    { name = 'Benjamin Zavala', citizenid = 'TEW0J9193' },
    { name = 'Mia Willis', citizenid = 'YOO09H193' },
    { name = 'Jacques Schmitt', citizenid = 'QBC091H93' },
    { name = 'Mert Simmonds', citizenid = 'YDN091H93' },
    { name = 'Rickie Browne', citizenid = 'PJD09D193' },
    { name = 'Deacon Stanley', citizenid = 'RND091D93' },
    { name = 'Daisy Fraser', citizenid = 'QWE091A93' },
    { name = 'Kitty Walters', citizenid = 'KJH0919M3' },
    { name = 'Jareth Fernandez', citizenid = 'ZXC09D193' },
    { name = 'Meredith Calhoun', citizenid = 'XYZ0919C3' },
    { name = 'Teagan Mckay', citizenid = 'ZYX0919F3' },
    { name = 'Kurt Bain', citizenid = 'IOP091O93' },
    { name = 'Burt Kain', citizenid = 'PIO091R93' },
    { name = 'Joanna Huff', citizenid = 'LEK091X93' },
    { name = 'Carrie-Ann Pineda', citizenid = 'ALG091Y93' },
    { name = 'Gracie-Mai Mcghee', citizenid = 'YUR09E193' },
    { name = 'Robyn Boone', citizenid = 'SOM091W93' },
    { name = 'Aliya William', citizenid = 'KAS009193' },
    { name = 'Rohit West', citizenid = 'SOK091093' },
    { name = 'Skylar Archer', citizenid = 'LOK091093' },
    { name = 'Jake Kumar', citizenid = 'AKA420609' },
}

local function GenerateOwnerName(plate)
    if not plate then return npcNames[math.random(1, #npcNames)] end

    local seed = 0
    for i = 1, #plate do
        seed = seed + string.byte(plate, i)
    end

    local index = (seed % #npcNames) + 1
    return npcNames[index]
end

local function GenerateTweetId()
    return "TWEET-" .. math.random(11111, 99999) .. os.time()
end

local function GenerateMailId()
    return "MAIL-" .. math.random(1111, 9999) .. os.time()
end

local function sendNewMailToOffline(citizenid, mailData)
    if not citizenid or not mailData then return end
    
    local mailId = GenerateMailId()
    local mailDocument = {
        citizenid = citizenid,
        sender = mailData.sender,
        subject = mailData.subject,
        message = mailData.message,
        mailid = mailId,
        read = 0,
        button = mailData.button,
        date = os.time() 
    }

    exports['tmgnosql']:SaveToCollection('player_mails', mailDocument)

    local Player = TMGCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player then
        local src = Player.PlayerData.source
        
        TriggerClientEvent('tmg-phone:client:NewMailNotify', src, mailData)

        local mails = exports['tmgnosql']:Find('player_mails', 
            { citizenid = citizenid }, 
            { sort = { date = -1 }, limit = 50 } 
        )
        
        TriggerClientEvent('tmg-phone:client:UpdateMails', src, mails)
    end
end

exports('sendNewMailToOffline', sendNewMailToOffline)



TMGCore.Functions.CreateCallback("tmg-phone:server:GetInvoices", function(source, cb)
    local Player = TMGCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    local cid = Player.PlayerData.citizenid

    local invoices = exports['tmgnosql']:Find('phone_invoices', { citizenid = cid })
    
    if not invoices or #invoices == 0 then return cb({}) end

    for _, invoice in pairs(invoices) do
        local SenderCID = invoice.sender
        local SenderPly = TMGCore.Functions.GetPlayerByCitizenId(SenderCID)

        if SenderPly then
            invoice.number = SenderPly.PlayerData.charinfo.phone
        else
            local result = exports['tmgnosql']:FindOne('players', 
                { citizenid = SenderCID }, 
                { projection = { ["charinfo.phone"] = 1 } }
            )
            
            invoice.number = result and result.charinfo.phone or "Unknown"
        end
    end

    cb(invoices)
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:GetCallState', function(_, cb, ContactData)
    local Target = TMGCore.Functions.GetPlayerByPhone(ContactData.number)
    
    if not Target then 
        return cb(false, false) 
    end

    local cid = Target.PlayerData.citizenid
    local isAvailable = not (Calls[cid] and Calls[cid].inCall)

    cb(isAvailable, true)
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:GetPhoneData', function(source, cb)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return cb(nil) end

    local cid = Player.PlayerData.citizenid
    
    local playerMeta = Player.PlayerData.metadata or {}
    local phoneMeta = playerMeta['phonedata'] or {}

    local PhoneData = {
        Applications = AppAlerts[cid] or {},
        MentionedTweets = MentionedTweets[cid] or {},
        Adverts = Adverts or {},
        Hashtags = Hashtags or {},
        Tweets = TWData or {}, 
        InstalledApps = phoneMeta.InstalledApps or {}, 
        
        PlayerContacts = {},
        Chats = {},
        Garage = {},
        Mails = {},
        CryptoTransactions = {},
        Images = {}
    }

    local contacts = exports['tmgnosql']:Find('player_contacts', { citizenid = cid }, { sort = { name = 1 } })
    if contacts then
        for _, v in pairs(contacts) do
            v.status = GetOnlineStatus(v.number)
        end
        PhoneData.PlayerContacts = contacts
    end

    PhoneData.Garage = exports['tmgnosql']:Find('player_vehicles', { citizenid = cid }) or {}
    PhoneData.Chats = exports['tmgnosql']:Find('phone_messages', { citizenid = cid }) or {}
    PhoneData.Mails = exports['tmgnosql']:Find('player_mails', { citizenid = cid }, { sort = { date = -1 } }) or {}

    local crypto = exports['tmgnosql']:Find('crypto_transactions', { citizenid = cid }, { sort = { date = -1 }, limit = 20 })
    if crypto then
        for _, v in pairs(crypto) do
            PhoneData.CryptoTransactions[#PhoneData.CryptoTransactions + 1] = {
                TransactionTitle = v.title,
                TransactionMessage = v.message
            }
        end
    end

    PhoneData.Images = exports['tmgnosql']:Find('phone_gallery', { citizenid = cid }, { sort = { date = -1 } }) or {}

    cb(PhoneData)
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:PayInvoice', function(source, cb, society, amount, invoiceId, sendercitizenid)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    local invoice = exports['tmgnosql']:FindOne('phone_invoices', { 
        id = invoiceId, 
        citizenid = Player.PlayerData.citizenid 
    })

    if not invoice then 
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Invoice record not found or already settled.", "error")
        return cb(false) 
    end

    if Player.Functions.RemoveMoney('bank', amount, 'paid-invoice-'..invoiceId) then
        
        exports['tmgnosql']:DeleteOne('phone_invoices', { id = invoiceId })

        local commission = 0
        if Config.BillingCommissions[society] then
            commission = TMGCore.Shared.Round(amount * Config.BillingCommissions[society])
        end

        local senderMailData = {
            sender = 'Billing Department',
            subject = 'Invoice Settled',
            message = string.format('%s %s has paid the invoice of $%s.', Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname, amount)
        }

        local SenderPly = TMGCore.Functions.GetPlayerByCitizenId(sendercitizenid)
        if commission > 0 then
            if SenderPly then
                SenderPly.Functions.AddMoney('bank', commission, 'invoice-commission')
                senderMailData.subject = 'Commission Received'
                senderMailData.message = senderMailData.message .. string.format(' You received a commission of $%s.', commission)
            else
                exports['tmgnosql']:UpdateOne('players', 
                    { citizenid = sendercitizenid }, 
                    { ["$inc"] = { ["money.bank"] = commission } }
                )
            end
        end

        exports['tmg-phone']:sendNewMailToOffline(sendercitizenid, senderMailData)

        TriggerEvent("tmg-phone:server:paidInvoice", src, invoiceId)
        exports['tmg-banking']:AddMoney(society, amount, 'Phone invoice')
        
        cb(true)
    else
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Insufficient bank balance for settlement.", "error")
        cb(false)
    end
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:DeclineInvoice', function(source, cb, _, _, invoiceId)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    local cid = Player.PlayerData.citizenid

    local invoice = exports['tmgnosql']:FindOne('phone_invoices', { 
        id = invoiceId, 
        citizenid = cid,
        candecline = 1 
    })

    if invoice then
        TriggerEvent("tmg-phone:server:declinedInvoice", src, invoiceId)

        exports['tmgnosql']:DeleteOne('phone_invoices', { 
            id = invoiceId, 
            citizenid = cid 
        })

        print("^5[TMG]^7 Invoice "..invoiceId.." declined by "..cid)
        cb(true)
    else
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: This invoice cannot be declined.", "error")
        cb(false)
    end
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:GetContactPictures', function(_, cb, Chats)
    if not Chats or next(Chats) == nil then return cb({}) end

    for _, chat in pairs(Chats) do
        local targetData = exports['tmgnosql']:FindOne('players', 
            { ["charinfo.phone"] = chat.number }, 
            { projection = { ["metadata.phone.profilepicture"] = 1 } }
        )

        if targetData and targetData.metadata and targetData.metadata.phone then
            chat.picture = targetData.metadata.phone.profilepicture or 'default'
        else
            chat.picture = 'default'
        end
    end

    cb(Chats)
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:GetContactPicture', function(_, cb, Chat)
    if not Chat or not Chat.number then return cb(Chat) end

    local result = exports['tmgnosql']:FindOne('players', 
        { ["charinfo.phone"] = Chat.number }, 
        { projection = { ["metadata.phone.profilepicture"] = 1 } }
    )

    if result and result.metadata and result.metadata.phone then
        Chat.picture = result.metadata.phone.profilepicture or 'default'
    else
        Chat.picture = 'default'
    end

    cb(Chat)
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:GetPicture', function(_, cb, number)
    if not number then return cb(nil) end

    local result = exports['tmgnosql']:FindOne('players', 
        { ["charinfo.phone"] = number }, 
        { projection = { ["metadata.phone.profilepicture"] = 1 } }
    )

    if result and result.metadata and result.metadata.phone then
        local Picture = result.metadata.phone.profilepicture or 'default'
        cb(Picture)
    else
        cb('default')
    end
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:FetchResult', function(_, cb, search)
    if not search or search == "" then return cb(nil) end

    local searchData = {}
    local searchParameters = SplitStringToArray(search)
    
    local query = {
        ["$or"] = {
            { citizenid = { ["$regex"] = search, ["$options"] = "i" } },
            { ["charinfo.firstname"] = { ["$regex"] = search, ["$options"] = "i" } },
            { ["charinfo.lastname"] = { ["$regex"] = search, ["$options"] = "i" } }
        }
    }

    if #searchParameters > 1 then
        query["$or"] = {
            { ["$and"] = {
                { ["charinfo.firstname"] = { ["$regex"] = searchParameters[1], ["$options"] = "i" } },
                { ["charinfo.lastname"] = { ["$regex"] = searchParameters[2], ["$options"] = "i" } }
            }},
            { citizenid = search }
        }
    end

    local players = exports['tmgnosql']:Find('players', query, { 
        projection = { charinfo = 1, metadata = 1, citizenid = 1 },
        limit = 10 
    })

    if players and #players > 0 then
        local cids = {}
        for _, p in ipairs(players) do cids[#cids+1] = p.citizenid end
        
        local apartments = exports['tmgnosql']:Find('apartments', { citizenid = { ["$in"] = cids } })
        local apartmentMap = {}
        for _, apa in pairs(apartments) do apartmentMap[apa.citizenid] = apa end

        for _, v in pairs(players) do
            searchData[#searchData + 1] = {
                citizenid = v.citizenid,
                firstname = v.charinfo.firstname,
                lastname = v.charinfo.lastname,
                birthdate = v.charinfo.birthdate,
                phone = v.charinfo.phone,
                nationality = v.charinfo.nationality,
                gender = v.charinfo.gender,
                warrant = false, 
                driverlicense = v.metadata.licences and v.metadata.licences.driver or false,
                appartmentdata = apartmentMap[v.citizenid] or {}
            }
        end
        cb(searchData)
    else
        cb(nil)
    end
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:GetVehicleSearchResults', function(_, cb, search)
    if not search or search == "" then return cb({}) end

    local searchData = {}
    local trimmedSearch = string.upper(search:gsub('%s+', '')) 

    local vehicleResults = exports['tmgnosql']:Find('player_vehicles', {
        ["$or"] = {
            { plate = { ["$regex"] = trimmedSearch, ["$options"] = "i" } },
            { citizenid = search }
        }
    }, { limit = 15 })

    if vehicleResults and #vehicleResults > 0 then
        local ownerIds = {}
        for _, veh in ipairs(vehicleResults) do ownerIds[#ownerIds+1] = veh.citizenid end

        local owners = exports['tmgnosql']:Find('players', 
            { citizenid = { ["$in"] = ownerIds } },
            { projection = { citizenid = 1, ["charinfo.firstname"] = 1, ["charinfo.lastname"] = 1 } }
        )

        local ownerMap = {}
        for _, owner in ipairs(owners) do ownerMap[owner.citizenid] = owner.charinfo end

        for _, veh in ipairs(vehicleResults) do
            local ownerData = ownerMap[veh.citizenid] or { firstname = "Unknown", lastname = "Owner" }
            local vehicleInfo = TMGCore.Shared.Vehicles[veh.vehicle]
            
            searchData[#searchData + 1] = {
                plate = veh.plate,
                status = true,
                owner = ownerData.firstname .. ' ' .. ownerData.lastname,
                citizenid = veh.citizenid,
                label = vehicleInfo and vehicleInfo.name or 'Model Unknown'
            }
        end
    else
        if GeneratedPlates[trimmedSearch] then
            searchData[#searchData + 1] = GeneratedPlates[trimmedSearch]
        else
            local npcOwner = GenerateOwnerName(trimmedSearch) 
            local npcData = {
                plate = trimmedSearch,
                status = true,
                owner = npcOwner.name,
                citizenid = npcOwner.citizenid,
                label = 'Local Resident'
            }
            GeneratedPlates[trimmedSearch] = npcData 
            searchData[#searchData + 1] = npcData
        end
    end

    cb(searchData)
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:ScanPlate', function(source, cb, plate)
    local src = source
    if not plate then 
        TriggerClientEvent('TMGCore:Notify', src, 'No Vehicle Detected', 'error')
        return cb(nil) 
    end

    local cleanPlate = string.upper(plate:gsub('%s+', ''))
    local vehicleData = nil

    local result = exports['tmgnosql']:FindOne('player_vehicles', { plate = cleanPlate })

    if result then
        local owner = exports['tmgnosql']:FindOne('players', 
            { citizenid = result.citizenid }, 
            { projection = { charinfo = 1 } }
        )

        if owner then
            vehicleData = {
                plate = cleanPlate,
                status = true,
                owner = owner.charinfo.firstname .. ' ' .. owner.charinfo.lastname,
                citizenid = result.citizenid
            }
        end
    end

    if not vehicleData then
        if GeneratedPlates[cleanPlate] then
            vehicleData = GeneratedPlates[cleanPlate]
        else
            local npcInfo = GenerateOwnerName(cleanPlate) 
            vehicleData = {
                plate = cleanPlate,
                status = true,
                owner = npcInfo.name,
                citizenid = npcInfo.citizenid
            }
            GeneratedPlates[cleanPlate] = vehicleData
        end
    end

    cb(vehicleData)
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:HasPhone', function(source, cb)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player then return cb(false) end

    local HasHardware = Player.Functions.GetItemByName('phone')

    if HasHardware and HasHardware.amount > 0 then
        cb(true)
    else
        cb(false)
    end
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:CanTransferMoney', function(source, cb, amount, iban)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    local transferAmount = tonumber(amount) or 0
    if transferAmount <= 0 then return cb(false) end

    if Player.PlayerData.money.bank < transferAmount then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Insufficient bank reserves.", "error")
        return cb(false)
    end

    local targetData = exports['tmgnosql']:FindOne('players', 
        { ["charinfo.account"] = iban }, 
        { projection = { citizenid = 1, money = 1 } }
    )

    if not targetData then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Invalid IBAN/Account Number.", "error")
        return cb(false)
    end

    if Player.Functions.RemoveMoney('bank', transferAmount, "phone-transfer-to-" .. iban) then
        
        local Receiver = TMGCore.Functions.GetPlayerByCitizenId(targetData.citizenid)
        
        if Receiver then
            Receiver.Functions.AddMoney('bank', transferAmount, "phone-transfer-from-" .. Player.PlayerData.charinfo.account)
            
            TriggerClientEvent('tmg-phone:client:TransferMoney', Receiver.PlayerData.source, transferAmount, Receiver.PlayerData.money.bank)
        else
            exports['tmgnosql']:UpdateOne('players', 
                { citizenid = targetData.citizenid }, 
                { ["$inc"] = { ["money.bank"] = transferAmount } }
            )
        end

        cb(true)
    else
        cb(false)
    end
end)


local ServiceJobs = {
    ['lawyer'] = true,
    ['realestate'] = true,
    ['mechanic'] = true,
    ['taxi'] = true,
    ['police'] = true,
    ['ambulance'] = true,
    
}

TMGCore.Functions.CreateCallback('tmg-phone:server:GetCurrentLawyers', function(_, cb)
    local activeServices = {}
    local allPlayers = TMGCore.Functions.GetPlayers()

    for _, src in pairs(allPlayers) do
        local Player = TMGCore.Functions.GetPlayer(src)
        if Player then
            local job = Player.PlayerData.job
            
            if ServiceJobs[job.name] and job.onduty then
                local char = Player.PlayerData.charinfo
                
                activeServices[#activeServices + 1] = {
                    name = char.firstname .. ' ' .. char.lastname,
                    phone = char.phone,
                    typejob = job.name
                }
            end
        end
    end

    cb(activeServices)
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:GetWebhook', function(source, cb)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return cb(nil) end

    local activeWebhook = Config.Webhook or WebHook 

    if activeWebhook and activeWebhook ~= "" and activeWebhook ~= "SET_YOUR_WEBHOOK_HERE" then
        print(string.format("^5[TMG Mainframe]^7 Camera Auth requested by %s", Player.PlayerData.citizenid))
        
        cb(activeWebhook)
    else
        print("^1[TMG ERROR]^7 Camera Webhook is NOT configured! Photos will fail to upload.")
        print("^1[FIX]^7 Update 'Config.Webhook' in your configuration BSON/file.")
        
        cb(nil)
    end
end)


TMGCore.Functions.CreateCallback('tmg-phone:server:UploadToFivemerr', function(source, cb)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return cb(nil) end

    local uploadUrl = "https://api.fivemerr.com/v1/media/images" 
    local apiToken = FivemerrApiToken or ""

    if Config.Fivemerr and apiToken == "" then
        print("^1[TMG ERROR]^7 Fivemerr is enabled but the API Token is missing.")
        return cb(nil)
    end

    if not Config.Fivemerr then
        uploadUrl = Config.Webhook or WebHook
    end

    exports['screenshot-basic']:requestClientScreenshot(src, {
        encoding = 'png'
    }, function(err, data)
        if err then 
            print("^1[TMG ERROR]^7 Screenshot failed for Player: " .. src)
            return cb(nil) 
        end

        PerformHttpRequest(uploadUrl, function(status, response)
            if status == 200 or status == 201 or status == 204 then
                cb(response)
            else
                print("^1[TMG ERROR]^7 Image Upload Failed. Status: " .. (status or "Unknown"))
                cb(nil)
            end
        end, "POST", json.encode({ image = data }), { 
            ['Authorization'] = apiToken,
            ['Content-Type'] = 'application/json'
        })
    end)
end)




RegisterNetEvent('tmg-phone:server:AddAdvert', function(msg, url)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not msg then return end

    local cid = Player.PlayerData.citizenid
    local firstName = Player.PlayerData.charinfo.firstname
    local lastName = Player.PlayerData.charinfo.lastname
    
    local cleanMsg = msg:gsub('[%<>\"()]', '')
    local cleanUrl = url and url:gsub('[%<>\"()\' $]', '') or ""

    local adData = {
        message = cleanMsg,
        name = "@" .. firstName .. " " .. lastName,
        number = Player.PlayerData.charinfo.phone,
        url = cleanUrl,
        time = os.time() 
    }

    Adverts[cid] = adData
    exports['tmgnosql']:UpdateOne('phone_adverts', 
        { citizenid = cid }, 
        { ["$set"] = adData }, 
        { upsert = true }
    )

    TriggerClientEvent('tmg-phone:client:UpdateAdverts', -1, Adverts, adData.name)
end)


RegisterNetEvent('tmg-phone:server:DeleteAdvert', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    Adverts[cid] = nil

    exports['tmgnosql']:DeleteOne('phone_adverts', { citizenid = cid })

    TriggerClientEvent('tmg-phone:client:UpdateAdvertsDel', -1, Adverts)
    
    
    print("^5[TMG]^7 Advertisement purged for Citizen: " .. cid)
end)


RegisterNetEvent('tmg-phone:server:SetCallState', function(bool)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    Calls[cid] = Calls[cid] or {}
    
    Calls[cid].inCall = (bool == true)

    
    print(string.format("^5[TMG]^7 %s is now %s", cid, bool and "In-Call" or "Available"))
end)


RegisterNetEvent('tmg-phone:server:RemoveMail', function(MailId)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    exports['tmgnosql']:DeleteOne('player_mails', { 
        mailid = MailId, 
        citizenid = cid 
    })

    local mails = exports['tmgnosql']:Find('player_mails', 
        { citizenid = cid }, 
        { sort = { date = -1 } } 
    )

    TriggerClientEvent('tmg-phone:client:UpdateMails', src, mails or {})
    
    
    
end)


RegisterNetEvent('tmg-phone:server:sendNewMail', function(mailData)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not mailData then return end

    local cid = Player.PlayerData.citizenid

    local mailDocument = {
        citizenid = cid,
        sender = mailData.sender or "Unknown",
        subject = mailData.subject or "No Subject",
        message = mailData.message or "",
        mailid = GenerateMailId(),
        read = 0,
        date = os.time() * 1000, 
        button = mailData.button 
    }

    exports['tmgnosql']:SaveToCollection('player_mails', mailDocument)

    TriggerClientEvent('tmg-phone:client:NewMailNotify', src, mailData)

    local updatedMails = exports['tmgnosql']:Find('player_mails', 
        { citizenid = cid }, 
        { sort = { date = -1 } }
    )

    TriggerClientEvent('tmg-phone:client:UpdateMails', src, updatedMails or {})
end)


RegisterNetEvent('tmg-phone:server:sendNewEventMail', function(citizenid, mailData)
    if not citizenid or not mailData then return end

    local mailDocument = {
        citizenid = citizenid,
        sender = mailData.sender or "System",
        subject = mailData.subject or "No Subject",
        message = mailData.message or "",
        mailid = GenerateMailId(),
        read = 0,
        date = os.time() * 1000, 
        button = mailData.button 
    }

    exports['tmgnosql']:SaveToCollection('player_mails', mailDocument)

    local Player = TMGCore.Functions.GetPlayerByCitizenId(citizenid)
    
    if Player then
        local src = Player.PlayerData.source

        local updatedMails = exports['tmgnosql']:Find('player_mails', 
            { citizenid = citizenid }, 
            { sort = { date = -1 } }
        )

        TriggerClientEvent('tmg-phone:client:UpdateMails', src, updatedMails or {})
        TriggerClientEvent('tmg-phone:client:NewMailNotify', src, mailData)
    else
        
        print("^5[TMG]^7 Event mail queued for offline Citizen: " .. citizenid)
    end
end)


RegisterNetEvent('tmg-phone:server:ClearButtonData', function(mailId)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not mailId then return end

    local cid = Player.PlayerData.citizenid

    exports['tmgnosql']:UpdateOne('player_mails', 
        { mailid = mailId, citizenid = cid }, 
        { ["$set"] = { button = nil } }
    )

    local updatedMails = exports['tmgnosql']:Find('player_mails', 
        { citizenid = cid }, 
        { sort = { date = -1 } }
    )

    TriggerClientEvent('tmg-phone:client:UpdateMails', src, updatedMails or {})
    
    print("^5[TMG]^7 Cleared for Mail: " .. mailId)
end)


RegisterNetEvent('tmg-phone:server:MentionedPlayer', function(firstName, lastName, TweetMessage)
    local targetCID = nil
    local targetSrc = nil

    for _, v in pairs(TMGCore.Functions.GetPlayers()) do
        local Player = TMGCore.Functions.GetPlayer(v)
        if Player and Player.PlayerData.charinfo.firstname == firstName and Player.PlayerData.charinfo.lastname == lastName then
            targetCID = Player.PlayerData.citizenid
            targetSrc = v
            break 
        end
    end

    if not targetCID then
        local result = exports['tmgnosql']:FindOne('players', { 
            ["charinfo.firstname"] = firstName, 
            ["charinfo.lastname"] = lastName 
        }, { projection = { citizenid = 1 } })

        if result then
            targetCID = result.citizenid
        end
    end

    if targetCID then
        QBPhone.SetPhoneAlerts(targetCID, 'twitter')
        QBPhone.AddMentionedTweet(targetCID, TweetMessage)

        if targetSrc then
            TriggerClientEvent('tmg-phone:client:GetMentioned', targetSrc, TweetMessage, AppAlerts[targetCID]['twitter'])
        end
    end
end)


RegisterNetEvent('tmg-phone:server:CallContact', function(TargetData, CallId, AnonymousCall)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not TargetData or not TargetData.number then return end

    local Target = TMGCore.Functions.GetPlayerByPhone(TargetData.number)
    
    if Target then
        local TargetSrc = Target.PlayerData.source
        
        local CallerID = Player.PlayerData.charinfo.phone
        if AnonymousCall then
            CallerID = "Unknown" 
        end

        TriggerClientEvent('tmg-phone:client:GetCalled', TargetSrc, CallerID, CallId, AnonymousCall)
        
        print(string.format("^5[TMG]^7 Call Handshake: %s -> %s (ID: %s)", Player.PlayerData.citizenid, Target.PlayerData.citizenid, CallId))
    else
        
        TriggerClientEvent('tmg-phone:client:CallContactError', src)
    end
end)


RegisterNetEvent('tmg-phone:server:BillingEmail', function(data, paid)
    local src = source
    local Sender = TMGCore.Functions.GetPlayer(src)
    if not Sender or not data or not data.society then return end

    local senderName = string.format("%s %s", Sender.PlayerData.charinfo.firstname, Sender.PlayerData.charinfo.lastname)

    local allPlayers = TMGCore.Functions.GetPlayers()
    for _, targetSrc in pairs(allPlayers) do
        local TargetPly = TMGCore.Functions.GetPlayer(targetSrc)
        
        if TargetPly and TargetPly.PlayerData.job.name == data.society then
            TriggerClientEvent('tmg-phone:client:BillingEmail', targetSrc, data, paid, senderName)
        end
    end

    print(string.format("^5[TMG]^7 %s notification sent to %s sector.", paid and "Payment" or "Invoice", data.society))
end)


RegisterNetEvent('tmg-phone:server:UpdateHashtags', function(Handle, messageData)
    if not Handle or not messageData then return end

    Hashtags[Handle] = Hashtags[Handle] or { hashtag = Handle, messages = {} }
    
    Hashtags[Handle].messages[#Hashtags[Handle].messages + 1] = messageData

    exports['tmgnosql']:UpdateOne('phone_hashtags', 
        { hashtag = Handle }, 
        { 
            ["$set"] = { hashtag = Handle },
            ["$push"] = { messages = messageData } 
        }, 
        { upsert = true }
    )

    TriggerClientEvent('tmg-phone:client:UpdateHashtags', -1, Handle, messageData)
    
    print("^5[TMG]^7 Hashtag #"..Handle.." indexed and broadcasted.")
end)


RegisterNetEvent('tmg-phone:server:SetPhoneAlerts', function(app, alerts)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not app then return end

    local cid = Player.PlayerData.citizenid

    AppAlerts[cid] = AppAlerts[cid] or {}
    AppAlerts[cid][app] = alerts

    local phonedata = Player.PlayerData.metadata['phonedata'] or {}
    phonedata.Alerts = AppAlerts[cid]
    
    Player.Functions.SetMetaData('phonedata', phonedata)

    TriggerClientEvent('tmg-phone:client:SetPhoneAlerts', src, app, alerts)
    
    print(string.format("^5[TMG]^7 Alert state updated for %s: %s (%s)", cid, app, alerts))
end)


RegisterNetEvent('tmg-phone:server:DeleteTweet', function(tweetId)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not tweetId then return end

    local cid = Player.PlayerData.citizenid

    local deletedCount = exports['tmgnosql']:DeleteOne('phone_tweets', { 
        tweetId = tweetId, 
        citizenid = cid 
    })

    if deletedCount > 0 then
        for i = #TWData, 1, -1 do
            if TWData[i].tweetId == tweetId then
                table.remove(TWData, i)
                break 
            end
        end

        TriggerClientEvent('tmg-phone:client:UpdateTweets', -1, TWData, nil, true)
        
        print(string.format("^5[TMG]^7 Tweet %s purged by %s", tweetId, cid))
    else
        print("^1[TMG]^7 Unauthorized tweet deletion attempt by " .. cid)
    end
end)

RegisterNetEvent('tmg-phone:server:UpdateTweets', function(_, TweetData)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not TweetData then return end

    local tweetId = GenerateTweetId()
    local cleanTweet = {
        citizenid = Player.PlayerData.citizenid,
        firstName = Player.PlayerData.charinfo.firstname,
        lastName = Player.PlayerData.charinfo.lastname,
        message = TweetData.message:gsub('[%<>\"()]', ''), 
        date = os.time() * 1000,
        url = TweetData.url and TweetData.url:gsub('[%<>\"()\' $]', '') or "",
        picture = TweetData.picture and TweetData.picture:gsub('[%<>\"()\' $]', '') or "",
        tweetId = tweetId
    }

    table.insert(TWData, 1, cleanTweet) 
    
    if #TWData > 100 then table.remove(TWData) end

    exports['tmgnosql']:SaveToCollection('phone_tweets', cleanTweet)

    TriggerClientEvent('tmg-phone:client:UpdateTweets', -1, TWData, cleanTweet, false)
    
    print(string.format("^5[TMG]^7 Global Tweet Published: %s", tweetId))
end)


RegisterNetEvent('tmg-phone:server:TransferMoney', function(iban, amount)
    local src = source
    local Sender = TMGCore.Functions.GetPlayer(src)
    if not Sender or not iban or not amount then return end

    local transferAmount = tonumber(amount) or 0
    if transferAmount <= 0 then 
        TriggerClientEvent('TMGCore:Notify', src, "Invalid Amount", "error")
        return 
    end

    if Sender.PlayerData.money.bank < transferAmount then
        TriggerClientEvent('TMGCore:Notify', src, "Insufficient Bank Reserves", "error")
        return
    end

    local targetData = exports['tmgnosql']:FindOne('players', 
        { ["charinfo.account"] = iban }, 
        { projection = { citizenid = 1, money = 1 } }
    )

    if not targetData then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: IBAN Not Found", "error")
        return
    end

    if Sender.Functions.RemoveMoney('bank', transferAmount, "phone-transfer-to-" .. targetData.citizenid) then
        
        local Receiver = TMGCore.Functions.GetPlayerByCitizenId(targetData.citizenid)

        if Receiver then
            Receiver.Functions.AddMoney('bank', transferAmount, "phone-transfer-from-" .. Sender.PlayerData.citizenid)
            
            if Receiver.Functions.GetItemByName('phone') then
                TriggerClientEvent('tmg-phone:client:TransferMoney', Receiver.PlayerData.source, transferAmount, Receiver.PlayerData.money.bank)
            end
        else
            exports['tmgnosql']:UpdateOne('players', 
                { citizenid = targetData.citizenid }, 
                { ["$inc"] = { ["money.bank"] = transferAmount } }
            )
        end

        TriggerClientEvent('TMGCore:Notify', src, "Transfer Successful: $" .. transferAmount, "success")
    else
        TriggerClientEvent('TMGCore:Notify', src, "Transfer Failed: Bank Error", "error")
    end
end)


RegisterNetEvent('tmg-phone:server:EditContact', function(newName, newNumber, newIban, oldName, oldNumber)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    local cleanName = newName:gsub('[%<>\"()]', '')
    local cleanNumber = newNumber:gsub('%s+', '') 
    local cleanIban = newIban:upper():gsub('%s+', '') 

    local success = exports['tmgnosql']:UpdateOne('player_contacts', 
        { 
            citizenid = cid, 
            name = oldName, 
            number = oldNumber 
        }, 
        { 
            ["$set"] = { 
                name = cleanName, 
                number = cleanNumber, 
                iban = cleanIban 
            } 
        }
    )

    if success then
        TriggerClientEvent('tmg-phone:client:RefreshContacts', src)
    else
        TriggerClientEvent('TMGCore:Notify', src, "Phone: Failed to update contact.", "error")
    end
end)


RegisterNetEvent('tmg-phone:server:RemoveContact', function(Name, Number)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    local success = exports['tmgnosql']:DeleteOne('player_contacts', { 
        name = Name, 
        number = Number, 
        citizenid = cid 
    })

    if success then
        TriggerClientEvent('tmg-phone:client:RefreshContacts', src)
        
    else
        print(string.format("^1[TMG ERROR]^7 Failed to purge contact for %s (Name: %s)", cid, Name))
    end
end)


RegisterNetEvent('tmg-phone:server:AddNewContact', function(name, number, iban)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    local cleanName = name:gsub('[%<>\"()]', '')
    local cleanNumber = number:gsub('%s+', '') 
    local cleanIban = iban and iban:upper():gsub('%s+', '') or ""

    local contactDocument = {
        citizenid = cid,
        name = cleanName,
        number = cleanNumber,
        iban = cleanIban
    }

    exports['tmgnosql']:SaveToCollection('player_contacts', contactDocument)

    TriggerClientEvent('tmg-phone:client:RefreshContacts', src)
    
    print(string.format("^5[TMG Mainframe]^7 New contact indexed for %s: %s", cid, cleanName))
end)


RegisterNetEvent('tmg-phone:server:UpdateMessages', function(ChatMessages, ChatNumber)
    local src = source
    local Sender = TMGCore.Functions.GetPlayer(src)
    if not Sender or not ChatNumber then return end

    local senderCID = Sender.PlayerData.citizenid
    local senderPhone = Sender.PlayerData.charinfo.phone

    local TargetResult = exports['tmgnosql']:FindOne('players', 
        { ["charinfo.phone"] = ChatNumber }, 
        { projection = { citizenid = 1 } }
    )
    if not TargetResult then return end

    local targetCID = TargetResult.citizenid

    local updatePayload = { ["$set"] = { messages = ChatMessages } }

    exports['tmgnosql']:UpdateOne('phone_messages', 
        { citizenid = senderCID, number = ChatNumber }, 
        updatePayload, { upsert = true }
    )

    exports['tmgnosql']:UpdateOne('phone_messages', 
        { citizenid = targetCID, number = senderPhone }, 
        updatePayload, { upsert = true }
    )

    local TargetPlayer = TMGCore.Functions.GetPlayerByCitizenId(targetCID)
    if TargetPlayer then
        TriggerClientEvent('tmg-phone:client:UpdateMessages', TargetPlayer.PlayerData.source, ChatMessages, senderPhone)
    end
end)


RegisterNetEvent('tmg-phone:server:AddRecentCall', function(callType, data)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not data or not data.number then return end

    local cid = Player.PlayerData.citizenid
    local timestamp = os.time() * 1000 

    local senderEntry = {
        name = data.name or "Unknown",
        number = data.number,
        anonymous = data.anonymous,
        type = callType, 
        time = timestamp
    }

    local Target = TMGCore.Functions.GetPlayerByPhone(data.number)
    
    local function logCall(targetCID, entry)
        exports['tmgnosql']:UpdateOne('phone_recent', 
            { citizenid = targetCID }, 
            { 
                ["$push"] = { 
                    calls = {
                        ["$each"] = { entry },
                        ["$sort"] = { time = -1 },
                        ["$slice"] = 30 
                    }
                } 
            }, 
            { upsert = true }
        )
    end

    logCall(cid, senderEntry)
    TriggerClientEvent('tmg-phone:client:AddRecentCall', src, senderEntry)

    if Target then
        local targetCID = Target.PlayerData.citizenid
        
        local receiverEntry = {
            name = data.anonymous and "Unknown" or (Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname),
            number = data.anonymous and "Unknown" or Player.PlayerData.charinfo.phone,
            anonymous = data.anonymous,
            type = 'incoming',
            time = timestamp
        }

        logCall(targetCID, receiverEntry)
        TriggerClientEvent('tmg-phone:client:AddRecentCall', Target.PlayerData.source, receiverEntry)
    end
end)


RegisterNetEvent('tmg-phone:server:CancelCall', function(ContactData)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not ContactData or not ContactData.TargetData then return end

    local senderCID = Player.PlayerData.citizenid
    local targetNumber = ContactData.TargetData.number

    local TargetPly = TMGCore.Functions.GetPlayerByPhone(targetNumber)
    
    if Calls[senderCID] then
        Calls[senderCID].inCall = false
    end

    if TargetPly then
        local targetCID = TargetPly.PlayerData.citizenid
        local targetSrc = TargetPly.PlayerData.source

        if Calls[targetCID] then
            Calls[targetCID].inCall = false
        end

        TriggerClientEvent('tmg-phone:client:CancelCall', targetSrc)
        
        print(string.format("^5[TMG]^7 Call Terminated: %s <-> %s", senderCID, targetCID))
    end
end)


RegisterNetEvent('tmg-phone:server:AnswerCall', function(CallData)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not CallData or not CallData.TargetData then return end

    local senderCID = Player.PlayerData.citizenid
    local targetNumber = CallData.TargetData.number

    local TargetPly = TMGCore.Functions.GetPlayerByPhone(targetNumber)
    
    Calls[senderCID] = Calls[senderCID] or {}
    Calls[senderCID].inCall = true

    if TargetPly then
        local targetCID = TargetPly.PlayerData.citizenid
        local targetSrc = TargetPly.PlayerData.source

        Calls[targetCID] = Calls[targetCID] or {}
        Calls[targetCID].inCall = true

        TriggerClientEvent('tmg-phone:client:AnswerCall', targetSrc)
        
        print(string.format("^5[TMG Mainframe]^7 Voice Bridge Active: %s <-> %s", senderCID, targetCID))
    else
        Calls[senderCID].inCall = false
        TriggerClientEvent('TMGCore:Notify', src, "Signal Lost: Caller Disconnected", "error")
    end
end)


RegisterNetEvent('tmg-phone:server:SaveMetaData', function(MData)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not MData then return end

    local cid = Player.PlayerData.citizenid

    exports['tmgnosql']:UpdateOne('players', 
        { citizenid = cid }, 
        { ["$set"] = { ["metadata.phone"] = MData } }
    )

    Player.Functions.SetMetaData('phone', MData)

    print("^5[TMG]^7 Metadata 'phone' state synced for Citizen: " .. cid)
end)


RegisterNetEvent('tmg-phone:server:GiveContactDetails', function(targetId)
    local src = source
    local Sender = TMGCore.Functions.GetPlayer(src)
    
    local Target = TMGCore.Functions.GetPlayer(tonumber(targetId))
    
    if not Sender or not Target then 
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Target not found.", "error")
        return 
    end

    local SuggestionData = {
        name = {
            firstName = Sender.PlayerData.charinfo.firstname,
            lastName = Sender.PlayerData.charinfo.lastname
        },
        number = Sender.PlayerData.charinfo.phone,
        bank = Sender.PlayerData.charinfo.account
    }

    TriggerClientEvent('tmg-phone:client:AddNewSuggestion', Target.PlayerData.source, SuggestionData)

    TriggerClientEvent('TMGCore:Notify', src, "Contact details shared with " .. Target.PlayerData.charinfo.firstname, "success")
    
    print(string.format("^5[TMG]^7 Contact Swap: %s -> %s", Sender.PlayerData.citizenid, Target.PlayerData.citizenid))
end)


RegisterNetEvent('tmg-phone:server:AddTransaction', function(data)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not data then return end

    local transactionDocument = {
        citizenid = Player.PlayerData.citizenid,
        title = data.TransactionTitle or "Crypto Transfer",
        message = data.TransactionMessage or "No details provided",
        time = os.time() * 1000
    }

    exports['tmgnosql']:SaveToCollection('phone_crypto_ledger', transactionDocument)
    
    print(string.format("^5[TMG]^7 Crypto Ledger Updated: %s (%s)", Player.PlayerData.citizenid, transactionDocument.title))
end)


RegisterNetEvent('tmg-phone:server:InstallApplication', function(ApplicationData)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not ApplicationData or not ApplicationData.app then return end

    local cid = Player.PlayerData.citizenid
    local appName = ApplicationData.app

    Player.PlayerData.metadata['phonedata'] = Player.PlayerData.metadata['phonedata'] or { InstalledApps = {} }
    Player.PlayerData.metadata['phonedata'].InstalledApps[appName] = ApplicationData

    exports['tmgnosql']:UpdateOne('players', 
        { citizenid = cid }, 
        { ["$set"] = { ["metadata.phonedata.InstalledApps." .. appName] = ApplicationData } }
    )

    TriggerClientEvent('tmg-phone:client:RefreshPhone', src)
    
    print(string.format("^5[TMG]^7 App '%s' provisioned for Citizen: %s", appName, cid))
end)


RegisterNetEvent('tmg-phone:server:RemoveInstallation', function(App)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not App then return end

    local cid = Player.PlayerData.citizenid

    if Player.PlayerData.metadata['phonedata'] and Player.PlayerData.metadata['phonedata'].InstalledApps then
        Player.PlayerData.metadata['phonedata'].InstalledApps[App] = nil
    end

    exports['tmgnosql']:UpdateOne('players', 
        { citizenid = cid }, 
        { ["$unset"] = { ["metadata.phonedata.InstalledApps." .. App] = "" } }
    )

    TriggerClientEvent('tmg-phone:client:RefreshPhone', src)
    
    print(string.format("^5[TMG]^7 App '%s' de-provisioned for Citizen: %s", App, cid))
end)


RegisterNetEvent('tmg-phone:server:addImageToGallery', function(image)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not image then return end

    local mediaDocument = {
        citizenid = Player.PlayerData.citizenid,
        image = image,
        date = os.time() * 1000 
    }

    exports['tmgnosql']:SaveToCollection('phone_gallery', mediaDocument)
    
    print("^5[TMG]^7 Image archived for Citizen: " .. Player.PlayerData.citizenid)
end)


RegisterNetEvent('tmg-phone:server:getImageFromGallery', function()
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player then return end

    local cid = Player.PlayerData.citizenid

    local images = exports['tmgnosql']:Find('phone_gallery', 
        { citizenid = cid }, 
        { sort = { date = -1 } }
    )

    TriggerClientEvent('tmg-phone:refreshImages', src, images or {})
    
    print("^5[TMG Mainframe]^7 Gallery stream completed for Citizen: " .. cid)
end)


RegisterNetEvent('tmg-phone:server:RemoveImageFromGallery', function(data)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    if not Player or not data or not data.image then return end

    local cid = Player.PlayerData.citizenid
    local imagePath = data.image

    local deletedCount = exports['tmgnosql']:DeleteOne('phone_gallery', { 
        image = imagePath, 
        citizenid = cid 
    })

    if deletedCount > 0 then
        print(string.format("^5[TMG]^7 Media purged for %s: %s", cid, imagePath))
        
        
    else
        print("^1[TMG WARNING]^7 Unauthorized or failed media purge attempt by " .. cid)
    end
end)


RegisterNetEvent('tmg-phone:server:sendPing', function(targetId)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    local Target = TMGCore.Functions.GetPlayer(tonumber(targetId))

    if src == tonumber(targetId) then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: You cannot ping your own terminal.", "error")
        return
    end

    if not Target then
        TriggerClientEvent('TMGCore:Notify', src, "Target terminal offline or unreachable.", "error")
        return
    end

    local senderData = {
        id = src,
        name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        phone = Player.PlayerData.charinfo.phone
    }

    TriggerClientEvent('tmg-phone:client:ReceivePing', Target.PlayerData.source, senderData)

    TriggerClientEvent('TMGCore:Notify', src, "GPS Signal beamed to " .. Target.PlayerData.charinfo.firstname, "success")
    
    print(string.format("^5[TMG]^7 Ping Handshake Initiated: %s -> %s", src, targetId))
end)




TMGCore.Commands.Add('setmetadata', 'Set Player Metadata (God Only)', {
    {name = 'id', help = 'Player ID'}, 
    {name = 'type', help = 'Metadata Type (e.g. jobrep)'},
    {name = 'key', help = 'Specific Key (e.g. trucker)'},
    {name = 'value', help = 'New Numeric Value'}
}, true, function(source, args)
    local targetId = tonumber(args[1])
    local metaType = tostring(args[2])
    local metaKey = tostring(args[3])
    local newValue = tonumber(args[4])

    local Target = TMGCore.Functions.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('TMGCore:Notify', source, "Mainframe: Target terminal not found.", "error")
        return
    end

    local bsonPath = string.format("metadata.%s.%s", metaType, metaKey)
    local cid = Target.PlayerData.citizenid

    exports['tmgnosql']:UpdateOne('players', 
        { citizenid = cid }, 
        { ["$set"] = { [bsonPath] = newValue } }
    )

    local currentMeta = Target.PlayerData.metadata[metaType] or {}
    currentMeta[metaKey] = newValue
    Target.Functions.SetMetaData(metaType, currentMeta)

    TriggerClientEvent('TMGCore:Notify', source, string.format("Update: %s.%s set to %s for ID %s", metaType, metaKey, newValue, targetId), "success")
    print(string.format("^5[TMG]^7 Admin %s modified %s for %s", source, bsonPath, cid))

end, 'god')


TMGCore.Commands.Add('bill', 'Bill A Player', { 
    { name = 'id', help = 'Player ID' }, 
    { name = 'amount', help = 'Fine Amount' } 
}, false, function(source, args)
    local src = source
    local Biller = TMGCore.Functions.GetPlayer(src)
    local Billed = TMGCore.Functions.GetPlayer(tonumber(args[1]))
    local amount = tonumber(args[2])

    local authorizedJobs = { ['police'] = true, ['ambulance'] = true, ['mechanic'] = true }
    
    if not authorizedJobs[Biller.PlayerData.job.name] then
        TriggerClientEvent('TMGCore:Notify', src, "Mainframe: Unauthorized access to billing protocols.", "error")
        return
    end

    if not Billed then
        TriggerClientEvent('TMGCore:Notify', src, "Target terminal offline.", "error")
        return
    end

    if Biller.PlayerData.citizenid == Billed.PlayerData.citizenid then
        TriggerClientEvent('TMGCore:Notify', src, "System Error: Cannot bill self-entity.", "error")
        return
    end

    if not amount or amount <= 0 then
        TriggerClientEvent('TMGCore:Notify', src, "Invalid Amount: Must be above 0.", "error")
        return
    end

    local invoiceId = "INV-" .. math.random(1111, 9999) .. os.time()
    local invoiceDocument = {
        invoiceId = invoiceId,
        citizenid = Billed.PlayerData.citizenid,
        amount = amount,
        society = Biller.PlayerData.job.name,
        sender = Biller.PlayerData.charinfo.firstname .. " " .. Biller.PlayerData.charinfo.lastname,
        sendercitizenid = Biller.PlayerData.citizenid,
        status = "unpaid",
        date = os.time() * 1000 
    }

    exports['tmgnosql']:SaveToCollection('phone_invoices', invoiceDocument)

    TriggerClientEvent('tmg-phone:client:RefreshInvoices', Billed.PlayerData.source) 
    TriggerClientEvent('TMGCore:Notify', src, 'Invoice Beamed Successfully', 'success')
    TriggerClientEvent('TMGCore:Notify', Billed.PlayerData.source, 'New Invoice Received: $' .. amount)
    
    print(string.format("^5[TMG]^7 Invoice %s generated by %s for %s", invoiceId, Biller.PlayerData.citizenid, Billed.PlayerData.citizenid))
end)
