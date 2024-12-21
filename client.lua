ESX = exports["es_extended"]:getSharedObject()

-- Variables locales
local PlayerData = {}
local hasVehicleKeys = {}
local activeAlarms = {} -- Ajouter cette ligne ici


-- Position du PNJ
local npcCoords = vector3(108.1240, -149.2380, 54.7491)
local npcHeading = 114.5603

-- Ajouter une variable pour suivre l'état du menu
local menuIsOpen = false

-- Charger les clés du joueur au démarrage
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    ESX.TriggerServerCallback('illama_keyscreator:getPlayerKeys', function(keys)
        hasVehicleKeys = keys
    end)
    SyncVehicleLockStates()
end)

-- Animation des clés
local function PlayKeyAnimation()
    local ped = PlayerPedId()
    local dict = "anim@mp_player_intmenu@key_fob@"
    
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(0)
    end

    TaskPlayAnim(ped, dict, "fob_click", 8.0, 8.0, -1, 48, 1, false, false, false)
    Citizen.Wait(500)
end

-- Fonction pour gérer toutes les portes
local function SetAllDoorStates(vehicle, state)
    for i = 0, 5 do -- 0 à 5 représente toutes les portes possibles
        SetVehicleDoorShut(vehicle, i, false)
    end
end

-- Réviser la fonction TriggerCarAlarm
local function TriggerCarAlarm(vehicle)
    local timer = GetGameTimer()
    local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
    activeAlarms[plate] = true
    
    Citizen.CreateThread(function()
        SetVehicleAlarm(vehicle, true)
        StartVehicleAlarm(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        
        while GetGameTimer() - timer < 15000 and activeAlarms[plate] do
            -- Son d'alarme fort et cohérent
            PlaySoundFromEntity(-1, "Car_Alarm_Loop_01", vehicle, "Stolen_Car_Alarms", true, 0)
            StartVehicleHorn(vehicle, 500, "HELDDOWN", false)
            
            -- Phares plus rapides
            SetVehicleLights(vehicle, 2)
            Citizen.Wait(100)
            SetVehicleLights(vehicle, 0)
            Citizen.Wait(100)
            
            if not IsVehicleAlarmActivated(vehicle) then
                SetVehicleAlarm(vehicle, true)
                StartVehicleAlarm(vehicle)
            end
        end
        
        -- Arrêter l'alarme et restaurer l'état normal
        activeAlarms[plate] = nil
        SetVehicleAlarm(vehicle, false)
        SetVehicleLights(vehicle, 0)
        
        -- Rétablir l'état du véhicule
        ESX.TriggerServerCallback('illama_keyscreator:getVehicleLockState', function(lockState)
            if lockState == 1 then
                SetVehicleDoorsLocked(vehicle, 2)
            else
                SetVehicleDoorsLocked(vehicle, 1)
            end
        end, plate)
    end)
end

-- Fonction pour le feedback visuel et sonore
local function PlayLockEffect(vehicle, locked)
    -- Flash des phares et klaxon
    SetVehicleLights(vehicle, 2)
    
    -- Double beep pour verrouillage, simple pour déverrouillage
    if locked then
        PlaySoundFromEntity(-1, "Remote_Control_Close", vehicle, "PI_Menu_Sounds", true, 0)
        -- Double bip plus fort
        StartVehicleHorn(vehicle, 300, "HELDDOWN", false)
        Citizen.Wait(100)
        StartVehicleHorn(vehicle, 300, "HELDDOWN", false)
    else
        PlaySoundFromEntity(-1, "Remote_Control_Open", vehicle, "PI_Menu_Sounds", true, 0)
        -- Simple bip plus fort
        StartVehicleHorn(vehicle, 300, "HELDDOWN", false)
    end
    
    -- Effet visuel
    Citizen.Wait(100)
    SetVehicleLights(vehicle, 0)
    Citizen.Wait(200)
    SetVehicleLights(vehicle, 2)
    Citizen.Wait(100)
    SetVehicleLights(vehicle, 0)
end

-- Création du PNJ
Citizen.CreateThread(function()
    local hash = GetHashKey("a_m_y_business_03")
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(1)
    end
    
    local npc = CreatePed(4, hash, npcCoords.x, npcCoords.y, npcCoords.z - 1, npcHeading, false, true)
    SetEntityHeading(npc, npcHeading)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)

    -- Configuration ox_target
    exports.ox_target:addLocalEntity(npc, {
        {
            name = 'talk_keys_npc',
            icon = 'fas fa-key',
            label = 'Parler au vendeur de clés',
            onSelect = function()
                OpenVehicleMenu()
            end
        }
    })
end)


-- Modifier la fonction OpenVehicleMenu
function OpenVehicleMenu()
    if not menuIsOpen then
        ESX.TriggerServerCallback('illama_keyscreator:getOwnedVehiclesWithKeys', function(vehicles)
            local formattedVehicles = {}
            
            for _, vehicle in ipairs(vehicles) do
                local vehicleData = json.decode(vehicle.vehicle)
                table.insert(formattedVehicles, {
                    label = GetLabelText(GetDisplayNameFromVehicleModel(vehicleData.model)),
                    plate = vehicle.plate,
                    hasKey = vehicle.has_key == 1
                })
            end
            
            -- Ouvrir la NUI
            menuIsOpen = true
            SetNuiFocus(true, true)
            SendNUIMessage({
                type = 'show',
                vehicles = formattedVehicles
            })
        end)
    end
end

-- Fonction pour fermer le menu
function CloseMenu()
    if menuIsOpen then
        menuIsOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({
            type = 'hide'
        })
    end
end


-- Modifier les callbacks NUI
RegisterNUICallback('closeMenu', function(data, cb)
    CloseMenu()
    cb('ok')
end)

RegisterNUICallback('createKey', function(data, cb)
    ESX.TriggerServerCallback('illama_keyscreator:getKeysCost', function(cost)
        if cost > 0 then
            ESX.ShowNotification(('Coût du double: ~r~%s$'):format(cost))
        end
        TriggerServerEvent('illama_keyscreator:registerVehicleKeys', data.plate)
    end, data.plate)
    
    hasVehicleKeys[data.plate] = true
    CloseMenu()
    cb('ok')
end)

-- Ajouter la gestion de la touche ECHAP
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if menuIsOpen and IsControlJustReleased(0, 177) then -- 177 est le code pour ECHAP
            CloseMenu()
        end
    end
end)

-- Événement de réception d'alerte de vol
RegisterNetEvent('illama_keyscreator:carTheftAlert')
AddEventHandler('illama_keyscreator:carTheftAlert', function(plate)
    ESX.ShowAdvancedNotification('Système d\'alarme', 'Alerte de sécurité', 'Tentative de vol détectée sur votre véhicule\nPlaque: ' .. plate, 'CHAR_CARSITE', 1)
    
    -- Trouver le véhicule correspondant
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        local vehPlate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
        if vehPlate == plate then
            TriggerCarAlarm(vehicle)
            break
        end
    end
end)

-- Gestion de la touche U pour verrouiller/déverrouiller
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustPressed(0, 303) then -- Touche U
            local playerPed = PlayerPedId()
            local vehicle = nil
            
            if IsPedInAnyVehicle(playerPed, false) then
                vehicle = GetVehiclePedIsIn(playerPed, false)
            else
                local coords = GetEntityCoords(playerPed)
                vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
            end
            
            if vehicle ~= 0 and DoesEntityExist(vehicle) then
                local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
                
                -- Vérifier si le joueur a les clés physiques
                local hasKey = exports.ox_inventory:Search('count', 'vehicle_key', {plate = plate}) > 0
                
                if hasKey then
                    -- Si une alarme est active pour ce véhicule, l'arrêter
                    if activeAlarms[plate] then
                        activeAlarms[plate] = nil
                        ESX.ShowNotification('Alarme ~g~désactivée~s~')
                        -- Petit délai pour laisser l'alarme s'arrêter proprement
                        Citizen.Wait(100)
                    end

                    ESX.TriggerServerCallback('illama_keyscreator:getVehicleLockState', function(lockState)
                        local newLockState = lockState == 1 and 0 or 1
                        
                        if not IsPedInAnyVehicle(playerPed, false) then
                            PlayKeyAnimation()
                        end
                        
                        TriggerServerEvent('illama_keyscreator:updateLockState', plate, newLockState)
                        
                        if newLockState == 1 then
                            SetVehicleDoorsLocked(vehicle, 2)
                            SetAllDoorStates(vehicle, true)
                            PlayVehicleDoorCloseSound(vehicle, 1)
                            PlayLockEffect(vehicle, true)
                            ESX.ShowNotification('Véhicule ~r~verrouillé~s~')
                        else
                            SetVehicleDoorsLocked(vehicle, 1)
                            PlayVehicleDoorOpenSound(vehicle, 0)
                            PlayLockEffect(vehicle, false)
                            ESX.ShowNotification('Véhicule ~g~déverrouillé~s~')
                        end
                    end, plate)
                else
                    ESX.ShowNotification('~r~Vous n\'avez pas les clés de ce véhicule')
                end
            end
        end
    end
end)

-- Vérification des tentatives de vol
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local ped = PlayerPedId()
        
        if DoesEntityExist(GetVehiclePedIsTryingToEnter(ped)) then
            local vehicle = GetVehiclePedIsTryingToEnter(ped)
            local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
            
            -- Vérifier si le joueur utilise ses clés
            if not hasVehicleKeys[plate] then
                ESX.TriggerServerCallback('illama_keyscreator:getVehicleLockState', function(lockState)
                    if lockState == 1 then
                        -- Empêcher l'entrée dans le véhicule temporairement
                        ClearPedTasks(ped)
                        
                        -- Enregistrer la tentative de vol
                        TriggerServerEvent('illama_keyscreator:registerTheftAttempt', plate)
                    end
                end, plate)
            end
        end
    end
end)

-- Synchroniser l'état des véhicules
function SyncVehicleLockStates()
    local vehicles = GetGamePool('CVehicle')
    for _, vehicle in ipairs(vehicles) do
        local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
        ESX.TriggerServerCallback('illama_keyscreator:getVehicleLockState', function(lockState)
            if lockState == 1 then
                SetVehicleDoorsLocked(vehicle, 2)
            else
                SetVehicleDoorsLocked(vehicle, 1)
            end
        end, plate)
    end
end

-- Synchronisation au chargement du joueur
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    SyncVehicleLockStates()
end)

-- Synchronisation périodique
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) -- Toutes les 30 secondes
        SyncVehicleLockStates()
    end
end)

-- Ajouter cette fonction pour recharger les clés (utile après un redémarrage)
function ReloadPlayerKeys()
    ESX.TriggerServerCallback('illama_keyscreator:getPlayerKeys', function(keys)
        hasVehicleKeys = keys
    end)
end

-- Ajouter cet événement pour recharger les clés après un redémarrage de ressource
AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    ReloadPlayerKeys()
end)

-- Ajouter l'export pour donner les clés (à mettre avec les autres exports/events)
exports('giveTemporaryKeys', function(plate)
    hasVehicleKeys[plate] = true
    TriggerServerEvent('illama_keyscreator:registerVehicleKeys', plate)
end)

-- Ajouter l'event pour retirer les clés
RegisterNetEvent('illama_keyscreator:removeKeys')
AddEventHandler('illama_keyscreator:removeKeys', function(plate)
    if hasVehicleKeys[plate] then
        hasVehicleKeys[plate] = nil
    end
end)