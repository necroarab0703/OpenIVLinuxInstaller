//{*******************************************************}
//{                                                       }
//{             .black - RAGE research project            }
//{                 Copyright(c) 2008-2017                }
//{                                                       }
//{                                                       }
//{   If you have any suggestions how improve this code   }
//{   please contact us on our web site                   }
//{                                  http://openiv.com/   }
//{                                                       }
//{*******************************************************}


// Parameters:
row_major float4x4 gWorldViewProj;                          // World * View * Projection 
float gTextured = 0.0; 	
texture TextureSampler;              						// Diffuse texture
float gAlpha = 1.0;

// Samplers:
sampler DiffuseSampler = sampler_state
{
    Texture = <TextureSampler>;
	AddressU = Wrap;
	AddressV = Wrap;
	AddressW = Wrap;
    MipFilter = Anisotropic;
    MinFilter = Anisotropic;
    MagFilter = LINEAR;
};

// Vertex shader input structures
struct VS_INPUT
{
    float4 vPos       : POSITION;
    float4 vColor     : COLOR0;
	float2 vTexCoord0 : TEXCOORD0;
};

// Vertex shader output structure
struct VS_OUTPUT
{
    float4 Position  : POSITION;  // vertex position
	float2 TextureUV : TEXCOORD0; // vertex texture coords 
    float4 Diffuse   : COLOR0;    // vertex diffuse color (note that COLOR0 is clamped from 0..1)		
};

// This shader computes standard transform and lighting
VS_OUTPUT VSBasic( VS_INPUT i )
{
    VS_OUTPUT Output;	
	// Transform the position from object space to homogeneous projection space
	Output.Position = mul(i.vPos, gWorldViewProj );
	Output.TextureUV = i.vTexCoord0;	
	// Save diffuse color for pixel shader
	Output.Diffuse = i.vColor;
    return Output;
}

// Pixel shader output structure
struct PS_OUTPUT
{
    float4 RGBColor : COLOR0;  // Pixel color    
};

// This shader outputs the pixel's color by modulating 
// the texture's color with diffuse material color
PS_OUTPUT PSBasic(VS_OUTPUT In)
{ 
	PS_OUTPUT Output;
	
    // Compute resulting diffuse color
	if (gTextured < 0.99) {
		Output.RGBColor = In.Diffuse;
	} else {		
		Output.RGBColor = tex2D( DiffuseSampler, In.TextureUV ); 
	}	
	Output.RGBColor.a *= gAlpha;
	return Output;
}

PS_OUTPUT PSAlpha(VS_OUTPUT In)
{ 
	PS_OUTPUT Output;
	
    // Compute resulting diffuse color
	Output.RGBColor = In.Diffuse;
	Output.RGBColor.a *= gAlpha;
	
	return Output;
}

// Techniques:
technique drawMap
{
    pass P0
    {   
        VertexShader = compile vs_3_0 VSBasic();
        PixelShader  = compile ps_3_0 PSBasic(); 
		AlphaBlendEnable = true;
    }
}

technique Draw
{
    pass P0
    {
        VertexShader = compile vs_3_0 VSBasic();
        PixelShader  = compile ps_3_0 PSAlpha();
		AlphaBlendEnable = true;
    }
}