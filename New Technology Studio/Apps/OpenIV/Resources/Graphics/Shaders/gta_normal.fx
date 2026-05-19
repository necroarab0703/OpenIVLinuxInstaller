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
float gTextured = 0.0; 	
float4 gMaterialAmbientColor = float4(0.35, 0.35, 0.35, 1); // Material's ambient color
float3 gLightDir[2];               							// Light's direction in world space
float4 gLightDiffuse[2];           							// Light's diffuse color
float4 gLightAmbient;              							// Light's ambient color
float bumpiness = 1.0;

// Textures:
texture TextureSampler;
texture BumpSampler;

// Samplers:
sampler DiffuseTex = sampler_state
{
    Texture = <TextureSampler>;
    AddressU = Wrap;
	AddressV = Wrap;
	AddressW = Wrap;
    MipFilter = Linear;
    MinFilter = Anisotropic;
    MagFilter = Linear;
};
sampler BumpTex = sampler_state
{
    Texture = <BumpSampler>;
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
    float4 vPos			: POSITION;
    float4 DiffuseColor	: COLOR0;
	float2 vTexCoord0 	: TEXCOORD0;
    float3 vNormal    	: NORMAL;
	float3 vTangent	  	: TANGENT0;
};

struct VS_INPUT_SKINNED
{
    float4 vPos         : POSITION;
    float4 BlendWeights : BLENDWEIGHT;
    int4 BlendIndices 	: BLENDINDICES;
	float2 vTexCoord0   : TEXCOORD0;
	float3 vNormal      : NORMAL;
    float4 vColor       : COLOR0;
};

// Vertex shader output structure
struct VS_OUTPUT
{
    float4 Position  		: POSITION;  // vertex position
    float4 Diffuse   		: COLOR0;    // vertex diffuse color (note that COLOR0 is clamped from 0..1)
	float2 vTextureUV 		: TEXCOORD0; // vertex texture coords 
	float3 vWorldNormal 	: TEXCOORD1;
	float3 vWorldBinormal	: TEXCOORD2;
	float3 vWorldTangent	: TEXCOORD3;
};

struct VS_OUTPUT_old
{
    float4 Position  : POSITION;  // vertex position
	float2 TextureUV : TEXCOORD0; // vertex texture coords 
	float3 vWorldNormal 	 : TEXCOORD1;
    float4 Diffuse   : COLOR0;    // vertex diffuse color (note that COLOR0 is clamped from 0..1)		
};

// This shader computes standard transform and lighting
VS_OUTPUT VSNormal( VS_INPUT In )
{
    VS_OUTPUT Output;
	    
	// Transform the position from object space to homogeneous projection space
	Output.Position = mul(In.vPos, gWorldViewProj );	
	// Transform the normal from object space to world space
	Output.vWorldNormal = normalize( mul( In.vNormal, (float3x3)gWorld ) );
	
	Output.vWorldBinormal = mul( cross(In.vTangent, In.vNormal), (float3x3)gWorld );
	Output.vWorldTangent = mul( In.vTangent, (float3x3)gWorld );
	
	// Texture coords
	Output.vTextureUV = In.vTexCoord0;
	// Save diffuse color for pixel shader
	Output.Diffuse = In.DiffuseColor;
	
    return Output;
}

VS_OUTPUT_old VSSkinned( VS_INPUT_SKINNED In )
{
	VS_OUTPUT_old Out;
	
    float4x3 vWorldPos = gBoneMtx[In.BlendIndices.x  * 255.0] * In.BlendWeights.x;
	vWorldPos += gBoneMtx[In.BlendIndices.y  * 255.0] * In.BlendWeights.y;
	vWorldPos += gBoneMtx[In.BlendIndices.z  * 255.0] * In.BlendWeights.z;
	vWorldPos += gBoneMtx[In.BlendIndices.w  * 255.0] * In.BlendWeights.w;
	
	float4 pos;	
	pos.xyz = mul((In.vPos * float4(1,1,1,0) + float4(0,0,0,1)), vWorldPos);
	pos.w = 1.0;
	Out.Position = mul(pos, gWorldViewProj);	
	
	// Transform the normal from object space to world space    
    float3 vNormalWorldSpace = normalize( mul( In.vNormal, (float3x3)gWorld ) ); // normal (world space)
		
	// Save vNormalWorldSpace for pixel shader
    Out.vWorldNormal = vNormalWorldSpace; 
	
	// Save diffuse color for pixel shader
	Out.Diffuse = In.vColor;
    
	// UV animation
	Out.TextureUV =  In.vTexCoord0;
	
	return Out;
}

// Pixel shader output structure
struct PS_OUTPUT
{
    float4 RGBColor : COLOR0;  // Pixel color    
};

PS_OUTPUT PSNormal(VS_OUTPUT In)
{ 
	PS_OUTPUT Output;
	
	// Compute simple directional lighting equation
    float3 vTotalLightDiffuse = float3(0, 0, 0);
	
	
    // Compute resulting diffuse color
	float4 outCol;
	if (gTextured < 0.99) {
		vTotalLightDiffuse += gLightDiffuse[0] *  max( 0, dot( In.vWorldNormal, gLightDir[0] ) );
	    vTotalLightDiffuse += gLightDiffuse[1] *  max( 0, dot( In.vWorldNormal, gLightDir[1] ) );
		outCol.rgb = In.Diffuse * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient;
		outCol.a = 1.0f;
		Output.RGBColor = outCol;
	} else {
	    float4 textureColor = tex2D( DiffuseTex, In.vTextureUV );
		float3 normal = 2.0 * tex2D(BumpTex, In.vTextureUV).xyz - 1.0;	//the normal must be expanded from 0-1 to -1 to 1
	    
		//create tangent space vectors
		float3 Nn = In.vWorldNormal;
		float3 Bn = In.vWorldBinormal;
		float3 Tn = In.vWorldTangent;
		
		float3x3 tgtSpace;
		tgtSpace[0] = Tn;
		tgtSpace[1] = Bn;
		tgtSpace[2] = Nn;

		float3 tgtLightDir1 = normalize(mul(tgtSpace, gLightDir[0]));
	    float3 tgtLightDir2 = normalize(mul(tgtSpace, gLightDir[1]));
		
		float mdiffuse = saturate(dot(tgtLightDir1, normalize(gLightDir[0]))) +
                  saturate(dot(tgtLightDir2, normalize(gLightDir[1])));
		
		//offset world space normal with normal map values
		//float3 N = (normal.z * Nn) + (normal.x * Bn) + (normal.y * -Tn);				//we use the values of the normal map to tweek surface normal, tangent, and binormal
		//N = normalize(N);																//normalizing the result gives us the new surface normal
		
		//float3 L = normalize(gLightDir[0]);
		
		//vTotalLightDiffuse += gLightDiffuse[0] *  max( 0, dot( N, gLightDir[0] ) );
	    //vTotalLightDiffuse += gLightDiffuse[1] *  max( 0, dot( N, gLightDir[1] ) );
		
		//float4 diffuselight = 2 * saturate(dot(N,L)) * gLightDiffuse[0];									//To get the diffuse light value we calculate the dot product between the light vector and the normal								
        //float4 Diffuse = float4(0.82, 0.82, 0.82, 1) * textureColor * diffuselight;
		
		//ambient light
        //float4 Ambient = gMaterialAmbientColor * textureColor;
		 
		//Output.RGBColor = Diffuse + Ambient ;
		
		Output.RGBColor = textureColor * mdiffuse;
		
		
		//Output.RGBColor.xyz = N;
		Output.RGBColor.a = 1.0;
		//outCol.rgb = float4(0.82, 0.82, 0.82, 0) * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient; 
		//outCol.a = 1.0f;
		//Output.RGBColor = textureColor * outCol; 
	}
	
	return Output;
}


PS_OUTPUT PSBasic(VS_OUTPUT_old In)
{ 
	PS_OUTPUT Output;
	
	// Compute simple directional lighting equation
    float3 vTotalLightDiffuse = float3(0, 0, 0);
	vTotalLightDiffuse += gLightDiffuse[0] *  max( 0, dot( In.vWorldNormal, gLightDir[0] ) );
	vTotalLightDiffuse += gLightDiffuse[1] *  max( 0, dot( In.vWorldNormal, gLightDir[1] ) );
	
    // Compute resulting diffuse color
	float4 outCol;
	if (gTextured < 0.99) {
		outCol.rgb = In.Diffuse * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient;
		outCol.a = 1.0f;
		Output.RGBColor = outCol;
	} else {
		outCol.rgb = float4(0.82, 0.82, 0.82, 0) * vTotalLightDiffuse + gMaterialAmbientColor * gLightAmbient; 
		outCol.a = 1.0f;
		Output.RGBColor = tex2D( DiffuseTex, In.TextureUV ) * outCol; 
	}
	
	return Output;
}

// Techniques:
technique Draw
{
    pass P0
    {   
        VertexShader = compile vs_3_0 VSNormal();
        PixelShader  = compile ps_3_0 PSNormal(); 
		AlphaBlendEnable = true;
    }
}

technique DrawSkinned
{
    pass P0
    {   
        VertexShader = compile vs_3_0 VSSkinned();
        PixelShader  = compile ps_3_0 PSBasic(); 
		AlphaBlendEnable = true;
    }
}