extends Node2D

# Lodovico Ferrari's method yoinked from the quartic equation wiki.
# Only returns real roots.
# Does not accept lower-order polynomials.
func ferrari_real(A: float, B: float, C: float, D: float, E: float) -> Array[float]:
	assert(A != 0., "QuarticSolver tried to solve a non-quartic polynomial.")
	
	var result: Array[float] = []
	var a: float = (C/A) - (0.375 *pow(B/A,2))
	var b: float = (D/A) - (0.5 *B*C/pow(A,2)) + pow(0.5*B/A, 3)
	var c: float = (E/A) - (0.25*B*D/pow(A,2)) + (1./16)*C*pow(B,2)/pow(A,3) - (3./256)*pow(B/A,4)
	
	var k = -0.25*B/A
	
	if is_zero_approx(b):
		var a_squared: float = pow(a,2)
		if a_squared < 4*c:
			return result
		var l = sqrt(a_squared - (4*c))
		for j in [-1,1]:
			if j*l < a:
				continue
			for i in [-1,1]:
				result.push_back(k + (i*sqrt(((j*l) - a) / 2)))
		
		return result
	
	var P = -c - (pow(a,2)/12)
	var Q = (a*c/3) - 0.125*pow(b,2) - (pow(a,3)/108)
	var R = pow(Q/2,2) + pow(P/3,3)
	if R < 0:
		return result
	R = sqrt(R) - (Q/2)
	
	var y = -a * 5/6
	if is_zero_approx(R):
		y -= cbrt(Q)
	else:
		var U = cbrt(R)
		y += U - U/3
	
	var W = sqrt(a + (2*y)) # Supposedly, this is always real.
	
	for i in [-1,1]:
		var m = -((3*a + (2*y) + (2*i*b/W)))
		if m < 0:
			continue
		m = sqrt(m)
		for j in [-1,1]:
			result.push_back(k + (0.5 * (i*W + j*m)))
	print([a,b,c,P,Q,R,W,y])
	
	return result

# Solution using the radical formula but with some cacheing.
# Only returns real roots.
# Does not accept lower-order polynomials.
# I assumed that complex terms will onlly yield complex roots. I am uncertain of its accuracy.
func radical_real(A: float, B: float, C: float, D: float, E: float) -> Array[float]:
	assert(A != 0., "QuarticSolver tried to solve a non-quartic polynomial.")
	
	var result: Array[float] = []
	var a: float = B/A
	var b: float = C/A
	var c: float = D/A
	var d: float = E/A
	
	var m = pow(b,2) - 3*a*c + 12*d
	var n = 2*pow(b,3) - 9*a*b*c + 27*(pow(c,2) + pow(a,2)*d) - 72*b*d
	var o = pow(n,2) - 4*pow(m,3)
	if o < 0:
		print("o")
		return result
	o = cbrt(n + sqrt(o))
	
	var p = cbrt(2) / (3*o)
	var q = o / cbrt(54)
	var r = pow(a,2)*0.25 - (2*b/3)
	var s = p + q
	var t = r + s
	if t < 0:
		print("t")
		return result
	var u = 0.5 * sqrt(s)
	var v = r - s
	var w = -pow(a,3) + 4*a*b - 8*c
	var x = w / (8*u)
	var y = -a / 4
	
	for i in [-1,1]:
		var z = v + i*x
		if z < 0:
			continue
		z = 0.5 * sqrt(z)
		for j in [-1,1]:
			result.push_back(y + i*u + j*z)
		print([m,n,o,p,q,r,s,t,u,v,w,x,y,z])
	
	return result

func cbrt(x: float) -> float:
	if x < 0:
		return -pow(-x, 1./3)
	else:
		return pow(x, 1./3)
