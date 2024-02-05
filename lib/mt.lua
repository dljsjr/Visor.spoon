--- Metatable Utils
local M = {}

--- https://www.lua.org/pil/13.4.5.html
function M.makeReadOnlyTable(t)
  local proxy = {}
  local mt = { -- create metatable
    __index = t,
    __newindex = function(t, k, v)
      error("attempt to update a read-only table", 2)
    end
  }
  setmetatable(proxy, mt)
  return proxy
end

function M.makeTerminal(termTemplate)
  assert(type(termTemplate) == "table",           "Terminal template must be a table")
  assert(type(termTemplate.macApp) == "string",   "Terminal Template must have \"string\" property `macApp`")
  assert(type(termTemplate.bundleId) == "string", "Terminal Template must have \"string\" property `bundleId`")
  assert(type(termTemplate.windowIdentifier) == "string",
         "Terminal Template must have \"string\" property `windowIdentifier`")

  return M.makeReadOnlyTable(termTemplate)
end

return M
