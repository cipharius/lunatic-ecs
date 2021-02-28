local ecs = require("../lunatic-ecs")

function populare_world()
  local world = ecs.new_world({
    componentA = { fields = { x = { type = "number" } } },
    componentB = { fields = { x = { type = "number" } } }
  })

  for i = 1, 10 do
    world:new_entity({
      componentA = { x = 0 },
      componentB = { x = 0 }
    })
  end

  for i = 1, 5 do
    world:new_entity({
      componentA = { x = 0 }
    })
  end

  for i = 1, 5 do
    world:new_entity({
      componentB = { x = 0 }
    })
  end

  return world
end

local case = {}

function case.shared_base_query()
  local world = populare_world()

  local base_query = world.all:with(world.component.componentA)
  assert(base_query:count() == 15, "World does not contain 15 entities with componentA")

  local without_B = base_query:without(world.component.componentB)
  local with_B = base_query:with(world.component.componentB)

  assert(without_B:count() == 5, "World does not contain 5 entities with componentA, but without componentB")
  assert(with_B:count() == 10, "World does not contain 10 entities with componentA and componentB")
end

return case
