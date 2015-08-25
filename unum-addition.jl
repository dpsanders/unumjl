#unum-addition.jl
#Performs addition with unums.  Requires two unums to have the same
#environment signature.  Also included here is subtraction.

#instead of making unary plus "do nothing at all", we will have it "firewall"
#the variable by creating a copy of it.  Use the "unsafe" constructor to save
#on checking since we know the source unum is valid.
+(x::Unum) = unum_unsafe(x)
#unary minus uses the shorthand pseudoconstructor, where all the values are the
#same but the flags may be altered.
-(x::Unum) = unum_unsafe(x, x.flags $ UNUM_SIGN_MASK)

#binary add performs a series of checks to find faster solutions followed by
#passing to either the 'addition' or 'subtraction' algorithms.  Two separate
#algorithms are necessary because of the zero-symmetrical nature of the unum
#floating point spec.
function +(a::Unum, b::Unum)
  #some basic gating checks before we do any crazy operations.
  #one, is either one zero?
  iszero(a) && return b
  iszero(b) && return a
  #do a nan check
  (isnan(a) || isnan(b)) && return nan(typeof(a))

  #infinities plus anything is NaN if opposite infinity. (checking for operand a)
  if (ispinf(a))
    (isninf(b)) && return nan(typeof(a))
    return pinf(typeof(a))
  elseif (isninf(a))
    (ispinf(b)) && return nan(typeof(a))
    return ninf(typeof(a))
  end

  #infinities b (infinity a is ruled out) plus anything is b3
  (ispinf(b)) && return pinf(typeof(a))
  (isninf(b)) && return ninf(typeof(a))

  #sort a and b and then add them using the gateway operation.
  __add_ordered(magsort(a,b)...)
end

#subtraction - merely flip the bit first and then roll with it.
function -(a::Unum, b::Unum)
  #check equality and return zero if equal.  It may not be the fastest to
  #create a new object before subtracting, but for now we won't optimize this.
  a + -b
end

##########################TODO:  Implement integers by converting upwards first.

#performs a carried add on an unsigned integer array.
function __carried_add(carry::Uint64, v1::SuperInt, v2::SuperInt)
  #first perform a direct sum on the integer arrays
  res = v1 + v2
  #check to see if we need a carry.  Note last() can operate on scalar values
  (last(res) < last(v1)) && (carry += 1)
  #iterate downward from the most significant word
  for idx = length(v1):-1:2
    #if it looks like it's lower than it should be, then make it okay.
    if res[idx - 1] < v1[idx - 1]
      #we don't need to worry about carries because at most we can be
      #FFF...FFF + FFF...FFF = 1FFF...FFFE
      res[idx] += 1
    end
  end
  (carry, res)
end

#returns a (SuperInt, int, bool) triplet:  (value, shift, falloff)
function __shift_after_add(carry::Uint64, value::SuperInt)
  #cache the length of value
  l = length(value)
  #calculate how far we have to shift.
  shift = 64 - clz(carry) - 1
  #did we lose values off the end of the number?
  falloff = (value & fillbits(shift, l)) != superzero(l)
  #shift the value over
  value = rsh(value, shift)
  #copy the carry over.
  if (l > 1)
    value[l] |= carry << (64 - shift)
  else
    value |= carry << (64 - shift)
  end
  (value, shift, falloff)
end

function __carried_diff(carry::Uint64, v1::SuperInt, v2::SuperInt)
  #run a difference engine across an array of 64-bit integers
  #"carry" will usually be one, but there are other possibilities (e.g. zero)

  #first perform a direct difference on the integer arrays
  res = v1 - v2
  #iterate downward from the most significant cell.  Sneakily, this loop
  #does not execute if we have a singleton SuperInt
  for idx = 1:length(v1) - 1
    #if it looks like it's higher than it should be....
    if res[idx] > v1[idx]
      #we don't need to worry about carries because at most we can be
      #FFF...FFF + FFF...FFF = 1FFF...FFFE
      res[idx + 1] -= 1
    end
  end

  #check to see if we need a carry.  Note last() can operate on scalar values
  (last(res) > last(v1)) && (carry -= 1)
  (carry, res)
end

################################################################################
## GATEWAY OPERATION

#an addition operation where a and b are ordered such that mag(a) > mag(b)
function __add_ordered{ESS,FSS}(a::Unum{ESS,FSS}, b::Unum{ESS,FSS}, _aexp, _bexp)
  a_neg = isnegative(a)
  b_neg = isnegative(b)

  if (b_neg != a_neg)
    __diff_ordered(a, b, _aexp, _bexp)
  else
    __sum_ordered(a, b, _aexp, _bexp)
  end
end

################################################################################
## SUM ALGORITHM

function __sum_ordered(a, b, _aexp, _bexp)
  #add two values, where a has a greater magnitude than b.  Both operands have
  #matching signs, either positive or negative.  At this stage, they may both
  #be ULPs.
  if (isulp(a) || isulp(b))
    __sum_ulp(a, b, _aexp, _bexp)
  else
    __sum_exact(a, b, _aexp, _bexp)
  end
end

function __sum_ulp(a, b, _aexp, _bexp)
  #this code is assuredly wrong.
  isalmostinf(a) && return a

  exact_a = Unum{ESS,FSS}(a.fsize, a.esize, a.flags & (~UBIT_MASK), a.fraction, a.exponent)
  exact_b = Unum{ESS,FSS}(b.fsize, b.esize, b.flags & (~UBIT_MASK), b.fraction, b.exponent)

  #find the min and max additions to be performed.
  max_a = (a_ulp) ? nextunum(a) : exact_a
  max_b = (b_ulp) ? nextunum(b) : exact_b

  #we may have to re-decode these because these might have changed.
  _maexp = decode_exp(a)
  _mbexp = decode_exp(b)

  #find the high and low bounds.  Pass this to a subsidiary function (recursion!)
  far_result = max_a + max_b
  near_result = exact_a + exact_b

  if a_neg
    ubound_resolve(open_ubound(far_result, near_result))
  else
    ubound_resolve(open_ubound(near_result, far_result))
  end
end

function __sum_exact{ESS, FSS}(a::Unum{ESS,FSS}, b::Unum{ESS, FSS}, _aexp, _bexp)
  #calculate the exact sum between two unums.  You may pass this function a unum
  #with a ubit, but it will calculate the sum as if it didn't have the ubit there

  l = length(a.fraction)
  #check for deviations due to subnormality.
  a_dev = issubnormal(a) ? 1 : 0
  b_dev = issubnormal(b) ? 1 : 0

  #calculate the bit offset.
  bit_offset = (_aexp + a_dev) - (_bexp + b_dev)

  #check to see if the offset is too big, just copy A with the unum bit flipped on, but also
  #make sure that the fraction is thrown all the way to the right.
  (bit_offset > max_fsize(FSS) + 1 - b_dev) && return Unum{ESS,FSS}(max_fsize(FSS), a.esize, a.flags | UNUM_UBIT_MASK, a.fraction, a.exponent)

  #generate the scratchpad by moving b.
  scratchpad = rsh(b.fraction, bit_offset)

  #don't forget b's phantom bit (1-b_dev) so it's zero if we are subnormal
  (bit_offset != 0) && (b_dev != 1) && (scratchpad |= __bit_from_top(bit_offset, l))

  #perform a carried add.  Start it off with a's phantom bit (1- a_dev), and
  #b's phantom bit if they are overlapping.
  carry::Uint64 = (1 - a_dev) + ((bit_offset == 0) ? (1 - b_dev) : 0)

  (carry, scratchpad) = __carried_add(carry, a.fraction, scratchpad)
  flags = a.flags & UNUM_SIGN_MASK
  
  #handle the carry bit (which may be up to three? or more).
  if (carry == 0)
    fsize = __frac_length(scratchpad, l)

    #don't use encode_exp because that might do strange things to subnormals.
    #just pass through esize, exponent from the a value.
    esize = a.esize
    exponent = a.exponent
  elseif (carry == 1)
    #esize is unchanged.  May have to alter fsize.
    fsize = __frac_length(scratchpad, l)

    (esize, exponent) = encode_exp(_aexp + a_dev) #promote the exponent if we
    #happened to have started as a subnormal.
  else
    (scratchpad, shift, is_ubit) = __shift_after_add(carry, scratchpad)

    #check to see if _shift_after_add wants us to decare us a ubit.
    is_ubit && (flags &= UNUM_UBIT_MASK)

    #check for overflows.
    _nexp = _aexp + shift

    (_nexp > max_exponent(ESS)) && return almostinf(a)

    fsize = __frac_length(scratchpad)
    (esize, exponent) = encode_exp(_nexp)
  end

  #another way to get overflow is: by adding just enough bits to exactly
  #make the binary value for infinity.  This should, instead, yield almostinf.
  #if (fsize == )
  #  return almostinf(a)
  #end

  Unum{ESS,FSS}(fsize, esize, flags, scratchpad, exponent)
end

################################################################################
## DIFFERENCE ALGORITHM

function __diff_ordered(a, b, _aexp, _bexp)
  #add two values, where a has a greater magnitude than b.  Both operands have
  #matching signs, either positive or negative.  At this stage, they may both
  #be ULPs.
  if (isulp(a) || isulp(b))
    __diff_ulp(a, b, _aexp, _bexp)
  else
    __diff_exact(a, b, _aexp, _bexp)
  end
end

function __diff_ulp(a, b, _aexp, _bexp)
  if (a_ulp)
    max_a = nextunum(a)
    exact_a = unum(a, a.flags & (~UBIT_MASK))
    _maexp = decode_exp(max_a)
  else
    max_a = exact_a = unum(a)
    _maexp = _aexp
  end
  if (b_ulp)
    max_b = nextunum(b)
    exact_b = unum(b, b.flags & (~UBIT_MASK))
    _mbexp = decode_exp(max_b)
  else
    max_b = exact_b = unum(b)
    _mbexp = _bexp
  end

  #do a check to see if a is almost infinite.
  if (isalmostinf(a))
    #a ubound ending in infinity can't result in an ulp unless the lower subtracted
    #value is zero, which is already tested for.
    isalmostinf(b) && return open_ubound(almostninf(Unum{ESS,FSS}), almostpinf(Unum{ESS,FSS}))

    if (a_neg)
      #exploit the fact that __exact_subtraction ignores ubits
      return open_ubound(a, __do_subtraction(a, max_b, _aexp, _mbexp))
    else
      return open_ubound(__do_subtraction(a, max_b, _aexp, _mbexp), a)
    end
  end

  far_res = __do_subtraction(max_a, exact_b, _maexp, _bexp)

  #it's possible that exact_a is less than max_b
  if ((exact_a.exponent > max_b.exponent) || ((exact_a.exponent == max_b.exponent) && (exact_a.fraction > max_b.fraction)))
    near_res = __do_subtraction(exact_a, max_b, _aexp, _mbexp)
  else
    near_res = __do_subtraction(max_b, exact_a, _mbexp, _aexp)
    near_res.flags &= SIGN_MASK
    near_res.flags |= SIGN_MASK $ far_res.flags
    #now we have to do something here.
  end

  if a_neg
    ubound_resolve(open_ubound(far_res, near_res))
  else
    ubound_resolve(open_ubound(near_res, far_res))
  end
end

#a subtraction operation where a and b are ordered such that mag(a) > mag(b)
function __diff_exact{ESS,FSS}(a::Unum{ESS,FSS}, b::Unum{ESS,FSS}, _aexp, _bexp)

  # a series of easy cases.
  if (a == -b)
    return zero(Unum{ESS,FSS})
  end
  if (iszero(b))
    return unum(a)
  end
  if (iszero(a))
    return -b
  end

  #check for deviations due to subnormality.
  a_dev = issubnormal(a) ? 1 : 0
  b_dev = issubnormal(b) ? 1 : 0

  bit_offset = (_aexp + a_dev) - (_bexp + b_dev)

  #check to make sure we're not falling off the end here, but in this case return
  #the previous exact as an ulp; make sure fraction is thrown all the way to the
  #right.
  #(bit_offset > max_fsize(FSS) + 1 - b_dev) &&
  #return Unum{ESS,FSS}(max_fsize(FSS), a.esize, a.flags | UNUM_UBIT_MASK, a.fraction, a.exponent)

  scratchpad = rsh(b.fraction, bit_offset)

  ##FIGURE THIS OUT.
  #push the phantom bit from b (1-b_dev), unless it matches the size of a
  scratchpad |= (bit_offset == 0) ? 0 : (1 - b_dev) << (64 - bit_offset)

  scratchpad = uint64(a.fraction - scratchpad)  #we know it's larger so things will be ok.

  #calculate the lsb and msb of the scratchpad.
  (rlsb, rmsb) = lsbmsb(scratchpad)
  shift = z16

  #if we started out with a_dev being subnormal, we don't care.
  if ((bit_offset == 0) && (b_dev == 0) && (a_dev == 0)) || (scratchpad > a.fraction)
    #then we've obliterated the phantom leading one, through direct subtraction
    #or through a reverse carry operation
    shift = uint16(64-rmsb)
  else
    rmsb = 64
  end

  flags = a.flags & SIGN_MASK
  #establish whether or not we will have to move things around a bit.
  #calculate how many fractions we have left.
  fsize = ((scratchpad == 0) ? z16 : uint16(rmsb - rlsb))

  #check to see if we are below the size of the exponent, if so
  #put a hard break on the unit's ability to push past the subnormal numbers
  if (a.exponent <= shift)
    #make sure our shift doesn't go past a.exponent, then set the parameters to
    #be subnormal.
    shift = a.exponent - 1
    #match it, but remember the subnormals have an incremented exponent.
    esize = z16
    exponent = z64
  else
    #check to see if we're verging on denormal
    if (_aexp - shift < 2^ESS)
      esize = z16
      exponent = z64
    else
      (esize, exponent) = encode_exp(_aexp - shift)
    end
  end
  fraction = scratchpad << shift
  Unum{ESS,FSS}(fsize, esize, flags, fraction, exponent)
end
