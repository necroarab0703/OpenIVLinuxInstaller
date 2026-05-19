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
float4 gColor;
float4 gColor2;
float4 gWindowSize;
float4x4 gTransformMatrix;

struct PS_OUTPUT
{
    float4 Color : COLOR0;  // Pixel color    
};

// Vertex Shader
struct VERTEX_SHADER_IO
{
	float4 Position : POSITION;
	float4 Color : COLOR;
};

VERTEX_SHADER_IO VertexShaderSolid(VERTEX_SHADER_IO Input)
{
	VERTEX_SHADER_IO Output;
	Output.Position = Input.Position;
	Output.Position.w = 1.0;

	Output.Position = mul(Output.Position, gTransformMatrix);

	Output.Position.x = Output.Position.x / gWindowSize.x * 2.0f - 1.0f;
	Output.Position.y = 1.0f - Output.Position.y / gWindowSize.y * 2.0f;
	Output.Position.z = 0.0f;
	Output.Position.w = 1.0f;

	// Vertex color
	Output.Color = gColor;

	return Output;
}

VERTEX_SHADER_IO VertexShaderVerticalGradient(VERTEX_SHADER_IO Input)
{
	VERTEX_SHADER_IO Output;
	Output.Position = Input.Position;
	Output.Position.w = 1.0;

	Output.Position = mul(Output.Position, gTransformMatrix);

	Output.Position.x = Output.Position.x / gWindowSize.x * 2.0f - 1.0f;
	Output.Position.y = 1.0f - Output.Position.y / gWindowSize.y * 2.0f;
	Output.Position.z = 0.0f;
	Output.Position.w = 1.0f;

	// Vertex Color
	if (Input.Position.w > 1.0)
	{
		Output.Color = gColor2;
	}
	else
	{
		Output.Color = gColor;
	}

	return Output;
}

VERTEX_SHADER_IO VertexShaderHorizontalGradient(VERTEX_SHADER_IO Input)
{
	VERTEX_SHADER_IO Output;
	Output.Position = Input.Position;
	Output.Position.w = 1.0;

	Output.Position = mul(Output.Position, gTransformMatrix);

	Output.Position.x = Output.Position.x / gWindowSize.x * 2.0f - 1.0f;
	Output.Position.y = 1.0f - Output.Position.y / gWindowSize.y * 2.0f;
	Output.Position.z = 0.0f;
	Output.Position.w = 1.0f;

	// Vertex Color
	if (Input.Position.w == 0.0 || Input.Position.w == 2.0)
	{
		Output.Color = gColor2;
	}
	else
	{
		Output.Color = gColor;
	}

	return Output;
}


// Pixel Shader
PS_OUTPUT BasicPixelShader(VERTEX_SHADER_IO Input)
{ 
	PS_OUTPUT Output;
	Output.Color = Input.Color;
	return Output;
}

// Techniques
technique draw
{
    pass P0
    {   
		CullMode = None; 
		ZWriteEnable = false;
        PointScaleEnable = false;
		VertexShader = compile vs_3_0 VertexShaderSolid();
		PixelShader = compile ps_3_0 BasicPixelShader();
    }
}

technique drawVerticalGradient
{
	pass P0
	{
		CullMode = None;
		ZWriteEnable = false;
		PointScaleEnable = false;
		VertexShader = compile vs_3_0 VertexShaderVerticalGradient();
		PixelShader = compile ps_3_0 BasicPixelShader();
	}
}

technique drawHorizontalGradient
{
	pass P0
	{
		CullMode = None;
		ZWriteEnable = false;
		PointScaleEnable = false;
		VertexShader = compile vs_3_0 VertexShaderHorizontalGradient();
		PixelShader = compile ps_3_0 BasicPixelShader();
	}
}
