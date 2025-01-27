Texture2DMS<float> depth_texture : register(t0);

float4 main(float4 position : SV_Position, out float depth : SV_Depth) : SV_Target
{    
    // we could sample over all samples to get the best depth but we don't need that level of precision for UI
    // uint2 dimensions;
    // uint sample_count;
    // depth_texture.GetDimensions(dimensions.x, dimensions.y, sample_count);
    depth = depth_texture.Load(position.xy, 0).r;
    return 0.f;
}
