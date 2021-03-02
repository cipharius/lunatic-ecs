-- Class: Query

local Query = {}
Query.__index = Query

function Query.new(world, node_type, parent)
  assert(world, "Query constructor requires world")
  local query = {}

  query.world = world
  query.parent = parent
  query.type = node_type
  query.components = {}
  query.without_components = {}
  query.optional_components = {}

  if query.parent then
    for i, v in pairs(query.parent.components) do
      query.components[i] = v
    end
    for i, v in pairs(query.parent.optional_components) do
      query.optional_components[i] = v
    end
  end

  return setmetatable(query, Query)
end

function Query:get_entities()
  local members = {}

  if next(self.components) ~= nil then
    local _, base_set = next(self.components)
    for _, component in pairs(self.components) do
      if component and #component.rows < #base_set.rows then
        base_set = component
      end
    end

    for i = 1, #base_set.rows do
      local id = base_set.rows[i].__id
      local skip = false

      for _, component in pairs(self.without_components) do
        if component.entity_ids[id] then
          skip = true
          break
        end
      end

      for _, component in pairs(self.components) do
        if component.entity_ids[id] == nil then
          skip = true
          break
        end
      end

      if not skip then
        members[#members+1] = id
      end
    end
  else
    local entity_ids = {}
    for _, component in pairs(self.world.component) do
      for id, _ in next, component.entity_ids do
        entity_ids[id] = true
      end
    end

    for id, _ in pairs(entity_ids) do
      members[#members+1] = id
    end
  end

  return members
end

function Query:get_components()
  local components = {}

  if next(self.components) ~= nil then
    local _, base_set = next(self.components)
    for _, component in pairs(self.components) do
      if component and #component.rows < #base_set.rows then
        base_set = component
      end
    end

    for i = 1, #base_set.rows do
      local id = base_set.rows[i].__id
      local t = {}
      for name, component in pairs(self.components) do
        if (component.entity_ids[id] ~= nil) == (component == false) then
          t = nil
          break
        end

        if t then
          t[name] = component.rows[component.entity_ids[id]]
        end
      end

      if t then
        for name, component in pairs(self.optional_components) do
          t[name] = component.rows[component.entity_ids[id]]
        end
        components[#components+1] = t
      end
    end
  else
    local entity_ids = {}
    for _, component in next, self.world.component do
      for id, _ in next, component.entity_ids do
        entity_ids[id] = true
      end
    end

    for id, _ in next, entity_ids do
      local t = {}
      for _, component in pairs(self.world.component) do
        t[component.name] = component.rows[component.entity_ids[id]]
      end
      components[#components+1] = t
    end
  end

  return components
end

function Query:execute()
  return self:get_entities()
end

function Query:count()
  return #self:get_entities()
end

function Query:remove()
  local result = self:get_entities()

  for i = 1, #result do
    self.world:remove_entity(result[i])
  end
end

function Query:with(...)
  local components = {...}
  local query = Query.new(self.world, "with", self)

  for i = 1, #components do
    assert(query.without_components[components[i].name] == nil, "Resulting query contradicts itself")
    query.components[components[i].name] = components[i]
  end

  return query
end

function Query:without(...)
  local components = {...}
  local query = Query.new(self.world, "without", self)

  for i = 1, #components do
    assert(query.components[components[i].name] == nil, "Resulting query contradicts itself")
    query.without_components[components[i].name] = components[i]
  end

  return query
end

function Query:optional(...)
  local components = {...}
  local query = Query.new(self.world, "optional", self)

  for i = 1, #components do
    if query.components[components[i].name] == nil and query.without_components[components[i].name] == nil then
      query.optional_components[components[i].name] = components[i].name
    end
  end

  return query
end

function Query:map(f)
  return function(...)
    local components = self:get_components()

    for i = 1, #components do
      f(components[i], ...)
    end

    return components
  end
end

function Query:fold(f)
  return function(initial, ...)
    local components = self:get_components()

    local result = initial
    for i = 1, #components do
      result = f(components[i], result)
    end

    return result
  end
end


-- Class: Component

local Component = {}
Component.__index = Component

function Component.new(name, schema)
  local component = {}

  component.name = name
  component.schema = schema
  component.entity_ids = {}
  component.rows = {}

  return setmetatable(component, Component)
end

function Component:contains(entity_id)
  return self.entity_ids[entity_id] ~= nil
end

function Component:add(entity_id, fields)
  self.rows[#self.rows+1] = setmetatable(fields, { __index = { __id = entity_id } })
  self.entity_ids[entity_id] = #self.rows
end

function Component:remove(entity_id)
  local index = self.entity_ids[entity_id]
  if index then
    self.entity_ids[self.rows[#self.rows].__id] = index
    self.rows[index] = self.rows[#self.rows]
    self.rows[#self.rows] = nil
    self.entity_ids[entity_id] = nil
  end
end

function Component:get(entity_id)
  local index = self.entity_ids[entity_id]
  if index then
    return self.rows[index]
  end
end

function Component:set(entity_id, fields)
  self.rows[self.entity_ids[entity_id]] = fields
end

-- Class: World

local World = {}
World.__index = World

function World.new()
  local components = components or {}
  local world = setmetatable({}, World)

  world.next_id = 1
  world.component = {}
  world.all = Query.new(world, "root")

  return world
end

function World:register_component(name, component)
  assert(type(name) == "string", "Component name expected")
  assert(self.component[name] == nil, "Component is already registered")

  self.component[name] = Component.new(name, component)
end

function World:unregister_component(name)
  self.component[name] = nil
end

function World:add_component(id, name, init)
  assert(type(id) == "number", "Entity ID expected")
  assert(self.component[name], "Component is not registered")

  if self.component[name]:contains(id) then
    self.component[name]:set(id, init or {})
  else
    self.component[name]:add(id, init or {})
  end
end

function World:remove_component(id, name)
  assert(type(id) == "number", "Entity ID expected")
  assert(self.component[name], "Component is not registered")
  self.component[name]:remove(id)
end

function World:add_entity(components)
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
