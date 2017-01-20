local pairs, type, setmetatable, string_match =
      pairs, type, setmetatable, string.match
local unpack = _G.unpack or table.unpack

local Query = {}
Query.__name = "query"
Query.__index = Query

function Query.new()
   return setmetatable({
      resolve = function(t, cont) return cont(t, 1) end,
      blacklist = nil }, Query)
end

function Query:clearpath()
   for i = 1, #self do
      self[i] = nil
   end
   return self
end

function Query:recur()
   local function recur_resolve(t, n, cont)
      local blacklist = self.blacklist
      for k, v in pairs(t) do
         if type(v) == "table" and not blacklist[v] then
            blacklist[v] = true
            self[n] = k
            if cont(v, n+1) then return end
            recur_resolve(v, n+1, cont)
         end
      end
   end
   local resolve = self.resolve
   self.resolve = function(t, cont)
      return resolve(t, function(v, n)
         local blacklist = self.blacklist
         if blacklist then
            if blacklist[v] then return end
            blacklist[v] = true
         end
         self.blacklist = { [v] = true }
         if cont(v, n) then return end
         recur_resolve(v, n, cont)
         self.blacklist = blacklist
      end)
   end
   return self
end

function Query:index(key)
   local resolve = self.resolve
   self.resolve = function(t, cont)
      return resolve(t, function(v, n)
         local value = v[key]
         if value then self[n] = key; return cont(value, n+1) end
      end)
   end
   return self
end

function Query:match(patt)
   local resolve = self.resolve
   self.resolve = function(t, cont)
      return resolve(t, function(v, n)
         for key, value in pairs(v) do
            if type(key) == "string" and string_match(key, patt) then
               self[n] = key; return cont(value, n+1)
            end
         end
      end)
   end
   return self
end

function Query:slice(first, last)
   local resolve = self.resolve
   self.resolve = function(t, cont)
      return resolve(t, function(v, n)
         local cm, cn = first or 1, last or -1
         if cm < 0 then cm = #v + cm + 1 end
         if cn < 0 then cn = #v + cn + 1 end
         for i = cm, cn do
            local value = v[i]
            if value then self[n] = i; return cont(value, n+1) end
         end
      end)
   end
   return self
end

function Query:map(f)
   local resolve = self.resolve
   self.resolve = function(t, cont)
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
   self.resolve = function(t, cont)
      return resolve(t, function(v, n)
         if f(v, self, n-1) then return cont(v, n) end
      end)
   end
   return self
end

function Query:all(ty)
   local resolve = self.resolve
   if not ty then
      self.resolve = function(t, cont)
         return resolve(t, function(v, n)
            for key, value in pairs(v) do
               self[n] = key; cont(value, n+1)
            end
         end)
      end
   else
      self.resolve = function(t, cont)
         return resolve(t, function(v, n)
            for key, value in pairs(v) do
               if type(value) == ty then
                  self[n] = key; cont(value, n+1)
               end
            end
         end)
      end
   end
   return self
end

function Query:collect(coll)
   local resolve = self.resolve
   self.resolve = function(t, cont)
      return resolve(t, function(v, n)
         coll[#coll+1] = v
         return cont(v, n)
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

