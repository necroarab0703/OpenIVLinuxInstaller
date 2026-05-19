
float4x3 ReadMatrixFromTexture(int boneIndex) 
{
	float4x3 result;// = (float4x3)0;

	float u = (boneIndex * 3) / 1024.0f + 0.5 / 1024.0f;
	float pixel = 1 / 1024.0f;
	float4 texCoord = float4(u, 0.5, 0, 0);
	float4 row0 = tex2Dlod(gBoneMtxSampler, texCoord); texCoord.x += pixel;
	float4 row1 = tex2Dlod(gBoneMtxSampler, texCoord); texCoord.x += pixel;
	float4 row2 = tex2Dlod(gBoneMtxSampler, texCoord);

	result._11_21_31_41 = row0;
	result._12_22_32_42 = row1;
	result._13_23_33_43 = row2;
/*
	float u = (boneIndex * 3) / 1024.0f + 0.5 / 1024.0f;
	float pixel = 1 / 1024.0f;
	float4 texCoord = float4(u, 0, 0, 0);
float4 row0 = tex2Dlod(tex, texCoord); texCoord.x += pixel;
float4 row1 = tex2Dlod(tex, texCoord); texCoord.x += pixel;
float4 row2 = tex2Dlod(tex, texCoord);
 как-то так может
*/

	return result;
}

float4x3 ComputeSkinMtx(float4 indicies, float4 weightsIN)
{
	float4 weights = weightsIN;//*0.0000000000001;

	float4x3 skinMtx=0;
	int4 i = D3DCOLORtoUBYTE4(indicies);		

	int bone0 = i.z;
	int bone1 = i.y;
	int bone2 = i.x;
	int bone3 = i.w;

	
	// Use this to get the posed mtx for use by verts & normals
	skinMtx  = ReadMatrixFromTexture(bone0) * weights.x;
	skinMtx += ReadMatrixFromTexture(bone1) * weights.y;
	skinMtx += ReadMatrixFromTexture(bone2) * weights.z;
	skinMtx += ReadMatrixFromTexture(bone3) * weights.w;

	return skinMtx;
}	