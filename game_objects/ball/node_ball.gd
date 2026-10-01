extends Node2D

enum Collision{
	FLOOR,
	NET_SIDE,
	NET_TOP,
	CEILING,
	WALL,
	NONE
}

@export var velocity: Vector2 = Vector2.ZERO
var gravity: Vector2 = Vector2(0, 980)
var frozen: bool = false

const RADIUS = 46
const FLOOR = 0
const CEILING = -1020
const WALL = 960
const NET_HEIGHT = -225

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	global_position = Vector2(-150,-400)
	velocity = Vector2(400,400)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if frozen:
		return
	var next = next_pos(global_position, velocity, gravity, delta)
	global_position = next[0] 
	velocity = next[1]

func next_pos(p: Vector2, v: Vector2, g: Vector2, delta: float) -> Array[Vector2]:
	if is_zero_approx(delta):
		return [p, v]
	
	var collision: Collision =  Collision.NONE
	var t_net = null
	var t_floor = null
	var t_ceiling = null
	var t_wall = null
	var net_collision
	
	t_floor = (sqrt(pow(v.y,2) + 2 * g.y * (p.y + RADIUS)) - v.y) / g.y
	if t_floor <= delta:
		score()
	
	if v.x != 0:
		t_wall = (WALL - RADIUS - (p.x*sign(v.x))) / -v.x
	if v.x * p.x < 0 or abs(p.x) < RADIUS:
		var t = (RADIUS*sign(p.x) - p.x) / v.x
		var y = p.y + v.y * t + 0.5 * g.y * pow(t,2)
		var dx = p.x
		var dy = p.y - NET_HEIGHT
		
		if t > 0 and y >= NET_HEIGHT:
			t_net = t
			net_collision = Collision.NET_SIDE
		else:
			var results = %QuarticSolver.ferrari_real(0.25*(pow(g.x,2)+pow(g.y,2)), (v.x*g.x)+(v.y*g.y), (g.x*dx)+(g.y*dy)+pow(v.x,2)+pow(v.y,2), 2*((v.x*dx)+(v.y*dy)), pow(dx,2)+pow(dy,2)-pow(RADIUS,2))
			print(results)
			if results.size() > 0:
				var min_ = 1.
				for r in results:
					if r > 0 and r < min_:
						min_ = r
				t_net = min_
				net_collision = Collision.NET_TOP
		
	if v.y < 0:
		var ymax = (-0.5*pow(v.y,2) / g.y) + p.y
		if ymax <= CEILING + RADIUS:
			print(ymax, CEILING+RADIUS)
			t_ceiling = (sqrt(pow(v.y,2) + 2 * g.y * (p.y - RADIUS - CEILING)) + v.y) / g.y
	
	var t_min = delta
	if t_net and not is_zero_approx(t_net) and t_net < t_min:
		t_min = t_net
		collision = net_collision
	if t_ceiling and not is_zero_approx(t_ceiling) and t_ceiling > 0 and t_ceiling < t_min:
		t_min = t_ceiling
		collision = Collision.CEILING
	if t_wall and t_wall != 0 and t_wall > 0 and t_wall < t_min:
		t_min = t_wall
		collision = Collision.WALL
	if not is_zero_approx(t_floor) and t_floor > 0 and t_floor < t_min:
		t_min = t_floor
		collision = Collision.FLOOR
	print([p,v,t_min,["floor","side","top","ceiling","wall","none"][collision],t_ceiling,t_wall])
	
	# Collision
	p += v * t_min + 0.5 * g * pow(t_min,2)
	v += g * t_min
	delta -= t_min
	if collision == Collision.NONE:
		return [p, v]
	if collision == Collision.NET_SIDE or collision == Collision.WALL:
		v.x = -v.x
	elif collision == Collision.NET_TOP:
		var n = Vector2(0, NET_HEIGHT).direction_to(p)
		v -= 2*v.dot(n)*n
	elif collision == Collision.CEILING or collision == Collision.FLOOR:
		v.y *= -1
	return next_pos(p, v, g, delta)

func score():
	pass
