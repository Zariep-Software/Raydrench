module raydrench.skybox;

import raylib;
import raylib.raymath;
import core.stdc.string : strncpy;
import core.stdc.stdio : snprintf;

import raydrench.maploader : g_scene;
import raydrench.entity;
import raydrench.brush;
import raydrench.geometry : ConvexHull;
import raydrench.transform;

@nogc nothrow:

enum MAX_SKY_TEXTURE_LEN = 64;

__gshared char[MAX_SKY_TEXTURE_LEN] g_skyTexture;
__gshared bool g_haveSkyEntity = false;

__gshared Model g_skyboxModel;
__gshared bool g_skyboxLoaded = false;

/*
	spawnSkybox
	- Registered against "env_skybox" (see game.fgd), the same way
		spawnPlayerStart is registered against "info_player_start" in
		player.d. Just records the requested cubemap name; the actual
		model/texture load happens later in generateSkybox(), once the
		whole scene (and therefore its bounds) is available
*/
void spawnSkybox(Entity* e)
{
	const(char)* tex = e.get("texture", "sky1");
	strncpy(g_skyTexture.ptr, tex, MAX_SKY_TEXTURE_LEN - 1);
	g_skyTexture[MAX_SKY_TEXTURE_LEN - 1] = '\0';
	g_haveSkyEntity = true;
}

/*
	computeMapBounds
	- Walks every brush's clipped face polygon (still in raw .map space
		at this point) and transforms each vertex into render space,
		matching what meshbuilder.buildAllModels actually uploads
	- Returns the axis-aligned bounds of the whole scene in render space
*/
BoundingBox computeMapBounds(float yawRadians = 0.0f)
{
	BoundingBox bounds;
	bounds.min = Vector3(float.max, float.max, float.max);
	bounds.max = Vector3(-float.max, -float.max, -float.max);
	bool any = false;

	foreach (ei; 0 .. g_scene.entityCount)
	{
		Entity* ent = &g_scene.entities[ei];
		foreach (bi; 0 .. ent.brushCount)
		{
			Brush* b = &ent.brushes[bi];
			foreach (fi; 0 .. b.faceCount)
			{
				ConvexHull* hull = &b.hulls[fi];
				foreach (vi; 0 .. hull.count)
				{
					Vector3 p = toRenderSpace(hull.verts[vi], WORLD_TO_RENDER_SCALE, yawRadians);
					any = true;

					if (p.x < bounds.min.x) bounds.min.x = p.x;
					if (p.y < bounds.min.y) bounds.min.y = p.y;
					if (p.z < bounds.min.z) bounds.min.z = p.z;

					if (p.x > bounds.max.x) bounds.max.x = p.x;
					if (p.y > bounds.max.y) bounds.max.y = p.y;
					if (p.z > bounds.max.z) bounds.max.z = p.z;
				}
			}
		}
	}

	if (!any)
	{
		// Empty scene fallback: unit box around the origin
		bounds.min = Vector3(-1, -1, -1);
		bounds.max = Vector3(1, 1, 1);
	}

	return bounds;
}

/*
	generateSkybox
	- Measures the loaded map's bounds and builds a big inverted cube
		around it, sized to comfortably enclose the whole scene so the
		sky never clips through geometry regardless of map size
	- Requires: loadMap() + buildAllModels() already called (hulls must
		exist), and spawnAllEntities() already called so g_haveSkyEntity /
		g_skyTexture are populated from any "env_skybox" entity
	- No env_skybox entity in the map -> returns false; caller just
		skips drawing a skybox.
*/
bool generateSkybox(float yawRadians = 0.0f, float margin = 2.0f)
{
	version (Android) { enum GLSL_VERSION = 100; }
	else version (Windows) { enum GLSL_VERSION = 330; }
	else version (linux) { enum GLSL_VERSION = 330; }
	else version (OSX) { enum GLSL_VERSION = 330; }
	else { enum GLSL_VERSION = 100; }

	if (g_skyboxLoaded)
	{
		UnloadModel(g_skyboxModel);
		g_skyboxLoaded = false;
	}

	TraceLog(TraceLogLevel.LOG_INFO, "generateSkybox: called, g_haveSkyEntity=%d, g_skyTexture=%s",
		cast(int)g_haveSkyEntity, g_skyTexture.ptr);

	if (!g_haveSkyEntity)
	{
		TraceLog(TraceLogLevel.LOG_WARNING, "generateSkybox: no env_skybox entity in map, skipping");
		return false;
	}

	char[256] path;
	snprintf(path.ptr, path.length, "textures/skybox/%s.png", g_skyTexture.ptr);

	Image img = LoadImage(path.ptr);
	if (img.data is null)
	{
		TraceLog(TraceLogLevel.LOG_WARNING, "generateSkybox: failed to load image: %s", path.ptr);
		return false;
	}

	Texture2D cubemap = LoadTextureCubemap(img, CubemapLayout.CUBEMAP_LAYOUT_AUTO_DETECT);
	UnloadImage(img);

	if (cubemap.id == 0)
	{
		TraceLog(TraceLogLevel.LOG_WARNING, "generateSkybox: LoadTextureCubemap failed for: %s", path.ptr);
		return false;
	}

	BoundingBox bounds = computeMapBounds(yawRadians);
	Vector3 extent = Vector3Subtract(bounds.max, bounds.min);
	float radius = 0.5f * Vector3Length(extent);
	if (radius < 1.0f) radius = 1.0f;
	float side = radius * 2.0f * margin;

	Mesh cube = GenMeshCube(side, side, side);
	g_skyboxModel = LoadModelFromMesh(cube);
	g_skyboxModel.materials[0].maps[MaterialMapIndex.MATERIAL_MAP_CUBEMAP].texture = cubemap;

	Shader skyShader = LoadShader(
		TextFormat("shaders/glsl%d/skybox.vs", GLSL_VERSION),
		TextFormat("shaders/glsl%d/skybox.fs", GLSL_VERSION)
	);
	g_skyboxModel.materials[0].shader = skyShader;

	int envMapValue = MaterialMapIndex.MATERIAL_MAP_CUBEMAP;
	int falseValue = 0;
	SetShaderValue(skyShader, GetShaderLocation(skyShader, "environmentMap".ptr), &envMapValue, ShaderUniformDataType.SHADER_UNIFORM_INT);
	SetShaderValue(skyShader, GetShaderLocation(skyShader, "doGamma".ptr), &falseValue, ShaderUniformDataType.SHADER_UNIFORM_INT);
	SetShaderValue(skyShader, GetShaderLocation(skyShader, "vflipped".ptr), &falseValue, ShaderUniformDataType.SHADER_UNIFORM_INT);

	g_skyboxLoaded = true;
	TraceLog(TraceLogLevel.LOG_INFO, "generateSkybox: built %.1f-unit skybox from %s", side, path.ptr);
	return true;
}
/*
	drawSkybox
	- Draws the skybox centered on the camera so it never appears to
		move relative to the player, with backface culling and depth
		writes disabled so it always renders behind everything else
	- Call first thing inside BeginMode3D/EndMode3D, before other geometry
*/
void drawSkybox(Vector3 cameraPos)
{
	if (!g_skyboxLoaded) return;

	rlDisableBackfaceCulling();
	rlDisableDepthMask();
	DrawModel(g_skyboxModel, cameraPos, 1.0f, Colors.WHITE);
	rlEnableBackfaceCulling();
	rlEnableDepthMask();
}

void unloadSkybox()
{
	if (g_skyboxLoaded)
	{
		UnloadModel(g_skyboxModel);
		g_skyboxLoaded = false;
	}
}