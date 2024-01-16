Shader "GrassV3Pro"
{
    Properties
    {
        [Header(Shading)]
        _TopColor("TopColor", Color) = (1, 1, 1, 1)  // ������ɫ����
        _BottomColor("BottomColor", Color) = (1, 1, 1, 1)  // �ײ���ɫ����

        [Header(Blade Properties)]
        _BladeWidth("Width", Float) = 0.05  // ҶƬ�������
        _BladeWidthRandom("WidthRandom", Float) = 0.02  // ҶƬ����������
        _BladeHeight("Height", Float) = 0.5  // ҶƬ�߶�����
        _BladeHeightRandom("HeightRandom", Float) = 0.3  // ҶƬ�߶��������
        _BladeForward("Foward", Float) = 0.38  // ҶƬǰ��������
        _BladeCurve("Curve", Range(1, 4)) = 2  // ҶƬ��������
        _BendRotationRandom("RotateRandom", Range(0, 1)) = 0.2  // ������ת�������

        [Header(Tessellation)]
        _TessellationUniform("TesseRandom", Range(1, 64)) = 1  // ϸ�־��ȶ�����

        [Header(Wind)]
        _WindDistortionMap("���Ť����ͼWind", 2D) = "white" {}  // ���Ť����ͼ����
        _WindFrequency("WindFrequency", Vector) = (0.05, 0.05, 0, 0)  // ���Ƶ������
        _WindStrength("WindStrength", Float) = 1  // ���ǿ������

        [Header(Trample)]
        _Trample("Interaction", Vector) = (0, 0, 0, 0)  // ��̤����
        _TrampleStrength("TrampleStrength", Range(0, 10)) = 0.2  // ��̤ǿ������
    }

        CGINCLUDE
#include "UnityCG.cginc"
#include "CustomTessellation.cginc"

#define BLADE_SEGMENTS 5  // ����ҶƬ�ֶ���

            // ��������ɺ���
            float rand(float3 co)
        {
            return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
        }

        // ������ת�ľ������ɺ���
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

        float2 UV : TEXCOORD0;  // ��������
        float _BendRotationRandom;  // ������ת���ֵ
        float _BladeWidth;  // ҶƬ���
        float _BladeWidthRandom;  // ҶƬ������ֵ
        float _BladeHeight;  // ҶƬ�߶�
        float _BladeHeightRandom;  // ҶƬ�߶����ֵ
        float _BladeForward;  // ҶƬǰ����
        float _BladeCurve;  // ҶƬ����

        sampler2D _WindDistortionMap;  // ���Ť����ͼ
        float4 _WindDistortionMap_ST;  // ���Ť����ͼ������ƫ�Ʋ���
        float2 _WindFrequency;  // ���Ƶ��
        float _WindStrength;  // ���ǿ��

        float4 _Trample;  // ��̤����
        float _TrampleStrength;  // ��̤ǿ��

        // ������ɫ������ṹ
        struct geometryOutput
        {
            float4 pos : SV_POSITION;  // ����λ��
            float2 uv : TEXCOORD0;  // ��������
        };

        // ������ɫ��
        geometryOutput VertexOutput(float3 pos, float2 uv)
        {
            geometryOutput o;
            o.pos = UnityObjectToClipPos(pos);  // ������λ�ôӶ���ռ�ת�����ü��ռ�
            o.uv = uv;  // ������������
            return o;
        }

        // ���ɲ�Ҷ����ĺ���
        geometryOutput GenerateGrassVertex(float3 vertexPosition, float width, float height, float forward, float2 uv,
            float3x3 transformationMatrix)
        {
            float3 tangentPoint = float3(width, forward, height);
            float3 localPosition = vertexPosition + mul(transformationMatrix, tangentPoint);

            return VertexOutput(localPosition, uv);
        }

        // ��ȡ��̤�����ĺ���
        float4 GetTrampleVector(float3 pos, float4 objectOrigin)
        {
            float3 trampleDiff = pos - (_Trample.xyz - objectOrigin);
            return float4(
                float3(normalize(trampleDiff).x,
                    0,
                    normalize(trampleDiff).z) * (1.0 - saturate(length(trampleDiff) / _Trample.w)),
                0);
        }

        // ������ɫ��
        [maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
        void geo(triangle vertexOutput IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
        {
            float3 pos = IN[0].vertex;  // ����λ��
            float3 normal = IN[0].normal;  // ���㷨��
            float4 tangent = IN[0].tangent;  // ��������
            float3 binormal = cross(normal, tangent) * tangent.w;  // ���㸱����

            float3x3 tangentToLocal = float3x3(
                tangent.x, binormal.x, normal.x,
                tangent.y, binormal.y, normal.y,
                tangent.z, binormal.z, normal.z
                );

            float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1));  // ���ɳ�����ת����
            float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_TWO_PI * 0.5,
                float3(-1, 0, 0));  // ����������ת����

            float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;  // �����Ť����ͼ����
            float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;  // ������Ť����ͼ
            float3 wind = normalize(float3(windSample.x, windSample.y, 0));  // ������
            float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);  // �����ת����

            float3x3 transformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix),
                bendRotationMatrix);  // ����任����
            float3x3 transformationMatrixFacing = mul(tangentToLocal, facingRotationMatrix);  // ֻ���ǳ���ı任����

            float width = (rand(pos.xyz) * 2 - 1) * _BladeWidthRandom + _BladeWidth;  // ����ҶƬ���
            float height = (rand(pos.xyz) * 2 - 1) * _BladeHeightRandom + _BladeHeight;  // ����ҶƬ�߶�
            float forward = rand(pos.yyz) * _BladeForward;  // ����ҶƬǰ����
            float4 objectOrigin = mul(unity_ObjectToWorld, float4(0.0, 0.0, 0.0, 1.0));  // ����ԭ�������������е�λ��

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
                    pos += trample * _TrampleStrength;  // ��̤Ч��
                }

                triStream.Append(
                    GenerateGrassVertex(pos, segmentWidth, segmentHeight, segmentForward, float2(0, t), transformMatrix));
                triStream.Append(
                    GenerateGrassVertex(pos, -segmentWidth, segmentHeight, segmentForward, float2(1, t), transformMatrix));
            }

            float4 trample = GetTrampleVector(pos, objectOrigin);
            pos += trample * _TrampleStrength;  // ��̤Ч��
            triStream.Append(GenerateGrassVertex(pos, 0, height, forward, float2(0.5, 1), transformationMatrix));  // ���Ҷ��
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

                float4 _TopColor;  // ������ɫ����
                float4 _BottomColor;  // �ײ���ɫ����
                float _TranslucentGain;  // ͸������������

            // Ƭ����ɫ����������ɫ��ֵ
                float4 frag(geometryOutput i, fixed facing : VFACE) : SV_Target
                {
                    return lerp(_BottomColor, _TopColor, i.uv.y);
                }
                    ENDCG
        }
        }
}