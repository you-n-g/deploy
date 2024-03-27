

local harpoon = require"harpoon"


print(harpoon:list())
print(harpoon.config)
print(harpoon.config.settings.save_on_toggle)
print(harpoon:settings())

local conf = require"harpoon.config"

print(conf)
print(conf.get_default_config())
print(conf.settings)
