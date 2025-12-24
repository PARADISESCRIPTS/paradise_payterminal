local QBCore = exports['qb-core']:GetCoreObject()

local function GetFramework()
    if GetResourceState('qbx_core') == 'started' then
        return 'qbx'
    elseif GetResourceState('qb-core') == 'started' then
        return 'qb'
    end
    return nil
end

local Framework = GetFramework()

CreateThread(function()
    for businessId, business in pairs(Config.Businesses) do
        for i, coords in ipairs(business.locations) do
            exports.ox_target:addSphereZone({
                coords = coords,
                radius = 1.0,
                debug = false,
                options = {
                    {
                        name = 'business_terminal_' .. businessId .. '_' .. i,
                        icon = 'fas fa-cash-register',
                        label = business.name .. ' Terminal',
                        canInteract = function()
                            local PlayerData = QBCore.Functions.GetPlayerData()
                            if not PlayerData or not PlayerData.job then return false end
                            
                            local playerJob = PlayerData.job.name
                            for _, job in ipairs(business.jobs) do
                                if job == playerJob then
                                    return true
                                end
                            end
                            return false
                        end,
                        onSelect = function()
                            startBusinessTerminal(businessId, business)
                        end
                    }
                }
            })
        end
    end
end)

RegisterNetEvent('paradise_payterminal:client:useItem', function()
    if Config.UseSameItem then
        showTerminalSelection()
    else
        startPaymentTerminal(false)
    end
end)

RegisterNetEvent('paradise_payterminal:client:useBusinessItem', function()
    if Config.UseSameItem then
        showTerminalSelection()
    else
        local PlayerData = QBCore.Functions.GetPlayerData()
        if not PlayerData or not PlayerData.job or not PlayerData.job.onduty then
            lib.notify({
                title = 'Business Terminal',
                description = 'You must be on duty to use the business terminal',
                type = 'error'
            })
            return
        end
        
        local playerJob = PlayerData.job.name
        local businessInfo = nil
        
        for businessId, business in pairs(Config.Businesses) do
            for _, job in ipairs(business.jobs) do
                if job == playerJob then
                    businessInfo = {
                        id = businessId,
                        name = business.name,
                        employeePercentage = business.employeePercentage,
                        isEmployee = true
                    }
                    break
                end
            end
            if businessInfo then break end
        end
        
        if not businessInfo then
            lib.notify({
                title = 'Business Terminal',
                description = 'You are not authorized to use any business terminal',
                type = 'error'
            })
            return
        end
        
        startPaymentTerminal(true, businessInfo)
    end
end)

function showTerminalSelection()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        startPaymentTerminal(false)
        return
    end
    
    local playerJob = PlayerData.job.name
    local isOnDuty = PlayerData.job.onduty
    local availableBusinesses = {}
    
    for businessId, business in pairs(Config.Businesses) do
        for _, job in ipairs(business.jobs) do
            if job == playerJob and isOnDuty then
                table.insert(availableBusinesses, {
                    id = businessId,
                    name = business.name,
                    business = business
                })
                break
            end
        end
    end
    
    if #availableBusinesses == 0 then
        startPaymentTerminal(false)
        return
    end
    
    local terminalOptions = {
        {value = 'personal', label = 'Personal Terminal'}
    }
    
    for _, businessData in ipairs(availableBusinesses) do
        table.insert(terminalOptions, {
            value = businessData.id,
            label = businessData.name .. ' Terminal'
        })
    end
    
    local input = lib.inputDialog('Payment Terminal', {
        {
            type = 'select',
            label = 'Select Terminal Type',
            description = 'Choose which terminal to use',
            options = terminalOptions,
            required = true
        }
    })
    
    if not input then return end
    
    local selectedOption = input[1]
    
    if selectedOption == 'personal' then
        startPaymentTerminal(false)
    else
        for _, businessData in ipairs(availableBusinesses) do
            if businessData.id == selectedOption then
                local businessInfo = {
                    id = businessData.id,
                    name = businessData.name,
                    employeePercentage = businessData.business.employeePercentage,
                    isEmployee = true
                }
                startPaymentTerminal(true, businessInfo)
                break
            end
        end
    end
end

function startBusinessTerminal(businessId, business)
    TriggerServerEvent('paradise_payterminal:server:checkBusinessAccess', businessId)
end

RegisterNetEvent('paradise_payterminal:client:businessAccessResult', function(canUse, businessInfo, errorMsg)
    if canUse then
        startPaymentTerminal(true, businessInfo)
    else
        lib.notify({
            title = 'Access Denied',
            description = errorMsg or 'You cannot use this business terminal',
            type = 'error'
        })
    end
end)

function startPaymentTerminal(isBusiness, businessInfo)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local nearbyPlayerIds = {}
    
    for _, playerId in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(playerId)
        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(playerCoords - targetCoords)
        
        if distance <= Config.MaxDistance and playerId ~= PlayerId() then
            local targetServerId = GetPlayerServerId(playerId)
            table.insert(nearbyPlayerIds, targetServerId)
        end
    end
    
    if #nearbyPlayerIds == 0 then
        lib.notify({
            title = 'Payment Terminal',
            description = 'No players nearby to bill',
            type = 'error'
        })
        return
    end
    
    TriggerServerEvent('paradise_payterminal:server:getNearbyPlayers', nearbyPlayerIds, isBusiness, businessInfo)
end

RegisterNetEvent('paradise_payterminal:client:receiveNearbyPlayers', function(nearbyPlayers, businessInfo)
    local dialogTitle = businessInfo and (businessInfo.name .. ' - Payment Terminal') or 'Payment Terminal'
    
    local input = lib.inputDialog(dialogTitle, {
        {
            type = 'select',
            label = businessInfo and 'Select Customer' or 'Select Player',
            options = nearbyPlayers,
            required = true
        },
        {
            type = 'number',
            label = 'Amount',
            description = 'Enter the amount to bill',
            required = true,
            min = Config.MinAmount,
            max = Config.MaxAmount
        },
        {
            type = 'select',
            label = 'Payment Method',
            options = Config.PaymentMethods,
            required = true
        },
        {
            type = 'input',
            label = businessInfo and 'Service Description' or 'Description (Optional)',
            description = businessInfo and 'What service was provided?' or 'What is this payment for?',
            placeholder = businessInfo and (businessInfo.name .. ' service') or 'Service description...',
            required = businessInfo and true or false
        }
    })
    
    if not input then return end
    
    local targetId = input[1]
    local amount = input[2]
    local paymentMethod = input[3]
    local description = input[4] or (businessInfo and (businessInfo.name .. ' Service') or 'Payment Terminal Bill')
    
    TriggerServerEvent('paradise_payterminal:server:sendBill', targetId, amount, paymentMethod, description, businessInfo)
end)

RegisterNetEvent('paradise_payterminal:client:receiveBill', function(senderId, amount, paymentMethod, description, billId, senderName)
    lib.notify({
        title = 'Payment Request',
        description = senderName .. ' sent you a bill for $' .. amount,
        type = 'inform',
        duration = 5000
    })
    
    local alert = lib.alertDialog({
        header = 'Payment Request',
        content = senderName .. ' is requesting payment of $' .. amount .. '\n\nDescription: ' .. description .. '\nPayment Method: ' .. string.upper(paymentMethod),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Pay Bill',
            cancel = 'Decline'
        }
    })
    
    if alert == 'confirm' then
        local tipInput = lib.inputDialog('Add Tip?', {
            {
                type = 'number',
                label = 'Tip Amount (Optional)',
                description = 'Add a tip to the payment',
                min = 0,
                max = Config.MaxTip,
                default = 0
            }
        })
        
        local tipAmount = 0
        if tipInput and tipInput[1] then
            tipAmount = tipInput[1]
        end
        
        TriggerServerEvent('paradise_payterminal:server:payBill', billId, senderId, amount, tipAmount, paymentMethod)
    else
        TriggerServerEvent('paradise_payterminal:server:declineBill', billId, senderId)
    end
end)

RegisterNetEvent('paradise_payterminal:client:paymentSuccess', function(amount, tipAmount, paymentMethod)
    local totalAmount = amount + tipAmount
    local tipText = tipAmount > 0 and ' (including $' .. tipAmount .. ' tip)' or ''
    
    lib.notify({
        title = 'Payment Successful',
        description = 'You paid $' .. totalAmount .. tipText .. ' via ' .. string.upper(paymentMethod),
        type = 'success'
    })
end)

RegisterNetEvent('paradise_payterminal:client:paymentFailed', function(reason)
    lib.notify({
        title = 'Payment Failed',
        description = reason,
        type = 'error'
    })
end)

RegisterNetEvent('paradise_payterminal:client:billPaid', function(payerName, amount, tipAmount, paymentMethod)
    local totalAmount = amount + tipAmount
    local tipText = tipAmount > 0 and ' (including $' .. tipAmount .. ' tip)' or ''
    
    lib.notify({
        title = 'Bill Paid',
        description = payerName .. ' paid your bill of $' .. totalAmount .. tipText .. ' via ' .. string.upper(paymentMethod),
        type = 'success'
    })
end)

RegisterNetEvent('paradise_payterminal:client:billDeclined', function(payerName)
    lib.notify({
        title = 'Bill Declined',
        description = payerName .. ' declined to pay the bill',
        type = 'error'
    })
end)

RegisterNetEvent('paradise_payterminal:client:employeeEarnings', function(earnings, tipAmount, businessName)
    local totalEarnings = earnings + tipAmount
    local tipText = tipAmount > 0 and ' + $' .. tipAmount .. ' tip' or ''
    
    lib.notify({
        title = 'Employee Earnings',
        description = 'You earned $' .. earnings .. tipText .. ' from ' .. businessName,
        type = 'success',
        duration = 7000
    })
end)