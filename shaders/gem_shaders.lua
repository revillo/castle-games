Shaders = {};

local randFloat = function(lo, hi) 
    return lo + (math.random() * (hi-lo));
end

Shaders.makeBorderMesh = function(width, height) 

  local vi = 1;
  local vertices = {};
  
  --[[
  vertices[vi] = {
    0, 0,
    0, 0,
    1, 1, 1
  }
  vi = vi + 1;
  ]]
  local thickness = 1.6;
  
  local randDepth = function()
    return randFloat(0, 1); 
  end;
  
  local jitter = function()
    return randFloat(-0.2, 0.2);
  end;
  
  local randHeight = function() 
    return randFloat(thickness, thickness);
  end
  
  local makeVerts = function(x1, y1, x2, y2, h) 
    vertices[vi] = {
      x1, y1,
      randDepth(), 0.0
    }
    vi = vi + 1;

    vertices[vi] = {
      x2, y2,
      randDepth(), math.min(1.0, h)
    }
    
    vi = vi + 1;
  end
  
  for x = 0, width do
    local ht = randHeight();
    makeVerts(x + jitter(), 0, x + jitter(), 0 - ht, ht);
  end
  
  for y = 1, height-1 do
    local ht = randHeight();
    makeVerts(width, y + jitter(), width + ht, y + jitter(), ht);
  end
  
  for x = width, 0, -1 do
    local ht = randHeight();
    makeVerts(x + jitter(), height-1, x + jitter(), height - 1 + ht, ht);
  end
  
  for y = height-1, 0, -1  do
    local ht = randHeight();
    makeVerts(0, y + jitter(), 0 - ht, y + jitter(), ht);
  end
  
  --return love.graphics.newMesh(vertices, "strip")
  return love.graphics.newMesh({{"VertexPosition", "float", 3}, {"VertexShade", "float", 1}}, vertices, "strip", "static")

end;


Shaders.quadMesh = function()

    local size = 1;
    
    local vertices = {
		{
			0, 0, 
			0, 0,
			1, 1, 1,
		},
		{
			1, 0,
			1, 0, 
			1, 1, 1
		},
		{
			1, 1,
			1, 1,
			1, 1, 1
		},
		{
			0, 1,
			0, 1,
			1, 1, 1
		},
    }
        
    return love.graphics.newMesh(vertices, "fan", "static")

end


Shaders.gemShader = function()

  return love.graphics.newShader([[
     
    
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

Shaders.backgroundShader = function()
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
	 
	return dot(d, vec4(52.0));
}


float snoise2(vec3 v) {

  return snoise(v * 0.5) + snoise(v * 2.0) * 0.5;
}

float snoiz(vec2 uv, float c) {
  return snoise(vec3(uv, c));
}

  
  float getDist(vec2 a, vec2 b) {
  
    b += vec2(snoiz(b, 1.0), snoiz(b, 10.0)) * 0.8;
  
    return length(a-b);
  
  }
  float signPow(float x, float e) {
        
        return pow(abs(x), e) * sign(x);
    
  }
  float getHeight(vec2 uv) {
      return signPow(snoise(vec3(uv, 1.0)), 0.2) - 0.7;
      //return max(0.0, signPow(snoise(vec3(uv, time * 0.0)), 0.2) - 0.6);
  }
    
    vec3 roundNormal(vec3 n, float tf, float pf) {
      
      float phi = asin(n.z) / 3.14159 + 0.5;

      float theta = atan(n.y, n.x) / 3.14159 + 0.5;
        
      theta = ((floor(theta * tf + 0.5) / tf) - 0.5) * 3.14159;
      phi = ((floor(phi * pf + 0.5) / pf) - 0.5) * 3.14159;
      
      return vec3(cos(theta) * cos(phi), sin(theta) * cos(phi), sin(phi));
    }
    
    
    float getCell(vec2 uv) {
      return snoise(vec3(uv, 1.0)) * 0.25 + 1.0;
    }
    

    void drawWall(vec2 uv, inout vec4 color, vec3 hue) {
    
       
       float nz1 = getCell(vec2(0.0, floor(uv.y)));
       float nz2 = getCell(vec2(0.0, ceil(uv.y)));
       
       float t = fract(uv.y);
       
       if (uv.x < mix(nz1, nz2, t)) {
          color.rgb = hue * nz2 * 0.2;
       } 
    
    }
    extern float time;
    extern float unit;
    extern vec2 scale;
    
    void drawWalls(vec2 uv, inout vec4 clr) {
      drawWall(uv * vec2(1.0, 4.0) + vec2(-3.0, time), clr, vec3(0.15, 0.15, 0.17));
      drawWall(uv * vec2(1.0, 2.0) + vec2(-1.5, time), clr, vec3(0.3, 0.3, 0.35));
      drawWall(uv * vec2(1.0, 1.0) + vec2( 0.0, time), clr, vec3(0.6, 0.6, 0.7));
    }
    

    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
    {

        //vec3 dx = normalize(dFdx(pos));
        //vec3 dy = normalize(dFdy(pos));
        //vec3 normal = normalize(cross(dy, dx));
        
        //float diffuse = dot(normal, normalize(vec3(-0.2, -0.5, 1.0))) * 0.5 + 0.5;
        
        //float diffuse = 1.0;
        
        //return vec4(vec3(diffuse) * vec3(0.61, 0.51, 0.7), 1.0);
        
        //float liq = snoise(vec3(texture_coords + vec2(0.0, time), 10.0));
        
        
        vec4 clr = vec4(0.0, 0.0, 0.0, 1.0);
       
        
        vec2 uv = screen_coords;
        float uvscale = 0.05 / unit;
        uv *= uvscale;     
        drawWalls(uv, clr);
        
        uv = vec2(scale.x, screen_coords.y) - vec2(screen_coords.x, 0.0);
        uv *= uvscale;
        uv.y += 100.0;
        drawWalls(uv, clr);

        
        
        return clr;
        
        
    }
  
  ]] , [[
  
    extern vec2 scale;

    attribute float VertexShade;
    
    vec4 position(mat4 transform_projection, vec4 vertex_position)
    {
        vec4 vp = vertex_position;
        vp.xy *= scale;
        return transform_projection * vp;
    }
  
  ]]);
end


Shaders.borderShader = function()

  return love.graphics.newShader([[
     
    varying vec3 pos; 
    varying float shade;

    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
    {

        vec3 dx = normalize(dFdx(pos));
        vec3 dy = normalize(dFdy(pos));
        vec3 normal = normalize(cross(dy, dx));
        
        float diffuse = dot(normal, normalize(vec3(-0.2, -0.5, 1.0))) * 0.5 + 0.5;
    
        return vec4(vec3(diffuse) * vec3(0.61, 0.51, 0.7) * shade, 1.0);
    
    }
  
  ]] , [[
  
    extern vec2 scale;
    varying vec3 pos;
    varying float shade;

    attribute float VertexShade;
    
    vec4 position(mat4 transform_projection, vec4 vertex_position)
    {
        vec4 vp = vertex_position;
        vp.xy *= scale;
        pos = vertex_position.xyz;
        shade = VertexShade;
        return transform_projection * vp;
    }
  
  ]]);
  
  
end
     
    

return Shaders;