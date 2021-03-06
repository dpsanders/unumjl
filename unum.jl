#Copyright (c) 2015 Rex Computing and Isaac Yonemoto
#see LICENSE.txt
#this work was supported in part by DARPA Contract D15PC00135
#unum.jl - a julia implementation of the unum
# this file is the module definition file and also contains
# includes for all of the components which make it work

#for now, only compatible with 64-bit architectures.
@assert(sizeof(Int) == 8, "currently only compatible with 64-bit architectures")

module Unums
#this module exports the Unum Type
export Unum

#1) for release versions, this will be set to 'false'
#2) is there a better way of doing this?
__UNUM_DEV = true
function __unum_development_environment()
  global __UNUM_DEV = true
end
function __unum_release_environment()
  global __UNUM_DEV = false
end
function __unum_isdev()
  __UNUM_DEV
end

#create the abstract Utype type
abstract Utype <: Real
export Utype

#bring in some important uint64 bitwise methods
include("unum-int64op.jl")
#helpers used in the unum type constructors andn pseudoconstructors
include("unum-helpers.jl")

#the base unum type and its pseudoconstructors
include("unum-unum.jl")
#and the derived ubound type
include("ubound-ubound.jl")

#functions that operate on the unum type itself, and friends.
include("unum-typeproperties.jl")

include("unum-constants.jl")
include("unum-properties.jl")
include("unum-comparison.jl")
include("unum-convert.jl")
include("unum-operations.jl")
#some math stuff
include("unum-addition.jl")
include("unum-subtraction.jl")
include("unum-multiplication.jl")
include("unum-division.jl")

#unary operators
include("unum-sqrs.jl")

#h-layer stuff (human)
include("unum-hlayer.jl")

#other utilities
include("unum-bitwalk.jl")
include("unum-promote.jl")
include("unum-expwalk.jl")
include("unum_solver.jl")

end #module
