local ecs = require("../lunatic-ecs")

local case = {}

function case.map_function()
  local world = ecs.new_world({
    color = { fields = { name = { type = "string" } } },
    identity = { fields = { name = { type = "string" } } }
  })

  local red_entity_id = world:new_entity({
    color = { name = "red" },
    identity = { name = "red" }
  })

  local green_entity_id = world:new_entity({
    color = { name = "green" },
    identity = { name = "green" }
  })

  local red_to_blue = world.all:with(
    world.component.color
  ):map(function(component)
    if component.color.name == "red" then
      component.color.name = "blue"
    end
  end)

  assert(world.component.color:get(red_entity_id).name == "red", "Red entity has to have a red color")
  assert(world.component.color:get(green_entity_id).name == "green", "Green entity has to have a green color")

  red_to_blue()

  assert(world.component.color:get(red_entity_id).name == "blue", "Red entity has to have a blue color")
  assert(world.component.color:get(green_entity_id).name == "green", "Green entity has to have a green color")

  local all_to_black = world.all:with(
    world.component.color
  ):map(function(component)
    component.color.name = "black"
  end)

  all_to_black()

  assert(world.component.color:get(red_entity_id).name == "black", "Red entity has to have a black color")
  assert(world.component.color:get(green_entity_id).name == "black", "Green entity has to have a black color")
end

function case.fold_function()
  local world = ecs.new_world({
    physical = { fields = { weight = { type = "number" } } },
  })

  for i = 1, 5 do
    world:new_entity({
      physical = { weight = i }
    })
  end

  local total_weight = world.all:with(
    world.component.physical
  ):fold(function(component, accumulate)
    return accumulate + component.physical.weight
  end)

  assert(total_weight(0) == 15, "Total weight has to be 15")
end

return case
