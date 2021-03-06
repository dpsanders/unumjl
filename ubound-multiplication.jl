#Copyright (c) 2015 Rex Computing and Isaac Yonemoto
#see LICENSE.txt
#this work was supported in part by DARPA Contract D15PC00135
#ubound-multiplication.jl

################################################################################
## multiplication
function *{ESS,FSS}(a::Unum{ESS,FSS}, b::Ubound{ESS,FSS})
  b * a
end

function *{ESS,FSS}(a::Ubound{ESS,FSS}, b::Unum{ESS,FSS})
  #two cases.  One:  the ubound doesn't straddle zero
  lbp = a.lowbound * b
  hbp = a.highbound * b

  t::Ubound = is_negative(b) ? ubound_unsafe(hbp, lbp) : ubound_unsafe(lbp, hbp)

  #attempt to resolve it if we did not straddle zero
  (a.lowbound.flags & UNUM_SIGN_MASK == a.highbound.flags & UNUM_SIGN_MASK) ? ubound_resolve(t) : t
end

function *{ESS,FSS}(a::Ubound{ESS,FSS}, b::Ubound{ESS,FSS})
  signcode::Uint16 = 0
  is_negative(a.lowbound)  && (signcode += 1)
  is_negative(a.highbound) && (signcode += 2)
  is_negative(b.lowbound)  && (signcode += 4)
  is_negative(b.highbound) && (signcode += 8)

  if (signcode == 0) #everything is positive
    ubound_resolve(ubound_unsafe(a.lowbound * b.lowbound, a.highbound * b.highbound))
  elseif (signcode == 1) #only a.lowbound is negative
    ubound_unsafe(a.lowbound * b.highbound, a.highbound * b.highbound)
  #signcode 2 is not possible
  elseif (signcode == 3) #a is negative and b is positive
    ubound_resolve(ubound_unsafe(a.lowbound * b.highbound, a.highbound * b.lowbound))
  elseif (signcode == 4) #only b.lowbound is negative
    ubound_unsafe(b.lowbound * a.highbound, b.highbound * a.highbound)
  elseif (signcode == 5) #a.lowbound and b.lowbound are negative
    minchoice1 = b.lowbound * a.highbound
    minchoice2 = b.highbound * a.lowbound
    maxchoice1 = b.lowbound * a.lowbound
    maxchoice2 = b.highbound * a.highbound

    (typeof(minchoice1) <: Ubound) && (minchoice1 = minchoice1.lowbound)
    (typeof(minchoice2) <: Ubound) && (minchoice2 = minchoice2.lowbound)
    (typeof(maxchoice1) <: Ubound) && (maxchoice1 = maxchoice1.highbound)
    (typeof(maxchoice2) <: Ubound) && (maxchoice2 = maxchoice2.highbound)

    ubound_unsafe(min(minchoice1, minchoice2), max(maxchoice1, maxchoice2))
  #signcode 6 is not possible
  elseif (signcode == 7) #only b.highbound is positive
    ubound_unsafe(b.highbound * a.lowbound, b.lowbound * a.lowbound)
  #signcode 8, 9, 10, 11 are not possible
  elseif (signcode == 12) #b is negative, a is positive
    ubound_resolve(ubound_unsafe(b.lowbound * a.highbound, b.highbound * a.lowbound))
  elseif (signcode == 13) #b is negative, a straddles
    ubound_unsafe(b.lowbound * a.highbound, b.lowbound * a.lowbound)
  #signcode 14 is not possible
  elseif (signcode == 15) #everything is negative
    ubound_resolve(ubound_unsafe(a.highbound * b.highbound, a.lowbound * b.lowbound))
  else
    println("----")
    println(describe(a))
    println(describe(b))
    throw(ArgumentError("some ubound had incorrect orientation, $signcode."))
  end
end
