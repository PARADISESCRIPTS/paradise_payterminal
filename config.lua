Config = {}

Config.ItemName = 'payment_terminal'

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
    useSnipeBanking = true,
    createTransactions = true,
}