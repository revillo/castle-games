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
    extern float facets;
    extern float bomb;
    
    float length0(vec2 p) {
        return max(abs(p.x), abs(p.y));
    }
    
    float signPow(float x, float e) {
        
        return pow(abs(x), e) * sign(x);
    
    }
    
    vec2 squash(vec2 uv, float amt) {
    
        vec2 rvec = (uv - vec2(0.5)) * 2.0;
        
        rvec.x = signPow(rvec.x, amt);
        rvec.y = signPow(rvec.y, amt);
        
        return rvec * 0.5 + vec2(0.5, 0.5);
        
    }
    
    vec3 gem(vec2 uv, Image texture) {
        
        uv = squash(uv, 2.0);
        
        vec2 center = vec2(0.5);// + dimensions - vec2(2.0)
        vec2 rvec = (uv - center);

        if (dimensions.x > 1.5) {
            //center = vec2(1.0) / dimensions;
            center = vec2(1.0);
            vec2 suv = dimensions * uv;
            
            if (suv.x > 1.0) {
                center.x += min(suv.x - 1.0, dimensions.x - 2.0);
            }
            
            if (suv.y > 1.0) {
                center.y += min(suv.y - 1.0, dimensions.y - 2.0);
            }
            
            rvec = suv - center;
            
        }
        
        float theta = atan(rvec.y, rvec.x) / 3.14159 + 0.5;
        
        theta = ((floor(theta * facets + 0.5) / facets) - 0.5) * 3.14159;
       
        
        vec2 ref = vec2(cos(theta), sin(theta));
        
        float proj = dot(rvec, ref);
        
        if (dimensions.x > 1.5) {
            proj *= 1.0;
        } else {
            proj *= 2.0;
        }
        
        
        
        
        float height = 1.0 - proj;
        
        if (height > 0.0) {
          height = min(0.6, height);
          height = height / 0.6;
          height = pow(height, 0.5);
          //height = height * 0.6;
        }
        

        
        return vec3(uv * dimensions, height);
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
    
    vec4 drawBomb(vec2 uv) {
    
      /*
      float radius = length(uv - vec2(0.5));
      
      if (radius > 0.5) return vec4(0.0, 0.0, 0.0, 0.0);
      
      vec3 normal = normalize(vec3(uv, 0.0) - vec3(0.5, 0.5, -0.5));
      
      float diffuse = dot(normal, normalize(vec3(-0.2, -0.5, 0.5))) * 0.5 + 0.5;
      //float diffuse = abs(normal.z) * 0.5 + 0.5;
      diffuse = pow(diffuse, 20.0);
      return vec4(vec3(diffuse), 1.0);
      */
      
      vec3 target = vec3(uv - vec2(0.5), 0.0) * 2.0;
      vec3 ray0 = vec3(0.0, 0.0, -1.0);
      
      vec3 ray = normalize(target - ray0);
      vec2 hit = raySphereIntersect(ray0, ray, vec3(0.0, 0.0, 1.0), 1.35);
      
      vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
      
      //fuse
      
      
      if (hit.x > 0.0) {
        
        vec3 pos = ray0 + ray * hit.x;
        vec3 normal = normalize(pos - vec3(0.0, 0.0, 1.0));
        float diffuse = dot(normal, normalize(vec3(-0.2, -0.5, -2.0))) * 0.5 + 0.5;
        diffuse = pow(diffuse, 100.0) * 0.8 + 0.2;
        color = vec4(vec3(diffuse), 1.0);

      } else {
        
        float dag = abs(-target.y - target.x);
        if (dag < 0.1 && target.x > 0.0 && target.x < 0.75 && target.y > -0.75) {
          color = vec4(vec3(1.0), 1.0);
        }
        
       
      
      }
      
      //spark
      
      vec3 srad = target - vec3(0.75, -0.75, 0.0);
      float maxrad = 0.4 + sin(time * 10.0) * 0.05;
      float sdist = length(srad) / maxrad;
      
       if (sdist < 1.0) {
          
          color = mix(color, vec4(1.0, 0.6, 0.3, 1.0), 1.0 - sdist);
          
          if (sdist < 0.2) {
              color = mix(color, vec4(1.0, 0.9, 0.8, 1.0), 1.0 - sdist);
          }
          
      }
      return color;
      
    }
    
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
      
        //vec2 uv = floor(texture_coords * dimensions * 24.0) / (dimensions * 24.0);
        vec2 uv = texture_coords;
        
        if (bomb > 0.0) {
          return drawBomb(uv);
        }
      
        vec3 pos = gem(uv, texture);
        
        vec3 nx = gem(uv + vec2(0.005, 0.0), texture);
        vec3 ny = gem(uv + vec2(0.0, 0.005), texture);
        
        vec3 vx = normalize(nx - pos);
        vec3 vy = normalize(ny - pos);
        
        vec3 normal = normalize(cross(vx, vy));
        
          /*
        float nd = (30.0 - pos.z) / normal.z;
        vec3 proj = pos + normal * nd;
        float liq = pow(snoise(vec3(proj.xy, time * 0.4)), 5.0) - 0.5;
          */
        
        
        float height = pos.z;
        
        vec2 rad = uv - vec2(0.5);
       
        if(height < 0.0 && time > -1.0) {
            return vec4(0.0, 0.0, 0.0, 0.0);
        }

       
       float diff = dot(normal, normalize(vec3(-0.2, -0.5, 0.5))) * 0.3 + 0.7;
       float spec = max(0.0, pow(diff, 15.0)) * 0.7;
       

   
       vec3 fclr = vec3(diff) * color.rgb + vec3(spec);
       //fclr = floor(fclr * 16.0) / 16.0;
       
       //gradient
       /*
       if (dimensions.x > 1.5) {
           vec2 rvec = uv - vec2(0.5);
           float grad = dot(rvec, vec2(-0.25, -0.5)) * 0.5 + 0.0;
           fclr += vec3(grad);
       }
       */
       
        return vec4(fclr, 1.0);
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