#Copyright (c) 2015 Rex Computing and Isaac Yonemoto

#see LICENSE.txt

#this work was supported in part by DARPA Contract D15PC00135


#unit-unum.jl

#test that the unum safe constructor throws appropriate errors

#a few useful definitions
o16 = one(Uint16)
z16 = zero(Uint16)
o64 = one(Uint64)
z64 = zero(Uint64)
f64 = uint64(-1)
t64 = 0x8000_0000_0000_0000

@test_throws ArgumentError Unums.__check_block_unum(0, 0, o16, z16, z64, z64)

#test that fsize error gets thrown.
@test_throws ArgumentError unum(Unum{0,0}, o16, z16, z16, z64, z64)
#test that esize error gets thrown
@test_throws ArgumentError unum(Unum{0,0}, z16, o16, z16, z64, z64)
#test that exponent error gets thrown
@test_throws ArgumentError unum(Unum{0,0}, z16, z16, z16, z64, uint64(2))
#test that the fraction error gets thrown
@test_throws ArgumentError unum(Unum{0,0}, z16, z16, z16, [z64, z64], z64)
#test that the constructor correctly engages frac_trim
walpiri_half = unum(Unum{0,0}, z16, z16, z16, f64, z64)
@test walpiri_half.fraction == t64
@test walpiri_half.fsize == 0
@test walpiri_half.flags & Unums.UNUM_UBIT_MASK == Unums.UNUM_UBIT_MASK

#test the unum_easy constructor
easy_walpiri_two = unum_easy(Unum{0,0}, z16, z64, o64)
@test easy_walpiri_two.fraction == z64
@test easy_walpiri_two.fsize == 0
@test easy_walpiri_two.flags == z16
#test that unum_easy will also take a sloppy SuperInt.
easy_walpiri_two_oops = unum_easy(Unum{0,0}, z16, [f64, z64], o64)
@test easy_walpiri_two_oops.fraction == z64
@test easy_walpiri_two_oops.fsize == 0
@test easy_walpiri_two_oops.flags == z16

#unset the development environment
Unums.__unum_release_environment()
#test that we can create unsafe unums using the unsafe constructor.
unsafe_fsize = Unum{0,0}(o16, z16, z16, z64, z64)
unsafe_fsize_2 = unum_unsafe(unsafe_fsize)
unsafe_esize = Unum{0,0}(z16, o16, z16, z64, z64)
unsafe_esize_2 = unum_unsafe(unsafe_esize)
unsafe_exponent = Unum{0,0}(z16, o16, z16, z64, uint64(2))
unsafe_exponent_2 = unum_unsafe(unsafe_exponent)
unsafe_fraction = Unum{0,0}(z16, o16, z16, [z64, z64], z64)
unsafe_fraction_2 = unum_unsafe(unsafe_fraction)
#then show that these trigger TypeErrors when passed through the safe constructor
@test_throws ArgumentError unum(unsafe_fsize)
@test_throws ArgumentError unum(unsafe_fsize_2)
@test_throws ArgumentError unum(unsafe_esize)
@test_throws ArgumentError unum(unsafe_esize_2)
@test_throws ArgumentError unum(unsafe_exponent)
@test_throws ArgumentError unum(unsafe_exponent_2)
@test_throws ArgumentError unum(unsafe_fraction)
@test_throws ArgumentError unum(unsafe_fraction_2)
