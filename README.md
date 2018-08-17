Lua Iteration Library
========================
[![Build Status](https://travis-ci.org/starwing/luaiter.svg?branch=master)](https://travis-ci.org/starwing/luaiter)
[![Coverage Status](https://coveralls.io/repos/github/starwing/luaiter/badge.svg?branch=master)](https://coveralls.io/github/starwing/luaiter?branch=master)

luaiter is a rewritten version of [luafun][1]: a high-performance
functional programming library for Lua designed with LuaJIT's trace
compiler in mind. luaiter focus plain Lua performance improve and
follows the standard Lua iteration protocol.

luaiter has the same [License][2] as Lua itself.

Some improves:
  - avoid any memory allocation when iteration.
  - use standard iteration protocol.
  - support Lua 5.3 bit operators.
  - add more useful functions like `scan` and `flatmap`.
  - add a powerful `selector` interface for quick-and-dirty lambda
    function support.

[1]: https://github.com/rtsisyk/luafun
[2]: https://www.lua.org/license.html


The standard iteration protocol
-------------------------------

luafun library use a custom protocol for iteration, makes using other
Lua-spec iterator e.g. `io.lines()`, `string.gmatch` difficult, it
requires a iteration state variable. luaiter follows the standard
protocol without the per-iteration state variable:

```Lua
for var1, ... in iter, state, init do
   ...
end
```

The first return value of `iter` function `var1` used as the state
variable, but it's meaningful: If `iter` function is stateful, i.e.
each iteration will change the `state` content, then var1 may occurs
the duplicate value in iterations. In this case, `init` will be `nil`
to indicate the beginning of the iteration (note that `nil` will never
occurs in iteration: it means the end of stream). Otherwise, the
`iter` will be stateless, means var1 will never repetition during
iteration.

- The stateful iterator example: `map` (remember the original iterator
  `var1`).
- The stateless iterator example: `range` (it only use previous `var1`
  to detect the next `var1`).


The selector interface
----------------------

luaiter has a very special selector interface, the underscore
`iter._`. This is a special object that has several functinal:

  - `_[1]` ... `_[9]` called `selector`, they can be used as function
    that select it's 1st...9th argument, e.g. `_[5]` same as
    `function(a, b, c, d, e) return e end`. They could shorten as
    `iter._1` to `iter._9`

  - `_1` to `_9` could used in expression, in this case the expression
    will return a function that do the calculation, and _1 ... _9
    means the order of arguments, e.g. `_3 + _1 * _2` same as
    `function(a, b, c)  return c + a * b end`. This will support all
    Lua operator that could override by metatable, including `_1[_2]`.

  - if use `_` as a function, it could return a function that call the
    `_`'s single argument, e.g. `_(print)(_2, _1)` same as
    `function(a, b) return print(b, a) end`, all underscore expression
    could be used in all place in call, e.g. `_(_2.each)(_3, _1*_4)`
    same as `function(a, b, c ,d) return b.each(c, a*d) end`

  - `_.self` returns a table-object, use `_.self(obj).each(_1, _2)`
    same as `function(a, b) return obj:each(a, b) end`.

  - `_.dots` same as `...`, if use `_.dots` in a expression/call, the
    generated function will accept vararg arguments.

  - `_.land`, `_.lor`, `_.lnot`, `_.andor` same as `and`, `or`, `not`
    operator and `a and b or c` expression.

  - used of `_` and `_1` to `_9` may cause `load`/`loadstring` when
    first call the generated function, every time the underscore
    expression calculated, a new function will `load`/`loadstring`
    from expression, so don't write expression in loop. Generate the
    function, and store it in the iterator will cache the generated
    function.

A example:

```Lua
> -- Functional style
>  print(reduce(_1+_2, 0, map(_1^2, range(100))))
338350.0

> -- Object-oriented style
> print(range(100):map(_1^2):reduce(_1+_2))
338350.0
```


The interface convention
------------------------

All functions that accept a iterator may used as the method of
`iterator` object. Iterator usually place at the end of interface,
when used as methods, the last iterator will be `self`, e.g. `map`
function has signature: `map(func, iter)`, So use `map` as a method
can call like this: `iter:map(func)`

If a function accept multiple iterators, the first will be the self
iterator, e.g. `zip(iter, iters...)` maybe called as `iter:zip(iters...)`

If a function doesn't accept a iterator, it can not used as the
method of `iterator` object.


The iterators
-------------

Generators:
  - `range([[first,] last[, step]])`
  - `rand([first, last])`
  - `str(string)`
  - `array(table)`
  - `resolve(...)`
  - `dup(...)`
  - `zeros() == dup(0)`
  - `ones()  == dup(1)`

Slicing:
  - `take(n, iter)`
  - `drop(n, iter)`
  - `slice(first, last, iter)`

Transforms:
  - `map(func, iter)`
  - `flatmap(func, iter)`
  - `scan(func, init, iter)`
  - `group(n, iter)`
  - `groupby(func, iter)`

Compositions:
  - `zip(iters...)`
  - `interleave(iters...)`
  - `chain(iters...)`
  - `cycle(iter)`

Filtering:
  - `takewhile(func, iter)`
  - `dropwhile(func, iter)`
  - `filter(func, iter)`
  - `fitlerout(func, iter)`

Reducing:
  - `each(func, iter)`
  - `reduce(func, iter)`
  - `index(func, iter)`
  - `collect(t, iter)`
  - `concat(delim, iter)`
  - `count(iter)`
  - `isempty(iter)`
  - `all(func, iter)`
  - `any(func, iter)`


