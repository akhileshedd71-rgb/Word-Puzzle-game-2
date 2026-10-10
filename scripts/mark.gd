extends Control
## Resolution-independent editorial illustrations, drawn in-engine.
var kind := "spark"
var color := Color("345ded")
var fill := Color("e9edff")
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
func _draw() -> void:
	var c := size / 2
	var r := minf(size.x, size.y) * 0.35
	match kind:
		"coin":
			draw_arc(c,r,0,TAU,40,color,2.5,true)
			draw_line(c+Vector2(0,-r*.45),c+Vector2(0,r*.45),color,2.5,true)
		"spark":
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2.from_angle(a)*r*0.32, c + Vector2.from_angle(a)*r, color, 3, true)
			draw_circle(c, r*0.14, color)
		"book":
			draw_polyline(PackedVector2Array([c+Vector2(-r,-r*.7),c+Vector2(0,-r*.45),c+Vector2(r,-r*.7),c+Vector2(r,r*.7),c+Vector2(0,r*.95),c+Vector2(-r,r*.7),c+Vector2(-r,-r*.7)]),color,3,true)
			draw_line(c+Vector2(0,-r*.45),c+Vector2(0,r*.95),color,3,true)
		"bolt":
			draw_colored_polygon(PackedVector2Array([c+Vector2(r*.25,-r),c+Vector2(-r*.7,r*.15),c+Vector2(-r*.05,r*.15),c+Vector2(-r*.25,r),c+Vector2(r*.7,-r*.2),c+Vector2(r*.05,-r*.2)]),color)
		"moon":
			draw_arc(c,r,0.35,5.3,40,color,3,true)
			draw_arc(c+Vector2(r*.45,-r*.15),r*.72,0.9,4.5,30,color,3,true)
		"grid":
			for x in 2:
				for y in 2:
					draw_rect(Rect2(c+Vector2(x*1.2-1.1,y*1.2-1.1)*r,Vector2.ONE*r*.8),color,false,2.5)
		"tune":
			for i in 3:
				var y := c.y + (i-1)*r*.65
				draw_line(Vector2(c.x-r,y),Vector2(c.x+r,y),color,2.5,true)
				draw_circle(Vector2(c.x+(-0.4 if i%2==0 else 0.4)*r,y),r*.19,fill)
				draw_arc(Vector2(c.x+(-0.4 if i%2==0 else 0.4)*r,y),r*.19,0,TAU,20,color,2.5,true)
		"sun":
			draw_arc(c,r*.53,0,TAU,40,color,3,true)
			for i in 8:
				var v := Vector2.from_angle(TAU*i/8.0)
				draw_line(c+v*r*.78,c+v*r,color,2.5,true)
