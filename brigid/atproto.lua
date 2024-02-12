-- Copyright (c) 2024 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local brigid = require "brigid"
brigid.json.write = require "brigid.json.write"
brigid.json.stringify = require "brigid.json.stringify"

local class = {}
local metatable = { __index = class, __name = "brigid.atproto" }

local function new(service, user_agent)
  local self = setmetatable({ service = service, user_agent = user_agent }, metatable)
  self.http_session = brigid.http_session {
    header = function (code, header)
      self.code = code;
      self.header = header;
    end;

    write = function (out)
      self.data_writer:write(out)
    end;
  }
  return self
end

function class:close()
  self.http_session:close()
end

function class:request(method, endpoint, header, data)
  local url = self.service.."/xrpc/"..endpoint

  self.data_writer = brigid.data_writer()

  local result, message = self.http_session:request {
    method = method;
    url = url;
    header = header;
    data = data;
  }
  if not result then
    return result, message
  end

  if self.debug then
    print(self.code)
    for k, v in pairs(self.header) do
      print(k, v)
    end
    print(self.data_writer)
  end

  return self.code, self.data_writer
end

function class:make_session_path(identifier)
  return "session-"..identifier..".json"
end

function class:save_session()
  local handle = io.open(self:make_session_path(self.identifier), "w")
  brigid.json.write(handle, self.session)
  handle:write "\n"
  return true
end

function class:load_session(identifier)
  local handle = io.open(self:make_session_path(identifier))
  if handle then
    local session = brigid.json.parse(handle:read "*a")
    handle:close()
    self.session = session
    self.identifier = identifier
    return true
  end
end

function class:make_header(params)
  local header = { ["User-Agent"] = self.user_agent }
  if params.jwt then
    header["Authorization"] = "Bearer "..params.jwt
  end
  if params.post_json then
    header["Content-Type"] = "application/json; charset=UTF-8"
  end
  return header
end

function class:create_session(identifier, password)
  local code, data_writer = self:request(
    "POST",
    "com.atproto.server.createSession",
    self:make_header { post_json = true },
    brigid.json.stringify {
      identifier = identifier;
      password = password;
    })
  if code == 200 then
    self.session = brigid.json.parse(data_writer)
    self.identifier = identifier
    self:save_session()
    return true
  else
    return nil, code
  end
end

function class:refresh_session()
  local code, data_writer = self:request(
    "POST",
    "com.atproto.server.refreshSession",
    self:make_header { jwt = self.session.refreshJwt })
  if code == 200 then
    self.session = brigid.json.parse(data_writer)
    self:save_session()
    return true
  else
    return nil, code
  end
end

function class:delete_session()
  local code, data_writer = self:request(
    "POST",
    "com.atproto.server.deleteSession",
    self:make_header { jwt = self.session.refreshJwt })
  if code == 200 then
    self.session = nil
    os.remove(self:make_session_path(self.identifier))
  else
    return nil, code
  end
end

function metatable:__close()
  self:close()
end

return setmetatable(class, {
  __call = function (_, ...)
    return new(...)
  end;
})
