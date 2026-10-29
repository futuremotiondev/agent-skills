local M = {}

--- Adds two numbers.
function M.add(a, b)
  return a + b
end

function M:method(x)
  if x then
    for i = 1, 10 do print(i) end
  end
  repeat x = x - 1 until x < 0
end

local function helper()
  local inner = function() return 1 end
  return inner()
end

M.sub = function(a, b) return a - b end

return M
