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
    local keep = {}
    local skip = {}

    for _, component in pairs(self.without_components) do
      for i = 1, #component.rows do
        skip[component.rows[i].__id] = true
      end
    end

    for name, component in pairs(self.world.component) do
      for id, _ in pairs(component.entity_ids) do
        if not skip[id] then
          keep[id] = true
        end
      end
    end

    for id, _ in pairs(keep) do
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
      local skip = false

      for _, component in pairs(self.without_components) do
        if component.entity_ids[id] ~= nil then
          skip = true
          break
        end
      end

      if not skip then
        local t = {}

        for name, component in pairs(self.components) do
          if component.entity_ids[id] == nil then
            skip = true
            break
          end

          t[name] = component.rows[component.entity_ids[id]]
        end

        if not skip then
          for name, component in pairs(self.optional_components) do
            if component.entity_ids[id] ~= nil then
              t[name] = component.rows[component.entity_ids[id]]
            end
          end
          components[#components+1] = t
        end
      end
    end
  else
    local keep = {}
    local skip = {}

    for _, component in pairs(self.without_components) do
      for i = 1, #component.rows do
        skip[component.rows[i].__id] = true
      end
    end

    for name, component in pairs(self.world.component) do
      for id, _ in pairs(component.entity_ids) do
        if not skip[id] then
          keep[id] = true
        end
      end
    end

    for id, _ in pairs(keep) do
      local t = {}
      for name, component in pairs(self.world.component) do
        t[name] = component.rows[component.entity_ids[id]]
      end
      members[#members+1] = t
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
      query.optional_components[components[i].name] = components[i]
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

    for _, component in pairs(self.components) do
      component:end_transaction()
    end

    for _, component in pairs(self.optional_components) do
      component:end_transaction()
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

function Query:on_add(f)
  local recently_handled = setmetatable({}, { __mode = "v" })

  local handler = function(id, component)
    if recently_handled[id] then return end

    for _, component in pairs(self.without_components) do
      if component.entity_ids[id] ~= nil then
        return
      end
    end

    local t = {}

    for name, component in pairs(self.components) do
      if component.entity_ids[id] == nil then
        return
      end
      t[name] = component.rows[component.entity_ids[id]]
    end

    for name, component in pairs(self.optional_components) do
      if component.entity_ids[id] then
        t[name] = component.rows[component.entity_ids[id]]
      end
    end

    recently_handled[id] = component
    f(t)
  end

  for _, component in pairs(self.components) do
    component:on_add_callback(handler)
  end
end

function Query:on_remove(f)
  error("Not implemented")
end

function Query:on_change(component, f)
  assert(self.components[component.name] ~= nil, "Can not listen to change on non-required component")

  local handler = function(id, field, value)
    for _, component in pairs(self.without_components) do
      if component.entity_ids[id] ~= nil then
        return
      end
    end

    local t = {}

    for name, component in pairs(self.components) do
      if component.entity_ids[id] == nil then
        return
      end
      t[name] = component.rows[component.entity_ids[id]]
    end

    for name, component in pairs(self.optional_components) do
      if component.entity_ids[id] then
        t[name] = component.rows[component.entity_ids[id]]
      end
    end

    f(t, field, value)
  end

  component:on_change_callback(handler)
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
  component.on_add_callbacks = {}
  component.on_remove_callbacks = {}
  component.on_change_callbacks = {}
  component.event_queue = {}

  return setmetatable(component, Component)
end

function Component:contains(entity_id)
  return self.entity_ids[entity_id] ~= nil
end

function Component:add(entity_id, fields)
  fields.__id = entity_id
  self.rows[#self.rows+1] = setmetatable({}, {
    __index = fields,
    __newindex = function(t, i, v)
      if #self.on_change_callbacks > 0 then
        self.event_queue[#self.event_queue+1] = { event = "change", id = entity_id, field = i, value = v }
      end
      fields[i] = v
    end
  })
  self.entity_ids[entity_id] = #self.rows
  self.event_queue[#self.event_queue+1] = { event = "add", id = entity_id, value = self.rows[#self.rows] }
end

function Component:remove(entity_id)
  local index = self.entity_ids[entity_id]
  if index then
    self.event_queue[#self.event_queue+1] = { event = "remove", id = entity_id, value = self.rows[index] }
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

function Component:end_transaction()
  for i = 1, #self.event_queue do
    test = i
    local event = self.event_queue[i]

    if event.event == "add" then
      for j = 1, #self.on_add_callbacks do
        self.on_add_callbacks[j](event.id, event.value)
      end
    elseif event.event == "remove" then
      for j = 1, #self.on_remove_callbacks do
        self.on_remove_callbacks[j](event.id, event.value)
      end
    elseif event.event == "change" then
      for j = 1, #self.on_change_callbacks do
        self.on_change_callbacks[j](event.id, event.field, event.value)
      end
    end
    self.event_queue[i] = nil
  end
end

function Component:on_add_callback(callback)
  self.on_add_callbacks[#self.on_add_callbacks+1] = callback
end

function Component:on_remove_callback(callback)
  self.on_remove_callbacks[#self.on_remove_callbacks+1] = callback
end

function Component:on_change_callback(callback)
  self.on_change_callbacks[#self.on_change_callbacks+1] = callback
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
    self:add_component(id, name, init, true)
  end

  for name, _ in pairs(components) do
    self.component[name]:end_transaction()
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
