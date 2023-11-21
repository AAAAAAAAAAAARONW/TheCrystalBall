Shader "GrassV2Pro"
{
    Properties
    {
        [Header(Shading)]
        _TopColor("TopColor", Color) = (1, 1, 1, 1)  // 顶部颜色属性
        _BottomColor("BottomColor", Color) = (1, 1, 1, 1)  // 底部颜色属性

        [Header(Blade Properties)]
        _BladeWidth("Width", Float) = 0.05  // 叶片宽度属性
        _BladeWidthRandom("WidthRandom", Float) = 0.02  // 叶片宽度随机属性
        _BladeHeight("Height", Float) = 0.5  // 叶片高度属性
        _BladeHeightRandom("HeightRandom", Float) = 0.3  // 叶片高度随机属性
        _BladeForward("Foward", Float) = 0.38  // 叶片前倾量属性
        _BladeCurve("Curve", Range(1, 4)) = 2  // 叶片曲率属性
        _BendRotationRandom("RotateRandom", Range(0, 1)) = 0.2  // 弯曲旋转随机属性

        [Header(Tessellation)]
        _TessellationUniform("TesseRandom", Range(1, 64)) = 1  // 细分均匀度属性

        [Header(Wind)]
        _WindDistortionMap("风的扭曲贴图Wind", 2D) = "white" {}  // 风的扭曲贴图属性
        _WindFrequency("WindFrequency", Vector) = (0.05, 0.05, 0, 0)  // 风的频率属性
        _WindStrength("WindStrength", Float) = 1  // 风的强度属性

        [Header(Trample)]
        _Trample("Interaction", Vector) = (0, 0, 0, 0)  // 践踏属性
        _TrampleStrength("TrampleStrength", Range(0, 10)) = 0.2  // 践踏强度属性
    }

        CGINCLUDE
#include "UnityCG.cginc"
#include "CustomTessellation.cginc"

#define BLADE_SEGMENTS 5  // 定义叶片分段数

            // 随机数生成函数
            float rand(float3 co)
        {
            return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
        }

        // 绕轴旋转的矩阵生成函数
        float3x3 AngleAxis3x3(float angle, float3 axis)
        {
            float c, s;
            sincos(angle, s, c);

            float t = 1 - c;
            float x = axis.x;
            float y = axis.y;
            float z = axis.z;

            return float3x3(
                t * x * x + c, t * x * y - s * z, t * x * z + s * y,
                t * x * y + s * z, t * y * y + c, t * y * z - s * x,
                t * x * z - s * y, t * y * z + s * x, t * z * z + c
                );
        }

        float2 UV : TEXCOORD0;  // 纹理坐标
        float _BendRotationRandom;  // 弯曲旋转随机值
        float _BladeWidth;  // 叶片宽度
        float _BladeWidthRandom;  // 叶片宽度随机值
        float _BladeHeight;  // 叶片高度
        float _BladeHeightRandom;  // 叶片高度随机值
        float _BladeForward;  // 叶片前倾量
        float _BladeCurve;  // 叶片曲率

        sampler2D _WindDistortionMap;  // 风的扭曲贴图
        float4 _WindDistortionMap_ST;  // 风的扭曲贴图的缩放偏移参数
        float2 _WindFrequency;  // 风的频率
        float _WindStrength;  // 风的强度

        float4 _Trample;  // 践踏向量
        float _TrampleStrength;  // 践踏强度

        // 顶点着色器输出结构
        struct geometryOutput
        {
            float4 pos : SV_POSITION;  // 顶点位置
            float2 uv : TEXCOORD0;  // 纹理坐标
        };

        // 顶点着色器
        geometryOutput VertexOutput(float3 pos, float2 uv)
        {
            geometryOutput o;
            o.pos = UnityObjectToClipPos(pos);  // 将顶点位置从对象空间转换到裁剪空间
            o.uv = uv;  // 传递纹理坐标
            return o;
        }

        // 生成草叶顶点的函数
        geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv,
            float3x3 transformationMatrix)
        {
            float3 tangentPoint = float3(width, forward, height);
            float3 localPosition = vertexPosition + mul(transformationMatrix, tangentPoint);

            return VertexOutput(localPosition, uv);
        }

        // 获取践踏向量的函数
        float4 GetTrampleVector(float3 pos, float4 objectOrigin)
        {
            float3 trampleDiff = pos - (_Trample.xyz - objectOrigin);
            return float4(
                float3(normalize(trampleDiff).x,
                    0,
                    normalize(trampleDiff).z) * (1.0 - saturate(length(trampleDiff) / _Trample.w)),
                0);
        }

        // 几何着色器
        [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
        void geo(triangle vertexOutput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
        {
            float3 pos = IN[0].vertex;  // 顶点位置
            float3 normal = IN[0].normal;  // 顶点法线
            float4 tangent = IN[0].tangent;  // 顶点切线
            float3 binormal = cross(normal, tangent) * tangent.w;  // 顶点副法线

            float3x3 tangentToLocal = float3x3(
                tangent.x, binormal.x, normal.x,
                tangent.y, binormal.y, normal.y,
                tangent.z, binormal.z, normal.z
                );

            float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));  // 生成朝向旋转矩阵
            float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_TWO_PI * 0.5,
                float3(-1, 0, 0));  // 生成弯曲旋转矩阵

            float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;  // 计算风扭曲贴图坐标
            float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;  // 采样风扭曲贴图
            float3 wind = normalize(float3(windSample.x, windSample.y, 0));  // 风向量
            float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);  // 风的旋转矩阵

            float3x3 transformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix),
                bendRotationMatrix);  // 计算变换矩阵
            float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);  // 只考虑朝向的变换矩阵

            float width = (rand(pos.xyz) * 2 - 1) * _BladeWidthRandom + _BladeWidth;  // 计算叶片宽度
            float height = (rand(pos.xyz) * 2 - 1) * _BladeHeightRandom + _BladeHeight;  // 计算叶片高度
            float forward = rand(pos.yyz) * _BladeForward;  // 计算叶片前倾量
            float4 objectOrigin = mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0));  // 物体原点在世界坐标中的位置

            for (int i = 0; i < BLADE_SEGMENTS; i++)
            {
                float t = i / (float)BLADE_SEGMENTS;
                float segmentHeight = height * t;
                float segmentWidth = width * (1 - t);
                float segmentForward = pow(t, _BladeCurve) * forward;

                float3x3 transformMatrix = i == 0 ? transformationMatrixFacing : transformationMatrix;

                if (i > 0)
                {
                    float4 trample = GetTrampleVector(pos, objectOrigin);
                    pos += trample * _TrampleStrength;  // 践踏效果
                }

                triStream.Append(
                    GenerateGrassVertex(pos, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
                triStream.Append(
                    GenerateGrassVertex(pos, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
            }

            float4 trample = GetTrampleVector(pos, objectOrigin);
            pos += trample * _TrampleStrength;  // 践踏效果
            triStream.Append(GenerateGrassVertex(pos, 0, height, forward, float2(0.5, 1), transformationMatrix));  // 添加叶尖
        }
        ENDCG

            SubShader
        {
            Cull Off

            Pass
            {
                Tags
                {
                    "RenderType" = "Opaque"
                    "LightMode" = "ForwardBase"
                }

                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma target 4.6
                #pragma geometry geo
                #pragma hull hull
                #pragma domain domain

                float4 _TopColor;  // 顶部颜色属性
                float4 _BottomColor;  // 底部颜色属性
                float _TranslucentGain;  // 透明度增益属性

            // 片段着色器，用于颜色插值
                float4 frag(geometryOutput i, fixed facing : VFACE) : SV_Target
                {
                    return lerp(_BottomColor, _TopColor, i.uv.y);
                }
                    ENDCG
        }
        }
}