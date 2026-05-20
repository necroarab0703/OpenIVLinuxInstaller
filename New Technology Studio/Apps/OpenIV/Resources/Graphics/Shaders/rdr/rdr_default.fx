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
texture TextureSampler;
texture gBoneMtxTexture;

row_major float4x4 identityMatrix = float4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);


// Samplers:
sampler DiffuseSampler = sampler_state
{
	Texture = < TextureSampler > ;
	MipFilter = LINEAR;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
};

sampler gBoneMtxSampler = sampler_state
{
	Texture = < gBoneMtxTexture > ;
	AddressU = WRAP;
	AddressV = WRAP;
	MinFilter = POINT;
	MagFilter = POINT;
};

// Vertex shader input structures
struct VS_INPUT
{
	float3 vPos       : POSITION;
	float4 vColor     : COLOR0;
	float2 vTexCoord0 : TEXCOORD0;
	float3 vNormal    : NORMAL;
};

struct VS_INPUT_SKINNED
{
	float3 vPos         : POSITION;
	float4 BlendWeights : BLENDWEIGHT;
	float4 BlendIndices : BLENDINDICES;
	float2 vTexCoord0   : TEXCOORD0;
	float3 vNormal      : NORMAL;
	float4 vColor       : COLOR0;
};

// Vertex shader output structure
struct VS_OUTPUT
{
	float4 Position  : POSITION;  // vertex position
	float2 TextureUV : TEXCOORD0; // vertex texture coords 
	float3 Data1 	 : TEXCOORD1;
	float4 Diffuse   : COLOR0;    // vertex diffuse color (note that COLOR0 is clamped from 0..1)		
};

#include "rdr\texturevertexskinning.fxh"

// This shader computes standard transform and lighting
VS_OUTPUT VSBasic(VS_INPUT i)
{
	VS_OUTPUT Output;

	// Transform the normal from object space to world space    
	float3 vNormalWorldSpace = normalize(mul(i.vNormal, (float3x3)gWorld)); // normal (world space)

		// Transform the position from object space to homogeneous projection space
		Output.Position = mul(float4(i.vPos, 1.0), gWorldViewProj);

	// Save vNormalWorldSpace for pixel shader
	Output.Data1 = vNormalWorldSpace;

	// Save diffuse color for pixel shader
	Output.Diffuse = i.vColor;

	// UV animation
	float3 r0 = float3(i.vTexCoord0.xy, 1.0f);
		Output.TextureUV.x = dot(globalAnimUV0, r0);
	Output.TextureUV.y = dot(globalAnimUV1, r0);

	return Output;
}

VS_OUTPUT VSSkinned(VS_INPUT_SKINNED In)
{
	VS_OUTPUT Out;

	//float4x3 vWorldPos = gBoneMtx[In.BlendIndices.x  * 255.0] * In.BlendWeights.x;
	//vWorldPos += gBoneMtx[In.BlendIndices.y  * 255.0] * In.BlendWeights.y;
	//vWorldPos += gBoneMtx[In.BlendIndices.z  * 255.0] * In.BlendWeights.z;
	//vWorldPos += gBoneMtx[In.BlendIndices.w  * 255.0] * In.BlendWeights.w;

	float4x3 vWorldPos;
	if (0.996070802 < In.BlendIndices.z) {
		//if (0.5 < In.BlendIndices.x) {
		vWorldPos = (float4x3)gWorld;
		Out.Diffuse = float4(0.95, 0, 0, 1.0);
	} else {
		vWorldPos = ComputeSkinMtx(In.BlendIndices, In.BlendWeights);
		Out.Diffuse = float4(1.0, 1.0, 1.0, 1.0);//In.vColor;
	}


	float4 pos;
	pos.xyz = mul((float4(In.vPos, 1.0) * float4(1, 1, 1, 0) + float4(0, 0, 0, 1)), vWorldPos);
	pos.w = 1.0;
	Out.Position = mul(pos, gWorldViewProj);

	// Transform the normal from object space to world space    
	float3 vNormalWorldSpace = normalize(mul(In.vNormal, (float3x3)vWorldPos)); // normal (world space)

	// Save vNormalWorldSpace for pixel shader
	Out.Data1 = vNormalWorldSpace;

	// Save diffuse color for pixel shader
	//Out.Diffuse = In.vColor;

	// UV animation
	float3 r0 = float3(In.vTexCoord0.xy, 1.0f);
		Out.TextureUV.x = dot(globalAnimUV0, r0);
	Out.TextureUV.y = dot(globalAnimUV1, r0);

	return Out;
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

	// Compute simple directional lighting equation
	float3 vTotalLightDiffuse = float3(0, 0, 0);
	vTotalLightDiffuse += gLightDiffuse[0] * max(0, dot(In.Data1, gLightDir[0]));
	vTotalLightDiffuse += gLightDiffuse[1] * max(0, dot(In.Data1, gLightDir[1]));

	// Compute resulting diffuse color
	float4 outCol;
	if (gTextured < 0.99) {
		outCol.rgb = In.Diffuse;// * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient;
		outCol.a = 1.0f;
		Output.RGBColor = outCol;
	} else {
		outCol.rgb = float4(0.82, 0.82, 0.82, 0) * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient;
		outCol.a = 1.0f;
		Output.RGBColor = tex2D( DiffuseSampler, In.TextureUV );// * outCol;
	}

	return Output;
}

// Techniques:
technique Draw
{
	pass P0
	{
		VertexShader = compile vs_3_0 VSBasic();
		PixelShader = compile ps_3_0 PSBasic();
		AlphaBlendEnable = true;
	}
}

technique DrawSkinned
{
	pass P0
	{
		VertexShader = compile vs_3_0 VSSkinned();
		PixelShader = compile ps_3_0 PSBasic();
		AlphaBlendEnable = true;
	}
}
