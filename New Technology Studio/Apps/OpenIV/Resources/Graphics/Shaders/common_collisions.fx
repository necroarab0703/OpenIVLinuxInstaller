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
float4x4 gWorld;                  								// World matrix for object
//float4x4 gView;													// View matrix
//float4x4 gProj;													// Projection matrix
float4x4 gWorldViewProj;    									// World * View * Projection 
float4 gMaterialAmbientColor = float4(0.35, 0.35, 0.35, 0);     // Material's ambient color
float3 gLightDir[2];               								// Light's direction in world space
float4 gLightDiffuse[2];           								// Light's diffuse color
float4 gLightAmbient;              								// Light's ambient color

// Vertex shader output structure
struct VS_OUTPUT
{
    float4 Position   : POSITION;   // vertex position 
    float4 Diffuse    : COLOR0;     // vertex diffuse color (note that COLOR0 is clamped from 0..1)	
    float2 TextureUV  : TEXCOORD0;  // vertex texture coords 
	float3 Data1 	  : TEXCOORD1;
};

// This shader computes standard transform and lighting
VS_OUTPUT VSBasic( float4 vPos : POSITION,
						 float4 vColor : COLOR0,
                         float3 vNormal : NORMAL,
                         float2 vTexCoord0 : TEXCOORD0)
{
       VS_OUTPUT Output;
    
	// Calculate resulting matrix
//	float4x4 gWorldViewProj;
//	gWorldViewProj = mul(mul( gWorld, gView ), gProj); 
	// Transform the position from object space to homogeneous projection space
    Output.Position = mul(vPos, gWorldViewProj);
	// Transform the normal from object space to world space    
    float3 vNormalWorldSpace = normalize( mul( vNormal, (float3x3)gWorld ) ); // normal (world space)
    // Save vNormalWorldSpace for pixel shader
    Output.Data1 = vNormalWorldSpace; 
	// Save diffuse color for pixel shader
	Output.Diffuse = vColor;
    // Just copy the texture coordinate through
    Output.TextureUV = vTexCoord0; 
   
    return Output;
}

// Pixel shader output structure
struct PS_OUTPUT
{
    float4 RGBColor : COLOR0;  // Pixel color    
};

// This shader outputs the pixel's color 
PS_OUTPUT PSBasic( VS_OUTPUT In) 
{
	PS_OUTPUT Output;
	
	// Compute simple directional lighting equation
    float vTotalLightDiffuse = float3(0, 0, 0);
	vTotalLightDiffuse += gLightDiffuse[0] *  max( 0, dot( In.Data1, gLightDir[0] ) );
	vTotalLightDiffuse += gLightDiffuse[1] *  max( 0, dot( In.Data1, gLightDir[1] ) );
    // Compute resulting diffuse color
	float4 outCol;
	outCol.rgb = In.Diffuse * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient;
	outCol.a = 1.0f;
	//Output.RGBColor = In.Diffuse * 0.5 + outCol * 0.5;
	Output.RGBColor = outCol;
	
    return Output;
}

// Techniques:
technique Draw
{
    pass P0
    {   
        VertexShader = compile vs_2_0 VSBasic();
        PixelShader  = compile ps_2_0 PSBasic();
    }
}
