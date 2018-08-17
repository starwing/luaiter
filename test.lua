local unit = require "luaunit"
local eq = unit.assert_equals

require "iter" ()

local select = select
local tostring = tostring
local table_concat = table.concat

local function newWriter()
   local t = {}
   local function writer(...)
      local n = select('#', ...)
      if n == 0 then return table_concat(t) end
      for i = 1, n do
         t[#t+1] = tostring((select(i, ...)))
      end
      return writer
   end
   return writer
end

local function newDumper()
   local self = {}
   local b = {}
   local n = 0
   function self.reset()
      n = 0
   end
   function self.geterror(f)
      n = 0
      local ok, res = pcall(f, self)
      if ok then error("error expected in test") end
      return res:match "^.-:%d+:%s*(.-)$".."\n"
   end
   function self.dump()
      return table_concat(self, nil, 1, n)
   end
   return setmetatable(self, {
      __call = function(_, ...)
         local cn = select('#', ...)
         for i = 1, cn do
            b[i] = tostring((select(i, ...)))
         end
         n = n + 1
         self[n] = table_concat(b, ",", 1, cn).."\n"
      end
   })
end

local function gen_test()
   io.input "test.impl.lua"
   local w = newWriter()
   local output, buff
   w "local newDumper, eq = ...; "
   for line in io.lines() do
      local res
      repeat
         res = line:match "%s*%-%-%!%s+([%w_]+)%s*"
         if res then
            if buff then w (table_concat(buff)) " end;" end
            w "function test_" (res) "() local print = newDumper()\n"
            buff = {}
            break
         end
         res = line:match "^%s*%-%-%[%[OUTPUT%s*$"
         if res then
            w "  print:reset(); do "
            w (table_concat(buff)) "  end; eq(print:dump(), [==[\n"
            output = true
            buff = {}
            break
         end
         res = line:match "^%s*%-%-%[%[ERROR%s*$"
         if res then
            w "  eq(print.geterror(function(print) "
            w (table_concat(buff)) "  end), [==[\n"
            output = true
            buff = {}
            break
         end
         res = line:match "^%s*%-%-%]%]%s*$"
         if output and res then
            w(table_concat(buff)) "]==])\n"
            output = false
            buff = {}
            break
         end
         if buff then
            buff[#buff+1] = line.."\n"
         else
            w(line) "\n"
         end
      until true
   end
   if buff then w (table_concat(buff)) "end\n" end
   io.input():close()
   local code = w()
   if 1 < 0 then
      io.output 'test.out.lua'
      io.write(code)
      io.close()
   end
   return code
end

assert((_G.loadstring or load)(gen_test(), "@test.impl.lua"))(newDumper, eq)

os.exit(unit.LuaUnit.run(), true)

