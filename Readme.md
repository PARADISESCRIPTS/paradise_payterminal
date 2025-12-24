# Paradise Pay Terminal

## Installation

### Add This In ox_inventory/data/items.lua

```
['payment_terminal'] = {
        label = 'Payment Terminal',
        weight = 500,
        stack = true,
        close = true,
        description = 'A portable payment terminal for billing customers',
        client = {
            image = 'payment_terminal.png',
        }
    },

    ['business_terminal'] = {
        label = 'Business Terminal',
        weight = 500,
        stack = true,
        close = true,
        description = 'A portable payment terminal for billing customers',
        client = {
            image = 'business_terminal.png',
        }
    },
```