Shader "SnowShaderV3"
{
	Properties
	{
		_Tess("Tessellation", Range(1,64)) = 4
		_TopMain("TopMain", 2D) = "white" {}
		_BottomMain("BottomMain", 2D) = "white" {}
		_TopColor("TopColor",Color) = (1,1,1,1)//上层的主色调
		_BottomColor("BottomColor",Color) = (1,1,1,1)//下层的主色调
		_DispTex("Displacement Texture", 2D) = "white" {}//脚印踩下去之后的模型顶点偏移贴图
		_ImprintTex("Imprint Texture", 2D) = "white" {}//印记贴图（仅记录深度）
		_Displacement("Displacement", Range(0, 1.0)) = 0.3//深度因子
		_SpecularColor("SpecularColor",Color) = (1,1,1,1)//高光反射的主色调
		_Gloss("Gloss",Range(1,100)) = 2 //光泽度（反光度） 控制高光区域的大小
	}
		SubShader
		{
			Tags{ "RenderType" = "Opaque" "LightMode" = "ForwardBase"}
			LOD 300

			Pass
			{
				CGPROGRAM
				#pragma vertex tessvert
				#pragma fragment frag
				#pragma hull hs_surf //细分控制着色器
				#pragma domain ds_surf //细分计算着色器
				#pragma target 4.6
				#pragma multi_compile_fwdbase
				#include "UnityCG.cginc"
				#include "Lighting.cginc"
				#include "AutoLight.cginc"
				//UnityDistanceBasedTess 函数在下面库中
				#include "Tessellation.cginc"

				struct appdata
				{
					float4 vertex : POSITION;
					float4 tangent : TANGENT;
					float3 normal : NORMAL;
					float2 texcoord : TEXCOORD0;
				};

		//细分顶点结构体
		struct InternalTessInterp_appdata {
			float4 vertex : INTERNALTESSPOS;
			float4 tangent : TANGENT;
			float3 normal : NORMAL;
			float2 texcoord : TEXCOORD0;
		};

		struct v2f
		{
			float4 pos : SV_POSITION;
			float2 texcoord:TEXCOORD0;
			float4 T2W0 : TEXCOORD1;
			fixed4 T2W1 : TEXCOORD2;
			float4 T2W2 : TEXCOORD3;
			                float4 worldCoord : TEXCOORD4;
			// SHADOW_COORDS(4)
		};

		float _Tess;
		sampler2D _TopMain;
		float4 _TopMain_ST;
		sampler2D _BottomMain;
		float4 _BottomMain_ST;
		sampler2D _ImprintTex;
		sampler2D _DispTex;
		float _Displacement;
		fixed4 _SpecularColor;
		fixed4 _TopColor;
		fixed4 _BottomColor;
		float _Gloss;

		InternalTessInterp_appdata tessvert(appdata v)
		{
			InternalTessInterp_appdata o;
			o.vertex = v.vertex;
			o.tangent = v.tangent;
			o.normal = v.normal;
			o.texcoord = v.texcoord;
			return o;
		}


		v2f vert(appdata v)
		{
			v2f o;
			// UNITY_INITIALIZE_OUTPUT(v2f,o);
			// UNITY_TRANSFER_INSTANCE_ID(v,o);
			// UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
			o.pos = UnityObjectToClipPos(v.vertex);
			o.texcoord = TRANSFORM_TEX(v.texcoord, _TopMain);

			float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
			float3 worldNormal = UnityObjectToWorldNormal(v.normal);
			fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
			fixed tangentSign = v.tangent.w * unity_WorldTransformParams.w;
			fixed3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
			o.T2W0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
			o.T2W1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
			o.T2W2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);
			// TRANSFER_SHADOW(o);
			return o;
		}

		//将模型顶点根据深度图进行拉伸，使其凹陷，并且_Displacement可以控制拉伸长度，即雪厚度
		void disp(inout appdata v)
		{
			//关于为什么这里用tex2Dlod，可以简单理解成因为tex2D是在片元着色器中使用的，
			//在顶点着色器中无法使用，tex2Dlod可以在顶点着色器中使用
			//变换深度纹理以适合摄影机
			float d = tex2Dlod(_ImprintTex, float4(1 - v.texcoord.x, v.texcoord.y, 0,0)).r * _Displacement;
			//深度纹理经过变换以适合照相机将其全部放置在一个更有趣的整体表面上，使其从顶部缩进并调低一半
			d *= 1 - tex2Dlod(_DispTex, float4(v.texcoord,0,0)) * .5f;
			v.vertex.xyz += v.normal * d;
		}

		//在 (minDist,maxDist)区间内细分会不断变化
		//这个函数计算每个顶点到相机的距离，得出最终的tessellation 因子。
		float4 tessDistance(appdata v0, appdata v1, appdata v2) {
			float minDist = 10.0; //细分最小距离，小于细分不在增加
			float maxDist = 25.0; //细分最远距离，超出不在细分
			
			return UnityDistanceBasedTess(v0.vertex, v1.vertex, v2.vertex, minDist, maxDist, _Tess);
		}

		//InputPatch<InternalTessInterp_appdata,3> 输入块，由3个InternalTessInterp_appdata的顶点构成
		UnityTessellationFactors hsconst_surf(InputPatch<InternalTessInterp_appdata,3> v)
		{
			UnityTessellationFactors o;
			float4 tf;
			appdata vi[3];
			vi[0].vertex = v[0].vertex;
			vi[0].tangent = v[0].tangent;
			vi[0].normal = v[0].normal;
			vi[0].texcoord = v[0].texcoord;
			vi[1].vertex = v[1].vertex;
			vi[1].tangent = v[1].tangent;
			vi[1].normal = v[1].normal;
			vi[1].texcoord = v[1].texcoord;
			vi[2].vertex = v[2].vertex;
			vi[2].tangent = v[2].tangent;
			vi[2].normal = v[2].normal;
			vi[2].texcoord = v[2].texcoord;
			tf = tessDistance(vi[0], vi[1], vi[2]);
			o.edge[0] = tf.x; o.edge[1] = tf.y; o.edge[2] = tf.z; o.inside = tf.w;
			return o;
		}

		//指明输入进hull shader的图元是三角形。
		[UNITY_domain("tri")]
		//决定舍入规则，fractional_odd意为factor截断在[1,max]范围内，然后取整到小于此数的最大奇数整数值。
		[UNITY_partitioning("fractional_odd")]
		//决定图元的朝向，由组成三角形的三个顶点的顺序所产生的方向决定，cw为clockwise顺时针，ccw为counter clockwise逆时针。
		[UNITY_outputtopology("triangle_cw")]
		//指明计算factor的方法
		[UNITY_patchconstantfunc("hsconst_surf")]
		//hull shader输出的outputpatch中的顶点数量。
		[UNITY_outputcontrolpoints(3)]
		//给出控制点在path中的ID，与outputcontrolpoints对应，例如outputcontrolpoints为4，那么i的取值就是[0,4)的整数。
		InternalTessInterp_appdata hs_surf(InputPatch<InternalTessInterp_appdata,3> v, uint id : SV_OutputControlPointID) {
			return v[id];
		}

		//SV_DomainLocation：由曲面细分阶段阶段传入的顶点位置信息。
		[UNITY_domain("tri")]
		v2f ds_surf(UnityTessellationFactors tessFactors, const OutputPatch<InternalTessInterp_appdata,3> vi, float3 bary : SV_DomainLocation) {
			appdata v;
			UNITY_INITIALIZE_OUTPUT(appdata,v);
			v.vertex = vi[0].vertex * bary.x + vi[1].vertex * bary.y + vi[2].vertex * bary.z;
			v.tangent = vi[0].tangent * bary.x + vi[1].tangent * bary.y + vi[2].tangent * bary.z;
			v.normal = vi[0].normal * bary.x + vi[1].normal * bary.y + vi[2].normal * bary.z;
			v.texcoord = vi[0].texcoord * bary.x + vi[1].texcoord * bary.y + vi[2].texcoord * bary.z;
			//以上就是细分顶点最终生成的位置，下面是将所有顶点进行拉伸
			disp(v);
			v2f o = vert(v);
			return o;
		}


		fixed4 frag(v2f i) : SV_Target
		{
			float3 worldPos = float3(i.T2W0.w,i.T2W1.w,i.T2W2.w);
			float3 worldNormal = float3(i.T2W0.z,i.T2W1.z,i.T2W2.z);
			//上下两层其实就是一层，但是利用深度的不同分布进行差值，陷下去的用bottom，没陷下去的用Top
			//所以只用一个texcoord，毕竟都是渲染同一个地面
			half4 c = lerp(
			tex2D(_TopMain, i.texcoord) * _TopColor,
			tex2D(_BottomMain, i.texcoord) * _BottomColor,
			1 - tex2D(_ImprintTex, float2(1 - i.texcoord.x, i.texcoord.y)).r);

			fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));//获取光源在世界空间下的方向（光源发射出来的方向）
			fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - worldPos);//计算眼睛的方向 相机位置-模型的世界坐标 向量

			//Blinn-Phong模型高光 
			fixed3 halfView = normalize(lightDir + viewDir);
			fixed3 specular = _LightColor0.rgb * _SpecularColor * pow(saturate(dot(worldNormal,halfView)),_Gloss);
			// fixed shadow = SHADOW_ATTENUATION(i);
			// UNITY_LIGHT_ATTENUATION(atten,i,worldPos);
			return fixed4(c.xyz + specular ,1);//(c.xyz * shadow + specular ,1);
		}
		ENDCG
	}
		}
			FallBack "Diffuse"
}

