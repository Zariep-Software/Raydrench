module raydrench.pickups;

import raylib;

import raydrench.entity;

struct Pickup
{
	Vector3 position;
	int healAmount;
	bool collected;
}

enum MAX_PICKUPS = 256;
__gshared Pickup[MAX_PICKUPS] g_pickups;
__gshared int g_pickupCount = 0;

__gshared Model g_medkitModel;
__gshared bool g_medkitModelLoaded = false;

@nogc nothrow
void spawnHealthPack(Entity* e)
{
	if (g_pickupCount >= MAX_PICKUPS) return;

	g_pickups[g_pickupCount].position = e.origin;
	g_pickups[g_pickupCount].healAmount = e.getInt("heal_amount", 25);
	g_pickups[g_pickupCount].collected = false;
	g_pickupCount++;
}

void loadMedkitModel()
{
	version(Android)
	{
		//TODO:FIXME
		// raylib's OBJ/MTL loader is trying to do chdir() to resolve relative
		// texture paths, even if i don't even use those textures
		g_medkitModelLoaded = false;
		return;
	}
	else
	{
		g_medkitModel = LoadModel("models/medkit.obj");
		g_medkitModelLoaded = (g_medkitModel.meshCount > 0);

		if (!g_medkitModelLoaded)
		{
			TraceLog(TraceLogLevel.LOG_WARNING, "Failed to load models/medkit.obj");
			return;
		}

		bool hasRealTexture = false;
		foreach (i; 0 .. g_medkitModel.materialCount)
		{
			Texture2D tex = g_medkitModel.materials[i].maps[MaterialMapIndex.MATERIAL_MAP_ALBEDO].texture;
			if (tex.id != 0)
			{
				hasRealTexture = true;
				break;
			}
		}

		if (hasRealTexture)
			return;

		TraceLog(TraceLogLevel.LOG_WARNING,
			"medkit.obj loaded but no diffuse texture was bound (check medkit.mtl's map_Kd path)");

		if (fileExists("models/medkit.png"))
		{
			Texture2D fallback = LoadTexture("models/medkit.png");
			if (fallback.id != 0)
			{
				foreach (i; 0 .. g_medkitModel.materialCount)
				{
					SetMaterialTexture(&g_medkitModel.materials[i], MaterialMapIndex.MATERIAL_MAP_ALBEDO, fallback);
				}
				TraceLog(TraceLogLevel.LOG_INFO, "Applied fallback texture models/medkit.png to medkit model");
			}
		}
	}
}

void unloadMedkitModel()
{
	if (g_medkitModelLoaded)
		UnloadModel(g_medkitModel);
}

void drawPickups(float spinDegrees)
{
	foreach (ref pk; g_pickups[0 .. g_pickupCount])
	{
		if (pk.collected) continue;

		if (g_medkitModelLoaded)
		{
			DrawModelEx(
				g_medkitModel,
				pk.position,
				Vector3(0, 1, 0),
				spinDegrees,
				Vector3(1.0f, 1.0f, 1.0f),
				Colors.WHITE
			);
		}
		else
		{
			DrawCube(pk.position, 0.5f, 0.5f, 0.5f, Colors.RED);
			DrawCubeWires(pk.position, 0.5f, 0.5f, 0.5f, Colors.WHITE);
		}
	}
}
