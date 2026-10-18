local config = require("config")

data:extend({
  {
    type = "int-setting",
    name = "grado-count-radius",
    setting_type = "startup",
    default_value = config.radius,
    minimum_value = 0,
    order = "a",
  },
  {
    type = "bool-setting",
    name = "grado-count-create-planets",
    setting_type = "startup",
    default_value = config.create_planets,
    order = "b",
  },
})
