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
row_major float4x4 gViewInverse;
float gTextured = 0.0;
float useTint = 0.0;  	
float4 gMaterialAmbientColor = float4(0.35, 0.35, 0.35, 0); // Material's ambient color
float3 gLightDir[2];               							// Light's direction in world space

float3 gLightDir2[2] = { {0.0f, -1.0f, 0.0f}, {0.0, 1.0, 0.0} };               							// Light's direction in world space

float4 gLightDiffuse[2];           							// Light's diffuse color
float4 gLightAmbient;              							// Light's ambient color
texture DiffuseSampler;              						// Diffuse texture
texture TintPaletteSampler;
float4 tintPaletteSelector = float4(0.0, 0.0, 0.0, 0.0);
texture BumpSampler;
texture SpecSampler;

#define MAX_LIGHTS 3


float specularFresnel : Fresnel
<
	string UIName = "Specular Fresnel";
	float UIMin = 0.0;
	float UIMax = 1.0;
	float UIStep = 0.01;
> = 0.97;

float specularFalloffMult : Specular
<
	string UIName = "Specular Falloff";
	float UIMin = 0.0;
	float UIMax = 512.0;
	float UIStep = 0.1;
> = 100.0;

float specularIntensityMult : SpecularColor
<
	string UIName = "Specular Intensity";
	float UIMin = 0.0;
	float UIMax = 1.0;
	float UIStep = 0.01;
> = 0.125;

float bumpiness : Bumpiness
<
	string UIName = "Bumpiness";
	float UIMin = 0.0;
	float UIMax = 10.0;
	float UIStep = 0.01;
> = 1.0;


// Samplers:
sampler DiffuseTextureSampler = sampler_state
{
    Texture = <DiffuseSampler>;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU  = WRAP; 
 	AddressV  = WRAP;
 	AddressW  = WRAP;
};
sampler BumpTextureSampler = sampler_state
{
    Texture = <BumpSampler>;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU  = CLAMP; 
 	AddressV  = CLAMP;
 	AddressW  = CLAMP;
};
sampler SpecTextureSampler = sampler_state
{
    Texture = <SpecSampler>;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU  = WRAP; 
 	AddressV  = WRAP;
 	AddressW  = WRAP;
};
sampler TintPaletteTextureSampler = sampler_state
{
    Texture = <TintPaletteSampler>;
    MipFilter = POINT;
    MinFilter = POINT;
    MagFilter = POINT;
    AddressU  = WRAP; 
 	AddressV  = WRAP;
 	AddressW  = WRAP;
};

// Vertex shader input structures
struct VS_INPUT
{
    float3 pos			: POSITION;
    float4 diffuse		: COLOR0;
	float2 texCoord0	: TEXCOORD0;
    float3 normal		: NORMAL;
    float4 tangent		: TANGENT0;	// w has binormal sign
};

struct VS_INPUT_SKINNED
{
	float3 pos			: POSITION;
    float4 diffuse		: COLOR0;
    float4 weight		: BLENDWEIGHT;
	float4 blendindices	: BLENDINDICES;
	float2 texCoord0	: TEXCOORD0;
    float3 normal		: NORMAL;
    float4 tangent		: TANGENT0;	// w has binormal sign
};

// Vertex shader output structure
struct VS_OUTPUT
{
    float4 pos			: POSITION;  
	float2 texCoord		: TEXCOORD0;
	float3 worldNormal	: TEXCOORD1; 
	float3 worldEyePos	: TEXCOORD3;
	float3 worldTangent	: TEXCOORD4;
	float3 worldBinormal: TEXCOORD5;
	float3 worldPos		: TEXCOORD6;
    float4 diffuse		: COLOR0;    
    float4 tintColor	: COLOR1;
};


#include "vertexskinning.fxh"

// Computes the binormal given the normal & tangent (accounts for mirroring UV's)
float3 rageComputeBinormal( float3 normal, float4 tangent )
{
	float3 OUT;
	OUT = cross((float3)tangent.xyz, normal);
	OUT *= tangent.w;	// w component contains the sign of the binormal

	return OUT;
}


// This shader computes standard transform and lighting
VS_OUTPUT VS_Transform(VS_INPUT IN)
{
    VS_OUTPUT OUT;

    float3x3 worldMtx = (float3x3)gWorld;
	    
    OUT.worldPos = mul(float4(IN.pos, 1.0), gWorld);
    OUT.worldEyePos = gViewInverse[3] - OUT.worldPos;
    OUT.worldNormal = normalize(mul(IN.normal, worldMtx) + 0.00001);
    float3 binorm = rageComputeBinormal(IN.normal, IN.tangent);
    OUT.worldTangent = normalize(mul(IN.tangent.xyz, worldMtx) + 0.00001);
    OUT.worldBinormal = normalize(mul(binorm, worldMtx) + 0.00001);
    OUT.diffuse = IN.diffuse;
    OUT.texCoord = IN.texCoord0;

    OUT.pos = mul(float4(IN.pos, 1.0), gWorldViewProj);

    float4 r0 = float4(0,0,0,0);
	r0.x = 4 * IN.diffuse.b;
	r0.x = min(r0.x, 3.99900007);
	r0.y = floor(r0.x);
	r0.x = frac(r0.x);
	r0.y = r0.y * tintPaletteSelector.y + tintPaletteSelector.x;
	r0 = tex2Dlod(TintPaletteTextureSampler, r0);
	OUT.tintColor = r0;
	
    return OUT;
}

VS_OUTPUT VS_TransformSkin(VS_INPUT_SKINNED IN)
{
	VS_OUTPUT OUT;// = (VS_OUTPUT)0;
	
	float4x3 vWorldPos = ComputeSkinMtx(IN.blendindices, IN.weight);



	float3x3 worldMtx = (float3x3)vWorldPos;
	    
    OUT.worldPos = mul(float4(IN.pos, 1.0), vWorldPos);
    OUT.worldEyePos = gViewInverse[3];// - OUT.worldPos;
    OUT.worldNormal = normalize(mul(IN.normal, worldMtx) + 0.00001);
    float3 binorm = rageComputeBinormal(IN.normal, IN.tangent);
    OUT.worldTangent = normalize(mul(IN.tangent.xyz, worldMtx) + 0.00001);
    OUT.worldBinormal = normalize(mul(binorm, worldMtx) + 0.00001);
    OUT.diffuse = IN.diffuse;
    OUT.texCoord = IN.texCoord0;

    OUT.pos = mul(float4(IN.pos, 1.0), gWorldViewProj);

    float4 r0 = float4(0,0,0,0);
	r0.x = 4 * IN.diffuse.b;
	r0.x = min(r0.x, 3.99900007);
	r0.y = floor(r0.x);
	r0.x = frac(r0.x);
	r0.y = r0.y * tintPaletteSelector.y + tintPaletteSelector.x;
	r0 = tex2Dlod(TintPaletteTextureSampler, r0);
	OUT.tintColor = r0;


	//float4x3 vWorldPos = gBoneMtx[In.BlendIndices.x  * 255.0] * In.BlendWeights.x;
	//vWorldPos += gBoneMtx[In.BlendIndices.y  * 255.0] * In.BlendWeights.y;
	//vWorldPos += gBoneMtx[In.BlendIndices.z  * 255.0] * In.BlendWeights.z;
	//vWorldPos += gBoneMtx[In.BlendIndices.w  * 255.0] * In.BlendWeights.w;

	/*float4x3 vWorldPos = ComputeSkinMtx(In.BlendIndices, In.BlendWeights);

	float4 pos;	
	pos.xyz = mul((float4(In.vPos, 1.0) * float4(1,1,1,0) + float4(0,0,0,1)), vWorldPos);
	pos.w = 1.0;
	Out.Position = mul(pos, gWorldViewProj);	
	
	// Transform the normal from object space to world space    
    float3 vNormalWorldSpace = normalize( mul( In.vNormal, (float3x3)vWorldPos ) ); // normal (world space)
		
	// Save vNormalWorldSpace for pixel shader
    Out.Data1 = vNormalWorldSpace; 
	
	// Save diffuse color for pixel shader
	Out.Diffuse = In.vColor;
    
	// UV 
	Out.TextureUV.xy = In.vTexCoord0.xy;

	float4 r0 = float4(0,0,0,0);
	r0.x = 4 * In.vColor.b;
	r0.x = min(r0.x, 3.99900007);
	r0.y = floor(r0.x);
	r0.x = frac(r0.x);
	r0.y = r0.y * tintPaletteSelector.y + tintPaletteSelector.x;
	r0 = tex2Dlod(TintPaletteTextureSampler, r0);
	Out.TintColor = r0;*/
	
	return OUT;
}	

// Pixel shader output structure
struct PS_OUTPUT
{
    float4 RGBColor : COLOR0;  // Pixel color    
};


struct rageLightOutput {
	float4 lightPosDir;				// Light position/directions
};


rageLightOutput rageComputeLightData(float3 inWorldPos, int idx)
{
	rageLightOutput OUT;

	if ( idx == 2 ) {
		OUT.lightPosDir.xyz = (float3(1403.0f, 1441.0f, 1690.0f) - inWorldPos.xyz);
		OUT.lightPosDir.w = length(OUT.lightPosDir.xyz);
		if ( OUT.lightPosDir.w != 0.0 ) {
			OUT.lightPosDir.xyz /= OUT.lightPosDir.w;
		}
	}
	else 
	{
		// We're going to negate the directional light so that the
		//	math more closely follows that of the point light
		OUT.lightPosDir.xyz = -gLightDir[idx].xyz;
		OUT.lightPosDir.w = 0.0;
	}

	return OUT;
}

// This mimics the intrinsic "lit" function, but uses less instructions (faster also??)
float4 rageGetLitFactors( float NdotL, float NdotH, float power )
{
	float4 OUT;
//	OUT = lit(NdotL, NdotH, power);
	OUT.y = max(NdotL, 0.0);
	if ( OUT.y <= 0 )
		OUT.z = 0.0;
	else
		OUT.z = pow((max(NdotH, 0.0)),power);
	OUT.xw = 1.0;
// NOTE: Had to rework to reduce instruction count (just the lit
//		command alone puts us over the top)
//    float4 OUT = lit( dot(N, L), dot(N, H), specularColor.w );
//    OUT.y *= IN.lightDistDir0.w;
//	OUT.y = min(light0.y, 1.0);

	return OUT;
}


// This shader outputs the pixel's color by modulating 
// the texture's color with diffuse material color
PS_OUTPUT PS_Textured(VS_OUTPUT IN)
{ 
	PS_OUTPUT OUT;
	//diffuse
	float4 diffuseColor = tex2D(DiffuseTextureSampler, IN.texCoord); //float4(0.5, 0.5, 0.5, 1.0);
	//bump
	float3 bumpN = (tex2D(BumpTextureSampler, IN.texCoord.xy).xyz - 0.5) * bumpiness;
    float3 N = normalize(IN.worldNormal + (bumpN.x * IN.worldTangent) + (bumpN.y * IN.worldBinormal) );
    //spec
    float3 E = normalize(IN.worldEyePos);
    float4 specularColor = tex2D(SpecTextureSampler, IN.texCoord.xy) * specularIntensityMult;

    float specStrength = specularColor.w * specularFalloffMult;

    float3 viewDir = gViewInverse[3].xyz - IN.worldEyePos;

    float4 light;
    float3 color = float3(0,0,0);
    // Compute specular color
	float3 specular = float3(0,0,0);

	[unroll]
    for (int i = 0; i < MAX_LIGHTS; ++i) {
    	rageLightOutput lightData = rageComputeLightData(viewDir, i);
	    float3 L = lightData.lightPosDir.xyz;

	    //float falloff = 1.0;


	    float falloff = 1.0 - min((lightData.lightPosDir.w / 1.0), 1.0);
		float lightIntensity = 0.8;
		if ( lightIntensity < 0.f ) {
			falloff *= -lightIntensity;		// Allow oversaturation
		}
		else {
			falloff = min(falloff * lightIntensity, 1.0);
		}


	    float3 H = normalize(L + E);

//
		float fresnel = 1.0 - dot(viewDir, H); // Caculate fresnel.
		fresnel = pow(fresnel, 5.0);
		fresnel += specularFresnel * (1.0 - fresnel);


//

	    light = rageGetLitFactors(dot(N,L), dot(N,H), specStrength);
		//specular += gLightColor[i].rgb * light.z * falloff;
		specular += float3(0.7, 0.7, 0.7) * light.z * falloff * fresnel;

		// Sum up color contribution of light sources
		//color += gLightColor[i].rgb * light.y * falloff;
		color += float3(0.7, 0.7, 0.7) * light.y * falloff * fresnel;
    }

    color += float4(0.5, 0.5, 0.5, 0.0);//gLightAmbient.xyz

    specular *= specularColor.xyz;

    float4 outColor = diffuseColor;
    outColor *= float4(IN.tintColor.xyz, 1.0);

	outColor *= float4(color, 1.0);

	// Add in specular
    outColor += float4(specular,0.);

    OUT.RGBColor = outColor;
    //OUT.RGBColor = float4(N, 1.0);

    return OUT;
/*
	// Compute simple directional lighting equation
    float3 vTotalLightDiffuse = float3(0, 0, 0);
	vTotalLightDiffuse += gLightDiffuse[0] *  max( 0, dot( In.Data1, gLightDir[0] ) );
	vTotalLightDiffuse += gLightDiffuse[1] *  max( 0, dot( In.Data1, gLightDir[1] ) );
	
    // Compute resulting diffuse color
	float4 outCol;
	if (gTextured < 0.99) {
		outCol.rgb = In.Diffuse * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient;
		outCol.a = 1.0f;
		Output.RGBColor = outCol;
	} else {
		outCol.rgb = float4(0.82, 0.82, 0.82, 0) * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient; 
		outCol.a = 1.0f;

		if (useTint < 0.99 ) {
			Output.RGBColor = tex2D( DiffuseTextureSampler, In.TextureUV ) * outCol; 
		} else {
			Output.RGBColor = tex2D( DiffuseTextureSampler, In.TextureUV ) * outCol * float4(In.TintColor.rgb, 1.0);
		}
	}
	
	return Output;*/
}

// Techniques:
technique Draw
{
    pass P0
    {   
        VertexShader = compile vs_3_0 VS_Transform();
        PixelShader  = compile ps_3_0 PS_Textured(); 
		AlphaBlendEnable = true;
    }
}

technique DrawSkinned
{
    pass P0
    {   
        VertexShader = compile vs_3_0 VS_TransformSkin();
        PixelShader  = compile ps_3_0 PS_Textured(); 
		AlphaBlendEnable = true;
    }
}