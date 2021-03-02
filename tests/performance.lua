local ecs = require("../lunatic-ecs")

local case = {}

function case.stress_test()
  local timer = os.clock
  local ecs_t0, ecs_t1
  local vanilla_t0, vanilla_t1

  ecs_t0 = timer()
  local world = ecs.new_world({
    data = { fields = { counter = { type = "number" } } }
  })

  for i = 1, 1e5 do
    world:add_entity({
      data = { counter = 0 }
    })
  end

  local count_up = world.all:with(
    world.component.data
  ):map(function(component)
    component.data.counter = component.data.counter + 1
  end)

  for i = 1, 10 do
    count_up()
  end
  ecs_t1 = timer()
  print("ECS:", ecs_t1 - ecs_t0)

  world = nil

  vanilla_t0 = timer()
  local world = {}

  for i = 1, 1e5 do
    world[i] = { counter = 0 }
  end

  for i = 1, 10 do
    for j = 1, 1e5 do
      world[j].counter = world[j].counter + 1
    end
  end
  vanilla_t1 = timer()
  print("Vanilla:", vanilla_t1 - vanilla_t0)
end

return case
