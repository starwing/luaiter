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
local pack   = table.pack or function(...) return { n = select('#', ...), ... } end


-- iterator creation
-- there are two categories of iterators: statless iterator and
-- stateful iterator.  In both case, iterator not allowed to change
-- state.
--
-- Stateless iterator should implement "iter" callback that generates
-- next values only from previous value.  It doesn't has internal
-- state.  To copy a stateless iterator, just copy it's essential
-- fields into a new table and makes it as an iterator.
--
-- A stateful iterator has its own modifiable internal state, the
-- "self" table. It still can not change state in iteration, but it
-- can modify it's "self" table.  A stateful iterator should implement
-- "next" callback, accept self table and state to generates next
-- values, by read/write the self table.
--
-- Stateful iterator has a "reset" callback that will be called with
-- one or two arguments.  If only one argument passed, it initlizes
-- the self table to prepare a new iteration going.  If it's called by
-- two arguments, "this" and "other", it should copy modifiable
-- internal state from "other", the same type iterator, and ensure
-- itself generates the same results as "other".
--
-- If iterators has sub iterator, i.e. composition iterator, they are
-- on iterator's array part, e.g. map() iterator has a sub iterator,
-- it puts on map iterator subscript 1.
--
-- All iterators has several public routines:
--    - rewind: rewind iterator to generates values from start.
--    - clone:  clone a iterator
--    - call directly: generates next values.
--    - as a iterator: iterates values.
--
-- iterators' internal callbacks must not be called directly:
--    - reset: prepare another iteration.
--    - next:  disable the "iter" callback and makes iterator stateful.
--    - iter:  makes iterator stateless.


local Iter   = {}
Iter.__name  = "iterator"
Iter.__index = Iter

-- internal callback defaults
function Iter:reset(other)
   if other then
      for i, base in ipairs(other) do self[i] = base:clone() end
   else
      for _, base in ipairs(self) do base:rewind() end
   end
   return self
end

local function collect_current(self, key, ...)
   self.current = key
   return key, ...
end

function Iter:next(state)
   return collect_current(self, self.iter(state, self.current))
end

local function collect(self, key, ...)
   if key == nil then self.stopped = true end
   return key, ...
end

function Iter:__call()
   if self.stopped then return end
   return collect(self, self:next(self.state))
end

function Iter:rewind()
   if self.stopped then
      self.stopped, self.current = nil, self.init
      if self.next ~= Iter.next then
         return self:reset() or self
      end
   end
   return self
end

function Iter:clone()
   local new = setmetatable({ state = self.state }, Iter)
   if self.next == Iter.next then
      new.iter    = self.iter
      new.init    = self.init
      new.current = self.current
   else
      new.next  = self.next
      new.reset = self.reset
      new = new:reset(self) or new
   end
   return new
end

local function new_stateless(func, state, init)
   local self = { iter = func, state = state, init = init, current = init }
   if not state then self.state = self end
   return setmetatable(self, Iter)
end

local function new_stateful(reset, func, state)
   local self = { reset = reset, next = func, state = state }
   if not state then self.state = self end
   return reset(setmetatable(self, Iter)) or self
end

local function nil_iter() end
local function string_iter(state, key)
   key = (key or 0) + 1
   local ch = sub(state, key, key)
   if ch == "" then return end
   return key, ch
end

local function newiter(v, state, init)
   local t = type(v)
   if t == "table" then
      if getmetatable(v) == Iter then return v:clone() end
      return new_stateless(pairs(v))
   elseif t == "function" then
      return new_stateless(v, state, init)
   elseif t == "string" then
      return new_stateless(string_iter, v, 0)
   elseif t == "nil" then
      return new_stateless(nil_iter)
   end
   local mt = getmetatable(v)
   if mt and mt.__pairs then return new_stateful(pairs(v)) end
   error(format('attempt to iterate a %s value', t))
end

iter.iter = newiter
iter.none = function() return iter() end


-- generators

local function inc_iter(state, key)
   return key + state
end

local function range_iter(state, key)
   key = key + state.step
   if key <= state.last then return key end
end

local function rrange_iter(state, key)
   key = key + state.step
   if key >= state.last then return key end
end

local function range(first, last, step)
   if last == nil and step == nil then
      if not first or first >= 0 then
         return range(1, first, 1)
      else
         return range(-1, first, -1)
      end
   end
   step = step or 1
   if step == 0 then return newiter() end
   if last == nil then
      return new_stateless(inc_iter, step, first - step)
   end
   local self = new_stateless(step >= 0 and range_iter or rrange_iter,
                              nil, first - step)
   local state = self.state
   state.first, state.last, state.step = first, last, step
   return self
end

local function rand_iter()       return random() end
local function rand2_iter(state) return random(state.first, state.last) end

local function rand(first, last)
   if not first and not last then
      return new_stateless(rand_iter)
   elseif not last then
      return rand(0, first)
   end
   local self = new_stateless(rand2_iter)
   local state = self.state
   state.first, state.last = first, last
   return self
end

local function array_reset(self, other)
   self.index = other and other.index or 0
end

local function array_next(self, state)
   local i = self.index + 1
   local v = state[i]
   self.index = i
   return v
end

local function array(t)
   assert(t, "table expected")
   return new_stateful(array_reset, array_next, t)
end

local function resolve1_iter(state, key) if key == nil then return state end end
local function resolven_iter(state, key) if key == nil then return unpack(state) end end

local function resolve(v, ...)
   local n = select('#', ...)
   if n == 0 then return new_stateless(resolve1_iter, v) end
   local self = pack(v, ...)
   self.iter  = resolven_iter
   self.state = self
   return setmetatable(self, Iter)
end

local function dup1_iter(state) return state end
local function dupn_iter(state) return unpack(state, 1, state.n) end

local function dup(v, ...)
   local n = select('#', ...)
   if n == 0 then return new_stateless(dup1_iter, v) end
   local self = pack(v, ...)
   self.iter  = dupn_iter
   self.state = self
   return setmetatable(self, Iter)
end

iter.range   = range
iter.rand    = rand
iter.array   = array
iter.resolve = resolve
iter.dup     = dup
iter.zeros   = function() return dup(0) end
iter.ones    = function() return dup(1) end


-- export routines

local function id(...) return ... end

local function alias(f1, f2, ...)
   for i = 1, select('#', ...) do
      local name = select(i, ...)
      iter[name] = f1
      Iter[name] = f2
   end
end

local function export0(f, ...)
   alias(function(...)
      return f(newiter(...))
   end, function(self)
      return f(self:clone())
   end, ...)
end

local function export1(f, ...)
   alias(function(arg1, ...)
      return f(arg1, newiter(...))
   end, function(self, arg1)
      return f(arg1, self:clone())
   end, ...)
end

local function export2(f, ...)
   alias(function(arg1, arg2, ...)
      return f(arg1, arg2, newiter(...))
   end, function(self, arg1, arg2)
      return f(arg1, arg2, self:clone())
   end, ...)
end

local function exportn(f, ...)
   alias(f, f, ...)
end


-- slicing

local function takedrop_reset(self, other)
   Iter.reset(self, other)
   self.remain = other and other.remain or self.state
end

local function taken_next(self)
   local remain = self.remain - 1
   if remain < 0 then return end
   self.remain = remain
   return self[1]()
end

local function taken(n, base)
   local self = new_stateful(takedrop_reset, taken_next, n)
   self[1] = base
   return self
end

local function dropn_next(self)
   local remain = self.remain
   if remain then
      self.remain = nil
      for _ = 1, remain do
         if self[1]() == nil then
            return
         end
      end
   end
   return self[1]()
end

local function dropn(n, base)
   local self = new_stateful(takedrop_reset, dropn_next, n)
   self[1]  = base
   return self
end

local function takewhile_collect(state, key, ...)
   if key == nil then return end
   if not state(key, ...) then return end
   return key, ...
end

local function takewhile_next(self, state)
   return takewhile_collect(state, self[1]())
end

local function takewhile(func, base)
   local self = new_stateful(Iter.reset, takewhile_next, func or id)
   self[1] = base
   return self
end

local function dropwhile_collect(self, state, key, ...)
   if key == nil then return end
   if self.remain ~= true then
      if state(key, ...) then return dropwhile_collect(self, state, self[1]()) end
      self.remain = true
   end
   return key, ...
end

local function dropwhile_next(self, state)
   return dropwhile_collect(self, state, self[1]())
end

local function dropwhile(func, base)
   local self = new_stateful(takedrop_reset, dropwhile_next, func or id)
   self[1] = base
   return self
end

export1(taken,     "taken", "take_n", "takeN")
export1(dropn,     "dropn", "drop_n", "dropN")
export1(takewhile, "takewhile", "take_while", "takeWhile")
export1(dropwhile, "dropwhile", "drop_while", "dropWhile")

export1(function(p, base)
   return type(p) == "function" and takewhile(p, base) or taken(p, base)
end, "take")
export1(function(p, base)
   return type(p) == "function" and dropwhile(p, base) or dropn(p, base)
end, "drop")
export2(function(first, last, base)
   if last < first or last <= 0 then return newiter() end
   if first < 1 then first = 1 end
   return taken(last - first + 1, dropn(first-1, base))
end, "slice")
export2(function(n, base)
   return taken(n, base), dropn(n, base)
end, "split", "span", "splitAt", "split_at")


-- transforms

local function enum_reset(self, other)
   Iter.reset(self, other)
   self.idx = other and other.idx or 0
   return self
end

local function enum_collect(self, key, ...)
   if not key then return end
   self.idx = self.idx + 1
   return self.idx, key, ...
end

local function enum_next(self)
   return enum_collect(self, self[1]())
end

local function enumerate(base)
   local self = new_stateful(enum_reset, enum_next)
   self[1] = base
   return self
end

local function map_collect(func, key, ...)
   if key ~= nil then return func(key, ...) end
end

local function map_next(self, state)
   return map_collect(state, self[1]())
end

local function map(func, base)
   local self = new_stateful(Iter.reset, map_next, func or id)
   self[1] = base
   return self
end

local function flatmap_reset(self, other)
   Iter.reset(self, other)
   if not other then self[2] = nil end
end

local function flatmap_collect_base(self, state, key, ...)
   if key ~= nil then
      self[2] = newiter(state(key, ...))
      return self[2]
   end
end

local function flatmap_collect(self, state, key, ...)
   if key ~= nil then return key, ... end
   if flatmap_collect_base(self, state, self[1]()) then
      return flatmap_collect(self, state, self[2]())
   end
end

local function flatmap_next(self, state)
   if not self[2] then return flatmap_collect(self, state) end
   return flatmap_collect(self, state, self[2]())
end

local function flatmap(func, base)
   local self = new_stateful(flatmap_reset, flatmap_next, func or id)
   self[1] = base
   return self
end

local function scan_reset(self, other)
   Iter.reset(self, other)
   self.current = other and other.current or nil
end

local function scan_collect(self, state, key, ...)
   if key == nil then return end
   if not self.current and not state.acc then
      return collect_current(self, state.func(key, self[1]()))
   end
   return collect_current(self, state.func(self.current or state.acc, key, ...))
end

local function scan_next(self, state)
   return scan_collect(self, state, self[1]())
end

local function scan(func, init, base)
   local self = new_stateful(scan_reset, scan_next)
   self.state.func = func or id
   self.state.acc  = init
   self[1] = base
   return self
end

local function group_reset(self, other)
   Iter.reset(self, other)
   if other then
      if other.collects then
         local collects = {}
         for k, v in pairs(other.collects) do
            collects[k] = v
         end
         self.collects = collects
      end
      self.remain = other.remain
   else
      self.collects = { n = 0 }
      self.remain   = self.state
   end
end

local function group_collect(self, state, key, ...)
   local collects = self.collects
   if key == nil then
      if collects.n == 0 then return end
      self.collects = nil
      return collects
   end
   local remain = self.remain
   remain = remain - 1
   local n, c = collects.n, select('#', ...)
   collects[n+1] = key
   for i = 1, c do
      collects[n+i+1] = select(i, ...)
   end
   collects.n = n + c + 1
   if remain <= 0 then
      self.remain   = state
      self.collects = { n = 0 }
      return collects
   end
   self.remain = remain
   return group_collect(self, state, self[1]())
end

local function group_next(self, state)
   if not self.collects then return end
   return group_collect(self, state, self[1]())
end

local function group(n, base)
   local self = new_stateful(group_reset, group_next, n)
   self[1] = base
   return self
end

local function groupby_reset(self, other)
   Iter.reset(self, other)
   if other then
      self.collects = other.collects and Iter.reset({}, other.collects) or nil
      self.dopack   = other.dopack
   else
      self.collects = {}
   end
end

local function groupby_collect(self, state, key, ...)
   local collects = self.collects
   if key == nil then
      self.collects = nil
      return collects
   end
   local oldkey = collects.key
   local newkey = state(key, ...)
   if oldkey ~= nil and oldkey ~= newkey then
      self.collects = self.dopack and { pack(key, ...) } or { (...) }
      self.collects.key = newkey
      return collects
   end
   collects.key = newkey
   collects[#collects+1] = self.dopack and pack(key, ...) or (...)
   return groupby_collect(self, state, self[1]())
end

local function groupby_next(self, state)
   if not self.collects then return end
   return groupby_collect(self, state, self[1]())
end

local function groupby(func, base)
   local self = new_stateful(groupby_reset, groupby_next, func or id)
   self[1] = base
   return self
end

export0(enumerate,   "enumerate")
export1(map,         "map")
export1(flatmap,     "flatmap", "flat_map", "flatMap")
export2(scan,        "scan", "accumulate", "reductions")
export1(group,       "group")
export1(groupby,     "groupby", "group_by", "groupBy")
export1(function(func, base)
   local self = groupby(func, base)
   self.dopack = true
   return self
end, "packgroupby", "pack_group_by", "packGroupBy")


-- compositions

local function collectiters(self, ...)
   local n = select('#', ...)
   if n == 0 then return newiter() end
   for i = 1, n do
      self[#self+1] = newiter((select(i, ...)))
   end
   return self
end

local function interleave_reset(self, other)
   Iter.reset(self, other)
   self.idx = other and other.idx or 1
end

local function interleave_collect(self, state, key, ...)
   if self.retry <= 0 then self.retry = nil; return end
   local idx = self.idx + 1
   idx = self[idx] and idx or 1
   self.idx = idx
   if key ~= nil or state.notskip then return key, ... end
   self.retry = self.retry - 1
   return interleave_collect(self, state, self[idx]())
end

local function interleave_next(self, state)
   self.retry = #self
   return interleave_collect(self, state, self[self.idx]())
end

local function interleave(...)
   return collectiters(new_stateful(interleave_reset, interleave_next), ...)
end

local function zip_reset(self, other)
   Iter.reset(self, other)
   self.collects = { n = 0 }
end

local function zip_collect(self, state, c, key, ...)
   local collects = self.collects
   local n = collects.n + 1
   collects[n] = key
   if c == #self then
      local cn = select('#', ...)
      for i = 1, cn do
         collects[n+i] = select(i, ...)
      end
      n = n + cn
   end
   collects.n = n
   c = c + 1
   if not self[c] then
      if collects[1] == nil then return end
      if state.notskip then
         for i = 2, n do
            if collects[i] == nil then return end
         end
      end
      return unpack(collects, 1, n)
   end
   return zip_collect(self, state, c, self[c]())
end

local function zip_next(self, state)
   self.collects.n = 0
   return zip_collect(self, state, 1, self[1]())
end

local function zip(...)
   return collectiters(new_stateful(zip_reset, zip_next), ...)
end

local function chain_reset(self, other)
   Iter.reset(self, other)
   self.idx = other and other.idx or 1
end

local function chain_collect(self, key, ...)
   if key ~= nil then return key, ... end
   local idx = self.idx + 1
   local base = self[idx]
   if not base then return end
   self.idx = idx
   return chain_collect(self, base())
end

local function chain_next(self)
   local base = self[self.idx]
   if not base then return end
   return chain_collect(self, base())
end

local function chain(...)
   return collectiters(new_stateful(chain_reset, chain_next), ...)
end

local function cycle_collect(self, retry, key, ...)
   if key ~= nil then return key, ... end
   if retry then
      self[1]:rewind()
      return cycle_collect(self, false, self[1]())
   end
end

local function cycle_next(self)
   return cycle_collect(self, true, self[1]())
end

local function cycle(base)
   local self = new_stateful(Iter.reset, cycle_next)
   self[1] = base
   return self
end

function Iter:prefix(...)
   local super = zip(...)
   super.notskip = true
   super[#super+1] = self:clone()
   return super
end

exportn(interleave, "interleave")
exportn(zip,        "zip", "zipany", "zipAny", "zip_any")
exportn(chain,      "chain")
export0(cycle,      "cycle")

exportn(function(...)
   local self = interleave(...)
   self.notskip = true
   return self
end, "skipinterleave", "skip_interleave", "skipInterleave")
exportn(function(...)
   local self = zip(...)
   self.notskip = true
   return self
end, "zipall", "zipAll", "zip_all")


-- filtering

local function filter_collect(self, state, key, ...)
   if key == nil then return end
   if state(key, ...) then return key, ...  end
   return filter_collect(self, state, self[1]())
end

local function filter_next(self, state)
   return filter_collect(self, state, self[1]())
end

local function filter(func, base)
   assert(func, "function expected")
   local self = new_stateful(Iter.reset, filter_next, func)
   self[1] = base
   return self
end

local function filterout(func, base)
   assert(func, "function expected")
   return filter(function(...) return not func(...) end, base)
end

export1(filter,    "filter", "removeifnot", "remove_if_not", "removeIfNot")
export1(filterout, "filterout", "filter_out", "filterOut",
                   "removeif", "remove_if", "removeIf")

export1(function(func, base)
   return filter(func, base), filterout(func, base)
end, "partition")
export1(function(patt, base)
   return filter(function(v) return v:match(patt) end, base)
end, "grep")


-- reducing

local function each_collect(func, key, ...)
   if key ~= nil then func(key, ...); return true end
end

local function each(func, base)
   while each_collect(func, base()) do end
end

local function foldl_collect(func, init, key, ...)
   if key == nil then return nil, init end
   return key, func(init, key, ...)
end

local function foldl(func, init, base)
   assert(func, "function expected")
   if init == nil then
      local key = base()
      if key == nil then return init end
      init = key
   end
   local key
   while true do
      key, init = foldl_collect(func, init, base())
      if key == nil then return init end
   end
end

local function index_collect(func, base, i, key, ...)
   if key == nil then return end
   if func(key, ...) then return i + 1, key, ...  end
   return index_collect(func, base, i + 1, base())
end

local function index(func, base)
   return index_collect(func or id, base, 0, base())
end

local function tcollect_collect(t, key, ...)
   if key == nil then return end
   local cn = select('#', ...)
   t[#t+1] = key
   for i = 1, cn do t[#t+1] = select(i, ...) end
   return true
end

local function tcollect(t, base)
   t = t or {}
   while tcollect_collect(t, base()) do end
   return t
end

local function concat(delim, base)
   local t, n = {}, 0
   for v in base do n = n + 1; t[n] = v end
   return tabcat(t, delim, 1, n)
end

local function count(base)
   local n = 0
   while base() do n = n + 1 end
   return n
end

local function isempty(base)
   return base() == nil
end

local function predicate_collect(func, key, ...)
   if key == nil then return end
   return func(key, ...), key
end

local function any(func, base)
   func = func or id
   while true do
      local r, key = predicate_collect(func, base())
      if key == nil then return false end
      if r          then return true end
   end
end

local function all(func, base)
   func = func or id
   while true do
      local r, key = predicate_collect(func, base())
      if key == nil then return true end
      if not r      then return false end
   end
end

export1(each,     "each", "foreach", "for_each", "forEach")
export2(foldl,    "reduce", "foldl")
export1(index,    "index", "find", "indexof", "indexOf", "index_of")
export1(tcollect, "collect")
export1(concat,   "concat")
export0(count,    "count", "length")
export0(isempty,  "isempty", "is_empty", "isEmpty")
export1(all,      "all", "every")
export1(any,      "any", "some")


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
      local code = "return function(_"
      if self.max > 0 then code = code..", _"..range(self.max):concat ", _" end
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
   id = id,

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
      return iter._(assert(self[op], "no such operator"))
   end
})

iter.op       = Operator
iter.operator = Operator


-- export

return setmetatable(iter, {
   __call = function(self, t)
      t = t or _G
      for k, v in pairs(self) do
         t[k] = v
      end
      return self
   end
})

-- cc: src='test.lua'

