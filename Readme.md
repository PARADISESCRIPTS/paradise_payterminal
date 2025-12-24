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

### IF Using qb-inventory add this in qb-core/shared/items.lua

```
    ['payment_terminal'] = {
        ['name'] = 'payment_terminal',
        ['label'] = 'Payment Terminal',
        ['weight'] = 500,
        ['type'] = 'item',
        ['image'] = 'payment_terminal.png',
        ['unique'] = false,
        ['useable'] = true,
        ['shouldClose'] = true,
        ['description'] = 'A portable payment terminal'
    },

    ['business_terminal'] = {
        ['name'] = 'business_terminal',
        ['label'] = 'Business Terminal',
        ['weight'] = 500,
        ['type'] = 'item',
        ['image'] = 'business_terminal.png',
        ['unique'] = false,
        ['useable'] = true,
        ['shouldClose'] = true,
        ['description'] = 'A business payment terminal for employees'
    },
```