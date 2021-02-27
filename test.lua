local tests = {}

-- Loads and shuffles tests
for i = 1, #arg do
  local name = arg[i]:sub(1,-5)
  tests[#tests+1] = {
    name = name,
    cases = require(name)
  }
end

local j, tmp
for i = 1, #tests do
  j = math.random(#tests)
  tmp = tests[j]
  tests[j] = tests[i]
  tests[i] = tmp
end

-- Runs tests
local timer = os.clock
for i = 1, #tests do
  local test = tests[i]
  print(("Test: %s"):format(test.name))

  -- Shuffles cases
  local cases = {}
  for name, case in pairs(test.cases) do
    cases[#cases+1] = { name = name, case = case }
  end

  local k, tmp
  for j = 1, #cases do
    k = math.random(#cases)
    tmp = cases[k]
    cases[k] = cases[j]
    cases[j] = tmp
  end

  -- Runs and profiles cases
  local t0, t1
  for i = 1, #cases do
    print("  Case:", cases[i].name)
    local success, err = pcall(function()
      t0 = timer()
      cases[i].case()
      t1 = timer()
    end)

    if success then
      print(("    Success: %f seconds"):format(t1 - t0))
    else
      print(("    Failure: %s"):format(err))
    end
  end
end
