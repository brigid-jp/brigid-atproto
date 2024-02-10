-- Copyright (c) 2024 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local brigid = require "brigid"

local class = {}
local metatable = { __index = class, __name = "brigid.atproto" }

local function post_json(self, url, data)
end

local function write(self, out)
end

local function new(service, identifier, password)
  local self = setmetatable({
    service = service;
    identifier = identifier;
    password = password;
  }, metatable)
  self.http_session = brigid.http_session {
    write = function (out) write(self, out) end;
  }
  return self
end

function class:close()
  self.http_session:close()
end

function class:write(out)
  print(tostring(out))
end

function class:post(endpoint, data)
end

function metatable:__close()
  self:close()
end

return setmetable(class, {
  __call = function (_, ...) return new(...) end;
})
