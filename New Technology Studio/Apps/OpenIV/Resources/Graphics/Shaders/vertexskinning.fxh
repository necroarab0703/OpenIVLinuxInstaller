
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
	skinMtx  = gBoneMtx[bone0] * weights.x;
	skinMtx += gBoneMtx[bone1] * weights.y;
	skinMtx += gBoneMtx[bone2] * weights.z;
	skinMtx += gBoneMtx[bone3] * weights.w;

	return skinMtx;
}	