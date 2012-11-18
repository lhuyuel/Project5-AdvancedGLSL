//View-Space directional light
//A unit vector
uniform vec3 u_CameraSpaceDirLight;

//Diffuse texture map for the day
uniform sampler2D u_DayDiffuse;
//Ambient texture map for the night side
uniform sampler2D u_Night;
//Color map for the clouds
uniform sampler2D u_Cloud;
//Transparency map for the clouds.  Note that light areas are where clouds are NOT
//Dark areas are were clouds are present
uniform sampler2D u_CloudTrans;
//Mask of which areas of the earth have specularity
//Oceans are specular, landmasses are not
uniform sampler2D u_EarthSpec;
//Bump map
uniform sampler2D u_Bump;

uniform float u_time;
uniform mat4 u_InvTrans;

varying vec3 v_Normal;              // surface normal in camera coordinates
varying vec2 v_Texcoord;
varying vec3 v_Position;            // position in camera coordinates
varying vec3 v_positionMC;          // position in model coordinates

mat3 eastNorthUpToEyeCoordinates(vec3 positionMC, vec3 normalEC);

void main(void)
{

	vec3 normal = normalize(v_Normal); // surface normal - normalized after rasterization
    vec3 eyeToPosition = normalize(v_Position); // normalized eye-to-position vector in camera coordinates

	//==========================================Bump map=====================================
	float center = texture2D( u_Bump, v_Texcoord );
	float right = texture2D( u_Bump, v_Texcoord + vec2(1.0/1000.0, 0.0) );
	float top = texture2D( u_Bump, v_Texcoord + vec2(0.0, 1.0/500.0) );

	vec3 perturbedNorm = normalize( vec3(center - right, center - top, 0.2) );
	vec3 bumpNorm = normalize(eastNorthUpToEyeCoordinates(v_positionMC, normal)* perturbedNorm);

    float BumpDiffuse = max( dot(u_CameraSpaceDirLight, bumpNorm), 0.0 );

    vec3 toReflectedLight = reflect(-u_CameraSpaceDirLight, normal);

	float earthFlag = length(vec3(texture2D(u_EarthSpec, v_Texcoord)));
    //==================================== Specular =========================================
	float specular;
	if( earthFlag > 0.01)	specular = max(dot(toReflectedLight, -eyeToPosition), 0.0);
	else	specular = 0;
    
	specular = pow(specular, 20.0) * texture2D(u_EarthSpec, v_Texcoord);
	
	float gammaCorrect = 1/2.0; //gamma correct by 1/1.8
	
	vec4 dayColor = ((0.6 * BumpDiffuse) + (0.4 * specular)) * texture2D(u_DayDiffuse, v_Texcoord);
	vec4 nightColor = pow(texture2D(u_Night, v_Texcoord),gammaCorrect); //apply gamma correction to nighttime texture

	//====================================== Add Clouds========================================
	vec2 cloudCoord = v_Texcoord + vec2( u_time, 0.0 );
	float cloudTransmitance = texture2D(u_CloudTrans,cloudCoord);

    float diffuse = max(dot(u_CameraSpaceDirLight, normal), 0.0);

	dayColor = mix( (0.6 * diffuse)*texture2D(u_Cloud,cloudCoord), dayColor, cloudTransmitance );
	nightColor = mix( vec4( 0.0 ), nightColor, cloudTransmitance);
	
	//===================================== Rim lighting ========================================
	float rimFactor = dot(v_Normal, v_Position) + 1;
	vec4 rimClr = vec4( 0.0 );
	if( rimFactor > 0 )
		rimClr = vec4(rimFactor/4, rimFactor/2, rimFactor/2, 1.0);

	gl_FragColor = rimClr + mix( dayColor, nightColor, pow(1.0 - diffuse, 3.0) );
}


mat3 eastNorthUpToEyeCoordinates(vec3 positionMC, vec3 normalEC)
{
    vec3 tangentMC = normalize(vec3(-positionMC.y, positionMC.x, 0.0));  // normalized surface tangent in model coordinates
    vec3 tangentEC = normalize(mat3(u_InvTrans) * tangentMC);            // normalized surface tangent in eye coordiantes
    vec3 bitangentEC = normalize(cross(normalEC, tangentEC));            // normalized surface bitangent in eye coordinates

    return mat3(
        tangentEC.x,   tangentEC.y,   tangentEC.z,
        bitangentEC.x, bitangentEC.y, bitangentEC.z,
        normalEC.x,    normalEC.y,    normalEC.z);
}