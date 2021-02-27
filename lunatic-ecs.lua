local unpack = unpack or table.unpack

-- Class: Query

local Query = {}
Query.__index = Query

function Query.new(world, parent)
  assert(world, "Query constructor requires world")
  local query = {}

  query.world = world
  query.parent = parent
  query.closure = function(q) return q end

  return setmetatable(query, Query)
end

function Query:execute()
  local query = { scope = {}, components = {} }

  if self.parent then
    local result = self.parent:execute()

    for i, v in pairs(result.components) do
      query.components[i] = v
    end

    for i = 1, #result.scope do
      query.scope[i] = result.scope[i]
    end
  end

  return self.closure(query)
end

function Query:count()
  return #self:execute().scope
end

function Query:remove()
  local result = self:execute()

  for i = 1, #result.scope do
    self.world:remove_entity(result.scope[i])
  end
end

function Query:all()
  self.closure = function(query)
    local entity_ids = {}

    for name, component in pairs(self.world.component) do
      query.components[name] = component

      for id, _ in pairs(component.entity_ids) do
        entity_ids[id] = true
      end
    end

    for id, _ in pairs(entity_ids) do
      query.scope[#query.scope+1] = id
    end

    return query
  end

  return Query.new(self.world, self)
end

function Query:with(base_component, ...)
  assert(base_component, "With query requires at least one component")
  local components = {...}

  self.closure = function(query)
    query.components[base_component.name] = base_component
    for id, _ in pairs(base_component.entity_ids) do
      query.scope[#query.scope+1] = id
    end

    for i = 1, #components do
      query.components[components[i].name] = components[i]

      for j = #query.scope, 1, -1 do
        if not components[i].entity_ids[query.scope[j]] then
          new_scope[j] = query.scope[#query.scope]
          new_scope[#new_scope] = nil
        end
      end
    end

    return query
  end

  return Query.new(self.world, self)
end

function Query:without(...)
  local components = {...}

  self.closure = function(query)
    for i = 1, #components do
      query.components[components[i].name] = nil

      for j = #query.scope, 1, -1 do
        if components[i].entity_ids[query.scope[j]] then
          query.scope[j] = query.scope[#query.scope]
          query.scope[#query.scope] = nil
        end
      end
    end

    return query
  end

  return Query.new(self.world, self)
end

function Query:optional(...)
  local components = {...}

  self.closure = function(query)
    for _, component in ipairs(components) do
      query.components[component.name] = component
    end

    return query
  end

  return Query.new(self.world, self)
end

function Query:where(f)
  self.closure = function(query)
    for i = #self.scope, 1, -1 do
      local t = {}
      for name, component in pairs(self.components) do
        t[name] = component.rows[component.entity_ids[i]]
      end

      if not f(t) then
        query.scope[i] = query.scope[#query.scope]
        query.scope[#query.scope] = nil
      end
    end

    return query
  end

  return Query.new(self.world, self)
end

function Query:map(f)
  self.closure = function(query)
    for i = 1, #query.scope do
      local id = query.scope[i]

      local t = {}
      for name, component in pairs(query.components) do
        t[name] = component.rows[component.entity_ids[id]]
      end

      f(id, t)
    end

    return query
  end

  return Query.new(self.world, self)
end

-- Class: World

local World = {}
World.__index = World

function World.new()
  local components = components or {}
  local world = setmetatable({}, World)

  world.next_id = 1
  world.component = {}
  world.query = Query.new(world)

  return world
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

  init = setmetatable(init, { __index = { __id = id } })

  local i = #self.component[name].rows + 1
  self.component[name].rows[i] = init
  self.component[name].entity_ids[id] = i
end

function World:remove_component(id, name)
  assert(type(id) == "number", "Entity ID expected")
  assert(self.component[name], "Component is not registered")

  local component = self.component[name]
  local row_id = component.entity_ids[id]
  if row_id then
    component.rows[row_id] = component.rows[#component.rows]
    component.entity_ids[component.rows[row_id].__id] = row_id

    component.rows[#component.rows] = nil
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


-- Library interface

local ecs = {}

function ecs.new_world(components)
  local components = components or {}
  local world = World.new(components)

  for name, component in pairs(components) do
    world:register_component(name, component)
  end

  return world
end

return ecs
