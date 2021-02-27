local ecs = require("../lunatic-ecs")

local case = {}

function case.empty_world()
  local world = ecs.new_world()
  assert(world.query:all():count() == 0, "World is not empty")
end

function case.empty_world_with_component()
  local world = ecs.new_world({
    basic_component = {}
  })
  assert(world.query:all():count() == 0, "World is not empty")
end

function case.populated_world()
  local world = ecs.new_world({
    basic_component = {}
  })
  assert(world.query:all():count() == 0, "World is not empty")

  for i = 1, 10 do
    world:new_entity({ basic_component = {} })
  end
  assert(world.query:all():count() == 10, "World does not contain 10 entities")

  world.query:all():remove()
  assert(world.query:all():count() == 0, "World is not empty")
end

return case
