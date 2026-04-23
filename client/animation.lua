

local phoneProp = 0
local phoneModel = `prop_npc_phone_02`

local isAnimLoopActive = false

local function LoadAnimation(dict)
    RequestAnimDict(dict)
    local timeout = 0
    
    while not HasAnimDictLoaded(dict) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    return HasAnimDictLoaded(dict)
end

local function CheckAnimLoop()
    if isAnimLoopActive then return end
    
    
    
    if type(PhoneData) ~= "table" or type(PhoneData.AnimationData) ~= "table" then 
        return 
    end

    isAnimLoopActive = true

    CreateThread(function()
        
        while PhoneData and PhoneData.AnimationData and PhoneData.AnimationData.lib ~= nil and PhoneData.AnimationData.anim ~= nil do
            local ped = PlayerPedId()
            
            if not IsEntityPlayingAnim(ped, PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 3) then
                if LoadAnimation(PhoneData.AnimationData.lib) then
                    TaskPlayAnim(ped, PhoneData.AnimationData.lib, PhoneData.AnimationData.anim, 3.0, 3.0, -1, 50, 0, false, false, false)
                end
            end
            Wait(500)
        end
        
        isAnimLoopActive = false
    end)
end

function newPhoneProp()
    deletePhone()
    RequestModel(phoneModel)
    
    local timeout = 0
    while not HasModelLoaded(phoneModel) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    if not HasModelLoaded(phoneModel) then
        print("^1[TMG Error]^7 Hardware instantiation aborted: Model load timeout.")
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    phoneProp = CreateObject(phoneModel, coords.x, coords.y, coords.z, true, true, false)
    local bone = GetPedBoneIndex(ped, 28422)
    
    if phoneModel == `prop_cs_phone_01` then
        AttachEntityToEntity(phoneProp, ped, bone, 0.0, 0.0, 0.0, 50.0, 320.0, 50.0, 1, 1, 0, 0, 2, 1)
    else
        AttachEntityToEntity(phoneProp, ped, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, 1, 0, 0, 2, 1)
    end
    
    SetModelAsNoLongerNeeded(phoneModel)
end

function deletePhone()
    if phoneProp ~= 0 then
        if DoesEntityExist(phoneProp) then
            DeleteObject(phoneProp)
        end
        phoneProp = 0
    end
end

function DoPhoneAnimation(anim)
    local ped = PlayerPedId()
    local AnimationLib = 'cellphone@'
    local AnimationStatus = anim
    
    if IsPedInAnyVehicle(ped, false) then
        AnimationLib = 'anim@cellphone@in_car@ps'
    end
    
    
    
    if type(PhoneData) ~= "table" then 
        PhoneData = {} 
    end
    
    if type(PhoneData.AnimationData) ~= "table" then 
        PhoneData.AnimationData = {} 
    end
    
    if LoadAnimation(AnimationLib) then
        TaskPlayAnim(ped, AnimationLib, AnimationStatus, 3.0, 3.0, -1, 50, 0, false, false, false)
        
        
        PhoneData.AnimationData.lib = AnimationLib
        PhoneData.AnimationData.anim = AnimationStatus
        
        CheckAnimLoop()
    else
        print("^3[TMG System]^7 Cellular animation bypassed: Assets unavailable.")
    end
end
