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
row_major float4x4 gWorldViewProj;
row_major float4x4 gWorld;
float3 gColor = float3(0, 0, 0);
float gScale = 0.25f;
float gZOffset = 1.0f;

// Vertex shader input structure
struct VS_INPUT
{
	float3 vPos : POSITION;
};

struct VS_INPUT_SKINNED
{
	float3 vPos         : POSITION;
	float4 BlendWeights : BLENDWEIGHT;
	float4 BlendIndices 	: BLENDINDICES;
};

// Vertex shader output structure
struct VS_OUTPUT
{
	float4 vPos : POSITION;
	float Size : PSIZE;
};

#include "vertexskinning.fxh"

// Vertex shader
VS_OUTPUT VShader(VS_INPUT In)
{
	VS_OUTPUT Output;

	// Transform the position from object space to homogeneous projection space
	Output.vPos = mul(float4(In.vPos, 1.0), gWorldViewProj);

	if (gZOffset > 0.99) {
		Output.vPos.z -= 1.0e-3;
	}
	Output.Size = 3.0f;

	return Output;
}

VS_OUTPUT VShaderSkinned(VS_INPUT_SKINNED In)
{
	VS_OUTPUT Output;

	//float4x3 vWorldPos = gBoneMtx[In.BlendIndices.x  * 255.0] * In.BlendWeights.x;
	//vWorldPos += gBoneMtx[In.BlendIndices.y  * 255.0] * In.BlendWeights.y;
	//vWorldPos += gBoneMtx[In.BlendIndices.z  * 255.0] * In.BlendWeights.z;
	//vWorldPos += gBoneMtx[In.BlendIndices.w  * 255.0] * In.BlendWeights.w;

	float4x3 vWorldPos;
	if (0.996070802 < In.BlendIndices.x) {
		//if (0.5 < In.BlendIndices.x) {
		vWorldPos = (float4x3)gWorld;
	} else {
		vWorldPos = ComputeSkinMtx(In.BlendIndices, In.BlendWeights);
	}


	float4 pos;
	pos.xyz = mul((float4(In.vPos, 1.0) * float4(1, 1, 1, 0) + float4(0, 0, 0, 1)), vWorldPos);
	pos.w = 1.0;
	Output.vPos = mul(pos, gWorldViewProj);

	if (gZOffset > 0.99) {
		Output.vPos.z -= 1.0e-3;
	}
	Output.Size = 3.0f;

	return Output;
}

VS_OUTPUT VSInstance(float4 vPos : POSITION,
	float3 vNormal : NORMAL,
	float4 vColor : COLOR0,
	float4 vInstanceMatrix1 : TEXCOORD1,
	float4 vInstanceMatrix2 : TEXCOORD2,
	float4 vInstanceMatrix3 : TEXCOORD3,
	float4 vColor1 : COLOR1)
{
	VS_OUTPUT Output;

	float4 row1 = float4(vInstanceMatrix1.x, vInstanceMatrix2.x, vInstanceMatrix3.x, 0);
		float4 row2 = float4(vInstanceMatrix1.y, vInstanceMatrix2.y, vInstanceMatrix3.y, 0);
		float4 row3 = float4(vInstanceMatrix1.z, vInstanceMatrix2.z, vInstanceMatrix3.z, 0);
		float4 row4 = float4(vInstanceMatrix1.w, vInstanceMatrix2.w, vInstanceMatrix3.w, 1);
		row_major float4x4 mInstanceMatrix = float4x4(row1, row2, row3, row4);

	float4 worldPosition = mul(vPos, mInstanceMatrix);
		worldPosition = mul(worldPosition, gWorld);
	Output.vPos = mul(worldPosition, gWorldViewProj);

	if (gZOffset > 0.99) {
		Output.vPos.z -= 1.0e-3;
	}
	Output.Size = 3.0f;

	return Output;
}

// Pixel shader output structure
struct PS_OUTPUT
{
	float4 Color : COLOR0;  // Pixel color    
};

// Trivial pixel shader
PS_OUTPUT PShader()
{
	PS_OUTPUT output;
	output.Color = float4(gColor, 1.0f);
	return output;
}

// Techniques:
technique Draw
{
	pass P0
	{
		CullMode = None;
		ZWriteEnable = false;
		PointScaleEnable = false;
		VertexShader = compile vs_3_0 VShader();
		PixelShader = compile ps_3_0 PShader();
	}
}

technique DrawZWrite
{
	pass P0
	{
		CullMode = None;
		ZWriteEnable = true;
		PointScaleEnable = false;
		VertexShader = compile vs_3_0 VShader();
		PixelShader = compile ps_3_0 PShader();
	}
}

technique DrawSkinned
{
	pass P0
	{
		CullMode = None;
		ZWriteEnable = false;
		PointScaleEnable = false;
		VertexShader = compile vs_3_0 VShaderSkinned();
		PixelShader = compile ps_3_0 PShader();
		AlphaBlendEnable = true;
	}
}

technique InstanceDraw
{
	pass P0
	{
		CullMode = None;
		ZWriteEnable = false;
		PointScaleEnable = false;
		VertexShader = compile vs_3_0 VSInstance();
		PixelShader = compile ps_3_0 PShader();
	}
}