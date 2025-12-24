Config = {}

Config.ItemName = 'payment_terminal'

Config.BusinessItemName = 'business_terminal'

Config.UseSameItem = false

Config.Target = 'ox'  -- use 'ox' for ox_target or use 'qb' for qb-target

Config.MaxDistance = 5.0

Config.MaxAmount = 999999

Config.MinAmount = 1

Config.BillExpireTime = 300

Config.MaxTip = 999999

Config.PaymentMethods = {
    {value = 'cash', label = 'Cash'},
    {value = 'bank', label = 'Bank'}
}

Config.Businesses = {
    ['mechanic'] = {
        name = 'Mechanic',
        jobs = {'mechanic'},
        employeePercentage = 15, 
        businessAccount = 'mechanic',
        locations = {
            vector3(-227.83, -1327.92, 29.89)
        }
    },
}

Config.Banking = {
    system = 'snipe', -- use 'snipe' for snipe-banking or use 'qb' for qb-management
    useSnipeBanking = true,
    createTransactions = true,
}