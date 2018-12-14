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
      float maxrad = 0.4 + sin(time * 10.0) * 0.05;

      vec3 ray = normalize(target - ray0);
      
      vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
      
      vec2 glowUV = (squash(uv, 1.5) - vec2(0.5)) * 2.0;
      
      float glowRad = length(glowUV);
      
      if (glowRad < 1.0) {
        float glowPulse = 0.5 + sin(time * 10.0) * 0.2;
        color = vec4(vec3(0.7, 0.7, 0.9), (1.0 - glowRad) * 5.0 * glowPulse);
      }
      
      vec2 hit = raySphereIntersect(ray0, ray, vec3(0.0, 0.0, 1.0), 1.3);

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
      float sdist = length(srad) / maxrad;
      
       if (sdist < 1.0) {
          
          color = mix(color, vec4(1.0, 0.6, 0.3, 1.0), 1.0 - sdist);
          
          if (sdist < 0.2) {
              color = mix(color, vec4(1.0, 0.9, 0.8, 1.0), 1.0 - sdist);
          }
          
      }
      return color;
      
    }
    
    vec3 gem(vec2 uv) {
        
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
    
 
    vec4 drawGem(vec2 uv, vec4 color) {
    
      vec3 pos = gem(uv);
        
        vec3 nx = gem(uv + vec2(0.005, 0.0));
        vec3 ny = gem(uv + vec2(0.0, 0.005));
        
        vec3 vx = normalize(nx - pos);
        vec3 vy = normalize(ny - pos);
        
        vec3 normal = normalize(cross(vx, vy));
            
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
    
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
      
        //vec2 uv = floor(texture_coords * dimensions * 24.0) / (dimensions * 24.0);
        vec2 uv = texture_coords;
        
        if (bomb > 0.0) {
          return drawBomb(uv);
        } else {
          return drawGem(uv, color);
        }
      
        
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

float random(float v) {
  return fract(4096.0 * sin(v));
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

    extern float time;
    extern float unit;
    extern vec2 scale;
    
    extern float flash;

  vec3 gem(vec2 uv, vec2 dimensions, float facets) {
        
        //uv = squash(uv, 2.0);
        
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
          height = min(0.7, height);
          height = height / 0.7;
          height = pow(height, 0.5);
        }

        return vec3(uv * dimensions, height);
    }
    
    float randNum(float seed, float min, float max) {
      
      return min + ceil(random(seed) * (max - min));
    
    }
    
    float lightFlip = -1.0;
    
    vec2 rotate(vec2 v, float a) {
      float s = sin(a);
      float c = cos(a);
      mat2 m = mat2(c, -s, s, c);
      return m * v;
    }    
    
    void drawGem(vec2 uv, vec4 color, float seed, inout vec4 clr) {
    
        vec2 dim = vec2(
          randNum( seed * 23.13 + 3020.34, 1.0, 3.0),
          randNum( seed * 1823.13 + 30.78, 1.0, 3.0)
        );
    
        //uv -= vec2(0.5, 0.5);
         //uv = rotate(uv, random(seed * 393.23) * 1.0);
        //uv += vec2(0.5, 0.5);
        //uv *= 1.6;
    
        uv *= vec2(dim.y, dim.x);
        //dim /= 2.0;
        
        //dim = vec2(2.0, 2.0);
      
        float facets = randNum(seed * 100.0 + 100.0, 2.0, 6.0);
        vec3 pos = gem(uv, dim, facets);
        
        vec3 nx = gem(uv + vec2(0.005, 0.0),dim, facets);
        vec3 ny = gem(uv + vec2(0.0, 0.005),dim, facets);
        
        vec3 vx = normalize(nx - pos);
        vec3 vy = normalize(ny - pos);
        
        vec3 normal = normalize(cross(vx, vy));
            
        float height = pos.z;
        
        vec2 rad = uv - vec2(0.5);
       
        if(height < 0.0) {
            return;
        }
       
       float diff = dot(normal, normalize(vec3(0.2 * lightFlip, -0.5, 0.5))) * 0.1 + 0.9;
       float spec = max(0.0, pow(diff, 100.0)) * 0.8;
        clr.rgb = vec3(diff - 0.4) * color.rgb + vec3(spec);
        clr.a = 1.0;
        
        //return vec4(fclr, 1.0);
    }
 
  float signPow(float x, float e) {
        
        return pow(abs(x), e) * sign(x);
    
  }
    
    vec3 roundNormal(vec3 n, float tf, float pf) {
      
      float phi = asin(n.z) / 3.14159 + 0.5;

      float theta = atan(n.y, n.x) / 3.14159 + 0.5;
        
      theta = ((floor(theta * tf + 0.5) / tf) - 0.5) * 3.14159;
      phi = ((floor(phi * pf + 0.5) / pf) - 0.5) * 3.14159;
      
      return vec3(cos(theta) * cos(phi), sin(theta) * cos(phi), sin(phi));
    }
    
    
    float getCell(float y) {
      float d =  sin(y) * 0.2 + sin(y * 10.0) * 0.05 + 1.0;
      d += random(y) * 0.5;
      return d;
    }
    
 
    float midYDist;
    void drawWall(vec2 uv, inout vec4 color, vec3 hue) {
        
       
        //uv.y += uv.x * cos(uv.y * 0.1 + uv.x * 0.3) * -0.3;
        uv.y += uv.x * midYDist * 1.4;
        
        vec2 guv = uv * 0.8;

       float nz1 = getCell(floor(uv.y));
       float nz2 = getCell(ceil(uv.y));
       
       float t = fract(uv.y);
       
       float wallDepth =  mix(nz1, nz2, t);
       

       
       if (uv.x < wallDepth) {
          color.rgb = hue * wallDepth * 0.2;
          color.b += cos(uv.y) * 0.01;
       } 
       
       
       //Draw Gem
       float gemDepth = getCell(ceil(guv.y) - 0.5);
       
       float seed = ceil(guv.y);
       guv.x += random(seed * 32.0 + 255.0) * 1.0 + 0.1;
       
        if ( random(seed) < 1.0 * hue.r && guv.x < 1.0 && guv.x > 0.0) {
           
          hue *= 0.4;
          hue.g += random(seed * 1000.0) * 0.6;
          hue.b += random(seed * 500.0) * 0.6;
          hue.r += random(seed * 200.0) * 0.6;
          
          drawGem(fract(guv), vec4(hue, 1.0), seed, color);
          
        }
        
    
    }

    void drawWalls(vec2 uv, inout vec4 clr) {
      
      vec3 wallColor = vec3(0.6, 0.6, 0.7);

      drawWall(uv * vec2(4.0, 4.0) + vec2(-10.0, time * 2.0), clr, wallColor * 0.25);
      drawWall(uv * vec2(2.0, 2.0) + vec2(-3.0, time * 1.5), clr, wallColor * 0.5);
      drawWall(uv * vec2(1.0, 1.0) + vec2( 0.0, time), clr, wallColor);
    }
    

    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
    {
        vec4 clr = vec4(0.0, 0.0, 0.0, 1.0);
        
        if (time < 0.0) {
          vec4 skyc = mix(vec4(0.15, 0.4, 0.8, 1.0), vec4(0.3, 0.6, 0.8, 1.0), texture_coords.y);
          vec4 white = vec4(1.0, 1.0, 1.0, 1.0);
          
          return mix(white, skyc, clamp(-time/50.0, 0.0,  1.0));
        }
       
       midYDist = screen_coords.y / scale.y - 0.5;
        
        vec2 uv = screen_coords;
        float uvscale = 0.05 / unit;
        uv *= uvscale;     
        uv.y += 10.0;
        drawWalls(uv, clr);
        
        lightFlip = 1.0;
        uv = vec2(scale.x, screen_coords.y) - vec2(screen_coords.x, 0.0);
        uv *= uvscale;
        uv.y += 200.0;
        drawWalls(uv, clr);

        return mix(clr, vec4(1.0,0.3, 0.1, 1.0), flash * 0.2);
        
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

Shaders.rubyShader = function() 
 return love.graphics.newShader([[

  extern float time;
 
 
    
float cone(in vec3 p, in vec3 c) {
    vec2 q = vec2(length(p.xz), p.y);
    float d1 = -p.y-c.z;
    float d2 = max(dot(q, c.xy), p.y);
    return length(max(vec2(d1, d2),0.0)) + min(max(d1, d2), 0.0);
}

float box_sdf(vec3 center, vec3 dimensions, vec3 pos) {

	vec3 dist = abs(pos - center) - dimensions;
    return max(max(dist.x, dist.y), dist.z);
}

float gem_sdf(in vec3 ray)
{
    float heightFactor = 1.5;
    vec3 coneBase = vec3(0.35, 0.4, 1.64 * heightFactor);
    vec3 coneBase2 = vec3(0.4, 0.3, 2.5 * heightFactor);


    // your magical distance function
    float cone1 = cone(vec3(ray.x, ray.y - coneBase.z , ray.z), coneBase);
    float cone2 = cone(vec3(ray.x, -ray.y - coneBase2.z, ray.z), coneBase2);
    return max(ray.y - coneBase.z * 0.3, min(cone1, cone2));
    

}


    vec2 rotate(vec2 v, float a) {
      float s = sin(a);
      float c = cos(a);
      mat2 m = mat2(c, -s, s, c);
      return m * v;
    }    

float sdf(vec3 pos) {
    
    //return box_sdf(vec3(0.0), vec3(1.0, 1.0, 1.0), pos);
    
    return gem_sdf(pos);
}

vec3 roundNormal(vec3 n, float tf, float pf) {
    //return floor(n * 5.0) / 5.0;
    
     //float phi = asin(n.y) / 3.14159 + 0.5;
    float phi = asin(n.y);
    float theta = atan(n.z, n.x) / 3.14159 + 0.5;

    theta = ((floor(theta * tf + 0.5) / tf) - 0.5) * 3.14159;
    //phi = ((floor(phi * pf + 0.5) / pf) - 0.5) * 3.14159;

    return vec3(cos(theta) * cos(phi), sin(phi), sin(theta) * cos(phi));
}

vec3 normal_sdf(vec3 pos) {

  const vec3 v1 = vec3( 1.0,-1.0,-1.0);
  const vec3 v2 = vec3(-1.0,-1.0, 1.0);
  const vec3 v3 = vec3(-1.0, 1.0,-1.0);
  const vec3 v4 = vec3( 1.0, 1.0, 1.0);
    
  const float eps = 0.02;

  return normalize( v1 * sdf( pos + v1*eps ) +
                    v2 * sdf( pos + v2*eps ) +
                    v3 * sdf( pos + v3*eps ) +
                    v4 * sdf( pos + v4*eps ) );

}
 
 
    vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
    {

      vec2 uv = texture_coords;

      uv *= 2.0;
      uv -= vec2(1.0, 1.0);
      uv.y *= -1.0;

      vec3 ray = normalize(vec3(uv, 1.0));
      
      float dist = 0.0;
      
      const int maxSteps = 40;
      int currentStep = 0;
      
      vec3 pos;
      float currentDistance;
      
      int hit = 0;
      
      float t = time;
      
      vec3 spos = vec3(sin(t), 0.0, -cos(t)) * 4.0;
      ray.xz = rotate(ray.xz, -t);
      

      while(currentStep < maxSteps)
      {
          pos = ray * dist + spos;
          currentDistance = sdf(pos);
          
          dist += max(0.0, currentDistance);
          
          hit += int(currentDistance < 0.01);
          ++currentStep;
      }
      
      vec3 light =  normalize(vec3(sin(t- 1.5), 0.0, -cos(t - 1.5)) * 4.0 + vec3(0.0, 10.0, 0.0));
    
      vec3 normal = roundNormal(normal_sdf(pos), 8.0 , 6.0);
      float diffuse = (dot(normal, light) * 0.5 + 0.5);
              
      vec3 eye = -normalize(spos - pos);

      float specular = pow(max(0.0, dot(reflect(eye, normal), light)), 3.0) * 1.0;

      
      return vec4(vec3(1.0,0.1,0.0) * diffuse + vec3(0.9, 0.9, 0.9) * specular, 1.0) * float(hit > 0.0);
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