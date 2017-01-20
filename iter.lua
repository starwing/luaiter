local iter = {
   NAME    = "iter 0.1",
   URL     = "https://github.com/starwing/luaiter",
   LICENSE = "Lua License"
}


local assert, error, pairs, select, type, getmetatable, setmetatable =
      assert, error, pairs, select, type, getmetatable, setmetatable
local load   = _G.loadstring or load
local unpack = _G.unpack     or table.unpack
local ceil   = math.ceil
local floor  = math.floor
local random = math.random
local tabcat = table.concat
local sub    = string.sub
local format = string.format
local pack   = table.pack or
               function(...) return { n = select('#', ...), ... } end


-- iterator creation

local Iter = {}
Iter.__name = "iterator"
Iter.__index = Iter

local function none_iter() end

function Iter:__call(state, key)
   return self.iter(state or self.state, key or self.init)
end

function Iter:unwrap()
   return self.iter, self.state, self.init
end

local function string_iter(state, key)
   key = key + 1
   local ch = sub(state, key, key)
   if ch == "" then return end
   return key, ch
end

local function checkiter(iter, state, init)
   local t = type(iter)
   if t == "function" then
      return iter, state, init
   elseif t == "table" then
      if getmetatable(iter) == Iter then
         return iter.iter, iter.state, iter.init
      end
      return pairs(iter)
   elseif t == "string" then
      if #iter == 0 then
         return none_iter
      end
      return string_iter, iter, 0
   end
   error(format('attempt to iterate a %s value', t))
end

local function unwrap(iter)
   return iter, iter.state, iter.init
end

local function wrap(...)
   local iter, state, init = checkiter(...)
   if getmetatable(iter) == Iter then
      return unwrap(iter)
   end
   local self = {
      iter  = iter,
      state = state,
      init  = init,
   }
   if state == nil then
      self.state = self
      state = self
   end
   return setmetatable(self, Iter), state, init
end

local function wrapiters(self, ...)
   local n = select('#', ...)
   if n == 0 then return wrap(none_iter) end
   if n >= 3 then
      local last = select(n - 2, ...)
      if type(last) == 'table' and getmetatable(last) == Iter
         and last.state == select(n - 1, ...)
         and last.init == select(n, ...)
      then
         n = n - 2
      end
   end
   local c = 0
   for i = 1, n do
      c = c + 4
      self[c-3], self[c-2], self[c-1], self[c] = checkiter((select(i, ...)))
   end
   self.c = c
   return unwrap(self)
end

iter.iter = wrap
iter.wrap = wrap
iter.none = function() return wrap(none_iter) end


-- generators

local function inc_iter(state, key)
   return key + state[3]
end

local function range_iter(state, key)
   key = key + state[3]
   if key <= state[2] then return key end
end

local function range_reviter(state, key)
   key = key + state[3]
   if key >= state[2] then return key end
end

local function range(first, last, step)
   if last == nil and step == nil then
      if not first or first >= 0 then return range(1, first, 1) end
      return range(-1, first, -1)
   end
   step = step or 1
   assert(step ~= 0, "step must not be zero")
   local iter = wrap(
      last == nil and inc_iter or
      step >= 0 and range_iter or range_reviter)
   iter.init = first - step
   iter[1], iter[2], iter[3] = nil, last, step
   return unwrap(iter)
end

local function rand_iter()  return random() end
local function rand2_iter(state) return random(state.first, state.last) end

local function rand(first, last)
   if not first and not last then
      return wrap(rand_iter)
   elseif not last then
      return rand(0, first)
   end
   local iter = wrap(rand2_iter)
   iter.first = first
   iter.last  = last
   return unwrap(iter)
end

local function tab_iter(state, key)
   if key == nil then state.i = -1 end
   local i = state.i + 1
   state.i = i
   return state.func(i)
end

local function tab(func)
   local self = wrap(tab_iter)
   self.func = assert(func, "expected a function value")
   return unwrap(self)
end

local function str_iter(state, key)
   if key == nil then state.i = 0 end
   local i = state.i + 1
   local v = sub(state.s, i, i)
   state.i = i
   return v ~= "" and v or nil
end

local function str(s)
   local self = wrap(str_iter)
   self.s = assert(s, "s must be a string")
   return unwrap(self)
end

local function array_iter(state, key)
   if key == nil then state.i = 0 end
   local i = state.i + 1
   local v = state.t[i]
   state.i = i
   return v
end

local function array(t)
   local self = wrap(array_iter)
   self.t = assert(t, "t must be a table")
   return unwrap(self)
end

local function resolve_iter(state, key)
   if key == nil then return unpack(state) end
end

local function resolve(...)
   if ... == nil then return wrap(none_iter) end
   local self = setmetatable(pack(...), Iter)
   self.iter  = resolve_iter
   self.state = self
   return unwrap(self)
end

local function dup1_iter(state) return state end
local function dupn_iter(state) return unpack(state, 1, state.n) end

local function dup(v, ...)
   local n = select('#', ...)
   if n == 0 then return wrap(dup1_iter, v) end
   return wrap(dupn_iter, { n = n + 1, v, ... })
end
iter.range   = range
iter.rand    = rand
iter.tab     = tab
iter.str     = str
iter.array   = array
iter.resolve = resolve
iter.dup     = dup
iter.zeros   = function() return dup(0) end
iter.ones    = function() return dup(1) end


-- export routines

local function alias(f1, f2, ...)
   for i = 1, select('#', ...) do
      local name = select(i, ...)
      iter[name] = f1
      Iter[name] = f2
   end
end

local function raw_unwrap(iter)
   return iter.iter, iter.state, iter.init
end

local function export0(f, ...)
   alias(function(...)
      return f(checkiter(...))
   end, function(self)
      return f(raw_unwrap(self))
   end, ...)
end

local function export1(f, ...)
   alias(function(arg1, ...)
      return f(arg1, checkiter(...))
   end, function(self, arg1)
      return f(arg1, raw_unwrap(self))
   end, ...)
end

local function export2(f, ...)
   alias(function(arg1, arg2, ...)
      return f(arg1, arg2, checkiter(...))
   end, function(self, arg1, arg2)
      return f(arg1, arg2, raw_unwrap(self))
   end, ...)
end

local function exportn(f, ...)
   alias(f, f, ...)
end


-- slicing

local function calliter(state)
   return state[1](state[2], state[4] or state[3])
end

local function iter_collect(state, key, ...)
   if key == nil then return end
   state[4] = key
   return key, ...
end

local function take_iter(state, key)
   if key == state.init then state.i = state.last end
   local i = state.i - 1
   if i < 0 then return end
   state.i = i
   return state[1](state[2], key)
end

local function take(last, ...)
   local self = wrap(take_iter)
   self[1], self[2], self[3] = ...
   self.init = self[3]
   self.last = last
   return unwrap(self)
end

local function drop_iter(state, key)
   local piter, pstate = state[1], state[2]
   if key == state.init then
      for _ = 1, state.first do
         key = piter(pstate, key)
         if key == nil then return end
      end
   end
   return piter(pstate, key)
end

local function drop(first, ...)
   local self = wrap(drop_iter)
   self[1], self[2], self[3] = ...
   self.init = self[3]
   self.first = first
   return unwrap(self)
end

local function slice(first, last, ...)
   if last < first or last <= 0 then return wrap(none_iter) end
   if first < 1 then first = 1 end
   local iter = drop(first-1, ...)
   return take(last - first + 1, raw_unwrap(iter))
end

export1(take,  "take")
export1(drop,  "drop")
export2(slice, "slice")


-- transforms

local function map_collect(state, key, ...)
   if key == nil then return end
   state[4] = key
   return state.func(key, ...)
end

local function map_iter(state, key)
   if key == nil then state[4] = nil end
   return map_collect(state, calliter(state))
end

local function map(func, ...)
   local self = wrap(map_iter)
   self.func = assert(func, "expected a function value")
   self[1], self[2], self[3] = ...
   return unwrap(self)
end

local function flatmap_collect(state, key, ...)
   if key == nil then
      local citer, cstate, cinit = map_collect(state, calliter(state))
      if not citer then return end
      state[4], state[5], state[6], state[7] = citer, cstate, cinit, nil
      return flatmap_collect(state, citer(cstate, cinit))
   end
   state[4] = key
   return key, ...
end

local function flatmap_iter(state, key)
   if key == nil then
      state[4] = nil
      return flatmap_collect(state)
   end
   local citer, cstate = state[4], state[5]
   if not citer then return flatmap_collect(state) end
   return flatmap_collect(state, citer(cstate, state[7]))
end

local function flatmap(func, ...)
   local self = wrap(flatmap_iter)
   self.func = assert(func, "expected a function value")
   self[1], self[2], self[3] = ...
   return unwrap(self)
end

local function scan_call(state, res, ...)
   state.curr = res
   return res, ...
end

local function scan_collect(state, key, ...)
   if key == nil then return end
   state[4] = key
   return scan_call(state, state.func(state.curr, key, ...))
end

local function scan_iter(state, key)
   if key == nil then state.curr, state[4] = state.first, nil end
   return scan_collect(state, calliter(state))
end

local function scan(func, init, ...)
   local self = wrap(scan_iter)
   self.func = assert(func, "expected a function value")
   self.first = init
   self[1], self[2], self[3] = ...
   return unwrap(self)
end

local function group_collect1(state, n, key)
   local piter, pstate = state[1], state[2]
   local args = state.args
   local cn = state.c-state.i
   args[n] = key
   for i = 1, cn do
      key = piter(pstate, key)
      if key == nil then
         state.i = nil
         return unpack(args, 1, n+i-1)
      end
      args[n+i] = key
   end
   state.i, state[4] = 1, key
   return unpack(args, 1, n+cn)
end

local function group_collect(state, n, key, ...)
   if key == nil then
      state.i = nil
      return unpack(state.args, 1, n-1)
   end
   local cn = select('#', ...)
   if cn == 0 then return group_collect1(state, n, key) end
   local args = state.args
   args[n] = key
   for i = 1, cn do
      args[n+i] = select(i, ...)
   end
   if state.i < state.c then
      state.i = state.i + 1
      return group_collect(state, n+cn+1, calliter(state))
   end
   state.i, state[4] = 1, key
   return unpack(args, 1, n+cn)
end

local function group_iter(state, key)
   if key == nil then state.i, state[4] = 1, nil end
   if not state.i then return end
   return group_collect(state, 1, calliter(state))
end

local function group(n, ...)
   if n < 1 then return wrap(none_iter) end
   local self = wrap(group_iter)
   self.args = {}
   self.c = n
   self[1], self[2], self[3] = ...
   return unwrap(self)
end

local function groupby_collect(state, n, key, ...)
   if key == nil then
      state.stop = true
      return unpack(state.args, 1, n-1)
   end
   local old = state.group
   state.group = state.func(key, ...)
   state[4] = key
   local cn = select('#', ...)
   if n == 1 or state.group == old then
      local args = state.args
      args[n] = key
      for i = 1, cn do args[n+i] = select(i, ...) end
      return groupby_collect(state, n+cn+1, calliter(state))
   end
   local args, cached = state.cached, state.args
   args[1] = key
   for i = 1, cn do args[i+1] = select(i, ...) end
   state.i = cn + 2
   state.args, state.cached = args, cached
   return unpack(cached, 1, n-1)
end

local function groupby_iter(state, key)
   if key == nil then state.i, state.stop, state[4] = 1, false, nil end
   if state.stop then return end
   return groupby_collect(state, state.i, calliter(state))
end

local function groupby(func, ...)
   local self = wrap(groupby_iter)
   self.func = assert(func, "expected a function value")
   self.args   = {}
   self.cached = {}
   self[1], self[2], self[3] = ...
   return unwrap(self)
end

export1(map,     "map")
export1(flatmap, "flatmap", "flat_map", "flatMap")
export2(scan,    "scan", "accumulate", "reductions")
export1(group,   "group")
export1(groupby, "groupby", "group_by", "groupBy")


-- compositions

local function zip_collect(state, c, key, ...)
   if key == nil then return end
   state[c+3] = key
   local args, n = state.args, state.n
   args[n] = key
   local cn = select('#', ...)
   for i = 1, cn do
      args[n+i] = select(i, ...)
   end
   state.n = n + cn + 1
   c = c + 4
   if c > state.c then
      return unpack(args, 1, state.n-1)
   end
   local citer, cstate, ckey = state[c], state[c+1], state[c+3] or state[c+2]
   return zip_collect(state, c, citer(cstate, ckey))
end

local function zip_iter(state, key)
   if key == nil then
      for i = 1, state.c, 4 do
         state[i+3] = nil
      end
   end
   local citer, cstate, ckey = state[1], state[2], state[4] or state[3]
   state.n = 1
   return zip_collect(state, 1, citer(cstate, ckey))
end

local function zip(...)
   local self = wrap(zip_iter)
   self.args = {}
   return wrapiters(self, ...)
end

function Iter:prefix(...)
   local iter = wrap(zip_iter)
   iter.args = {}
   wrapiters(iter, ...)
   local c = iter.c + 1
   iter[c], iter[c+1], iter[c+2] = raw_unwrap(self)
   iter.c = c + 3
   return iter
end

local function interleave_collect(state, key, ...)
   if key == nil then return end
   local i = state.i + 4
   state.i = i > state.c and 1 or i
   state[i-1] = key
   return key, ...
end

local function interleave_iter(state, key)
   if key == nil then
      state.i = 1
      for i = 1, state.c, 4 do
         state[i+3] = nil
      end
   end
   local c = state.i
   local citer, cstate, ckey = state[c], state[c+1], state[c+3] or state[c+2]
   return interleave_collect(state, citer(cstate, ckey))
end

local function interleave(...)
   return wrapiters(wrap(interleave_iter), ...)
end

local function chain_collect(state, c, key, ...)
   if key == nil then
      c = c + 4
      state.i = c
      if c > state.c then return end
      local citer, cstate, cinit = state[c], state[c+1], state[c+2]
      return chain_collect(state, c, citer(cstate, cinit))
   end
   state[c+3] = key
   return key, ...
end

local function chain_iter(state, key)
   if key == nil then
      state.i = 1
      for i = 1, state.c, 4 do
         state[i+3] = nil
      end
   end
   local c = state.i
   local citer, cstate, ckey = state[c], state[c+1], state[c+3] or state[c+2]
   return chain_collect(state, c, citer(cstate, ckey))
end

local function chain(...)
   return wrapiters(wrap(chain_iter), ...)
end

local function cycle_collect(state, key, ...)
   state[4] = key
   if key == nil then
      return cycle_collect(state, calliter(state))
   end
   return key, ...
end

local function cycle_iter(state, key)
   if key == nil then
      state[4] = nil
      return iter_collect(state, calliter(state))
   end
   return cycle_collect(state, calliter(state))
end

local function cycle(...)
   local self = wrap(cycle_iter)
   self[1], self[2], self[3] = ...
   return unwrap(self)
end

exportn(zip,        "zip")
exportn(interleave, "interleave")
exportn(chain,      "chain")
export0(cycle,      "cycle")


-- filtering

local function takewhile_collect(func, key, ...)
   if key == nil then return end
   if func(key, ...) then return key, ...  end
end

local function takewhile_iter(state, key)
   local func, piter, pstate = state.func, state[1], state[2]
   return takewhile_collect(func, piter(pstate, key))
end

local function takewhile(func, iter, state, init)
   local self = wrap(takewhile_iter, nil, init)
   self.func = assert(func, "expected a function value")
   self[1], self[2], self[3] = iter, state, init
   return wrap(self)
end

local function dropwhile(func, iter, state, init)
   local self = wrap(takewhile_iter, nil, init)
   assert(func, "expected a function value")
   self.func = function(...) return not func(...) end
   self[1], self[2], self[3] = iter, state, init
   return unwrap(self)
end

local function filter_collect(func, iter, state, key, ...)
   if select('#', ...) == 0 then
      while key ~= nil do
         if func(key) then return key end
         key = iter(state, key)
      end
   end
   if key == nil then return end
   if func(key, ...) then return key, ...  end
   return filter_collect(func, iter, state, iter(state, key))
end

local function filter_iter(state, key)
   local func, piter, pstate = state.func, state[1], state[2]
   return filter_collect(func, piter, pstate, piter(pstate, key))
end

local function filter(func, iter, state, init)
   local self = wrap(filter_iter, nil, init)
   self.func = assert(func, "expected a function value")
   self[1], self[2], self[3] = iter, state, init
   return unwrap(self)
end

local function filterout(func, iter, state, init)
   assert(func, "expected a function value")
   local self = wrap(filter_iter, nil, init)
   self.func = function(...) return not func(...) end
   self[1], self[2], self[3] = iter, state, init
   return unwrap(self)
end

export1(takewhile, "takewhile", "take_while", "takeWhile")
export1(dropwhile, "dropwhile", "drop_while", "dropWhile")
export1(filter,    "filter", "removeifnot", "remove_if_not", "removeIfNot")
export1(filterout, "filterout", "filter_out", "filterOut",
                   "removeif", "remove_if", "removeIf")


-- reducing

local function each_collect(func, key, ...)
   if key == nil then return end
   return func(key, ...) or key
end

local function each(func, iter, state, key)
   repeat
      key = each_collect(func, iter(state, key))
   until key == nil
end

local function foldl_detect(func, init, key, ...)
   if key == nil then return nil, init end
   return select('#', ...), key, func(init, key, ...)
end

local function foldl_collect(func, init, key, ...)
   if key == nil then return nil, init end
   return key, func(init, key, ...)
end

local function foldl(func, init, iter, state, key)
   if init == nil then
      key = iter(state, key)
      if key == nil then return end
      init = key
   end
   assert(func, "expected a function value")
   local n
   n, key, init = foldl_detect(func, init, iter(state, key))
   if key == nil then return init end
   if n == 0 then
      for v in iter, state, init do
         init = func(init, v)
      end
   else
      while true do
         key, init = foldl_collect(func, init, iter(state, key))
         if key == nil then break end
      end
   end
   return init
end

local function index_collect(func, iter, state, i, key, ...)
   if key == nil then return end
   if func(key, ...) then
      return i + 1, key, ...
   end
   return index_collect(func, iter, state, i + 1, iter(state, key))
end

local function index(func, iter, state, key)
   assert(func, "expected a function value")
   return index_collect(func, iter, state, 0, iter(state, key))
end

local function collect_collect(t, n, key, ...)
   if key == nil then return nil, n-1 end
   local cn = select('#', ...)
   t[n] = key
   for i = 1, cn do
      t[n + i] = select(i, ...)
   end
   return key, n + cn + 1
end

local function collect(t, iter, state, key)
   t = t or {}
   local n = #t + 1
   while true do
      key, n = collect_collect(t, n, iter(state, key))
      if key == nil then return t, n end
   end
end

local function concat(delim, iter, state, key)
   local t = {}
   local n = 0
   for v in iter, state, key do
      n = n + 1
      t[n] = v
   end
   return tabcat(t, delim, 1, n)
end

local function count(iter, state, key)
   local n = 0
   for _ in iter, state, key do n = n + 1 end
   return n
end

local function isempty(iter, state, key)
   return iter(state, key) == nil
end

local function predicate_collect(func, key, ...)
   if key == nil then return end
   return func(key, ...), key
end

local function any(func, iter, state, key)
   assert(func, "expected a function value")
   local r
   while true do
      r, key = predicate_collect(func, iter(state, key))
      if key == nil then return false end
      if r          then return true end
   end
end

local function all(func, iter, state, key)
   assert(func, "expected a function value")
   local r
   while true do
      r, key = predicate_collect(func, iter(state, key))
      if key == nil then return true end
      if not r      then return false end
   end
end

export1(each,    "each", "foreach", "for_each", "forEach")
export2(foldl,   "reduce", "foldl")
export1(index,   "index")
export1(collect, "collect")
export1(concat,  "concat")
export0(count,   "count", "length")
export0(isempty, "isempty", "is_empty", "isEmpty")
export1(all,     "all", "every")
export1(any,     "any", "some")


-- operators

local Selector = {} do
Selector.__name  = "selector"

local rawget, rawset = rawget, rawset
local make_selector = function(t) return setmetatable(t, Selector) end

local function gen(v, root)
   if getmetatable(v) == Selector then return v.gen(root) end
   local t = type(v)
   if t == "nil" or t == "boolean" or t == "number" then
      return tostring(v)
   elseif t == "string" then
      return format('%q', v)
   end
   local n = root.n + 1
   root.n = n
   rawset(root, n, v)
   return "_["..n.."]"
end

local function unary(op, a)
   return make_selector {
      gen = function(root) return "("..op..gen(a, root)..")" end }
end

local function binary(op, a, b)
   return make_selector {
      gen = function(root)
         return "("..gen(a, root)..op..gen(b, root)..")" end }
end

function Selector.__newindex()   error("attempt to change a selector") end
function Selector.__add(a, b)    return binary('+',  a, b) end
function Selector.__band(a, b)   return binary('&',  a, b) end
function Selector.__bnot(a)      return unary ('~',  a   ) end
function Selector.__bnot(a)      return binary('~',  a, a) end
function Selector.__bor(a, b)    return binary('|',  a, b) end
function Selector.__bxor(a, b)   return binary('~',  a, b) end
function Selector.__concat(a, b) return binary('..', a, b) end
function Selector.__div(a, b)    return binary('/',  a, b) end
function Selector.__idiv(a, b)   return binary('//', a, b) end
function Selector.__len(a)       return unary ('#',  a   ) end
function Selector.__mod(a, b)    return binary('%',  a, b) end
function Selector.__mul(a, b)    return binary('*',  a, b) end
function Selector.__pow(a, b)    return binary('^',  a, b) end
function Selector.__shl(a, b)    return binary('<<', a, b) end
function Selector.__shr(a, b)    return binary('>>', a, b) end
function Selector.__sub(a, b)    return binary('-',  a, b) end
function Selector.__unm(a)       return unary ('-',  a   ) end

function Selector.__index(a, b)
   return make_selector {
      gen = function(root)
         return format("(%s[%s])", gen(a, root), gen(b, root))
      end
   }
end

function Selector:__call(...)
   local eval = rawget(self, "eval")
   if not eval then
      rawset(self, 'n',    0)
      rawset(self, 'max',  0)
      rawset(self, 'dots', false)
      local expr = self.gen(self)
      local code = "return function(_, _"..range(self.max):concat ", _"
      if self.dots then code = code .. ", ..." end
      code = code .. ") return "..expr.."; end"
      eval = assert(load(code, expr))()
      rawset(self, "eval", eval)
   end
   return eval(self, ...)
end

local function call(...)
   local args = pack(...)
   return make_selector {
      gen = function(root)
         for i = 1, args.n do
            args[i] = gen(args[i], root)
         end
         return args[1].."("..tabcat(args, ", ", 2, args.n)..")"
      end
   }
end

local selectors = {
   call = call;
   self = function(obj)
      return setmetatable({}, {
         __index = function(_, key)
            return function(...) return call(obj[key], obj, ...) end
         end;
      })
   end;
   dots = make_selector {
      eval = function(_, ...) return ... end;
      gen = function(root)
         root.dots = true
         return "..."
      end;
   };

   lt    = function(a, b) return binary("<",   a, b) end;
   le    = function(a, b) return binary("<=",  a, b) end;
   gt    = function(a, b) return binary(">",   a, b) end;
   ge    = function(a, b) return binary(">=",  a, b) end;
   eq    = function(a, b) return binary("==",  a, b) end;
   ne    = function(a, b) return binary("~=",  a, b) end;
   land  = function(a, b) return binary("and", a, b) end;
   lnot  = function(a)    return unary ("not", a   ) end;
   lor   = function(a, b) return binary("or",  a, b) end;
   andor = function(a, b, c)
      return make_selector {
         gen = function(root)
            return format("(%s and %s or %s)",
                          gen(a, root), gen(b, root), gen(c, root))
         end
      }
   end;
}

for i = 1, 9 do
   local selector = make_selector {
      eval = assert(load("return function(_, _"..range(i):concat ", _"..
                         ") return _"..i.. " end", '_'..i))();
      gen = function(root)
         if root.max < i then root.max = i end
         return '_'..i
      end;
   }
   selectors[i] = selector
   iter['_'..i] = selector
end

iter._ = setmetatable(selectors, {
   __newindex = Selector.__newindex;
   __call = function(_, f)
      if type(f) == "string" then
         return assert(load("return function(_"..range(9):concat ", _"..
                            ") return "..f.."; end", f))()
      end
      return function(...) return call(f, ...) end
   end;
})

end

local Operator = {
   id = function(...) return ... end;

   -- Comparison operators
   eq = function(a, b) return a == b end;
   lt = function(a, b) return a <  b end;
   le = function(a, b) return a <= b end;
   ne = function(a, b) return a ~= b end;
   gt = function(a, b) return a >  b end;
   ge = function(a, b) return a >= b end;

   -- Arithmetic operators
   add = function(a, b) return a + b end;
   sub = function(a, b) return a - b end;
   mul = function(a, b) return a * b end;
   div = function(a, b) return a / b end;
   mod = function(a, b) return a % b end;
   pow = function(a, b) return a ^ b end;
   neg = function(a)    return   - a end;
   unm = function(a)    return   - a end;

   floordiv = function(a, b) return floor(a/b) end;
   intdiv   = function(a, b)
      local q = a / b
      if a >= 0 then return floor(q) else return ceil(q) end
   end;

   -- String operators
   cat    = function(a, b) return a .. b end;
   concat = function(a, b) return a .. b end;
   len    = function(a)    return    # a end;
   length = function(a)    return    # a end;

   -- Posfix operators
   index = function(a, b)   return a[b]   end;
   call  = function(a, ...) return a(...) end;

   -- logic operators
   landor = function(a, b, c) return a and b or c end;
   land   = function(a, b)    return a and b      end;
   lor    = function(a, b)    return a       or b end;
   lnot   = function(a)       return   not a      end;

   -- misc
   newindex = function(a, b, c) a[b] = c end;
}

--[[Lua 5.3 operators]] do
   local loader = load [[
      local Operator = ...
      function Operator.idiv(a, b) return a // b end
      function Operator.band(a, b) return a &  b end
      function Operator.bor(a, b)  return a |  b end
      function Operator.bxor(a, b) return a ~  b end
      function Operator.bnot(a)    return   ~  a end
      function Operator.shl(a, b)  return a << b end
      function Operator.shr(a, b)  return a >> b end
   ]]
   if loader then loader(Operator) end
end

setmetatable(Operator, {
   __call = function(self, op)
      op = assert(self[op], "not such operator")
      return iter._(op)
   end
})

iter.op       = Operator
iter.operator = Operator


-- export

return setmetatable(iter, {
   __call = function(iter, t)
      t = t or _G
      for k, v in pairs(iter) do
         t[k] = v
      end
      return iter
   end
})

-- cc: src='test.lua'

