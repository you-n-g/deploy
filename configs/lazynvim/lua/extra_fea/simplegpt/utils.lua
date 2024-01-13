local M = {}

local function class(className, super)
  -- 构建类
  local clazz = { __cname = className, super = super }
  local mt = {
    __call = function(cls, ...)
      -- local instance = {}
      -- 设置对象的元表为当前类，这样，对象就可以调用当前类生命的方法了
      local self = setmetatable({}, { __index = cls })
      if cls.ctor then
        cls.ctor(self, ...)
      end
      return self
    end
  }
  if super then
    -- 设置类的元表，此类中没有的，可以查找父类是否含有
    mt.__index = super
  end
  setmetatable(clazz, mt)
  return clazz
end

M.class = class
return M
