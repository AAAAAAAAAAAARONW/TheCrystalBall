Shader "Mobile/流水（Test）"
{
    Properties
    {
        _TintColor("Tint Color", Color) = (0.5, 0.5, 0.5, 0.5)
        _EmissiveStrength("Emissive strength", Range(0, 1)) = 0.5
        _MainTex("Base (RGB) Trans (A)", 2D) = "white" {}
        _UVScrollSpeed("UV Scroll Speed", Range(0, 10)) = 1.0
        _Alpha("Alpha", Range(0, 1)) = 1.0
    }

        SubShader
        {
            Tags { "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
            LOD 200
            Cull Off
            Lighting Off
            ZWrite Off
            Blend SrcAlpha One
            ColorMask RGB

            Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile_fog

                #include "UnityCG.cginc"

                struct appdata_t
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float2 uv : TEXCOORD0;
                    float4 vertex : SV_POSITION;
                };

                sampler2D _MainTex;
                float4 _TintColor;
                half _EmissiveStrength;
                float _UVScrollSpeed;
                half _Alpha;

                v2f vert(appdata_t v)
                {
                    v2f o;
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    o.uv = v.uv + float2(0, _UVScrollSpeed * _Time.y);
                    return o;
                }

                half4 frag(v2f i) : SV_Target
                {
                    half4 c = tex2D(_MainTex, i.uv);
                    half4 finalColor = c * _TintColor;
                    finalColor.a = c.a * _Alpha; // 使用透明度属性来控制透明度
                    finalColor.rgb += c.rgb * _EmissiveStrength;
                    return finalColor;
                }
                ENDCG
            }
        }
}


