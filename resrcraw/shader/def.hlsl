struct VS_IN
{
    float3 pos : POSITION;
    float2 uv : TEXCOORD;
    float3 normal : NORMAL;
    float3 tangent : TANGENT;
};

struct VS_OUT
{
    float4 pos : SV_Position;
    float2 uv : TEXCOORD;
    float3 normal : NORMAL;
    float3 tangent : TANGENT;
    
};

VS_OUT VS_Main(VS_IN input)
{
    VS_OUT output = (VS_OUT)0;
    output.pos = float4(input.pos, 1.f);
    output.uv = input.uv;
    output.normal = input.normal;
    output.tangent = input.tangent;
    return output;
}

float4 PS_Main(VS_OUT input) : SV_Target
{
    return float4(input.uv, 0.f, 1.f);
}