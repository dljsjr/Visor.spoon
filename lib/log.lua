--
-- log.lua
--
-- Copyright (c) 2016 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local log = setmetatable({ _version = "0.1.0" }, {
  __call = function(self, modname)
    self.modname = modname
    return self
  end
})

log.usecolor = true
log.level = "trace"
log.lineinfo = true
log.datefmt = "%H:%M:%S"
log.modname = nil


local modes = {
  { name = "trace", color = "\27[34m", },
  { name = "debug", color = "\27[36m", },
  { name = "info",  color = "\27[32m", },
  { name = "warn",  color = "\27[33m", },
  { name = "error", color = "\27[31m", },
  { name = "fatal", color = "\27[35m", },
}


local levels = {}
for i, v in ipairs(modes) do
  levels[v.name] = i
end


local round = function(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end


local _tostring = tostring

local tostring = function(...)
  local t = {}
  for i = 1, select('#', ...) do
    local x = select(i, ...)
    if type(x) == "number" then
      x = round(x, .01)
    end
    t[#t + 1] = _tostring(x)
  end
  return table.concat(t, " ")
end


for i, x in ipairs(modes) do
  local nameupper = x.name:upper()
  log[x.name] = function(...)
    -- Return early if we're below the log level
    if i < levels[log.level] then
      return
    end

    local msg = tostring(...)
    local info = debug.getinfo(2, "Sl")
    local lineinfo = info.short_src .. ":" .. info.currentline

    -- Output to console
    print(string.format("%s[%s%s]%s %s%s: %s",
                        log.usecolor and x.color or "",
                        nameupper,
                        log.datefmt and os.date(log.datefmt) or "",
                        log.usecolor and "\27[0m" or "",
                        log.lineinfo and lineinfo or "",
                        log.modname and string.format("%s[%s]", (log.lineinfo and " " or ""), log.modname) or "",
                        msg))
  end
end

local function _fmt_log(log_fn)
  return function(fmt, ...)
    log_fn(string.format(fmt, ...))
  end
end

local hs_level_map = {
  error = "error",
  [1] = "error",
  warning = "warn",
  [2] = "warn",
  info = "info",
  [3] = "info",
  debug = "debug",
  [4] = "debug",
  verbose = "trace",
  [5] = "trace"
}

function log.hs_install(hs_logger)
  local hs_log = hs_logger or hs.logger.new(log.modname or "spoonlogger", hs.logger.defaultLogLevel)
  hs_log.e = log.error
  hs_log.w = log.warn
  hs_log.i = log.info
  hs_log.d = log.debug
  hs_log.v = log.trace

  hs_log.ef = _fmt_log(log.error)
  hs_log.wf = _fmt_log(log.warn)
  hs_log.f = _fmt_log(log.info)
  hs_log.df = _fmt_log(log.debug)
  hs_log.vf = _fmt_log(log.trace)

  hs_log.log = hs_log.i
  hs_log.logf = hs_log.f

  local _setLogLevel = hs_log.setLogLevel
  hs_log.setLogLevel = function(lvl)
    _setLogLevel(lvl)
    local newLevel = log.level
    if type(lvl) == "string" then
      newLevel = hs_level_map[string.lower(lvl)] or newLevel
    elseif type(lvl) == "number" then
      newLevel = hs_level_map[lvl] or newLevel
    else
      error('loglevel must be a string or a number', 3)
    end

    log.level = newLevel
  end

  return hs_log
end

return log
