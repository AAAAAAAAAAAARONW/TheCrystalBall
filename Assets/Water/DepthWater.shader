Shader "DepthWater"
{
	Properties
	{
		_WaterTex("WaterTex", 2D) = "black" {}   //MainTex
		_BumpTex("BumpTex", 2D) = "bump" {}      //法线贴图
		_GTex("Gradient", 2D) = "white" {}       //水深度颜色
		_WaterSpeed("WaterSpeed", float) = 0.74  //水速度
		_Refract("Refract", float) = 0.07        //折射（法线偏移程度可控
		_Specular("Specular", float) = 1.86      //反射系数
		_Gloss("Gloss", float) = 0.71            //折射光照
		_SpecColor("SpecColor", color) = (1, 1, 1, 1)   //折射颜色（一般为白色
		_Range("Range", vector) = (0.13, 1.53, 0.37, 0.78)  //公开四个数
			 _MainTex("Main Texture", 2D) = "white" {}  // 添加名为"MainTex"的材质

	}

		CGINCLUDE

			//BlinnPhong
			fixed4 LightingWaterLight(SurfaceOutput s, fixed3 lightDir, half3 viewDir, fixed atten)
		{
			//用视角方向和光线方向之间的角平分线来模拟反射向量
			half3 halfDir = normalize(lightDir + viewDir);
			float NdotL = saturate(dot(lightDir, s.Normal));
			float HdotA = max(0, dot(halfDir, s.Normal));
			float spec = saturate(pow(HdotA, s.Specular * 128.0) * s.Gloss);

			fixed4 c;
			c.rgb = (s.Albedo * _LightColor0.rgb * NdotL + _SpecColor.rgb * spec * _LightColor0.rgb) * (atten);
			c.a = s.Alpha + spec * _SpecColor.a;
			return c;
		}
		ENDCG


			SubShader
		{
			Tags
			{
			"RenderType" = "Transparent"
			"Queue" = "Transparent"
			}
			LOD 200
			Cull off

			GrabPass{}

			zwrite off

			CGPROGRAM
			#pragma surface surf WaterLight vertex:vert alpha noshadow
			#pragma target 4.0


			UNITY_INSTANCING_BUFFER_START(Props)

			UNITY_INSTANCING_BUFFER_END(Props)


			sampler2D _GTex;

			sampler2D _WaterTex;
			sampler2D _BumpTex;
			sampler2D _MainTex;

			sampler2D _CameraDepthTexture;  //Main Camera渲染的深度贴图
			sampler2D _GrabTexture;
			half4 _GrabTexture_TexelSize;

			float4 _Range;

			half _WaterSpeed;

			half _WaveSpeed;
			fixed4 waterColor = fixed4(1, 1, 1, 1); // 或者使用你想要的默认颜色


			fixed _Refract;
			half _Specular;
			fixed _Gloss;

			float4 _WaterTex_TexelSize;

			struct Input {
				float2 uv_WaterTex;
				float2 uv_NoiseTex;
				float4 proj;
				float4 pos;
				float3 viewDir;
			};


			//顶点着色器中获取顶点在屏幕空间的位置，用做采样深度图的uv坐标
			void vert(inout appdata_full v, out Input i)
			{
				UNITY_INITIALIZE_OUTPUT(Input, i);

				i.pos = UnityObjectToClipPos(v.vertex);
				i.proj = ComputeScreenPos(i.pos);  //将返回片段着色器的屏幕位置
				COMPUTE_EYEDEPTH(i.proj.z);        //计算顶点摄像机空间的深度：距离裁剪平面的距离，线性变化
			}

			void surf(Input IN, inout SurfaceOutput o)
			{

				//根据法线设置偏移值

				 float4 offsetColor = (tex2D(_BumpTex, IN.uv_WaterTex + float2(_WaterSpeed * _Time.x,0)) + tex2D(_BumpTex, float2(1 - IN.uv_WaterTex.y,IN.uv_WaterTex.x) + float2(_WaterSpeed * _Time.x,0))) / 2;
				 half2 offset = UnpackNormal(offsetColor).xy * _Refract;//法线偏移程度可控
				// o.Albedo = tex2D(_MainTex, IN.uv_WaterTex).rgb;
				 //让水面检测深度并根据Grab贴图 显示;

				 float2 uv = IN.proj.xy / IN.proj.w;   // 获取屏幕纹理坐标信息

				 fixed4 water = (tex2D(_WaterTex, IN.uv_WaterTex));  //采样water贴图

				 half4 bott = tex2D(_GrabTexture, uv + offset);         //采样渐变贴图
				 fixed4 mainTextureColor = tex2D(_MainTex, IN.uv_WaterTex);
				

			     // 从_MainTex采样颜色并将其设置为o.Albedo
				 /*fixed4 mainTexColor = tex2D(_MainTex, IN.uv_WaterTex);
				 o.Albedo = mainTexColor.rgb;*/
				// o.Albedo = tex2D(_MainTex, IN.uv_WaterTex).rgb;
				
			
				// fixed4 mainTexture1Color = tex2D(_MainTex, IN.uv_WaterTex);
				// fixed4 waterColor = tex2D(_GTex, float2(min(_Range.y, deltaDepth) / _Range.y, 1));

				 // 控制混合比例
				/// float blendFactor = 0.5; // 你可以根据需要调整混合比例

				 // 使用 lerp 函数混合两者的颜色
				// o.Albedo = lerp(mainTexture1Color.rgb, waterColor.rgb, blendFactor);


				//fixed4 mainTexture1Color = tex2D(_MainTex, IN.uv_WaterTex);
				//o.Albedo = lerp(bott.rgb, mainTexture1Color.rgb, water.a);


				 fixed dis1 = distance(IN.uv_WaterTex,fixed2(0.5,0.5));
				 fixed2 uv1 = IN.uv_WaterTex + 2 * sin(_Time.y + dis1 * 2);
				 fixed4 c = tex2D(_WaterTex,uv1);


				 //计算当前像素深度
				 float depth = tex2Dproj(_CameraDepthTexture, IN.proj).r;  //UNITY_PROJ_COORD:深度值 [0,1]
				 half m_depth = LinearEyeDepth(depth);                      //深度根据相机的裁剪范围的值[0.3,1000],将经过透视投影变换的深度值还原
				 half deltaDepth = m_depth - IN.proj.z;

				 fixed4 waterColor = tex2D(_GTex, float2(min(_Range.y,deltaDepth) / _Range.y,1));   //根据深度显示水的颜色

				 //采样两次法线，交叉移动形成波光粼粼的样子
				 float4 bumpColor1 = tex2D(_BumpTex, IN.uv_WaterTex + offset + float2(_WaterSpeed * _Time.x,0));
				 float4 bumpColor2 = tex2D(_BumpTex, float2(1 - IN.uv_WaterTex.y,IN.uv_WaterTex.x) + offset + float2(_WaterSpeed * _Time.x,0));
				 o.Normal = UnpackNormal((bumpColor1 + bumpColor2) / 2).xyz;  //采样法线贴图，并移动。

				 o.Specular = _Specular;  //镜面反射系数
				 o.Gloss = _Gloss;  //实时调整光泽系数  就是光强

				 //深度 控制 颜色
				 half water_w = min(_Range.w, deltaDepth) / _Range.w;

				 o.Albedo = bott.rgb * (1 - water_w) + waterColor.rgb * water_w;             //输出纹理

				 o.Alpha = min(_Range.x, deltaDepth) / _Range.x;   //岸边为透明，所以a的值是根据深度来控制的
			 }
			 ENDCG
		}
			FallBack "Diffuse"
}