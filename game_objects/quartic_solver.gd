extends Node2D

# Lodovico Ferrari's method yoinked from the quartic equation wiki. This only returns real numbers.
func ferrari_real(A: float, B: float, C: float, D: float, E: float) -> Array[float]:
	assert(A != 0., "QuarticSolver tried to solve a non-quartic polynomial.")
	
	var result: Array[float] = []
	var a: float = (C/A) - (0.375 *pow(B/A,2))
	var b: float = (D/A) - (0.5 *B*C/pow(A,2)) + pow(0.5*B/A, 3)
	var c: float = (E/A) - (0.25*B*D/pow(A,2)) + (1./16)*C*pow(B,2)/pow(A,3) - (3./256)*pow(B/A,4)
	
	var a_squared: float = pow(a,2)
	var k = -0.25*B/A
	
	if is_zero_approx(b):
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
	R -= (Q/2)
	
	var y = -a * 5/6
	if is_zero_approx(R):
		y -= pow(Q,1./3)
	else:
		var U = pow(R,1./3)
		y += U - U/3
	
	var W = sqrt(a + (2*y)) # Supposedly, this is always real.
	
	for i in [-1,1]:
		var m = -((3*a + (2*y) + (2*i*b/W)))
		if m < 0:
			continue
		m = sqrt(m)
		for j in [-1,1]:
			result.push_back(k + (0.5 * (i*W + j*m)))
	
	return []
