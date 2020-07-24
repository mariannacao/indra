//
//  Shaders.metal
//  Mandelbrot
//
//  Created by Andriy K. on 2/4/16.
//  Copyright © 2016 Andriy K. All rights reserved.
//

#include <metal_stdlib>
#include <metal_math>

using namespace metal;

typedef struct{
    float r;
    float im;
} com;

typedef struct{
    com a, b, c, d;
} mob;

com add(com a, com b){
    com res;
    res.r = a.r + b.r;
    res.im = a.im + b.im;
    return res;
}

com subtract(com a, com b){
    com res;
    res.r = a.r - b.r;
    res.im = a.im - b.im;
    return res;
}

com multiply(com a, com b){
    com res;
    res.r = a.r*b.r - a.im*b.im;
    res.im = a.r*b.im + a.im*b.r;
    return res;
}

com conj(com x){
    com res;
    res.r = x.r;
    res.im = -x.im;
    return res;
}

com divide(com a, com b){
    com res = multiply(a, conj(b));
    res.r /= (b.r*b.r + b.im*b.im);
    res.im /= (b.r*b.r + b.im*b.im);
    return res;
}

mob CreateMobiusXForm(com a, com b, com c, com d){
    mob m;
    m.a = a, m.b = b, m.c = c, m.d = d;
    return m;
}

com MobiusDeterminant(mob m){
    return subtract(multiply(m.a, m.d), multiply(m.b, m.c));
}

mob MobiusInverse(mob m){
    com tmp;
    tmp.r = 0, tmp.im = 0;
    return CreateMobiusXForm(m.d, subtract(tmp, m.b), subtract(tmp, m.c), m.a);
}

com MobiusPointXForm(com z, mob m){
    if(z.r == INFINITY){
        if(m.c.r == 0.0 && m.c.im == 0.0){
            com inf;
            inf.r = INFINITY;
            inf.im = INFINITY;
            return inf;
        }
        return divide(m.a, m.c);
    }
    return divide(add(multiply(z, m.a), m.b), add(multiply(z, m.c), m.d));
}

mob ComposeMobiusXForms(mob a, mob b){
    com aa = add(multiply(a.a, b.a), multiply(a.b, b.c));
    com bb = add(multiply(a.a, b.b), multiply(a.b, b.d));
    com cc = add(multiply(a.c, b.a), multiply(a.d, b.c));
    com dd = add(multiply(a.c, b.b), multiply(a.d, b.d));
    return CreateMobiusXForm(aa, bb, cc, dd);
}

mob FindMobiusXForm(com z1, com z2, com z3){
    com one, zero;
    one.r = 1, one.im = 0;
    zero.r = 0, zero.im = 0;
    
    com a, b, c, d;

    if(z1.r == INFINITY){
        a = zero;
        b = subtract(z2, z3);
        c = one;
        d = subtract(zero, z3);
    }
    else if(z2.r == INFINITY){
        a = one;
        b = subtract(zero, z1);
        c = one;
        d = subtract(zero, z3);
    }
    else if(z3.r == INFINITY){
        a = one;
        b = subtract(zero, z1);
        c = zero;
        d = subtract(z2, z1);
    }
    else{
        a = subtract(z2, z3);
        b = multiply(subtract(zero, z1), subtract(z2, z3));
        c = subtract(z2, z1);
        d = multiply(subtract(zero, z3), subtract(z2, z1));
    }
    
    mob m = CreateMobiusXForm(a, b, c, d);
    return m;
}

float check(com p, com z1, com z2, com z3){
    //return p.r >= 0 ? 1.0 : 0.0;
    
    for(int d = 0; d < 10; d++){
        mob m = FindMobiusXForm(z1, z2, z3);
        p = MobiusPointXForm(p, m);
        
        float col = float(d) + 1;
        
        if(p.r <= 0) return col;
        else if(p.r >=1) return col;
        else if(pow(pow(p.r-0.5, 2) + pow(p.im, 2), 0.5) <= 0.5) return col;
        else if(pow(pow(p.r-0.5, 2) + pow(p.im-1, 2), 0.5) <= 0.5) return col;
        else if(p.im < 0) return 0.0;
        
        if(p.im >= 1){
            z1.r = 0, z1.im = 1;
            z2.r = 1, z2.im = 1;
            z3.r = INFINITY, z3.im = INFINITY;
        }
        else if(p.r <= 0.5){
            z1.r = 0, z1.im = 1;
            z2.r = 0, z2.im = 0;
            z3.r = 0.5, z3.im = 0.5;
        }
        else{
            z1.r = 1, z1.im = 1;
            z2.r = 0.5, z2.im = 0.5;
            z3.r = 1, z3.im = 0;
        }
    }
    return 0.0;
}

// Vertex data recieved in vertex shader
struct Vertex {
  float3 position [[attribute(0)]];
};

// Vertex data sent from vertex shader to fragment shader (interpolated)
struct VertexOut {
    float4 position [[position]];
    float2 coords;
};

// Constants
struct Uniforms {
    float scale;
    float xTranslate;
    float yTranslate;
    float maxIterations;
    float aspectRatio;
    float z1r, z1im, z2r, z2im, z3r, z3im;
};

// ================
// Vertex shader
vertex VertexOut vertexShader(const    Vertex    vertexIn      [[stage_in]],
                              constant Uniforms &uniformBuffer [[buffer(1)]],
                              unsigned int       vid           [[vertex_id]])
{
  VertexOut vertexOut;
  vertexOut.position = float4(vertexIn.position,1);
  float scale = uniformBuffer.scale;
  vertexOut.coords.x = (vertexIn.position.x * uniformBuffer.aspectRatio) * scale - uniformBuffer.xTranslate;
  vertexOut.coords.y = vertexIn.position.y * scale - uniformBuffer.yTranslate;
  return vertexOut;
}

// ================
// Fragment shader
fragment float4 fragmentShader(VertexOut interpolated [[stage_in]],
                               texture2d<float>  tex2D        [[texture(0)]],
                               constant Uniforms &uniformBuffer [[buffer(0)]],
                               sampler           sampler2D    [[sampler(0)]])
{
    float x = interpolated.coords.x;
    float y = interpolated.coords.y;
    
    com z1, z2, z3;
    z1.r = uniformBuffer.z1r;
    z1.im = uniformBuffer.z1im;
    z2.r = uniformBuffer.z2r;
    z2.im = uniformBuffer.z2im;
    z3.r = uniformBuffer.z3r;
    z3.im = uniformBuffer.z3im;
    //z3.r = 0.1;
    //z3.im = 0.1;
    com n;
    n.r = x, n.im = y;
    
    float nn = check(n, z1, z2, z3)/10.0;

    float2 paletCoord = float2(nn, 0);
    float4 finalColor = tex2D.sample(sampler2D, paletCoord);

    return finalColor;
}

