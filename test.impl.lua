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

fun = function(...) return 'map', ... end
map(fun, range(0)):each(print)
--[[OUTPUT
--]]

map(fun, range(4)):each(print)
--[[OUTPUT
map,1
map,2
map,3
map,4
--]]

map(fun, {"a", "b", "c", "d", "e"}):each(print)
--[[OUTPUT
map,1,a
map,2,b
map,3,c
map,4,d
map,5,e
--]]

fun = nil
map(_1*2, range(4)):each(print)
--[[OUTPUT
2
4
6
8
--]]

interleave({}, dup"x"):each(print)
--[[OUTPUT
--]]

interleave(array{"a", "b", "c", "d", "e"}, dup"x"):each(print)
--[[OUTPUT
a
x
b
x
c
x
d
x
e
x
--]]

interleave(array{"a", "b", "c", "d", "e", "f"},dup"x"):each(print)
--[[OUTPUT
a
x
b
x
c
x
d
x
e
x
f
x
--]]

--! compositions

zip(array{"a", "b", "c", "d"}, array{"one", "two", "three"}):each(print)
--[[OUTPUT
a,one
b,two
c,three
--]]

zip():each(print)
--[[OUTPUT
--]]

zip(range(0)):each(print)
--[[OUTPUT
--]]

zip(range(0), range(0)):each(print)
--[[OUTPUT
--]]

slice(10, 10, zip(
   range(1, 100, 3),
   range(1, 100, 5),
   range(1, 100, 7))):each(print)
--[[OUTPUT
28,46,64
--]]

take(15, cycle{}):each(print)
--[[OUTPUT
--]]

take(15, cycle(array{"a", "b", "c", "d", "e"})):each(print)
--[[OUTPUT
a
b
c
d
e
a
b
c
d
e
a
b
c
d
e
--]]

take(15, cycle(range(5))):each(print)
--[[OUTPUT
1
2
3
4
5
1
2
3
4
5
1
2
3
4
5
--]]

take(15, cycle(zip(range(5), array{"a", "b", "c", "d", "e"}))):each(print)
--[[OUTPUT
1,a
2,b
3,c
4,d
5,e
1,a
2,b
3,c
4,d
5,e
1,a
2,b
3,c
4,d
5,e
--]]

chain(range(2)):each(print)
--[[OUTPUT
1
2
--]]

chain(range(2), array{"a", "b", "c"}, array{"one", "two", "three"}):each(print)
--[[OUTPUT
1
2
a
b
c
one
two
three
--]]

take(15, cycle(chain({"a", "b", "c"},
    array {"one", "two", "three"}))):each(print)
--[[OUTPUT
1,a
2,b
3,c
one
two
three
1,a
2,b
3,c
one
two
three
1,a
2,b
3,c
--]]

chain(range(0), range(0), range(0)):each(print)
--[[OUTPUT
--]]

chain(range(0), range(1), range(0)):each(print)
--[[OUTPUT
1
--]]

--! filtering

filter(_"_1 % 3 == 0", range(10)):each(print)
--[[OUTPUT
3
6
9
--]]

filter(_"_1 % 3 == 0", range(0)):each(print)
--[[OUTPUT
--]]

take(5, filter(_"_1 % 3 == 0", zip(range(), dup('x')))):each(print)
--[[OUTPUT
3,x
6,x
9,x
12,x
15,x
--]]

filter(_"_1 % 16 == 0", map(_"_1, _3, _2",
              zip(range(0, 50, 1),
                  range(0, 50, 2),
                  range(0, 50, 3)))):each(print)
--[[OUTPUT
0,0,0
16,48,32
--]]

lines_to_grep = {
    "Lorem ipsum dolor sit amet, consectetur adipisicing elit, ",
    "sed do eiusmod tempor incididunt ut labore et dolore magna ",
    "aliqua. Ut enim ad minim veniam, quis nostrud exercitation ",
    "ullamco laboris nisi ut aliquip ex ea commodo consequat.",
    "Duis aute irure dolor in reprehenderit in voluptate velit ",
    "esse cillum dolore eu fugiat nulla pariatur. Excepteur sint ",
    "occaecat cupidatat non proident, sunt in culpa qui officia ",
    "deserunt mollit anim id est laborum."
}

filter(_(string.match)(_1, "lab"), array(lines_to_grep)):each(print)
--[[OUTPUT
sed do eiusmod tempor incididunt ut labore et dolore magna 
ullamco laboris nisi ut aliquip ex ea commodo consequat.
deserunt mollit anim id est laborum.
--]]

lines_to_grep = {
    "Emily",
    "Chloe",
    "Megan",
    "Jessica",
    "Emma",
    "Sarah",
    "Elizabeth",
    "Sophie",
    "Olivia",
    "Lauren"
}

filter(_(string.match)(_1, "^Em"), array(lines_to_grep)):each(print)
--[[OUTPUT
Emily
Emma
--]]

--! reducing

eq(foldl(_1 + _2, 0, range(5)), 15)
eq(foldl(op.add, 0, range(5)), 15)
eq(foldl(_1+_2*_3, 0, zip(range(1, 5), array{4, 3, 2, 1})), 20)
eq(foldl, reduce)

eq(length{"a", "b", "c", "d", "e"}, 5)
eq(length{}, 0)
eq(length(range(0)), 0)
eq(length, count)

eq(isempty{"a", "b", "c", "d", "e"}, false)
eq(isempty{}, true)
eq(isempty(range(0)), true)

local iter, state, init = range(5)
eq(isempty(iter, state, init), false)
wrap(iter, state, init):each(print)
--[[OUTPUT
1
2
3
4
5
--]]

eq(all(_1, array{true, true, true, true}), true)
eq(all(_1, array{true, true, true, false}), false)
eq(all(_1, {}), true)

eq(any(_1, array{false, false, false, false}), false)
eq(any(_1, array{false, false, false, true}), true)
eq(any(_1, {}), false)

--! operators

eq(op, operator) -- an alias

local comparators = { 'le', 'lt', 'eq', 'ne', 'ge', 'gt' }
for op in array(comparators) do
    print('op', op)
    print('==')
    print('num:')
    print(operator[op](0, 1))
    print(operator[op](1, 0))
    print(operator[op](0, 0))
    print('str:')
    print(operator[op]("abc", "cde"))
    print(operator[op]("cde", "abc"))
    print(operator[op]("abc", "abc"))
    print('')
end
--[[OUTPUT
op,le
==
num:
true
false
true
str:
true
false
true

op,lt
==
num:
true
false
false
str:
true
false
false

op,eq
==
num:
false
false
true
str:
false
false
true

op,ne
==
num:
true
true
false
str:
true
true
false

op,ge
==
num:
false
true
true
str:
false
true
true

op,gt
==
num:
false
true
false
str:
false
true
false

--]]

print(math.floor(operator.add(-1.0, 1.0)))
print(operator.add(0, 0))
print(operator.add(12, 2))
--[[OUTPUT
0
0
14
--]]

print(math.floor(operator.div(10, 2)))
print(operator.div(10, 3))
print(operator.div(-10, 3))
--[[OUTPUT
5
3.3333333333333
-3.3333333333333
--]]

print(operator.floordiv(10, 3))
print(operator.floordiv(11, 3))
print(operator.floordiv(12, 3))
print(operator.floordiv(-10, 3))
print(operator.floordiv(-11, 3))
print(operator.floordiv(-12, 3))
--[[OUTPUT
3
3
4
-4
-4
-4
--]]

print(operator.intdiv(10, 3))
print(operator.intdiv(11, 3))
print(operator.intdiv(12, 3))
print(operator.intdiv(-10, 3))
print(operator.intdiv(-11, 3))
print(operator.intdiv(-12, 3))
--[[OUTPUT
3
3
4
-3
-3
-4
--]]

print(operator.div(10, 3))
print(operator.div(11, 3))
print(math.floor(operator.div(12, 3)))
print(operator.div(-10, 3))
print(operator.div(-11, 3))
print(math.floor(operator.div(-12, 3)))
--[[OUTPUT
3.3333333333333
3.6666666666667
4
-3.3333333333333
-3.6666666666667
-4
--]]

print(operator.mod(10, 2))
print(operator.mod(10, 3))
print(operator.mod(-10, 3))
--[[OUTPUT
0
1
2
--]]

print(math.floor(operator.mul(10, 0.1)))
print(operator.mul(0, 0))
print(operator.mul(-1, -1))
--[[OUTPUT
1
0
1
--]]

print(operator.neg(1))
print(operator.neg(0) == 0)
print(operator.neg(-0) == 0)
print(operator.neg(-1))
--[[OUTPUT
-1
true
true
1
--]]

print(operator.unm(1))
print(operator.unm(0) == 0)
print(operator.unm(-0) == 0)
print(operator.unm(-1))
--[[OUTPUT
-1
true
true
1
--]]

print(math.floor(operator.pow(2, 3)))
print(math.floor(operator.pow(0, 10)))
print(math.floor(operator.pow(2, 0)))
--[[OUTPUT
8
0
1
--]]

print(operator.sub(2, 3))
print(operator.sub(0, 10))
print(operator.sub(2, 2))
--[[OUTPUT
-1
-10
0
--]]

print(operator.concat("aa", "bb"))
print(operator.concat("aa", ""))
print(operator.concat("", "bb"))
--[[OUTPUT
aabb
aa
bb
--]]

print(operator.len(""))
print(operator.len("ab"))
print(operator.len("abcd"))
--[[OUTPUT
0
2
4
--]]

print(operator.length(""))
print(operator.length("ab"))
print(operator.length("abcd"))
--[[OUTPUT
0
2
4
--]]

print(operator.land(true, true))
print(operator.land(true, false))
print(operator.land(false, true))
print(operator.land(false, false))
print(operator.land(1, 0))
print(operator.land(0, 1))
print(operator.land(1, 1))
print(operator.land(0, 0))
--[[OUTPUT
true
false
false
false
0
1
1
0
--]]

print(operator.lor(true, true))
print(operator.lor(true, false))
print(operator.lor(false, true))
print(operator.lor(false, false))
print(operator.lor(1, 0))
print(operator.lor(0, 1))
print(operator.lor(1, 1))
print(operator.lor(0, 0))
--[[OUTPUT
true
true
true
false
1
0
1
0
--]]

print(operator.lnot(true))
print(operator.lnot(false))
print(operator.lor(1))
print(operator.lor(0))
--[[OUTPUT
false
true
1
0
--]]


