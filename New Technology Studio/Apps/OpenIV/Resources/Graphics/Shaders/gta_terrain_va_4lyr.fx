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
row_major float4x4 gWorld;                  				// World matrix for object
row_major float4x4 gWorldViewProj;                          // World * View * Projection 
float gTextured = 0.0; 	
float4 gMaterialAmbientColor = float4(0.35, 0.35, 0.35, 0); // Material's ambient color
float3 gLightDir[2];               							// Light's direction in world space
float4 gLightDiffuse[2];           							// Light's diffuse color
float4 gLightAmbient;              							// Light's ambient color

// Textures:
texture TextureSampler_layer0;              		
texture TextureSampler_layer1;    
texture TextureSampler_layer2;    
texture TextureSampler_layer3;

// Samplers:
sampler TextureSampler_lyr0 = sampler_state
{
    Texture = <TextureSampler_layer0>;
	AddressU = Wrap;
	AddressV = Wrap;
	AddressW = Wrap;
    MipFilter = Linear;
    MinFilter = Anisotropic;
    MagFilter = Linear;
};
sampler TextureSampler_lyr1 = sampler_state
{
    Texture = <TextureSampler_layer1>;
    AddressU = Wrap;
	AddressV = Wrap;
	AddressW = Wrap;
    MipFilter = Linear;
    MinFilter = Anisotropic;
    MagFilter = Linear;
};
sampler TextureSampler_lyr2 = sampler_state
{
    Texture = <TextureSampler_layer2>;
    AddressU = Wrap;
	AddressV = Wrap;
	AddressW = Wrap;
    MipFilter = Linear;
    MinFilter = Anisotropic;
    MagFilter = Linear;
};
sampler TextureSampler_lyr3 = sampler_state
{
    Texture = <TextureSampler_layer3>;
    AddressU = Wrap;
	AddressV = Wrap;
	AddressW = Wrap;
    MipFilter = Linear;
    MinFilter = Anisotropic;
    MagFilter = Linear;
};

// Vertex shader input structures
struct VS_INPUT
{
    float4 vPos       : POSITION;
	float3 vNormal    : NORMAL;
    float4 vColor     : COLOR0;
	float2 vTexCoord0 : TEXCOORD0;
	float2 vTexCoord1 : TEXCOORD1;
	float2 vTexCoord2 : TEXCOORD2;
	float2 vTexCoord3 : TEXCOORD3;
	float2 vTexCoord4 : TEXCOORD4;
    float2 vTexCoord5 : TEXCOORD5;
};

// Vertex shader output structure
struct VS_OUTPUT
{
    float4 vPos   		: POSITION;  // vertex position
	float2 vTextureUV0 	: TEXCOORD0; // vertex texture coords 
	float2 vTextureUV1 	: TEXCOORD1;
	float2 vTextureUV2 	: TEXCOORD2;
	float2 vTextureUV3 	: TEXCOORD3;
	float3 vWorldNormal	: TEXCOORD6;
    float4 DiffuseColor : COLOR0;    // vertex diffuse color 		
	float4 Mask			: COLOR1;
};

// This shader computes standard transform and lighting
VS_OUTPUT VSBasic( VS_INPUT In )
{
    VS_OUTPUT Output;
	
	// Transform the position from object space to homogeneous projection space
	Output.vPos = mul(In.vPos, gWorldViewProj );	
	// Transform the normal from object space to world space    
    Output.vWorldNormal = normalize(0.00001 + mul( In.vNormal, (float3x3)gWorld ) ); // normal (world space)
	// Texture coords for each layer
	Output.vTextureUV0 = In.vTexCoord0;
	Output.vTextureUV1 = In.vTexCoord1;
	Output.vTextureUV2 = In.vTexCoord2;
	Output.vTextureUV3 = In.vTexCoord3;	
	// Save diffuse color for pixel shader
	Output.DiffuseColor = In.vColor;
	// Layers mask
	Output.Mask.xy = In.vTexCoord4;
	Output.Mask.zw = In.vTexCoord5;
	
    return Output;
}

// Pixel shader output structure
struct PS_OUTPUT
{
    float4 RGBColor : COLOR0;  // Pixel color    
};

PS_OUTPUT PSBasic(VS_OUTPUT In)
{ 
	PS_OUTPUT Output;
	
	// Compute simple directional lighting equation
    float3 vTotalLightDiffuse = float3(0, 0, 0);
	vTotalLightDiffuse += gLightDiffuse[0] *  max( 0, dot( In.vWorldNormal, gLightDir[0] ) );
	vTotalLightDiffuse += gLightDiffuse[1] *  max( 0, dot( In.vWorldNormal, gLightDir[1] ) );
	
    // Compute resulting diffuse color
	float4 outCol;
	if (gTextured < 0.99) {
		outCol.rgb = In.DiffuseColor * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient;
		outCol.a = 1.0f;
		Output.RGBColor = outCol;
	} else {
		outCol.rgb = float4(0.82, 0.82, 0.82, 0) * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient; 
		outCol.a = 1.0f;
		
		float4 texCol0 = tex2D(TextureSampler_lyr0, In.vTextureUV0);
	    float4 texCol1 = tex2D(TextureSampler_lyr1, In.vTextureUV1);
	    float4 texCol2 = tex2D(TextureSampler_lyr2, In.vTextureUV2);
		float4 texCol3 = tex2D(TextureSampler_lyr3, In.vTextureUV3);
		
		float4 r0 = texCol0;
		float4 r1 = texCol1;
		r0.w = r1.w * In.Mask.y;
		float4 r2;
		r2.xyz = lerp(r0, r1, r0.w); 
		r0 = texCol2;
		r0.w *= In.Mask.z;
		r1.xyz = lerp(r2, r0, r0.w); 		
		r0 = texCol3;
		r0.w *= In.Mask.w;
		r2.xyz = lerp(r1, r0, r0.w);
		
		Output.RGBColor.xyz = r2 * outCol;
		Output.RGBColor.w = 1.0;
	}
	
	return Output;
}

// Techniques:
technique Draw
{
    pass P0
    {   
        VertexShader = compile vs_3_0 VSBasic();
        PixelShader  = compile ps_3_0 PSBasic(); 
    }
}