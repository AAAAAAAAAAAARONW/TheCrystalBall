Shader "WaterShader02"
{
    Properties
    {
        _Tint("Tint", Color) = (1, 1, 1, .5)
        _MainTex("Main Texture", 2D) = "white" {}
        _MainDistortionFactor("Main Distortion Factor", Range(0, 10)) = 1
        _Amount("Wave Amount", Range(0, 1)) = 0.5
        _Height("Wave Height", Range(0, 1)) = 0.5
        _Speed("Wave Speed", Range(0, 1)) = 0.5
        _FoamThickness("Foam Thickness", Range(0, 10)) = 0.5
        _DistortionMap("Distortion Tex", 2D) = "grey"
        _BumpMap("Normal Map", 2D) = "white"

       // _EdgeColor("Edge Color", Color) = (1, 1, 1, .5)
    }

        SubShader
        {
            Tags { "RenderType" = "Opaque" "Queue" = "Transparent" }
            LOD 100
            Blend SrcAlpha OneMinusSrcAlpha
            Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #include "UnityCG.cginc"

                float4 _Tint, _EdgeColor;
                float _Speed, _Amount, _Height, _FoamThickness, _MainDistortionFactor;
                sampler2D _DistortionMap, _MainTex, _BumpMap;
                sampler2D _CameraDepthTexture, _GrabTexture;
                float4 _DistortionMap_ST, _MainTex_ST;
                float4 _GrabTexture_TexelSize;

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                    float4 screenPos : TEXCOORD1;
                    float2 dismap : TEXCOORD2;
                    float4 grabtex : TEXCOORD3;
                };

                v2f vert(appdata v)
                {
                    v2f o;
                    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                    o.dismap = TRANSFORM_TEX(v.uv, _DistortionMap);
                    o.vertex.y += sin(_Time.z * _Speed + (v.vertex.x * v.vertex.z * _Amount)) * (_Height + UnpackNormal(tex2D(_BumpMap, o.uv)).r);
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    o.screenPos = ComputeScreenPos(o.vertex);
                    o.grabtex = ComputeGrabScreenPos(o.vertex);
                    return o;
                }

                fixed4 frag(v2f i) : SV_Target
                {
                    float2 dism = UnpackNormal(tex2D(_DistortionMap, i.dismap + (_Time.x * 0.2)));
                    float2 offset = dism * (_MainDistortionFactor * 10) * _GrabTexture_TexelSize.xy * 10;
                    i.grabtex.xy = offset + i.grabtex.xy;
                    float4 dis = tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(i.grabtex)) * _EdgeColor;

                    float3 incidentDir = normalize(i.screenPos.xyz - _WorldSpaceCameraPos);
                    float3 normalDir = normalize((half3)UnpackNormal(tex2D(_BumpMap, i.uv)));
                    float fresnel = 1.0 - dot(-incidentDir, normalDir);
                    fresnel = pow(fresnel, 5.0);

                    half4 col = tex2D(_MainTex, i.uv + offset);
                    col.rgb = lerp(col.rgb, 1.0, fresnel);
                    col += dis;
                    col = (col + dis) * col.a;

                    return col;
                }
                ENDCG
            }
                        }
}
