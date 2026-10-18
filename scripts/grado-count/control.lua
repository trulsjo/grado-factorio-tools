-- grado-count: counts every resource entity by name around each surface's origin.
--
-- WHAT IT DOES. Tick 30 after the map starts: with grado-count-create-planets, create the surface
-- of every planet that has none; then on every surface request the chunks within
-- grado-count-radius of the origin's chunk and force them. Ticks 120 and 600: count every
-- `resource` entity by name in that square of 2 * radius + 1 chunks a side. At tick 600, write
-- script-output/grado-count.json: the map seed; per tick and surface its seed, radius, the chunks
-- of the square that were generated and the counts; the resource prototypes (autoplace, infinite,
-- category); and active_mods. From the throwaway grado-count 0.0.2 of
-- trulsjo/grado-factorio-modpack#307 (grado-factorio-tools#161), whose two copies, radius 24 on
-- every planet and radius 48 on Nauvis alone, the two settings replace.
--
-- WHAT IT CANNOT SEE. Anything outside the square, so an ore placed only farther out reads as
-- unplaced. A resource a mod places later than tick 30's generation, or in a chunk generated
-- after tick 600. Whether a surface's generation finished: t120 equal to t600 says it settled,
-- not that it is complete. A surface that is not a planet's and does not exist at tick 30.
-- A resource with no entity has no key under its surface's `resources`.

local RADIUS = settings.startup["grado-count-radius"].value
local CREATE_PLANETS = settings.startup["grado-count-create-planets"].value
local LO = -RADIUS * 32
local HI = (RADIUS + 1) * 32
local seen = 0
local out = { counts = {}, settings = { radius = RADIUS, create_planets = CREATE_PLANETS } }

local function resource_names()
  local names = {}
  for name, _ in pairs(prototypes.get_entity_filtered({ { filter = "type", type = "resource" } })) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

local function generate()
  if CREATE_PLANETS and game.planets then
    for _, planet in pairs(game.planets) do
      if not planet.surface then planet.create_surface() end
    end
  end
  for _, surface in pairs(game.surfaces) do
    surface.request_to_generate_chunks({ 0, 0 }, RADIUS)
    surface.force_generate_chunk_requests()
  end
end

local function count(label)
  local names = resource_names()
  local result = {}
  for _, surface in pairs(game.surfaces) do
    local generated = 0
    for cx = -RADIUS, RADIUS do
      for cy = -RADIUS, RADIUS do
        if surface.is_chunk_generated({ cx, cy }) then generated = generated + 1 end
      end
    end
    local by_name = {}
    for _, name in ipairs(names) do
      local n = surface.count_entities_filtered({ area = { { LO, LO }, { HI, HI } }, name = name })
      if n > 0 then by_name[name] = n end
    end
    result[surface.name] = { seed = surface.map_gen_settings.seed, radius = RADIUS, chunks = generated, resources = by_name }
  end
  out.counts[label] = result
end

local function resources()
  local list = {}
  for name, p in pairs(prototypes.get_entity_filtered({ { filter = "type", type = "resource" } })) do
    list[name] = { autoplace = p.autoplace_specification ~= nil, infinite = p.infinite_resource or false,
      category = p.resource_category }
  end
  return list
end

script.on_event(defines.events.on_tick, function()
  seen = seen + 1
  if seen == 30 then generate() end
  if seen == 120 then count("t120") end
  if seen == 600 then
    count("t600")
    out.seed = game.default_map_gen_settings.seed
    out.prototypes = resources()
    local mods = {}
    for name, version in pairs(script.active_mods) do mods[name] = version end
    out.active_mods = mods
    helpers.write_file("grado-count.json", helpers.table_to_json(out), false)
  end
end)
