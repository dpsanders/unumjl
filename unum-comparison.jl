#Copyright (c) 2015 Rex Computing and Isaac Yonemoto
#see LICENSE.txt
#this work was supported in part by DARPA Contract D15PC00135
#unum-comparison.jl

#test equality on unums.

function =={ESS,FSS}(a::Unum{ESS,FSS}, b::Unum{ESS,FSS})
  #first compare the ubits.... These must be the same or else they aren't equal.
  ((a.flags & UNUM_UBIT_MASK) != (b.flags & UNUM_UBIT_MASK)) && return false

  #next, compare the sign bits...  The only one that spans is zero.
  ((a.flags & UNUM_SIGN_MASK) != (b.flags & UNUM_SIGN_MASK)) && (return (is_zero(a) && is_zero(b)))
  #because of the phantom bit ensuring a one at the head, the decoded exponent must be identical
  #check if either is nan
  (isnan(a) || isnan(b)) && return false

  _aexp::Int64 = decode_exp(a)
  _bexp::Int64 = decode_exp(b)

  #make sure the exponents are the same, otherwise not equal unless subnormal...
  #but if one of them has a positive exponent, subnormality is impossible.
  is_strange_subnormal(a) && (a = __resolve_subnormal(a); _aexp = decode_exp(a))
  is_strange_subnormal(b) && (b = __resolve_subnormal(b); _bexp = decode_exp(b))

  (_aexp != _bexp) && return false
  #now that we know that the exponents are the same,
  #the fractions must also be identical
  (a.fraction != b.fraction) && return false
  #the ubit on case is simple - the fsizes must be equal
  ((a.flags & UNUM_UBIT_MASK) == UNUM_UBIT_MASK) && return (a.fsize == b.fsize)
  #so we are left with exact floats at any resolution, ok, or uncertain floats
  #with the same resolution.  These must be equal.
  return true
end

function __frac_ulp{ESS,FSS}(a::Unum{ESS,FSS})
  is_exact(a) && return superzero(length(a.fraction))
  __bit_from_top(a.fsize, length(a.fraction))
end

function >{ESS,FSS}(a::Unum{ESS,FSS}, b::Unum{ESS,FSS})
  (isnan(a) || isnan(b)) && return false
  _b_pos = (is_positive(b))
  _a_pos = (is_positive(a))
  (_b_pos) && (!_a_pos) && return false
  (!_b_pos) && (_a_pos) && return (!(is_zero(a) && is_zero(b)))
  #resolve exponents for strange subnormals.

  is_strange_subnormal(a) && (a = __resolve_subnormal(a); _aexp = decode_exp(a))
  is_strange_subnormal(b) && (b = __resolve_subnormal(b); _bexp = decode_exp(b))

  #so now we know that these two have the same sign.
  (decode_exp(b) > decode_exp(a)) && return (!_a_pos)
  (decode_exp(b) < decode_exp(a)) && return _a_pos
  #check fractions.

  #if the fractions are equal, then the condition is satisfied only if a is
  #an ulp and b is exact.
  (b.fraction == a.fraction) && return (is_exact(b) && is_ulp(a) && _a_pos)
  #check the condition that b.fraction is less than a.fraction.  This should
  #be xor'd to the _a_pos to give an instant failure condition.  Eg. if we are
  #positive, then b > a means failure.
  ((b.fraction < a.fraction) != _a_pos) && return false

  if (_a_pos) #then we aexpect b to be less than a.
    (_, cmp) = __carried_add(z64, __frac_ulp(b), b.fraction)
    (cmp <= a.fraction) && return true
  else
    (_, cmp) = __carried_add(z64, __frac_ulp(a), a.fraction)
    (cmp <= b.fraction) && return true
  end
  return false
end

#hopefully the julia compiler knows what to do here.
function <{ESS,FSS}(a::Unum{ESS,FSS}, b::Unum{ESS,FSS})
  return b > a
end

#make sure we have an isequal function that is equivalent to main one.
import Base.isequal
#note that unlike for floats, unum's is_equal considers is_equal(0.0, -0.0) => true
#this is because in unums, zero always makes the same representation for negative
#zero as positive zero, unlike floats which subsume the neg_mmr in, as well.
function isequal{ESS,FSS}(a::Unum{ESS,FSS}, b::Unum{ESS,FSS})
  if isnan(a) && isnan(b)
    return true
  else
    return a == b
  end
end
export isequal

import Base.min
import Base.max
function min{ESS,FSS}(a::Unum{ESS,FSS}, b::Unum{ESS,FSS})
  #adjust them in case they are subnormal
  is_strange_subnormal(a) && (a = __resolve_subnormal(a))
  is_strange_subnormal(b) && (b = __resolve_subnormal(b))

  #first, fastest criterion:  Are they not the same sign?
  if (a.flags $ b.flags) & UNUM_SIGN_MASK != 0
    is_negative(a) && return a
    return b
  end
  #next criterion, are the exponents different
  _aexp = decode_exp(a)
  _bexp = decode_exp(b)
  if (_aexp != _bexp)
    ((_aexp > _bexp) != is_negative(a)) && return a
    return b
  end
  #next criteria, check the fractions
  if (a.fraction != b.fraction)
    ((a.fraction > b.fraction) != is_negative(a)) && return a
    return b
  end
  #finally, check the ubit
  (is_ulp(a) != is_negative(a)) && return a
  return b
end

function max{ESS,FSS}(a::Unum{ESS,FSS}, b::Unum{ESS,FSS})
  #adjust them in case they are subnormal
  is_strange_subnormal(a) && (a = __resolve_subnormal(a))
  is_strange_subnormal(b) && (b = __resolve_subnormal(b))

  #first, fastest criterion:  Are they not the same sign?
  if (a.flags $ b.flags) & UNUM_SIGN_MASK != 0
    isnegative(a) && return b
    return a
  end
  #next criterion, are the exponents different
  _aexp = decode_exp(a)
  _bexp = decode_exp(b)
  if (_aexp != _bexp)
    ((_aexp > _bexp) != is_negative(a)) && return b
    return a
  end
  #next criteria, check the fractions
  if (a.fraction != b.fraction)
    ((a.fraction > b.fraction) != is_negative(a)) && return b
    return a
  end
  #finally, check the ubit
  (is_ulp(a) != is_negative(a)) && return b
  return a
end
export min, max
