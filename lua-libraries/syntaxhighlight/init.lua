local unpack = unpack or table.unpack
local lexer_search_path
do
  local parts = { }
  for part in package.path:gmatch('[^;]+') do
    local _continue_0 = false
    repeat
      if not (part:match("%?%.lua$")) then
        _continue_0 = true
        break
      end
      table.insert(parts, (part:gsub("%?%.lua", "syntaxhighlight/lexers/?.lua")))
      table.insert(parts, (part:gsub("%?%.lua", "syntaxhighlight/textadept/?.lua")))
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  lexer_search_path = table.concat(parts, ";")
end

local searchpath = function(name, path)
  local tried = { }
  for part in path:gmatch("[^;]+") do
    local filename = part:gsub("%?", name)
    if loadfile(filename) then
      return filename
    end
    tried[#tried + 1] = string.format("no file '%s'", filename)
  end
  return nil, table.concat(tried, "\n")
end

local lexer_mod
local load_lexer = function()
  if lexer_mod then
    return
  end
  lexer_mod = require("syntaxhighlight.textadept.lexer")
  lexer_mod.property = {
    ["lexer.lpeg.home"] = lexer_search_path:gsub("/%?%.lua", "")
  }
  lexer_mod.property_int = setmetatable({ }, {
    __index = function(self, k)
      return tonumber(lexer_mod.property[k]) or 0
    end,
    __newindex = function(self)
      return error("read-only property")
    end
  })
end
local lexers = setmetatable({ }, {
  __index = function(self, name)
    if not (lexer_mod) then
      load_lexer()
    end
    local source_path = searchpath(name, lexer_search_path)
    local mod
    if source_path then
      mod = lexer_mod.load(name)
    else
      mod = false
    end
    self[name] = mod
    return self[name]
  end
})
local tag_tokens
tag_tokens = function(source, tokens)
  local position = 1
  local current_type
  return (function()
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #tokens do
      local _continue_0 = false
      repeat
        local token = tokens[_index_0]
        local _exp_0 = type(token)
        if "number" == _exp_0 then
          local chunk = source:sub(position, token - 1)
          position = token
          _accum_0[_len_0] = {
            (assert(current_type, "got position without type")),
            chunk
          }
        elseif "string" == _exp_0 then
          current_type = token
          _continue_0 = true
          break
        else
          _accum_0[_len_0] = error("unknown token type: " .. tostring(type(token)))
        end
        _len_0 = _len_0 + 1
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    return _accum_0
  end)()
end

local parse_extra_styles = function(s)
  local _accum_0 = { }
  local _len_0 = 1
  for t in s:gmatch("%$%(style%.([^)]+)%)") do
    _accum_0[_len_0] = t
    _len_0 = _len_0 + 1
  end
  return _accum_0
end

local classes_for_chunk_type = function(lex, chunk_type, alias_cache)
  do
    local out = alias_cache and alias_cache[chunk_type]
    if out then
      return out
    end
  end
  local out
  if lex._EXTRASTYLES and lex._EXTRASTYLES[chunk_type] then
    local other_tags = parse_extra_styles(lex._EXTRASTYLES[chunk_type])
    out = {
      chunk_type,
      unpack(other_tags)
    }
  else
    out = {
      chunk_type
    }
  end
  if alias_cache then
    alias_cache[chunk_type] = out
  end
  return out
end

local merge_adjacent = function(tuples)
  local out = { }
  for _index_0 = 1, #tuples do
    local t = tuples[_index_0]
    local last = out[#out]
    if last and last[1] == t[1] then
      out[#out] = {
        last[1],
        last[2] .. t[2]
      }
    else
      table.insert(out, t)
    end
  end
  return out
end


-- BEGIN DIDIER REPLACED THE ORIGINAL FUNC.
local totable = function(language, code, opts)
  local lex = lexers[language]
  if not (lex) then
    return nil, "failed to find lexer for " .. tostring(language)
  end
  local tokens, err = lex:lex(code)
  if not (tokens) then
    return nil, err
  end

  local cache = { }
  local tagged_tokens = merge_adjacent(tag_tokens(code, tokens))

  local buffer = { }
  for _, tagged_token in ipairs(tagged_tokens) do
    local chunk_type, chunk = tagged_token[1], tagged_token[2]
    local classes = classes_for_chunk_type(lex, chunk_type, cache)
    table.insert(buffer, { classes = classes, text = chunk })
  end
  return buffer
end
-- END DIDIER

return {
  lexers = lexers,
  totable = totable,
  VERSION = "1.0.0"
}
