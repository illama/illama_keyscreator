ESX = exports["es_extended"]:getSharedObject()
local ox_inventory = exports.ox_inventory
local keysCounts = {}

-- Table pour stocker les tentatives de vol
local theftAttempts = {}

-- Table de cache pour les plaques des véhicules joueurs
local playerVehicles = {}

-- Charger les véhicules au démarrage
CreateThread(function()
    MySQL.Async.fetchAll('SELECT plate FROM owned_vehicles', {}, function(vehicles)
        for _, vehicle in ipairs(vehicles) do
            playerVehicles[ESX.Math.Trim(vehicle.plate)] = true
        end
    end)
end)

-- Callback pour vérifier si c'est un véhicule joueur
ESX.RegisterServerCallback('illama_keyscreator:isPlayerVehicle', function(source, cb, plate)
    cb(playerVehicles[ESX.Math.Trim(plate)] == true)
end)

-- Mettre à jour le cache quand un véhicule est acheté
RegisterNetEvent('esx_vehicleshop:setVehicleOwned')
AddEventHandler('esx_vehicleshop:setVehicleOwned', function(vehicleProps)
    if vehicleProps and vehicleProps.plate then
        playerVehicles[ESX.Math.Trim(vehicleProps.plate)] = true
    end
end)

-- Récupérer les véhicules du joueur avec leurs clés
ESX.RegisterServerCallback('illama_keyscreator:getOwnedVehiclesWithKeys', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    MySQL.Async.fetchAll('SELECT ov.*, ik.has_key FROM owned_vehicles ov LEFT JOIN illama_keys ik ON ov.plate = ik.plate WHERE ov.owner = @owner', {
        ['@owner'] = xPlayer.identifier
    }, function(vehicles)
        cb(vehicles)
    end)
end)
RegisterServerEvent('illama_keyscreator:giveJobKeys')
AddEventHandler('illama_keyscreator:giveJobKeys', function(plate, jobName, vehicleName)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Créer un identifiant unique avec le job et un timestamp
    local uniqueId = string.format("%s_%s_%s", jobName, plate, os.time())
    
    MySQL.Async.execute('INSERT INTO illama_keys (plate, owner, has_key, locked, first_key_used) VALUES (@plate, @owner, @has_key, @locked, @first_key_used)', {
        ['@plate'] = plate,
        ['@owner'] = xPlayer.identifier,
        ['@has_key'] = 1,
        ['@locked'] = 0,
        ['@first_key_used'] = false,
    })

    -- Donner l'item clé avec l'identifiant unique
    exports.ox_inventory:AddItem(source, 'vehicle_key', 1, {
        label = ('Clés de service - %s'):format(vehicleName or plate),
        description = ('Véhicule de service - %s\nPlaque: %s'):format(jobName, plate),
        plate = plate,
        uniqueId = uniqueId,
        jobName = jobName,
    })
end)

RegisterServerEvent('illama_keyscreator:removeJobKeys')
AddEventHandler('illama_keyscreator:removeJobKeys', function(plate, jobName)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)

    
    -- D'abord supprimer les items
    local items = exports.ox_inventory:Search(source, 'slots', 'vehicle_key', {jobName = jobName, plate = plate})
    if items and #items > 0 then
        for _, item in pairs(items) do
            exports.ox_inventory:RemoveItem(source, 'vehicle_key', 1, nil, item.slot)
        end
    else
    end
    
    -- Supprimer de la base de données avec vérification
    MySQL.Async.execute('DELETE FROM illama_keys WHERE plate = @plate AND owner = @owner', {
        ['@plate'] = plate,
        ['@owner'] = xPlayer.identifier
    }, function(rowsChanged)
    end)
end)
-- Vérifier l'état de verrouillage d'un véhicule
ESX.RegisterServerCallback('illama_keyscreator:getVehicleLockState', function(source, cb, plate)
    MySQL.Async.fetchScalar('SELECT locked FROM illama_keys WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(locked)
        cb(locked or 0)
    end)
end)

-- Dans l'event registerVehicleKeys, remplacer par :
RegisterServerEvent('illama_keyscreator:registerVehicleKeys')
AddEventHandler('illama_keyscreator:registerVehicleKeys', function(plate)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Vérifier si le joueur a déjà eu sa première clé gratuite
    MySQL.Async.fetchScalar('SELECT first_key_used FROM illama_keys WHERE plate = @plate', {
        ['@plate'] = plate
    }, function(hasUsedFirstKey)
        if not hasUsedFirstKey then
            -- Première clé gratuite
            MySQL.Async.execute('INSERT INTO illama_keys (plate, owner, has_key, locked, first_key_used) VALUES (@plate, @owner, @has_key, @locked, @first_key_used) ON DUPLICATE KEY UPDATE first_key_used = @first_key_used', {
                ['@plate'] = plate,
                ['@owner'] = xPlayer.identifier,
                ['@has_key'] = 1,
                ['@locked'] = 0,
                ['@first_key_used'] = true
            })
        else
            -- Vérifier l'argent pour les doubles
            local cashMoney = exports.ox_inventory:Search(source, 'count', 'money')
            if cashMoney >= 5000 then
                if exports.ox_inventory:RemoveItem(source, 'money', 5000) then
                    TriggerClientEvent('esx:showNotification', source, 'Vous avez payé ~r~5000$~s~ pour le double')
                else
                    return
                end
            else
                TriggerClientEvent('esx:showNotification', source, '~r~Vous n\'avez pas assez d\'argent en liquide')
                return
            end
        end
        
        -- Créer la clé
        MySQL.Async.fetchAll('SELECT owner, firstname, lastname FROM owned_vehicles LEFT JOIN users ON owned_vehicles.owner = users.identifier WHERE plate = @plate', {
            ['@plate'] = plate
        }, function(result)
            if result[1] then
                local ownerName = ('%s %s'):format(result[1].firstname, result[1].lastname)
                exports.ox_inventory:AddItem(source, 'vehicle_key', 1, {
                    label = ('Clés %s - %s'):format(ownerName, plate),
                    owner = ownerName,
                    plate = plate
                })
            end
        end)
    end)
end)

ESX.RegisterServerCallback('illama_keyscreator:getKeysCost', function(source, cb, plate)
    if not keysCounts[plate] then
        keysCounts[plate] = 0
    end
    cb(keysCounts[plate] > 0 and 5000 or 0)
end)

-- Mettre à jour l'état de verrouillage
RegisterServerEvent('illama_keyscreator:updateLockState')
AddEventHandler('illama_keyscreator:updateLockState', function(plate, lockState)
    MySQL.Async.execute('UPDATE illama_keys SET locked = @locked WHERE plate = @plate', {
        ['@plate'] = plate,
        ['@locked'] = lockState
    })
end)

-- Récupérer les clés du joueur au chargement
ESX.RegisterServerCallback('illama_keyscreator:getPlayerKeys', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    MySQL.Async.fetchAll('SELECT plate FROM illama_keys WHERE owner = @owner AND has_key = 1', {
        ['@owner'] = xPlayer.identifier
    }, function(keys)
        local playerKeys = {}
        for _, key in ipairs(keys) do
            playerKeys[key.plate] = true
        end
        cb(playerKeys)
    end)
end)

-- Modifier la partie du serveur qui gère les tentatives de vol
RegisterServerEvent('illama_keyscreator:registerTheftAttempt')
AddEventHandler('illama_keyscreator:registerTheftAttempt', function(plate)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not theftAttempts[plate] then
        theftAttempts[plate] = { count = 1, timeout = nil }
    else
        theftAttempts[plate].count = theftAttempts[plate].count + 1
    end

    -- Reset après 1 minute
    if theftAttempts[plate].timeout then
        ESX.ClearTimeout(theftAttempts[plate].timeout)
    end
    
    theftAttempts[plate].timeout = ESX.SetTimeout(60000, function()
        theftAttempts[plate] = nil
    end)

    -- Après 3 tentatives, trouver le propriétaire et l'alerter
    if theftAttempts[plate].count >= 3 then
        MySQL.Async.fetchAll('SELECT owner FROM owned_vehicles WHERE plate = @plate', {
            ['@plate'] = plate
        }, function(result)
            if result[1] then
                local owner = result[1].owner
                local xPlayer = ESX.GetPlayerFromIdentifier(owner)
                if xPlayer then
                    TriggerClientEvent('illama_keyscreator:carTheftAlert', xPlayer.source, plate)
                end
            end
        end)
        -- Reset les tentatives
        theftAttempts[plate] = nil
    end
end)