if ... == nil then return dofile './test.lua' end


--! array

for v in array { 1,2,3 } do print(v) end
--[[OUTPUT
1
2
3
--]]

for i, v in iter(iter(iter { 1,2,3 })) do print(i, v) end
--[[OUTPUT
1,1
2,2
3,3
--]]

for v in wrap(wrap(array { 1,2,3 })) do print(v) end
--[[OUTPUT
1
2
3
--]]

for i, v in wrap(wrap(ipairs { 1,2,3 })) do print(i, v) end
--[[OUTPUT
1,1
2,2
3,3
--]]

for v in array{} do print(i, v) end
--[[OUTPUT
--]]

for i, v in iter(iter(array{})) do print(i, v) end
--[[OUTPUT
--]]

-- Test that ``wrap`` do nothing for wrapped iterators
iter1, state1, init1 = iter({1, 2, 3}):unwrap()
iter2, state2, init2 = wrap(iter1, state1, init1):unwrap()
eq(iter1,  iter2)
eq(state1, state2)
eq(init1,  init2)


--! map

local t = {}
for k, v in iter { a = 1, b = 2, c = 3} do t[#t + 1] = k end
table.sort(t)
for v in array(t) do print(v) end
--[[OUTPUT
a
b
c
--]]

local t = {}
for k, v in iter(iter(iter { a = 1, b = 2, c = 3})) do t[#t + 1] = k end
table.sort(t)
for v in array(t) do print(v) end
--[[OUTPUT
a
b
c
--]]

for k, v in iter({}) do print(k, v) end
--[[OUTPUT
--]]

for k, v in iter(iter(iter({}))) do print(k, v) end
--[[OUTPUT
--]]


--! string

for a in str "abcde" do print(a) end
--[[OUTPUT
a
b
c
d
e
--]]

for _, a in iter "abcde" do print(a) end
--[[OUTPUT
a
b
c
d
e
--]]

for a in iter(iter(str "abcde")) do print(a) end
--[[OUTPUT
a
b
c
d
e
--]]

for _, a in iter(iter(iter "abcde")) do print(a) end
--[[OUTPUT
a
b
c
d
e
--]]

for a in str "" do print(a) end
--[[OUTPUT
--]]

for _, a in iter "" do print(a) end
--[[OUTPUT
--]]

for a in iter(iter(str "")) do print(a) end
--[[OUTPUT
--]]

for _, a in iter(iter(iter "")) do print(a) end
--[[OUTPUT
--]]


--! custom

local function myrange_iter(max, curr)
   if curr >= max then return nil end
   return curr + 1
end

local function myrange(max)
    return myrange_iter, max, 0
end

for a in iter(myrange(10)) do print(a) end
--[[OUTPUT
1
2
3
4
5
6
7
8
9
10
--]]


--! invalid values

for i, a in iter(nil) do print(a) end
--[[ERROR
attempt to iterate a nil value
--]]

for i, a in iter(false) do print(a) end
--[[ERROR
attempt to iterate a boolean value
--]]

for i, a in iter(1) do print(a) end
--[[ERROR
attempt to iterate a number value
--]]

for i, a in iter(1, 2, 3, 4, 5, 6, 7) do print(a) end
--[[ERROR
attempt to iterate a number value
--]]


--! each

each(print, {1, 2, 3})
--[[OUTPUT
1,1
2,2
3,3
--]]

each(print, iter {1, 2, 3})
--[[OUTPUT
1,1
2,2
3,3
--]]

each(print, array {1, 2, 3})
--[[OUTPUT
1
2
3
--]]

each(print, {})
--[[OUTPUT
--]]

each(print, array {})
--[[OUTPUT
--]]

each(print, iter {})
--[[OUTPUT
--]]

local keys, vals = {}, {}
each(function(k, v)
    keys[#keys + 1] = k
    vals[#vals + 1] = v
end, { a = 1, b = 2, c = 3})
table.sort(keys)
table.sort(vals)
each(print, array(keys))
each(print, array(vals))
--[[OUTPUT
a
b
c
1
2
3
--]]

each(print, "abc")
--[[OUTPUT
1,a
2,b
3,c
--]]

each(print, iter "abc")
--[[OUTPUT
1,a
2,b
3,c
--]]

eq(for_each, each) -- an alias
eq(foreach, each) -- an alias
eq(forEach, each) -- an alias


--! generators

range(0):each(print)
--[[OUTPUT
--]]

range(0, 0):each(print)
--[[OUTPUT
0
--]]

range(5):each(print)
--[[OUTPUT
1
2
3
4
5
--]]

range(0, 5):each(print)
--[[OUTPUT
0
1
2
3
4
5
--]]

range(0, 5, 1):each(print)
--[[OUTPUT
0
1
2
3
4
5
--]]

range(0, 10, 2):each(print)
--[[OUTPUT
0
2
4
6
8
10
--]]

range(-5):each(print)
--[[OUTPUT
-1
-2
-3
-4
-5
--]]

range(0, -5, 1):each(print)
--[[OUTPUT
--]]

range(0, -5, -1):each(print)
--[[OUTPUT
0
-1
-2
-3
-4
-5
--]]

range(0, -10, -2):each(print)
--[[OUTPUT
0
-2
-4
-6
-8
-10
--]]

range(1.2, 1.6, 0.1):each(print)
--[[OUTPUT
1.2
1.3
1.4
1.5
--]]

-- Invalid step
range(0, 5, 0):each(print)
--[[ERROR
step must not be zero
--]]

take(5, dup(48)):each(print)
--[[OUTPUT
48
48
48
48
48
--]]

take(5, dup(1,2,3,4,5)):each(print)
--[[OUTPUT
1,2,3,4,5
1,2,3,4,5
1,2,3,4,5
1,2,3,4,5
1,2,3,4,5
--]]

take(5, tab(2 * _1)):each(print)
--[[OUTPUT
0
2
4
6
8
--]]

take(5, zeros()):each(print)
--[[OUTPUT
0
0
0
0
0
--]]

take(5, ones()):each(print)
--[[OUTPUT
1
1
1
1
1
--]]

print(all(_"_1 >= 0 and _1 <= 1", take(5, rand())))
--[[OUTPUT
true
--]]

take(5, rand(0)):each(print)
--[[OUTPUT
0
0
0
0
0
--]]

print(all(_"math.floor(_1) == _1", take(5, rand(10))))
--[[OUTPUT
true
--]]

print(all(_"math.floor(_1) == _1", take(5, rand(1024))))
--[[OUTPUT
true
--]]

take(5, rand(0, 0)):each(print)
--[[OUTPUT
0
0
0
0
0
--]]

take(5, rand(5, 5)):each(print)
--[[OUTPUT
5
5
5
5
5
--]]

print(all(_"_1 >= 10, _1 <= 20", take(20, rand(10, 20))))
--[[OUTPUT
true
--]]


--iter.str     = str
--iter.array   = array
--iter.resolve = resolve


--! slicing

slice(2, 2, range(5)):each(print)
--[[OUTPUT
2
--]]

slice(10, 10, range(5)):each(print)
--[[OUTPUT
--]]

slice(2, 2, range(0)):each(print)
--[[OUTPUT
--]]

slice(2, 2, array {"a", "b", "c", "d", "e"}):each(print)
--[[OUTPUT
b
--]]

slice(2, 2, ipairs {"a", "b", "c", "d", "e"}):each(print)
--[[OUTPUT
2,b
--]]

slice(1, 1, str "abcdef"):each(print)
--[[OUTPUT
a
--]]

slice(2, 2, str "abcdef"):each(print)
--[[OUTPUT
b
--]]

slice(6, 6, str "abcdef"):each(print)
--[[OUTPUT
f
--]]

slice(0, 0, str "abcdef"):each(print)
--[[OUTPUT
--]]

slice(7, 7, str "abcdef"):each(print)
--[[OUTPUT
--]]

take(0, dup(48)):each(print)
--[[OUTPUT
--]]

take(5, range(0)):each(print)
--[[OUTPUT
--]]

take(1, dup(48)):each(print)
--[[OUTPUT
48
--]]

take(5, dup(48)):each(print)
--[[OUTPUT
48
48
48
48
48
--]]

take(5, range():zip(dup('x'))):each(print)
--[[OUTPUT
1,x
2,x
3,x
4,x
5,x
--]]

drop(5, range(10)):each(print)
--[[OUTPUT
6
7
8
9
10
--]]

drop(0, range(5)):each(print)
--[[OUTPUT
1
2
3
4
5
--]]

drop(5, range(0)):each(print)
--[[OUTPUT
--]]

drop(2, ipairs {'a', 'b', 'c', 'd', 'e'}):each(print)
--[[OUTPUT
3,c
4,d
5,e
--]]


--! transforms


