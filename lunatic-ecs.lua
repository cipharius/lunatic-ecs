local Query = {}
Query.__index = Query

function Query:without(...)
  local components = {...}

  table.insert(self.chain, function()
    for i = 1, #components do
      self.components[components[i].name] = nil

      for j = #self.scope, 1, -1 do
        if components[i].entity_ids[self.scope[j]] then
          self.scope[j] = self.scope[#self.scope]
          self.scope[#self.scope] = nil
        end
      end
    end
  end)

  return self
end

function Query:optional(...)
  local components = {...}

  table.insert(self.chain, function()
    for _, component in ipairs(components) do
      self.components[component.name] = component
    end
  end)

  return self
end

function Query:where(f)
  table.insert(self.chain, function()
    for i = #self.scope, 1, -1 do
      local t = {}
      for name, component in pairs(self.components) do
        t[name] = component.rows[component.entity_ids[i]]
      end

      if not f(t) then
        self.scope[i] = self.scope[#self.scope]
        self.scope[#self.scope] = nil
      end
    end
  end)

  return self
end

function Query:map(f)
  return function()
    for i = 1, #self.chain do
      self.chain[i]()
    end

    for i = 1, #self.scope do
      local id = self.scope[i]

      local t = {}
      for name, component in pairs(self.components) do
        t[name] = component.rows[component.entity_ids[id]]
      end

      f(id, t)
    end
  end
end

local World = {}
World.__index = World

function World:query(base_component, ...)
  assert(base_component, "Query requires at least one component")
  local components = {...}
  local query = {}

  query.world = self
  query.scope = {}
  query.components = {}
  query.chain = {}

  table.insert(query.chain, function()
    query.components[base_component.name] = base_component
    for id, _ in pairs(base_component.entity_ids) do
      query.scope[#query.scope+1] = id
    end

    for i = 1, #components do
      query.components[components[i].name] = components[i]

      for j = #query.scope, 1, -1 do
        if not components[i].entity_ids[query.scope[j]] then
          query.scope[j] = query.scope[#query.scope]
          query.scope[#query.scope] = nil
        end
      end
    end
  end)

  return setmetatable(query, Query)
end

function World:register_component(name, component)
  assert(type(name) == "string", "Component name expected")
  assert(self.component[name] == nil, "Component is already registered")

  -- TODO Validate schema

  self.component[name] = {
    name = name,
    schema = component,
    entity_ids = {},
    rows = {}
  }
end

function World:unregister_component(name)
  self.component[name] = nil
end

function World:add_component(id, name, init)
  assert(type(id) == "number", "Entity ID expected")
  assert(self.component[name], "Component is not registered")
  local init = init or {}

  local i = #self.component[name].rows + 1
  self.component[name].rows[i] = init
  self.component[name].entity_ids[id] = i
end

function World:remove_component(id, name)
  assert(type(id) == "number", "Entity ID expected")
  assert(self.component[name], "Component is not registered")

  local component = self.component[name]
  if component.entity_ids[id] then
    table.remove(component.rows[i], component.entity_ids[id])
    component.entity_ids[id] = nil
  end
end

function World:new_entity(components)
  local components = components or {}
  local id = self.next_id

  for name, init in pairs(components) do
    self:add_component(id, name, init)
  end

  self.next_id = self.next_id + 1
  return id
end

function World:remove_entity(id)
  assert(type(id) == "number", "Entity ID expected")

  for name, _ in pairs(self.component) do
    self:remove_component(id, name)
  end
end

local ecs = {}

function ecs.new_world(components)
  local components = components or {}
  local world = {}

  world.next_id = 1
  world.component = {}

  world = setmetatable(world, World)

  for name, component in pairs(components) do
    world:register_component(name, component)
  end

  return world
end

return ecs
