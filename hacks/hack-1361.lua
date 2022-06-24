SILE.defaultTypesetter.pushGlue = function(self, spec)
  -- if SU.type(spec) ~= "table" then SU.warn("Please use pushHorizontal() to pass a premade node instead of a spec") end
  local node = SU.type(spec) == "glue" and spec or SILE.nodefactory.glue(spec)
  return self:pushHorizontal(node:absolute()) -- absolutized #1361 HACK WORKAROUND (NOT A PROPER FIX!!!)
end

SILE.defaultTypesetter.pushExplicitGlue = function(self, spec)
  local node = SU.type(spec) == "glue" and spec or SILE.nodefactory.glue(spec)
  node.explicit = true
  node.discardable = false
  return self:pushHorizontal(node:absolute()) -- absolutized #1361 HACK WORKAROUND (NOT A PROPER FIX!!!)
end

SILE.defaultTypesetter.pushVglue = function(self, spec)
  local node = SU.type(spec) == "vglue" and spec or SILE.nodefactory.vglue(spec)
  return self:pushVertical(node:absolute()) -- absolutized #1361 HACK WORKAROUND (NOT A PROPER FIX!!!)
end

SILE.defaultTypesetter.pushExplicitVglue = function(self, spec)
  local node = SU.type(spec) == "vglue" and spec or SILE.nodefactory.vglue(spec)
  node.explicit = true
  node.discardable = false
  return self:pushVertical(node:absolute()) -- absolutized #1361 HACK WORKAROUND (NOT A PROPER FIX!!!)
end

SILE.typesetter.pushGlue = SILE.defaultTypesetter.pushGlue
SILE.typesetter.pushExplicitGlue = SILE.defaultTypesetter.pushExplicitGlue
SILE.typesetter.pushVglue = SILE.defaultTypesetter.pushVglue
SILE.typesetter.pushExplicitVglue = SILE.defaultTypesetter.pushExplicitVglue
