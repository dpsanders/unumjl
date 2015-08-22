#unit-convert.jl
#unit tests methods to convert unums

#TEST helper functions
#bitof - retrieves single bits from an int64, zero indexed.

#integer to unum

@test [calculate(convert(Unum{3,6},i)) for i=-50:50] == [BigFloat(i) for i = -50:50]

@test isalmostinf(mmr(Unum{0,0}))

@test isalmostinf(convert(Unum{0,0}, 2))
@test isalmostinf(convert(Unum{1,1}, 8))

#subnormal unums
#at lower resolution than the float
#at equal resolution to the float
#at higher resolution to the float

#unum to integer

#unum to float
#generate random bits in the unum
#for ess = 1:5
#  for fss = 1:6
#    for idx = 1:100
#      esize = uint16(rand(Uint64) & Unums.mask(ess))
#      fsize = uint16(rand(Uint64) & Unums.mask(fss))
#      exponent = rand(Uint64) & Unums.mask(esize + 1)
#      fraction = rand(Uint64) & Unums.mask(-(fsize + 1))
#      uval = float64(Unum{ess,fss}(fsize, esize, zero(Uint16), fraction, exponent))
#      cval = 2.0^(exponent - 2.0^(esize - 1)) * (big(fraction) / 2.0^64)
#    end
#  end
#end

#float to unum
#test that the general conversion works for normal floating points in the {4,6} environment

seed = randn(100)
f16a = [BigFloat(float16(seed[i])) for i = 1:100]
f32a = [BigFloat(float32(seed[i])) for i = 1:100]
f64a = [BigFloat(float64(seed[i])) for i = 1:100]
c16a = [calculate(convert(Unum{4,6}, float16(seed[i]))) for i = 1:100]
c32a = [calculate(convert(Unum{4,6}, float32(seed[i]))) for i = 1:100]
c64a = [calculate(convert(Unum{4,6}, float64(seed[i]))) for i = 1:100]
@test f16a == c16a
@test f32a == c32a
@test f64a == c64a

#test that NaNs convert.
@test isnan(convert(Unum{4,6}, NaN16))
@test isnan(convert(Unum{4,6}, NaN32))
@test isnan(convert(Unum{4,6}, NaN))
#and positive and negative Infs
@test ispinf(convert(Unum{4,6}, Inf16))
@test ispinf(convert(Unum{4,6}, Inf32))
@test ispinf(convert(Unum{4,6}, Inf))
@test isninf(convert(Unum{4,6}, -Inf16))
@test isninf(convert(Unum{4,6}, -Inf32))
@test isninf(convert(Unum{4,6}, -Inf))
#test that zero converts correctly
@test iszero(convert(Unum{4,6}, zero(Float16)))
@test iszero(convert(Unum{4,6}, zero(Float32)))
@test iszero(convert(Unum{4,6}, zero(Float64)))

#test some subnormal numbers.
f16sn = reinterpret(Float16, one(Uint16))
@test calculate(convert(Unum{4,6}, f16sn)) == BigFloat(f16sn)
f32sn = reinterpret(Float32, one(Uint32))
@test calculate(convert(Unum{4,6}, f32sn)) == BigFloat(f32sn)
f64sn = reinterpret(Float64, one(Uint64))
@test calculate(convert(Unum{4,6}, f64sn)) == BigFloat(f64sn)

#test pushing exact into a unum's subnormal range.
justsubnormal(ess) = reinterpret(Float64,(Unums.min_exponent(ess) + 1022) << 52)
smallsubnormal(ess, fss) = reinterpret(Float64,(Unums.min_exponent(ess) - Unums.max_fsize(fss) + 1022) << 52)
pastsubnormal(ess, fss) = reinterpret(Float64,(Unums.min_exponent(ess) - Unums.max_fsize(fss) + 1021) << 52)
@test calculate(convert(Unum{0,0}, justsubnormal(0))) == BigFloat(justsubnormal(0))
@test calculate(convert(Unum{1,1}, justsubnormal(1))) == BigFloat(justsubnormal(1))
@test calculate(convert(Unum{2,2}, justsubnormal(2))) == BigFloat(justsubnormal(2))
@test calculate(convert(Unum{3,3}, justsubnormal(3))) == BigFloat(justsubnormal(3))
@test calculate(convert(Unum{0,0}, smallsubnormal(0,0))) == BigFloat(smallsubnormal(0,0))
@test calculate(convert(Unum{1,1}, smallsubnormal(1,1))) == BigFloat(smallsubnormal(1,1))
@test calculate(convert(Unum{2,2}, smallsubnormal(2,2))) == BigFloat(smallsubnormal(2,2))
@test calculate(convert(Unum{3,3}, smallsubnormal(3,3))) == BigFloat(smallsubnormal(3,3))
@test isinfinitesimal(convert(Unum{0,0}, pastsubnormal(0,0)))
@test isinfinitesimal(convert(Unum{1,1}, pastsubnormal(1,1)))
@test isinfinitesimal(convert(Unum{2,2}, pastsubnormal(2,2)))
@test isinfinitesimal(convert(Unum{3,3}, pastsubnormal(3,3)))
tinyfloat = reinterpret(Float64, o64)
@test isinfinitesimal(convert(Unum{0,0}, tinyfloat))
@test isinfinitesimal(convert(Unum{1,1}, tinyfloat))
@test isinfinitesimal(convert(Unum{2,2}, tinyfloat))
@test isinfinitesimal(convert(Unum{3,3}, tinyfloat))
@test isalmostinf(convert(Unum{0,0}, 2.2))
@test isalmostinf(convert(Unum{1,1}, 8.2))
