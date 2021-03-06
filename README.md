# Lunatic ECS

A wild approach to Entity-Component-System architecture in Lua.

## Vision

Currently the framework is at it's very infancy and the code does not reflect the vision of the project fully.
The high-level project goals are:

* Lua implementation of Entity-Component-System, following the schema: entity as a int, components as arrays of plain datastructures and systems as code containing the business/game logic.
* A flexible, yet efficient way to build queries against the world, such as: all entities with components A and B, but without component C.
* Functional(-ish) reactive way of describing system logic, based on the defined queries, such as: Map the function over all entities selected by query, or react to addition, removal and change in queried entities.
* Design underlying structures in such way, that would allow implementing the framework's interface in C/C++. Components should be compatible with C structs, so that cache-friendly component store could be implemented.

## Distant future ideas

* Turn the framework into C/C++ Lua module, where the underlying component database would be implemented in C side taking full advantage of cache optimized components

* Gather runtime statistics such as average indexing order for each component and once in a while sort the component array by the calculated average index position.
  In theory, this would create self optimizing system, by keeping the components array contiguous and having commonly accessed data be kept closer in memory.

## Sources of inspiration

* Apecs: Haskell Entity-Component-System library
  https://github.com/jonascarpay/apecs#readme

* T-machine blog
  http://t-machine.org/index.php/category/entity-systems/
