-- Copyright (c) 2024 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local brigid = require "brigid"
brigid.json.write = require "brigid.json.write"
brigid.json.stringify = require "brigid.json.stringify"

local percent_encode_table = {}

for byte = 0x00, 0xFF do
  percent_encode_table[string.char(byte)] = ("%%%02X"):format(byte)
end

local function percent_encode(s)
  -- https://url.spec.whatwg.org/#application-x-www-form-urlencoded-percent-encode-set
  return (s:gsub("[^%w%*%-%.%_]", percent_encode_table))
end

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
    return true
  else
    return nil, code
  end
end

function class:get(endpoint, params)
  if params then
    local query = {}
    for k, v in pairs(params) do
      query[#query + 1] = percent_encode(tostring(k)).."="..percent_encode(tostring(v))
    end
    endpoint = endpoint.."?"..table.concat(query)
  end
  local code, data_writer = self:request(
    "GET",
    endpoint,
    self:make_header { jwt = self.session.accessJwt })
  if code == 200 then
    return brigid.json.parse(data_writer)
  else
    return nil, code
  end
end

function class:post(endpoint, json)
  local header
  local data

  if json then
    header = self:make_header { jwt = self.session.accessJwt, post_json = true }
    data = brigid.json.stringify(json)
  else
    header = self:make_header { jwt = self.session.accessJwt }
    data = ""
  end

  local code, data_writer = self:request("POST", endpoint, header, data)
  if code == 200 then
    return brigid.json.parse(data_writer)
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
