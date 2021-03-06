#Copyright (c) 2015 Rex Computing and Isaac Yonemoto
#see LICENSE.txt
#this work was supported in part by DARPA Contract D15PC00135
#unum-properties
#functions that assess properties of unum values.

#generally speaking, the "unum library form" of a test will have the form
#is_XXXXX, for some of these, they are equivalent to a julia form from floating
#point tests that are overloaded - e.g. isnan == is_nan.  A separate file
#unum-teoe-func.jl provides aliasing implementations for all of the function
#in appendix a of "The End of Error"

decode_exp(x::Unum) = decode_exp(x.esize, x.exponent)
export decode_exp

#some really dumb ones, but we'll put these in for legibility.
is_ulp(x::Unum) = ((x.flags & UNUM_UBIT_MASK) != 0)
is_exact(x::Unum) = ((x.flags & UNUM_UBIT_MASK) == 0)
is_negative(x::Unum) = ((x.flags & UNUM_SIGN_MASK) != 0)
is_positive(x::Unum) = ((x.flags & UNUM_SIGN_MASK) == 0)
is_neg_def(x::Unum) = (!is_zero(x)) && is_negative(x)
is_pos_def(x::Unum) = (!is_zero(x)) && is_positive(x)
export is_ulp, is_exact, is_negative, is_positive

#a couple of testing conditions
import Base.isnan
function isnan{ESS,FSS}(x::Unum{ESS,FSS})
  (x.fsize == (1 << FSS - 1)) && (x.esize == (1 << ESS - 1)) && is_ulp(x) && (x.fraction == fillbits(-(1 << FSS), uint16(length(x.fraction)))) && (x.exponent == mask(1 << ESS))
end
is_nan(x) = isnan(x)                                                            #alias the unum form with the julia.
export isnan, is_nan

import Base.isinf
import Base.isfinite
#isinf matches the julia definiton and triggers on either positive or negative
#infinity.  is_pos_inf and is_neg_inf both are Unum-specific functions that detect
#the expected values.
is_inf{ESS,FSS}(x::Unum{ESS,FSS}) = is_exact(x) && (x.esize == 1 << ESS - 1) && (x.exponent == mask(1 << ESS)) && (x.fsize == 1 << FSS - 1) && (x.fraction == fillbits(-(1 << FSS), uint16(length(x.fraction))))
is_pos_inf{ESS, FSS}(x::Unum{ESS, FSS}) = is_positive(x) && is_inf(x)
is_neg_inf{ESS, FSS}(x::Unum{ESS, FSS}) = is_negative(x) && is_inf(x)
#caution, isfinite is a rather slow algorithm
is_finite{ESS,FSS}(x::Unum{ESS,FSS}) = (x.exponent != mask(1 << ESS)) || (x.fraction != fillbits(-1 << FSS, uint16(length(x.fraction))))

#aliasing and exporting
isinf{ESS,FSS}(x::Unum{ESS,FSS}) = is_inf(x)                                                            #alias the unum form with the julia form
isfinite{ESS,FSS}(x::Unum{ESS,FSS}) = is_finite(x)                                                      #alias the unum form with the julia form
export isinf, is_inf, is_pos_inf, is_neg_inf, isfinite, is_finite

import Base.issubnormal
#NB:  The difference between "is_exp_zero" and "issubnormal" - is_exp_zero admits
#zero as a solution; issubnormal is in compliance with the standard julia
#issubnormal function and does not admit zero as a true result.
is_subnormal{ESS,FSS}(x::Unum{ESS,FSS}) = (x.exponent == z64) && ((ESS > 6) ? !(allzeros(x.fraction)) : x.fraction != 0)
is_exp_zero{ESS,FSS}(x::Unum{ESS,FSS}) = x.exponent == z64
is_strange_subnormal{ESS,FSS}(x::Unum{ESS,FSS}) = is_exp_zero(x) && (x.esize < max_esize(ESS))

issubnormal{ESS,FSS}(x::Unum{ESS,FSS}) = is_subnormal(x)                       #alias the unum-form to the julia-compliant form.
#use ESS because this will be checked by the compiler, instead of at runtime.
is_frac_zero{ESS,FSS}(x::Unum{ESS,FSS}) = (ESS > 6) ? allzeros(x.fraction) : (x.fraction == 0)

is_zero(x::Unum) = (x.exponent == z64) && is_exact(x) && is_frac_zero(x)

#helper function that checks if a superint is of the form 10000...0000
function __top_frac{ESS,FSS}(x::Unum{ESS,FSS})
  last(x.fraction) != t64 && return false
  for idx = 2:length(x.fraction)
    x.fraction[idx] != z64 && return false
  end
  return true
end

#annoyingly, asymmetric exponents make the process of checking unit values more labourious.
function is_unit{ESS,FSS}(x::Unum{ESS,FSS})
  #one is not an ulp, it is exact.
  is_ulp(x) && return false
  #case one:  An exponent of zero and nothing in the fraction.
  #note that when x.esize == 0, then decode_exp 0 is subnormal.
  (x.esize != 0) && (decode_exp(x) == 0) && is_frac_zero(x) && return true
  #case two:  A short exponent and
  is_subnormal(x) && (x.esize == 0) && (__top_frac(x)) && return true
  return false
end

is_one(x::Unum) = is_positive(x) && is_unit(x)
is_neg_one(x::Unum) = is_negative(x) && is_unit(x)
#checks if the value is sss ("smaller than small subnormal")
is_sss(x::Unum) = (x.exponent == z64) && is_ulp(x) && is_frac_zero(x)
is_pos_sss(x::Unum) = is_positive(x) && is_sss(x)
is_neg_sss(x::Unum) = is_negative(x) && is_sss(x)
#checks if the value is more than maxreal
is_mmr{ESS,FSS}(x::Unum{ESS,FSS}) = is_ulp(x) && (x.exponent == mask(1 << ESS)) && (x.fraction == fillbits(-(1 << FSS - 1), uint16(length(x.fraction))))
is_pos_mmr(x::Unum) = is_positive(x) && is_mmr(x)
is_neg_mmr(x::Unum) = is_negative(x) && is_mmr(x)

export issubnormal, is_subnormal, is_exp_zero
export is_frac_zero, is_zero, is_sss, is_pos_sss, is_neg_sss
export is_mmr, is_pos_mmr, is_neg_mmr

function width{ESS,FSS}(x::Unum{ESS,FSS})
  is_exact(x) && return zero(Unum{ESS,FSS})
  #return the difference, but made exact, and with ulp and sign bits bashed away.
  return unum_unsafe(__outward_exact(x) - __inward_exact(x), z16)
end
export width
