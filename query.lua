local pairs, type, setmetatable, string_match =
      pairs, type, setmetatable, string.match
local unpack = _G.unpack or table.unpack

local Query = {}
Query.__name = "query"
Query.__index = Query

function Query.new()
   return setmetatable({
      resolve = function(t, cont) return cont(t, 1) end
   }, Query)
end

function Query:clearpath()
   for i = 1, #self do self[i] = nil end
   return self
end

function Query:index(key)
   local resolve = self.resolve
   function self.resolve(t, cont)
      return resolve(t, function(v, n)
         local value = v[key]
         if value then self[n] = key; return cont(value, n+1) end
      end)
   end
   return self
end

function Query:map(f)
   local resolve = self.resolve
   function self.resolve(t, cont)
      return resolve(t, function(v, n)
         local value, key = f(v)
         self[n] = key or "*mapped*"
         return cont(value, n+1)
      end)
   end
   return self
end

function Query:filter(f)
   local resolve = self.resolve
   function self.resolve(t, cont)
      return resolve(t, function(v, n)
         if f(v, self, n-1) then return cont(v, n) end
      end)
   end
   return self
end

function Query:collect(coll)
   local resolve = self.resolve
   function self.resolve(t, cont)
      return resolve(t, function(v, n)
         coll[#coll+1] = v
         return cont(v, n)
      end)
   end
   return self
end

function Query:all(ty)
   if ty then return self:alltype(type) end
   local resolve = self.resolve
   function self.resolve(t, cont)
      return resolve(t, function(v, n)
         for key, value in pairs(v) do
            self[n] = key
            local r = cont(value, n+1); if r then return r end
         end
      end)
   end
   return self
end

function Query:alltype(ty)
   local resolve = self.resolve
   function self.resolve(t, cont)
      return resolve(t, function(v, n)
         for key, value in pairs(v) do
            if type(key) == ty then
               self[n] = key
               local r = cont(value, n+1); if r then return r end
            end
         end
      end)
   end
   return self
end

function Query:match(patt)
   local resolve = self.resolve
   function self.resolve(t, cont)
      return resolve(t, function(v, n)
         for key, value in pairs(v) do
            if type(key) == "string" and string_match(key, patt) then
               self[n] = key
               local r = cont(value, n+1); if r then return r end
            end
         end
      end)
   end
   return self
end

function Query:recur(limit)
   limit = limit or -1
   local function recur_resolve(t, n, deep, cont)
      for k, v in pairs(t) do
         if type(v) == "table" then
            self[n] = k
            local r = cont(v, n+1); if r then return r end
            if deep ~= 1 then
               recur_resolve(v, n+1, deep-1, cont)
            end
         end
      end
   end
   local resolve = self.resolve
   function self.resolve(t, cont)
      return resolve(t, function(v, n)
         local r = cont(v, n); if r then return r end
         recur_resolve(v, n, limit, cont)
      end)
   end
   return self
end

function Query:slice(first, last, step)
   first, last, step = first or 1, last or -1, step or 1
   local resolve = self.resolve
   function self.resolve(t, cont)
      return resolve(t, function(v, n)
         local cm, cn = first, last
         if cm < 0 then cm = #v + cm + 1 end
         if cn < 0 then cn = #v + cn + 1 end
         for i = cm, cn, step do
            local value = v[i]
            if value ~= nil then
               self[n] = i
               local r = cont(value, n+1); if r then return r end
            end
         end
      end)
   end
   return self
end

function Query:query(t, visit)
   if type(visit) == 'function' then
      return self.resolve(t, function(v, n) visit(v, self, n) end)
   end
   visit = visit or {}
   self.resolve(t, function(v) visit[#visit+1] = v end)
   return visit
end

function Query:querypath(t, rt)
   rt = rt or {}
   self.resolve(t, function(v, n)
      local path = { unpack(self, 1, n-1) }
      path[n] = v
      rt[#rt+1] = path
   end)
   return rt
end

return setmetatable(Query, { __call = Query.new })

