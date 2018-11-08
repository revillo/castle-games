Shaders = {};



Shaders.quadMesh = function(love)

    local size = 200;
    
    local vertices = {
		{
			-- top-left corner (red-tinted)
			-size, -size, -- position of the vertex
			0, 0, -- texture coordinate at the vertex position
			1, 1, 1, -- color of the vertex
		},
		{
			-- top-right corner (green-tinted)
			size, -size,
			1, 0, -- texture coordinates are in the range of [0, 1]
			1, 1, 1
		},
		{
			-- bottom-right corner (blue-tinted)
			size, size,
			1, 1,
			1, 1, 1
		},
		{
			-- bottom-left corner (yellow-tinted)
			-size, size,
			0, 1,
			1, 1, 1
		},
    }
        
    return love.graphics.newMesh(vertices, "fan")

end


Shaders.planetShader = function(love)

  return love.graphics.newShader[[
  
    extern mat3 rotation;
    
    vec3 random3(vec3 c) {
        float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
        vec3 r;
        r.z = fract(512.0*j);
        j *= .125;
        r.x = fract(512.0*j);
        j *= .125;
        r.y = fract(512.0*j);
        return r-0.5;
    }
    
    float snoise(vec3 p) {
        const float F3 =  0.3333333;
        const float G3 =  0.1666667;
        vec3 s = floor(p + dot(p, vec3(F3)));
        vec3 x = p - s + dot(s, vec3(G3));
         
        vec3 e = step(vec3(0.0), x - x.yzx);
        vec3 i1 = e*(1.0 - e.zxy);
        vec3 i2 = 1.0 - e.zxy*(1.0 - e);
            
        vec3 x1 = x - i1 + G3;
        vec3 x2 = x - i2 + 2.0*G3;
        vec3 x3 = x - 1.0 + 3.0*G3;
         
        vec4 w, d;
         
        w.x = dot(x, x);
        w.y = dot(x1, x1);
        w.z = dot(x2, x2);
        w.w = dot(x3, x3);
         
        w = max(0.6 - w, 0.0);
         
        d.x = dot(random3(s), x);
        d.y = dot(random3(s + i1), x1);
        d.z = dot(random3(s + i2), x2);
        d.w = dot(random3(s + 1.0), x3);
         
        w *= w;
        w *= w;
        d *= w;
         
        return dot(d, vec4(52.0)) * 0.5 + 0.5;
    }
    
    vec2 raySphereIntersect(vec3 r0, vec3 rd, vec3 s0, float sr) {
      float a = dot(rd, rd);
      vec3 s0_r0 = r0 - s0;
      float b = 2.0 * dot(rd, s0_r0);
      float c = dot(s0_r0, s0_r0) - (sr * sr);
      
      if (b*b - 4.0*a*c < 0.0) {
          return vec2(-0.01, -0.01);
      }
      
      float q = (-b - sqrt((b*b) - 4.0*a*c))/(2.0);
      
      
      return vec2(q / a, c / q);
    }
    
    vec4 planetColor(vec3 pos) {
        
        float step = snoise(pos * 2.0);
        
        float clr = floor(step * 10.0) / 9.0;
        
        clr = mix(0.5, 1.0, clr);
        
        return vec4(0.0, clr, clr, 1.0);
        
    }
     
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
      //vec4 pixel = vec4(texture_coords, 0.0, 1.0);
      
      vec3 rayOrig = vec3(0, 0, -5.0);
      vec3 rayDir = normalize(vec3(texture_coords * 2.0 - vec2(1.0), 0) - rayOrig);
      vec2 hits = raySphereIntersect(rayOrig, rayDir, vec3(0.0), 0.9);
      
      if (hits.x < 0.0) {
        discard;
        return vec4(0.0, 0.0, 0.0, 0.0);
      } 
      
      vec3 hitPos = rotation * (rayOrig + rayDir * hits.x);
      
      return planetColor(hitPos);
    }
    
  ]];
  
  

end


return Shaders;