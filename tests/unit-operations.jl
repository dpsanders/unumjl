#Copyright (c) 2015 Rex Computing and Isaac Yonemoto

#see LICENSE.txt

#this work was supported in part by DARPA Contract D15PC00135


#unit-operations.jl
#other useful operations on unums.

#test __resolve_subnormal.
#takes a subnormal number and makes it normal, or the smallest subnormal class
#as makes most sense for that number.

#example:  0 1 0 0 is unum(0.5) in all contexts, and this is the same as:
#          01 0 1 0 in most unums.

#first demonstrate that the two representations (the subnormal and the normal) are
#equivalent.
x = Unum{4,6}(z16, z16, z16, t64, z64)
u = Unums.__resolve_subnormal(x)
@test calculate(x) == calculate(u)
@test u.fsize == z16
@test u.esize == o16
@test u.flags == z16
@test u.fraction == z64
@test u.exponent == o64
#note we can't use the equality operator testnig because the equality operator
#will engage the __resolve_subnormal function itself.

#repeat the exercise in a SuperInt unum.
x = Unum{4,8}(z16, z16, z16, [z64, z64, z64, t64], z64)
u = Unums.__resolve_subnormal(x)
#@test calculate(x) == calculate(u)  #NB "calculate" doesn't currently work on superint unums.
@test u.fsize == z16
@test u.esize == o16
@test u.flags == z16
@test u.fraction == [z64, z64, z64, z64]
@test u.exponent == o64

#repeat the exercise in a very small unum.
x = Unum{2,2}(z16, z16, z16, t64, z64)
u = Unums.__resolve_subnormal(x)
@test calculate(x) == calculate(u)
@test u.fsize == z16
@test u.esize == o16
@test u.flags == z16
@test u.fraction == z64
@test u.exponent == o64

#second example:  Take a unum at the edge of smallness and show that we can
#resolve this into the apropriate even smaller subnormal number.
x = Unum{2,4}(uint16(15), z16, z16, 0x0001_0000_0000_0000, z64)
u = Unums.__resolve_subnormal(x)
@test calculate(x) == calculate(u)
@test u.esize == 1 << esizesize(u) - 1
@test u.exponent == 0
