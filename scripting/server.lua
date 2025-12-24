local QBCore
local isQBX = Config.Framework == 'qbx'

if isQBX then
    QBCore = exports.qbx_core
else
    QBCore = exports['qb-core']:GetCoreObject()
end

local activeBills = {}
local billIdCounter = 0

if isQBX then
    exports.qbx_core:CreateUseableItem(Config.ItemName, function(source, item)
        TriggerClientEvent('paradise_payterminal:client:useItem', source)
    end)
    
    if not Config.UseSameItem then
        exports.qbx_core:CreateUseableItem(Config.BusinessItemName, function(source, item)
            TriggerClientEvent('paradise_payterminal:client:useBusinessItem', source)
        end)
    end
else
    QBCore.Functions.CreateUseableItem(Config.ItemName, function(source, item)
        TriggerClientEvent('paradise_payterminal:client:useItem', source)
    end)
    
    if not Config.UseSameItem then
        QBCore.Functions.CreateUseableItem(Config.BusinessItemName, function(source, item)
            TriggerClientEvent('paradise_payterminal:client:useBusinessItem', source)
        end)
    end
end

local function GetPlayer(source)
    if isQBX then
        return exports.qbx_core:GetPlayer(source)
    else
        return QBCore.Functions.GetPlayer(source)
    end
end

local function RemoveMoney(Player, moneyType, amount, reason)
    if isQBX then
        return Player.Functions.RemoveMoney(moneyType, amount, reason)
    else
        return Player.Functions.RemoveMoney(moneyType, amount, reason)
    end
end

local function AddMoney(Player, moneyType, amount, reason)
    if isQBX then
        return Player.Functions.AddMoney(moneyType, amount, reason)
    else
        return Player.Functions.AddMoney(moneyType, amount, reason)
    end
end

local function GetPlayerMoney(Player, moneyType)
    if isQBX then
        return Player.PlayerData.money[moneyType] or 0
    else
        return Player.PlayerData.money[moneyType] or 0
    end
end

local function GetPlayerName(Player)
    if isQBX then
        return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    else
        return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    end
end

local function SendDiscordLog(title, description, color, fields)
    if not Paradise.DiscordLogging.enabled or not Paradise.DiscordLogging.webhook or Paradise.DiscordLogging.webhook == 'YOUR_DISCORD_WEBHOOK_URL_HERE' then
        return
    end

    local embed = {
        {
            title = title,
            description = description,
            color = color or Paradise.DiscordLogging.embedColor,
            fields = fields or {},
            footer = {
                text = 'Payment Terminal System',
                icon_url = 'https://cdn.discordapp.com/emojis/1234567890123456789.png'
            },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        }
    }

    PerformHttpRequest(Paradise.DiscordLogging.webhook, function(err, text, headers) end, 'POST', json.encode({
        username = Paradise.DiscordLogging.botName,
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

local function AddMoneyToBusiness(businessAccount, amount, memo)
    if not Config.Banking then
        print('^1[ERROR] Config.Banking is nil - config file not loaded properly^7')
        return false
    end
    
    if Config.Banking.system == 'snipe' and GetResourceState('snipe-banking') == 'started' then
        exports['snipe-banking']:AddMoneyToAccount(businessAccount, amount)
        
        if Config.Banking.createTransactions then
            exports['snipe-banking']:CreateJobTransactions(
                businessAccount,
                amount,
                memo or 'Payment Terminal Revenue',
                'deposit',
                'system',
                nil,
                true
            )
        end
        return true
    elseif Config.Banking.system == 'qb' and GetResourceState('qb-management') == 'started' then
        exports['qb-management']:AddMoney(businessAccount, amount)
        return true
    end
    return false
end

local function CreatePersonalTransaction(Player, amount, memo, transactionType, otherPlayer)
    if not Config.Banking then return end
    
    if Config.Banking.system == 'snipe' and Config.Banking.createTransactions and GetResourceState('snipe-banking') == 'started' then
        local playerIdentifier = GetPlayerIdentifier(Player)
        local otherIdentifier = otherPlayer and GetPlayerIdentifier(otherPlayer) or nil
        
        exports['snipe-banking']:CreatePersonalTransactions(
            playerIdentifier,
            amount,
            memo,
            transactionType,
            otherIdentifier,
            false
        )
    end
end

local function GetPlayerIdentifier(Player)
    if isQBX then
        return Player.PlayerData.citizenid
    else
        return Player.PlayerData.citizenid
    end
end

RegisterNetEvent('paradise_payterminal:server:checkBusinessAccess', function(businessId)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player then return end
    
    local business = Config.Businesses[businessId]
    if not business then
        TriggerClientEvent('paradise_payterminal:client:businessAccessResult', src, false, nil, 'Business not found')
        return
    end
    
    local playerJob = Player.PlayerData.job.name
    local isEmployee = false
    
    for _, job in ipairs(business.jobs) do
        if job == playerJob then
            isEmployee = true
            break
        end
    end
    
    if not isEmployee then
        TriggerClientEvent('paradise_payterminal:client:businessAccessResult', src, false, nil, 'You are not an employee of ' .. business.name)
        return
    end
    
    local businessInfo = {
        id = businessId,
        name = business.name,
        employeePercentage = business.employeePercentage,
        isEmployee = true
    }
    
    TriggerClientEvent('paradise_payterminal:client:businessAccessResult', src, true, businessInfo)
end)

RegisterNetEvent('paradise_payterminal:server:getNearbyPlayers', function(playerIds, isBusiness, businessInfo)
    local src = source
    local Player = GetPlayer(src)
    local nearbyPlayersWithNames = {}
    
    for _, playerId in ipairs(playerIds) do
        local TargetPlayer = GetPlayer(playerId)
        if TargetPlayer then
            local playerName = GetPlayerName(TargetPlayer)
            table.insert(nearbyPlayersWithNames, {
                value = playerId,
                label = 'ID: ' .. playerId .. ' - ' .. playerName
            })
        end
    end
    
    TriggerClientEvent('paradise_payterminal:client:receiveNearbyPlayers', src, nearbyPlayersWithNames, businessInfo)
end)

RegisterNetEvent('paradise_payterminal:server:sendBill', function(targetId, amount, paymentMethod, description, businessInfo)
    local src = source
    local Player = GetPlayer(src)
    local TargetPlayer = GetPlayer(targetId)
    
    if not Player or not TargetPlayer then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Payment Terminal',
            description = 'Player not found',
            type = 'error'
        })
        return
    end
    
    billIdCounter = billIdCounter + 1
    local billId = 'bill_' .. billIdCounter
    
    activeBills[billId] = {
        senderId = src,
        targetId = targetId,
        amount = amount,
        paymentMethod = paymentMethod,
        description = description,
        timestamp = os.time(),
        businessInfo = businessInfo
    }
    
    local senderName = GetPlayerName(Player)
    if businessInfo then
        senderName = senderName .. ' (' .. businessInfo.name .. ')'
    end
    TriggerClientEvent('paradise_payterminal:client:receiveBill', targetId, src, amount, paymentMethod, description, billId, senderName)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Payment Terminal',
        description = 'Bill sent to ' .. GetPlayerName(TargetPlayer),
        type = 'success'
    })
end)

RegisterNetEvent('paradise_payterminal:server:payBill', function(billId, senderId, amount, tipAmount, paymentMethod)
    local src = source
    local Player = GetPlayer(src)
    local SenderPlayer = GetPlayer(senderId)
    
    if not Player or not SenderPlayer then
        TriggerClientEvent('paradise_payterminal:client:paymentFailed', src, 'Player not found')
        return
    end
    
    if not activeBills[billId] then
        TriggerClientEvent('paradise_payterminal:client:paymentFailed', src, 'Bill not found or expired')
        return
    end
    
    local billData = activeBills[billId]
    local totalAmount = amount + tipAmount
    local playerName = GetPlayerName(Player)
    
    local hasEnoughMoney = GetPlayerMoney(Player, paymentMethod) >= totalAmount
    
    if not hasEnoughMoney then
        TriggerClientEvent('paradise_payterminal:client:paymentFailed', src, 'Insufficient funds')
        return
    end
    
    RemoveMoney(Player, paymentMethod, totalAmount, 'paradise_payterminal-bill')
    
    if billData.businessInfo and billData.businessInfo.isEmployee then
        local businessInfo = billData.businessInfo
        local employeePercentage = businessInfo.employeePercentage
        local employeeEarnings = math.floor(amount * (employeePercentage / 100))
        local businessEarnings = amount - employeeEarnings
        
        AddMoney(SenderPlayer, paymentMethod, employeeEarnings + tipAmount, 'business-employee-earnings')
        
        local businessAccount = Config.Businesses[businessInfo.id].businessAccount
        local businessAdded = AddMoneyToBusiness(businessAccount, businessEarnings, 'Payment Terminal Revenue - ' .. billData.description)
        
        if Config.Banking.system == 'snipe' and Config.Banking.createTransactions and GetResourceState('snipe-banking') == 'started' then
            CreatePersonalTransaction(SenderPlayer, employeeEarnings + tipAmount, 'Payment Terminal Earnings - ' .. billData.description, 'deposit', Player)
            CreatePersonalTransaction(Player, totalAmount, 'Payment Terminal Bill - ' .. billData.description, 'withdraw', SenderPlayer)
        end
        
        TriggerClientEvent('paradise_payterminal:client:employeeEarnings', senderId, employeeEarnings, tipAmount, businessInfo.name)
        
        if Paradise.DiscordLogging.logTypes.businessPayments then
            local fields = {
                {name = 'Customer', value = playerName .. ' (ID: ' .. src .. ')', inline = true},
                {name = 'Employee', value = GetPlayerName(SenderPlayer) .. ' (ID: ' .. senderId .. ')', inline = true},
                {name = 'Business', value = businessInfo.name, inline = true},
                {name = 'Total Amount', value = '$' .. totalAmount, inline = true},
                {name = 'Employee Earnings', value = '$' .. (employeeEarnings + tipAmount) .. ' (' .. employeePercentage .. '% + tip)', inline = true},
                {name = 'Business Earnings', value = '$' .. businessEarnings, inline = true},
                {name = 'Payment Method', value = string.upper(paymentMethod), inline = true},
                {name = 'Service', value = billData.description, inline = false}
            }
            
            if tipAmount > 0 then
                table.insert(fields, {name = 'Tip Amount', value = '$' .. tipAmount, inline = true})
            end
            
            SendDiscordLog(
                '💼 Business Payment Processed',
                'A business transaction has been completed with employee percentage split.',
                65280,
                fields
            )
        end
    else
        AddMoney(SenderPlayer, paymentMethod, totalAmount, 'paradise_payterminal-received')
        
        if Config.Banking.system == 'snipe' and Config.Banking.createTransactions and GetResourceState('snipe-banking') == 'started' then
            CreatePersonalTransaction(SenderPlayer, totalAmount, 'Payment Terminal Payment - ' .. billData.description, 'deposit', Player)
            CreatePersonalTransaction(Player, totalAmount, 'Payment Terminal Bill - ' .. billData.description, 'withdraw', SenderPlayer)
        end
        
        if Paradise.DiscordLogging.logTypes.payments then
            local fields = {
                {name = 'Payer', value = playerName .. ' (ID: ' .. src .. ')', inline = true},
                {name = 'Receiver', value = GetPlayerName(SenderPlayer) .. ' (ID: ' .. senderId .. ')', inline = true},
                {name = 'Amount', value = '$' .. amount, inline = true},
                {name = 'Payment Method', value = string.upper(paymentMethod), inline = true},
                {name = 'Description', value = billData.description, inline = false}
            }
            
            if tipAmount > 0 then
                table.insert(fields, {name = 'Tip Amount', value = '$' .. tipAmount, inline = true})
                table.insert(fields, {name = 'Total Paid', value = '$' .. totalAmount, inline = true})
            end
            
            SendDiscordLog(
                '💳 Payment Processed',
                'A payment terminal transaction has been completed.',
                3447003,
                fields
            )
        end
    end
    
    TriggerClientEvent('paradise_payterminal:client:paymentSuccess', src, amount, tipAmount, paymentMethod)
    TriggerClientEvent('paradise_payterminal:client:billPaid', senderId, playerName, amount, tipAmount, paymentMethod)
    
    activeBills[billId] = nil
end)

RegisterNetEvent('paradise_payterminal:server:declineBill', function(billId, senderId)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player then return end
    
    if not activeBills[billId] then return end
    
    local billData = activeBills[billId]
    local playerName = GetPlayerName(Player)
    local SenderPlayer = GetPlayer(senderId)
    
    TriggerClientEvent('paradise_payterminal:client:billDeclined', senderId, playerName)
    
    if Paradise.DiscordLogging.logTypes.declinedBills and SenderPlayer then
        local fields = {
            {name = 'Customer', value = playerName .. ' (ID: ' .. src .. ')', inline = true},
            {name = 'Biller', value = GetPlayerName(SenderPlayer) .. ' (ID: ' .. senderId .. ')', inline = true},
            {name = 'Amount', value = '$' .. billData.amount, inline = true},
            {name = 'Payment Method', value = string.upper(billData.paymentMethod), inline = true},
            {name = 'Description', value = billData.description, inline = false}
        }
        
        if billData.businessInfo then
            table.insert(fields, {name = 'Business', value = billData.businessInfo.name, inline = true})
        end
        
        SendDiscordLog(
            '❌ Payment Declined',
            'A payment terminal bill has been declined by the customer.',
            16711680,
            fields
        )
    end
    
    activeBills[billId] = nil
end)

CreateThread(function()
    while true do
        Wait(60000)
        local currentTime = os.time()
        
        for billId, billData in pairs(activeBills) do
            if currentTime - billData.timestamp > Config.BillExpireTime then
                activeBills[billId] = nil
            end
        end
    end
end)