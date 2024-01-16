Shader "Custom/GrassVertexAniInteractive"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Noise("Noise", 2D) = "black" {}
        _WindControl("WindControl(x:XSpeed y:YSpeed z:ZSpeed w:windMagnitude)",vector) = (1,1,1,0.5)
            //前面几个分量表示在各个轴向上自身摆动的速度, w表示摆动的强度
            _WaveControl("WaveControl(x:XSpeed y:YSpeed z:ZSpeed w:worldSize)",vector) = (1,0,1,1)
            //前面几个分量表示在各个轴向上风浪的速度, w用来模拟地图的大小,值越小草摆动的越凌乱，越大摆动的越整体
            //_PlayerPos("PlayerPos", vector) = (0,0,0,0)
            //物体的位置坐标，需要在运行时通过C#代码传入，所以这里注释掉，把这个参数作为全局控制的参数
            _Strength("Strength", float) = 1
            //草地弯曲的强度
            _PushRadius("PushRadius", float) = 1
            //交互的范围
    }
        SubShader
        {
            Tags { "RenderType" = "Opaque" }
            LOD 100

            Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile_instancing

                #include "UnityCG.cginc"

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                    UNITY_VERTEX_INPUT_INSTANCE_ID
                };

                struct v2f
                {
                    float2 uv : TEXCOORD0;
                    float4 pos : SV_POSITION;
                };

                sampler2D _MainTex;
                sampler2D _Noise;
                half4 _WindControl;
                half4 _WaveControl;

                float4 _PlayerPos;
                half _Strength;
                half _PushRadius;

                v2f vert(appdata v)
                {
                    v2f o;
                    UNITY_SETUP_INSTANCE_ID(v);
                    //草地自身风吹草动的计算
                    float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                    float2 samplePos = worldPos.xz / _WaveControl.w;
                    samplePos += _Time.x * -_WaveControl.xz;
                    fixed waveSample = tex2Dlod(_Noise, float4(samplePos, 0, 0)).r;
                    worldPos.x += sin(waveSample * _WindControl.x) * _WaveControl.x * _WindControl.w * v.uv.y;
                    worldPos.z += sin(waveSample * _WindControl.z) * _WaveControl.z * _WindControl.w * v.uv.y;
                    //草地交互的计算
                    float dis = distance(_PlayerPos, worldPos);
                    float pushDown = saturate((1 - dis + _PushRadius) * v.uv.y * _Strength);
                    float3 direction = normalize(worldPos.xyz - _PlayerPos.xyz);
                    direction.y *= 0.5;
                    worldPos.xyz += direction * pushDown;

                    o.pos = mul(UNITY_MATRIX_VP, worldPos);
                    o.uv = v.uv;

                    return o;
                }

                fixed4 frag(v2f i) : SV_Target
                {
                    fixed4 col = tex2D(_MainTex, i.uv);
                    return col;
                }
                ENDCG
            }
        }
}