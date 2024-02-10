-- Copyright (c) 2024 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local brigid = require "brigid"
local write = require "brigid.json.write"

return function (u)
  return tostring(write(brigid.data_writer(), u))
end
