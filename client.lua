local isPlacing = false
local isRepositioning = false
local previewPed = nil
local selectedModel = nil
local spawnedPeds = {}
local selectedAnimationIndex = 1
local repositioningData = nil

function RayCastGamePlayCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        cameraCoord.x, cameraCoord.y, cameraCoord.z,
        destination.x, destination.y, destination.z,
        1, PlayerPedId(), 4
    )
    local _, hit, endCoords, _, entity = GetShapeTestResult(rayHandle)
    return hit, endCoords, entity
end

function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

function PlacePed(coords, heading)
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    
    print("Creating ped with model:", selectedModel)
    print("At coords:", coords.x, coords.y, coords.z)
    print("With heading:", heading)
    print("Animation index:", selectedAnimationIndex)
    
    local ped = CreatePed(4, GetHashKey(selectedModel), coords.x, coords.y, coords.z, heading or 0.0, true, true)
    
    if not DoesEntityExist(ped) then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"Error", "Failed to create ped"}
        })
        return
    end
    
    SetPedRandomComponentVariation(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    FreezeEntityPosition(ped, true)
    
    table.insert(spawnedPeds, {
        handle = ped,
        animation = selectedAnimationIndex
    })
    
    ApplyPedAnimation(ped, selectedAnimationIndex)
    
    TriggerEvent('chat:addMessage', {
        color = {0, 255, 0},
        multiline = true,
        args = {"Success", "Ped has been placed with " .. PedAnimations[selectedAnimationIndex].label .. " animation"}
    })
    
    lib.hideTextUI()
    
    isPlacing = false
    previewPed = nil
    
    SetModelAsNoLongerNeeded(GetHashKey(selectedModel))
end

function CancelPlacement()
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    
    lib.hideTextUI()
    
    TriggerEvent('chat:addMessage', {
        color = {255, 165, 0},
        multiline = true,
        args = {"Cancelled", "Ped placement cancelled"}
    })
    
    isPlacing = false
    previewPed = nil
    
    if selectedModel then
        SetModelAsNoLongerNeeded(GetHashKey(selectedModel))
    end
end

function BeginPedPlacement()
    if not LoadModel(selectedModel) then 
        return 
    end
    
    isPlacing = true
    local pedHeading = 0.0
    
    local coords = GetEntityCoords(PlayerPedId())
    previewPed = CreatePed(4, GetHashKey(selectedModel), coords.x, coords.y, coords.z - 1.0, pedHeading, false, false)
    
    if not DoesEntityExist(previewPed) then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"Error", "Failed to create preview ped"}
        })
        isPlacing = false
        return
    end
    
    SetEntityAlpha(previewPed, 200, false)
    FreezeEntityPosition(previewPed, true)
    SetEntityCollision(previewPed, false, false)
    
    if selectedAnimationIndex > 1 then
        ApplyPedAnimation(previewPed, selectedAnimationIndex)
    end
    
    lib.showTextUI('[ENTER] Place Ped | [SCROLL] Rotate | [ESC] Cancel', {
        position = "top-center",
        icon = 'user',
        style = {
            borderRadius = 0,
            backgroundColor = '#141517',
            color = 'white'
        }
    })
    
    CreateThread(function()
        while isPlacing do
            Wait(0)
            
            local hit, coords, entity = RayCastGamePlayCamera(10.0)
            
            if hit then
                
                SetEntityCoords(previewPed, coords.x, coords.y, coords.z, false, false, false, false)
                SetEntityHeading(previewPed, pedHeading)
                
                if IsControlJustPressed(0, 14) then
                    pedHeading = pedHeading + 15.0
                    if pedHeading >= 360.0 then pedHeading = 0.0 end
                    SetEntityHeading(previewPed, pedHeading)
                elseif IsControlJustPressed(0, 15) then
                    pedHeading = pedHeading - 15.0
                    if pedHeading < 0.0 then pedHeading = 345.0 end
                    SetEntityHeading(previewPed, pedHeading)
                end
                
                if IsControlJustPressed(0, 18) then
                    PlacePed(coords, pedHeading)
                    break
                end
            end
            
            if IsControlJustPressed(0, 194) then
                CancelPlacement()
                break
            end
        end
    end)
end

function BeginRepositioningPed(pedData, pedIndex)
    if isPlacing or isRepositioning then
        return
    end
    
    local ped = pedData.handle
    
    if not DoesEntityExist(ped) then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"Error", "Ped no longer exists"}
        })
        return
    end
    
    isRepositioning = true
    local pedHeading = GetEntityHeading(ped)
    local pedModel = GetEntityModel(ped)
    local pedAnimation = pedData.animation or 1
    
    local pedCoords = GetEntityCoords(ped)
    previewPed = CreatePed(4, pedModel, pedCoords.x, pedCoords.y, pedCoords.z, pedHeading, false, false)
    SetEntityAlpha(previewPed, 200, false)
    FreezeEntityPosition(previewPed, true)
    SetEntityCollision(previewPed, false, false)
    
    if pedAnimation > 1 then
        ApplyPedAnimation(previewPed, pedAnimation)
    end
    
    SetEntityAlpha(ped, 0, false)
    
    lib.showTextUI('[ENTER] Place Ped | [SCROLL] Rotate | [ESC] Cancel', {
        position = "top-center",
        icon = 'user',
        style = {
            borderRadius = 0,
            backgroundColor = '#141517',
            color = 'white'
        }
    })
    
    repositioningData = {
        pedIndex = pedIndex,
        animation = pedAnimation
    }
    
    CreateThread(function()
        while isRepositioning do
            Wait(0)
            
            local hit, coords, entity = RayCastGamePlayCamera(10.0)
            
            if hit then
                SetEntityCoords(previewPed, coords.x, coords.y, coords.z, false, false, false, false)
                SetEntityHeading(previewPed, pedHeading)
                
                if IsControlJustPressed(0, 14) then
                    pedHeading = pedHeading + 15.0
                    if pedHeading >= 360.0 then pedHeading = 0.0 end
                    SetEntityHeading(previewPed, pedHeading)
                elseif IsControlJustPressed(0, 15) then -- Mouse wheel up
                    pedHeading = pedHeading - 15.0
                    if pedHeading < 0.0 then pedHeading = 345.0 end
                    SetEntityHeading(previewPed, pedHeading)
                end
                
                if IsControlJustPressed(0, 18) then
                    FinishRepositioningPed(coords, pedHeading)
                    break
                end
            end
            
            if IsControlJustPressed(0, 194) then
                CancelRepositioningPed()
                break
            end
        end
    end)
end

function FinishRepositioningPed(coords, heading)
    if not repositioningData then return end
    
    local pedIndex = repositioningData.pedIndex
    local animIndex = repositioningData.animation
    
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    
    local ped = spawnedPeds[pedIndex].handle
    
    if DoesEntityExist(ped) then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(ped, heading)
        SetEntityAlpha(ped, 255, false)
        FreezeEntityPosition(ped, true)
        
        ClearPedTasksImmediately(ped)
        ApplyPedAnimation(ped, animIndex)
        
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 0},
            multiline = true,
            args = {"Success", "Ped repositioned"}
        })
    else
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"Error", "Ped no longer exists"}
        })
    end
    
    lib.hideTextUI()
    
    isRepositioning = false
    previewPed = nil
    repositioningData = nil
end

function CancelRepositioningPed()
    if not repositioningData then return end
    
    local pedIndex = repositioningData.pedIndex
    
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    
    local ped = spawnedPeds[pedIndex].handle
    
    if DoesEntityExist(ped) then
        SetEntityAlpha(ped, 255, false)
    end
    
    lib.hideTextUI()
    
    TriggerEvent('chat:addMessage', {
        color = {255, 165, 0},
        multiline = true,
        args = {"Cancelled", "Ped repositioning cancelled"}
    })
    
    isRepositioning = false
    previewPed = nil
    repositioningData = nil
end

function ChangeAnimation(pedIndex)
    local pedData = spawnedPeds[pedIndex]
    if not pedData or not DoesEntityExist(pedData.handle) then
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"Error", "Selected ped no longer exists"}
        })
        return
    end
    
    local animOptions = {}
    for i, animInfo in ipairs(PedAnimations) do
        table.insert(animOptions, {label = animInfo.label, value = i})
    end
    
    local input = lib.inputDialog('Change Animation', {
        {
            type = 'select', 
            label = 'Select animation', 
            options = animOptions, 
            default = pedData.animation or 1
        }
    })
    
    if input and input[1] then
        local newAnimIndex = input[1]
        pedData.animation = newAnimIndex
        
        ClearPedTasksImmediately(pedData.handle)
        
        ApplyPedAnimation(pedData.handle, newAnimIndex)
        
        FreezeEntityPosition(pedData.handle, true)
        
        TriggerEvent('chat:addMessage', {
            color = {0, 255, 0},
            multiline = true,
            args = {"Success", "Animation changed to " .. PedAnimations[newAnimIndex].label}
        })
    end
end

function OpenSpawnDialog()
    local pedOptions = {}
    for _, pedInfo in ipairs(PedModels) do
        table.insert(pedOptions, {label = pedInfo.label, value = pedInfo.model})
    end
    
    local animOptions = {}
    for i, animInfo in ipairs(PedAnimations) do
        table.insert(animOptions, {label = animInfo.label, value = i})
    end
    
    local input = lib.inputDialog('Ped Spawner', {
        {type = 'select', label = 'Select a ped model', options = pedOptions, required = true},
        {type = 'select', label = 'Select animation (optional)', options = animOptions, default = 1}
    })
    
    if input and input[1] then
        selectedModel = input[1]
        selectedAnimationIndex = input[2] or 1
        
        print("Selected model:", selectedModel)
        print("Selected animation index:", selectedAnimationIndex)
        
        BeginPedPlacement()
    end
end

-- Command to open the ped menu
RegisterCommand('pedmenu', function()
    local options = {}
    
    table.insert(options, {
        title = 'Spawn New Ped',
        description = 'Create a new ped in the world',
        icon = 'user-plus',
        onSelect = function()
            OpenSpawnDialog()
        end
    })
    
    local pedCount = 0
    for i, pedData in ipairs(spawnedPeds) do
        local ped = pedData.handle
        if DoesEntityExist(ped) then
            pedCount = pedCount + 1
            local pedCoords = GetEntityCoords(ped)
            local pedModel = GetEntityModel(ped)
            local modelName = GetModelNameFromHash(pedModel)
            local animName = PedAnimations[pedData.animation or 1].label
            
            table.insert(options, {
                title = modelName .. ' #' .. i,
                description = 'Location: ' .. math.floor(pedCoords.x) .. ', ' .. math.floor(pedCoords.y),
                icon = 'user',
                menu = 'ped_' .. i,
                metadata = {
                    {label = 'Model', value = modelName},
                    {label = 'Animation', value = animName},
                    {label = 'Position', value = math.floor(pedCoords.x) .. ', ' .. math.floor(pedCoords.y) .. ', ' .. math.floor(pedCoords.z)}
                }
            })
            
            lib.registerContext({
                id = 'ped_' .. i,
                title = 'Manage: ' .. modelName .. ' #' .. i,
                menu = 'ped_menu',
                options = {
                    {
                        title = 'Reposition',
                        description = 'Move this ped to a new location',
                        icon = 'arrows-up-down-left-right',
                        onSelect = function()
                            BeginRepositioningPed(pedData, i)
                        end
                    },
                    {
                        title = 'Change Animation',
                        description = 'Apply a different animation to this ped',
                        icon = 'film',
                        onSelect = function()
                            ChangeAnimation(i)
                        end
                    },
                    {
                        title = 'Teleport To',
                        description = 'Teleport yourself to this ped',
                        icon = 'location-arrow',
                        onSelect = function()
                            local pCoords = GetEntityCoords(ped)
                            SetEntityCoords(PlayerPedId(), pCoords.x, pCoords.y, pCoords.z + 1.0, false, false, false, false)
                            TriggerEvent('chat:addMessage', {
                                color = {0, 255, 0},
                                multiline = true,
                                args = {"Success", "Teleported to ped"}
                            })
                        end
                    },
                    {
                        title = 'Delete',
                        description = 'Remove this ped from the world',
                        icon = 'trash',
                        onSelect = function()
                            DeleteEntity(ped)
                            table.remove(spawnedPeds, i)
                            TriggerEvent('chat:addMessage', {
                                color = {0, 255, 0},
                                multiline = true,
                                args = {"Success", "Ped deleted"}
                            })
                        end
                    }
                }
            })
        end
    end
    
    if pedCount > 0 then
        table.insert(options, {
            title = 'Clear All Peds',
            description = 'Remove all placed peds',
            icon = 'trash-can',
            onSelect = function()
                local count = 0
                for _, pedData in ipairs(spawnedPeds) do
                    if DoesEntityExist(pedData.handle) then
                        DeleteEntity(pedData.handle)
                        count = count + 1
                    end
                end
                
                spawnedPeds = {}
                
                TriggerEvent('chat:addMessage', {
                    color = {0, 255, 0},
                    multiline = true,
                    args = {"Peds Cleared", count .. " peds have been removed"}
                })
            end
        })
    end
    
    lib.registerContext({
        id = 'ped_menu',
        title = 'Ped Spawner & Manager',
        options = options
    })
    
    lib.showContext('ped_menu')
end, false)

RegisterKeyMapping('pedmenu', 'Open Ped Menu', 'keyboard', 'F7')

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    
    for _, pedData in ipairs(spawnedPeds) do
        if pedData.handle and DoesEntityExist(pedData.handle) then
            DeleteEntity(pedData.handle)
        end
    end
    
    if isPlacing or isRepositioning then
        lib.hideTextUI()
    end
end)