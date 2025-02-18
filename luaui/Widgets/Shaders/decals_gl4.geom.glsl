#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
// This shader is (c) Beherith (mysterme@gmail.com)

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout(points) in;
layout(triangle_strip, max_vertices = 40) out;
#line 20000

uniform float fadeDistance;
uniform sampler2D heightmapTex;
uniform sampler2D miniMapTex;
uniform sampler2D mapNormalsTex;

in DataVS {
	uint v_skipdraw;
	vec4 v_lengthwidthrotation;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
} dataIn[];

out DataGS {
	vec4 g_color;
	vec4 g_uv;
	vec4 g_position; // how to get tbnmatrix here?
	vec4 g_mapnormal;
	vec4 g_tangent;
	vec4 g_bitangent;
	mat3 tbnmatrix;
	mat3 tbninverse;
};

mat3 rotY;
vec3 decalDimensions; // length, height, widgth
vec4 centerpos;
vec4 uvoffsets;

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy; 
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

// This function takes in a set of UV coordinates [0,1] and tranforms it to correspond to the correct UV slice of an atlassed texture
vec2 transformUV(float u, float v){// this is needed for atlassing
	//return vec2(uvoffsets.p * u + uvoffsets.q, uvoffsets.s * v + uvoffsets.t); old
	float a = uvoffsets.t - uvoffsets.s;
	float b = uvoffsets.q - uvoffsets.p;
	return vec2(uvoffsets.s + a * u, uvoffsets.p + b * v);
}

void offsetVertex4( float x, float y, float z, float u, float v){
	g_uv.xy = transformUV(u,v);
	vec3 primitiveCoords = vec3(x,y,z) * decalDimensions;
	//vec3 vecnorm = normalize(primitiveCoords);// AHA zero case!
	vec4 worldPos = vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	
	vec2 uvhm = heighmapUVatWorldPos(worldPos.xz);
	worldPos.y = textureLod(heightmapTex, uvhm, 0.0).x + 0.01;
	gl_Position = cameraViewProj * worldPos;
	gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in Z
	g_uv.zw = dataIn[0].v_parameters.zw;
	g_color =  textureLod(heightmapTex, centerpos.xz*0.0001, 0.0);
	g_position.xyz = worldPos.xyz;
	g_position.w = length(vec2(x,z));
	g_mapnormal = textureLod(mapNormalsTex, uvhm, 0.0).raaa;
	g_mapnormal.g = sqrt( 1.0 - dot( g_mapnormal.ra, g_mapnormal.ra));
	g_mapnormal.xyz = g_mapnormal.rga;
	// the tangent of the UV goes in the +U direction
	// we _kinda_ need to know the Y rot, and the normal dir for this
	// assume that tangent points "right" (+U)
	
	vec3 Nup = vec3(0.0, 1.0, 0.0);
	vec3 Trot = rotY * vec3(1.0, 0.0, 0.0);
	vec3 Brot = rotY * vec3(0.0, 0.0, 1.0);
	tbnmatrix = mat3(Trot, Brot, Nup);
	//tbninverse = transpose(g_mapnormal.xyx * tbnmatrix );
	
	g_tangent = vec4(vec3(rotY * vec3(1.0, 0.0, 0.0)), 1.0);
	g_bitangent = vec4(rotY * vec3(0.0, 0.0, 1.0), 1.0);
	
	
	
	//mat3 tbnmatrix = mat3(g_tangent.xyz, g_bitangent.xyz, g_mapnormal.xyz);
	//mat3 tbninverse = transpose(mat3(T, B, N));  
	
	EmitVertex();
}
#line 22000
void main(){
	if (dataIn[0].v_skipdraw > 0u) return; //bail

	centerpos = dataIn[0].v_centerpos;
	rotY = rotation3dY(dataIn[0].v_lengthwidthrotation.z); // Create a rotation matrix around Y from the unit's rotation
	//rotY = mat3(1.0);

	uvoffsets = dataIn[0].v_uvoffsets; // if an atlas is used, then use this, otherwise dont
	decalDimensions = vec3(dataIn[0].v_lengthwidthrotation.x * 0.5, 0.0, dataIn[0].v_lengthwidthrotation.y * 0.5);

	// for a simple quad
	/*
		float length = dataIn[0].v_lengthwidthrotation.x;
		float width = dataIn[0].v_lengthwidthrotation.y;
		offsetVertex4( width * 0.5, 0.0,  length * 0.5, 0.0, 1.0); // bottom right
		offsetVertex4( width * 0.5, 0.0, -length * 0.5, 0.0, 0.0); // top right
		offsetVertex4(-width * 0.5, 0.0,  length * 0.5, 1.0, 1.0); // bottom left
		offsetVertex4(-width * 0.5, 0.0, -length * 0.5, 1.0, 0.0); // top left
		EndPrimitive();
	*/
	
	// for a 4x4 quad
	for (int i = 0; i<4; i++){ //draw from bottom (front) to back
		float v = float(i)*0.25; // [0-2]
		// draw 4 strips of 9 verts
		//10 8 6 4 2
		// 9 7 5 3 1
		float striptop = (2.0*v - 0.5);
		float stripbot = (2.0*v - 1.0);
		offsetVertex4( 1.0, 0.0, stripbot, 1.0 , v       ); // 1
		offsetVertex4( 1.0, 0.0, striptop, 1.0 , v + 0.25); // 2
		offsetVertex4( 0.5, 0.0, stripbot, 0.75, v       ); // 3
		offsetVertex4( 0.5, 0.0, striptop, 0.75, v + 0.25); // 4
		offsetVertex4( 0.0, 0.0, stripbot, 0.5, v ); // 5
		offsetVertex4( 0.0, 0.0, striptop, 0.5, v + 0.25); // 6
		offsetVertex4(-0.5, 0.0, stripbot, 0.25, v ); // 7
		offsetVertex4(-0.5, 0.0, striptop, 0.25, v + 0.25); // 8
		offsetVertex4(-1.0, 0.0, stripbot, 0.0, v ); // 8
		offsetVertex4(-1.0, 0.0, striptop, 0.0, v + 0.25); // 10
		EndPrimitive();
	}
	
}