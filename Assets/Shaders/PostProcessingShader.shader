﻿Shader "PostProcessingShader"
{
    Properties //Declare properties
    {
        _MainTex ("Main", 2D) = "white" {} //Main texture = camera input
        [Toggle] _desaturate("Desaturate", Float) = 0 //Desaturation
        _desaturationStrength("Desaturation strength", Range(0,1)) = 0 //Desaturation
        _desaturationBrightness("Desaturation brightness", Range(-0.05,0.15)) = 0 //Desaturation
        _OverlayTexture ("Overlay", 2D) = "white" {} //Overlay
        _overlayIntensity("Overlay intensity", Range(0,0.25)) = 0 //Overlay
        _NoiseMaskTexture("Noise Mask", 2D) = "white" {} //Noise mask
        _noiseMaskIntensity ("Noise Mask intensity", Range(0,1)) = 0 //Noise mask
        _offsetX("OffsetX",Float) = 0.0 //Noise
        _offsetY("OffsetY",Float) = 0.0 //Noise
        _octaves("Octaves",Int) = 7 //Noise
        _lacunarity("Lacunarity", Range(1.0 , 5.0)) = 2 //Noise
        _gain("Gain", Range(0.0 , 1.0)) = 0.5 //Noise
        _value("Value", Range(-2.0 , 2.0)) = 0.0 //Noise
        _amplitude("Amplitude", Range(0.0 , 5.0)) = 1.5 //Noise
        _frequency("Frequency", Range(0.0 , 6.0)) = 2.0 //Noise
        _power("Power", Range(0.1 , 5.0)) = 1.0 //Noise
        _noiseSpeedU("Noise Speed X", Range(-5,5)) = 0 //Noise
        _noiseSpeedV("Noise Speed Y", Range(-5,5)) = 0 //Noise
        _scale("Scale", Float) = 1.0 //Noise
        _range("Monochromatic Range", Range(0.0 , 1.0)) = 0.5 //Noise
    }
    SubShader
    {
        // No culling or depth as it is a post processing shader
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct v2f //Declare vertex to(2) float coordinate struct
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct SHADERDATA // Declare shader data struct
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float _octaves, _lacunarity, _gain, _value, _amplitude, _frequency, _offsetX, _offsetY, _power, _scale, _range, _noiseMaskIntensity, _overlayIntensity, _noiseSpeedU, _noiseSpeedV, _desaturate, _desaturationStrength, _desaturationBrightness;
            sampler2D _MainTex, _OverlayTexture, _NoiseMaskTexture; //Declare textures
            uniform float4  _OverlayTexture_ST, _NoiseMaskTexture_ST; //Declare Scale and Transform properties of the texture inputs

            float fbm(float2 p) //Declare noise function
            {
                p = p * _scale + float2(_offsetX, _offsetY); //Simplex noise scale and offset
                for (int i = 0; i < _octaves; i++) //For each octave
                {
                    float2 f = frac(p * _frequency); //Simplex frequency fractural
                    float2 t = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
                    float2 i = floor(p * _frequency); //Simplex frequency floor
                    float2 a = i + float2(0.0, 0.0); //Get UV corner sample points top left
                    float2 b = i + float2(1.0, 0.0); //Get UV corner sample points top right
                    float2 c = i + float2(0.0, 1.0); //Get UV corner sample points bottom left
                    float2 d = i + float2(1.0, 1.0); //Get UV corner sample points bottom right
                    a = -1.0 + 2.0 * frac(sin(float2(dot(a, float2(127.1, 311.7)), dot(a, float2(269.5, 183.3)))) * 43758.5453123); //Sample point a with simplex table
                    b = -1.0 + 2.0 * frac(sin(float2(dot(b, float2(127.1, 311.7)), dot(b, float2(269.5, 183.3)))) * 43758.5453123); //Sample point b with simplex table
                    c = -1.0 + 2.0 * frac(sin(float2(dot(c, float2(127.1, 311.7)), dot(c, float2(269.5, 183.3)))) * 43758.5453123); //Sample point c with simplex table
                    d = -1.0 + 2.0 * frac(sin(float2(dot(d, float2(127.1, 311.7)), dot(d, float2(269.5, 183.3)))) * 43758.5453123); //Sample point d with simplex table
                    float A = dot(a, f - float2(0.0, 0.0)); //Apply sampled simplex result a to UV corner top left
                    float B = dot(b, f - float2(1.0, 0.0)); //Apply sampled simplex result b to UV corner top right
                    float C = dot(c, f - float2(0.0, 1.0)); //Apply sampled simplex result c to UV corner bottom left
                    float D = dot(d, f - float2(1.0, 1.0)); //Apply sampled simplex result d to UV corner bottom right
                    float noise = (lerp(lerp(A, B, t.x), lerp(C, D, t.x), t.y)); //Lerp between simplex results and fractural
                    _value += _amplitude * noise; //Add noise value per pixel multiplied by amplitude
                    _frequency *= _lacunarity; //Increase frequency for each subsequent octave to make the noise more detailed per octave
                    _amplitude *= _gain; //Decrease strength of the noise for each subsequent octave to make the noise be less noticable per octave
                }
                _value = clamp(_value, -1.0, 1.0); //Clamp color of noise between 0 and 1
                return pow(_value * 0.5 + 0.5, _power); //Power increases or decreases contrast
            }

            SHADERDATA vertex_shader(float4 vertex:POSITION, float2 uv : TEXCOORD0) //Convert all vertexes on screen to UV coordinates
            {
                SHADERDATA vs;
                vs.vertex = UnityObjectToClipPos(vertex);
                vs.uv = uv;
                return vs;
            }

            SHADERDATA vert(v2f v) //Calculate shader data from 3d to 2d
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag(SHADERDATA i) : SV_Target //Main shader
            {
                fixed4 col = tex2D(_MainTex, i.uv); //Get color per pixel from camera
                if (_desaturate > 0) { //Desaturation
                    fixed4 desaturation = fixed4(0.3 * col.r, 0.6 * col.g, 0.1 * col.b, 1.0f);
                    col.r = col.r + _desaturationStrength * (desaturation - col.r) + _desaturationBrightness;
                    col.g = col.g + _desaturationStrength * (desaturation - col.g) + _desaturationBrightness;
                    col.b = col.b + _desaturationStrength * (desaturation - col.b) + _desaturationBrightness;
                }
                float2 overlayUV = i.uv.xy; //Declare overlay UV from main UV
                overlayUV.x += _Time * -_OverlayTexture_ST.z; //Move overlay UV
                overlayUV.y += _Time * _OverlayTexture_ST.w;
                overlayUV.x *= _OverlayTexture_ST.x; //Scale overlay UV
                overlayUV.y *= _OverlayTexture_ST.y;
                fixed4 overlayColor = tex2D(_OverlayTexture, overlayUV);
                float2 noiseMaskUV = i.uv.xy; //Declare noise mask UV from main UV
                noiseMaskUV.x += _Time * -_NoiseMaskTexture_ST.z; //Move noise mask UV
                noiseMaskUV.y += _Time * _NoiseMaskTexture_ST.w;
                noiseMaskUV.x *= _NoiseMaskTexture_ST.x; //Scale noise mask UV
                noiseMaskUV.y *= _NoiseMaskTexture_ST.y;
                fixed4 noiseColor = tex2D(_NoiseMaskTexture, noiseMaskUV);
                float2 noiseUV = i.uv.xy; //Declare noise UV from main UV
                noiseUV.x += _Time * -_noiseSpeedU; //Move noise
                noiseUV.y += _Time * _noiseSpeedV;          
                if (overlayColor.r<1) { col.r = col.r - overlayColor.r * _overlayIntensity; } //Per color, affect it if the overlay mask color is <1 in that channel
                if (overlayColor.g<1) { col.g = col.g - overlayColor.g * _overlayIntensity; }
                if (overlayColor.b<1) { col.b = col.b - overlayColor.b * _overlayIntensity; }
                float c = fbm(noiseUV); //Calculate noise from noise function for this pixel
                if (c >= _range) { //Filter by noise strength
                    if (noiseColor.r < _noiseMaskIntensity) { col.r = col.r * c * noiseColor.r; } //Change pixel color to noice color but mask it by noise mask
                    if (noiseColor.g < _noiseMaskIntensity) { col.g = col.g * c * noiseColor.g; }
                    if (noiseColor.b < _noiseMaskIntensity) { col.b = col.b * c * noiseColor.b; }
                }  

                return col; //Return pixel color result
            }
            ENDCG
        }
    }
}
