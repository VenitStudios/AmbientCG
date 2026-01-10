@tool extends Node


func make_standard_material(files : PackedStringArray, options : Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.uv1_triplanar = options.get("use_triplanar_uv", false)
	
	for file : String in files:
		if file.containsn("color"): 
			material.albedo_texture = load(file)
		if file.containsn("normal"): 
			material.normal_enabled = true
			material.normal_texture = load(file)
		if file.containsn("metalness"):
			material.metallic_texture = load(file)
		if file.containsn("rough"): 
			material.roughness_texture = load(file)
		if file.containsn("displacement") or file.containsn("height"):
			material.heightmap_enabled = not options.get("use_triplanar_uv", false) # height maps dont support being used on triplanar materials.
			material.heightmap_texture
	
	
	return material


func make_orm_material(files : PackedStringArray, options : Dictionary) -> ORMMaterial3D:
	var material := ORMMaterial3D.new()
	
	
	
	return material
