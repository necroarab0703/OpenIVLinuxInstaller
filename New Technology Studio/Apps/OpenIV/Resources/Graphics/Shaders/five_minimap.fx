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
float4x3 gBoneMtx[48];
row_major float4x4 gWorld;                  				// World matrix for object
row_major float4x4 gWorldViewProj;                          // World * View * Projection 
float3 globalAnimUV0;										// UV0
float3 globalAnimUV1;										// UV1
float gTextured = 0.0; 	
float4 gMaterialAmbientColor = float4(0.35, 0.35, 0.35, 0); // Material's ambient color
float3 gLightDir[2];               							// Light's direction in world space
float4 gLightDiffuse[2];           							// Light's diffuse color
float4 gLightAmbient;              							// Light's ambient color
texture TextureSampler;              						// Diffuse texture

// Samplers:
sampler DiffuseSampler = sampler_state
{
    Texture = <TextureSampler>;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

// Vertex shader input structures
struct VS_INPUT
{
    float3 vPos       : POSITION;
    float4 vColor     : COLOR0;
};

// Vertex shader output structure
struct VS_OUTPUT
{
    float4 Position  : POSITION;  // vertex position
    float4 Diffuse   : COLOR0;    // vertex diffuse color (note that COLOR0 is clamped from 0..1)		
};

// This shader computes standard transform and lighting
VS_OUTPUT VSBasic( VS_INPUT i )
{
    VS_OUTPUT Output;
	
	// Transform the position from object space to homogeneous projection space
	Output.Position = mul( float4(i.vPos, 1.0), gWorldViewProj );
	
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
	float4 outCol;

	outCol.rgb = In.Diffuse;
	outCol.a = 1.0f;
	Output.RGBColor = outCol;

	return Output;
}

// Techniques:
technique Draw
{
    pass P0
    {   
        VertexShader = compile vs_3_0 VSBasic();
        PixelShader  = compile ps_3_0 PSBasic(); 
		AlphaBlendEnable = true;
    }
}
