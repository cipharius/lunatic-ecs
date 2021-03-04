local ecs = require("../lunatic-ecs")

local case = {}

function case.on_add()
  local world = ecs.new_world({
    A = {},
    B = {}
  })

  local count = {
    with_A_B = 0,
    with_A = 0,
    with_A_without_B = 0
  }

  world.all:with(
    world.component.A,
    world.component.B
  ):on_add(function(comp)
    assert(comp.A ~= nil, "Component A is not present in A and B query")
    assert(comp.B ~= nil, "Component B is not present in A and B query")
    count.with_A_B = count.with_A_B + 1
  end)

  world.all:with(
    world.component.A
  ):on_add(function(comp)
    assert(comp.A ~= nil, "Component A is not present in A query")
    count.with_A = count.with_A + 1
  end)

  world.all:with(
    world.component.A
  ):without(
    world.component.B
  ):on_add(function(comp)
    assert(comp.A ~= nil, "Component A is not present in A without B query")
    assert(comp.B == nil, "Component B is present in A without B query")
    count.with_A_without_B = count.with_A_without_B + 1
  end)

  world:add_entity({ A = {} })
  world:add_entity({ A = {}, B = {} })
  world:add_entity({ A = {}, B = {} })
  world:add_entity({ B = {} })

  assert(count.with_A_B == 2, "A and B reaction count is not 2")
  assert(count.with_A == 3, "A reaction count is not 3")
  assert(count.with_A_without_B == 1, "A without B reaction count is not 1")
end

function case.on_change()
  local world = ecs.new_world({
    counter = { fields = { count = "number" } },
    label = { fields = { text = "string" } }
  })

  local labeled_counter = world:add_entity({
    counter = { count = 0 },
    label = { text = "Current value: 0" }
  })

  local plain_counter = world:add_entity({
    counter = { count = 0 }
  })

  local is_all_zero = world.all:with(world.component.counter):fold(function(comp, acc)
    return acc and comp.counter.count == 0
  end)
  assert(is_all_zero(true) == true, "All counters must be 0")

  world.all:with(
    world.component.counter,
    world.component.label
  ):on_change(world.component.counter, function(comp, field, value)
    comp.label.text = "Current value: " .. value
  end)

  local increment_all = world.all:with(world.component.counter):map(function(comp)
    comp.counter.count = comp.counter.count + 1
  end)

  increment_all()

  local is_all_one = world.all:with(world.component.counter):fold(function(comp, acc)
    return acc and comp.counter.count == 1
  end)

  assert(is_all_one(true) == true, "All counters must be 1")
  assert(world.component.label:get(labeled_counter).text == "Current value: 1", "Labeled counter does not have label with count 1")

  local increment_nonlabeled = world.all:with(
    world.component.counter
  ):without(
    world.component.label
  ):map(function(comp)
    comp.counter.count = comp.counter.count + 1
  end)

  increment_nonlabeled()
  assert(world.component.label:get(labeled_counter).text == "Current value: 1", "Labeled counter does not have label with count 1")

  increment_all()
  assert(world.component.label:get(labeled_counter).text == "Current value: 2", "Labeled counter does not have label with count 2")
end

return case
