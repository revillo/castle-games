Shaders = {};



Shaders.quadMesh = function(love)

    local size = 1;
    
    local vertices = {
		{
			-- top-left corner (red-tinted)
			0, 0, -- position of the vertex
			0, 0, -- texture coordinate at the vertex position
			1, 1, 1, -- color of the vertex
		},
		{
			-- top-right corner (green-tinted)
			1, 0,
			1, 0, -- texture coordinates are in the range of [0, 1]
			1, 1, 1
		},
		{
			-- bottom-right corner (blue-tinted)
			1, 1,
			1, 1,
			1, 1, 1
		},
		{
			-- bottom-left corner (yellow-tinted)
			0, 1,
			0, 1,
			1, 1, 1
		},
    }
        
    return love.graphics.newMesh(vertices, "fan")

end


Shaders.gemShader = function(love)

  return love.graphics.newShader([[
     
    
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

const float F3 =  0.3333333;
const float G3 =  0.1666667;
float snoise(vec3 p) {

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

    extern float time;
    extern vec2 dimensions;
    
    float length0(vec2 p) {
        return max(abs(p.x), abs(p.y));
    }
    
    vec3 pyr(vec2 uv) {
        
        vec2 cuv = (uv - vec2(0.5)) * 1.3;
        //cuv *= dimensions;

        //float height = min(0.5, mix(1.0, 0.0, length0(cuv)));
        
       
        vec2 suv = uv * dimensions;
      
        float border = 1.0 / 6.0;
        
        float height = min(suv.x / border, (dimensions.x - suv.x) / border );
        height = min(height, 
                       min(suv.y / border, (dimensions.y - suv.y) / border )
                    );
                    
                    
        float coneHeight = mix(2.0, 0.0, length(cuv));
        
        //height = mix(height, coneHeight, 0.2);

        height = min(height, 1.0);
        
       return vec3(uv * dimensions, height);
        
    }
    
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
      
        vec2 uv = floor(texture_coords * dimensions * 24.0) / (dimensions * 24.0);
      
        vec3 pos = pyr(uv);
        
        vec3 nx = pyr(uv + vec2(0.01, 0.0));
        vec3 ny = pyr(uv + vec2(0.0, 0.01));
        
        vec3 vx = normalize(nx - pos);
        vec3 vy = normalize(ny - pos);
        
        vec3 normal = normalize(cross(vx, vy));
               
        float nd = (30.0 - pos.z) / normal.z;
        vec3 proj = pos + normal * nd;
        float liq = pow(snoise(vec3(proj.xy, time * 0.4)), 5.0) * 0.0;
        
        float height = pos.z;
        
        vec2 rad = uv - vec2(0.5);
       
       if(height < -0.9 && time > 0.0) {discard; return vec4(0.0, 0.0, 0.0, 0.0);}

       
       float diff = dot(normal, normalize(vec3(-0.2, -0.5, 0.5))) * 0.5 + 0.5;
       float spec = max(0.0, pow(diff, 10.0)) * 0.3;
       
        return vec4(vec3(diff) * color.rgb + vec3(liq) + vec3(spec), 1.0);
    }
    
  ]], [[
  
    extern vec2 scale;
    
    
    vec4 position(mat4 transform_projection, vec4 vertex_position)
    {
        vec4 vp = vertex_position;
        vp.xy *= scale;
        return transform_projection * vp;
    }
  
  ]]);
  
  

end


return Shaders;