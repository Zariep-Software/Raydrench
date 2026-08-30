module raydrench.maploader;

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib : atoi, realloc;

import raylib;

import raydrench.brush;
import raydrench.entity;
import raydrench.transform;
import raydrench.utils;

enum MAX_LINE_LEN = 1024;

/*
	Scene
	- the full set of brushes parsed from one .map file
*/
struct Scene
{
	int formatVersion;

	Entity* entities;
	int entityCount;
	int entityCapacity;

	@nogc nothrow:

	void reserve(int needed)
	{
		if (needed <= entityCapacity) return;
		int newCap = entityCapacity == 0 ? 32 : entityCapacity * 2;
		if (newCap < needed) newCap = needed;
		entities = cast(Entity*) realloc(entities, newCap * Entity.sizeof);
		foreach (i; entityCapacity .. newCap)
		{
			entities[i] = Entity.init;
		}
		entityCapacity = newCap;
	}

	Entity* add()
	{
		reserve(entityCount + 1);
		entities[entityCount] = Entity.init;
		return &entities[entityCount++];
	}

	// Convenience: total brush count across every entity, for e.g.
	// collision iteration that doesn't care which entity owns what.
	int totalBrushCount() const
	{
		int n = 0;
		foreach (i; 0 .. entityCount) n += entities[i].brushCount;
		return n;
	}
}

__gshared Scene g_scene; // currently loaded map

@nogc nothrow:

private char* trimLine(char* raw)
{
	char* s = raw;
	while (*s == ' ' || *s == '\t') s++;

	size_t len = strlen(s);
	while (len > 0 && (s[len - 1] == '\n' || s[len - 1] == '\r' || s[len - 1] == ' ' || s[len - 1] == '\t'))
	{
		s[len - 1] = '\0';
		len--;
	}
	return s;
}

private bool parseFaceLine(const(char)* line, out FaceDef face)
{
	char[64] texname;
	int matched = sscanf(line,
		"( %f %f %f ) ( %f %f %f ) ( %f %f %f ) %63s [ %f %f %f %f ] [ %f %f %f %f ] %i %i %i",
		&face.a.x, &face.a.y, &face.a.z,
		&face.b.x, &face.b.y, &face.b.z,
		&face.c.x, &face.c.y, &face.c.z,
		texname.ptr,
		&face.axisU.x, &face.axisU.y, &face.axisU.z, &face.axisU.w,
		&face.axisV.x, &face.axisV.y, &face.axisV.z, &face.axisV.w,
		&face.rotationDegrees, &face.scaleU, &face.scaleV);

	if (matched != 21) return false;

	strncpy(face.textureName.ptr, texname.ptr, face.textureName.length);
	face.textureName[face.textureName.length - 1] = '\0';
	return true;
}

private void finalizeBrush(ref Brush b)
{
	// Build polygons in raw .map space.
	b.buildPolygons();

	// Re-express face positions (and therefore cached halfspaces) in
	// render space, so per-frame collision matches the drawn geometry.
	foreach (j; 0 .. b.faceCount)
	{
		b.faces[j].a = toRenderSpace(b.faces[j].a);
		b.faces[j].b = toRenderSpace(b.faces[j].b);
		b.faces[j].c = toRenderSpace(b.faces[j].c);
	}
	b.refreshHalfspaces();
}

/*
	loadMap
	filename[const char*] filename under maps/, e.g. "test.map"
	- parses a Valve220-format .map file into g_scene as a list of
		Entity blocks (worldspawn included), each carrying its own
		key/value pairs and the brushes nested inside its { }.
*/
bool loadMap(const(char)* filename)
{
	char[256] fullPath;
	snprintf(fullPath.ptr, fullPath.length, "maps/%s", filename);

	FILE* file = fopen(fullPath.ptr, "r");
	if (!file)
	{
		perror("Failed to open .map file");
		printf("Tried searching in: %s\n", fullPath.ptr);
		return false;
	}
	printf("Loading map: %s\n", fullPath.ptr);

	char[MAX_LINE_LEN] lineBuf;
	bool inEntity = false;
	bool inBrush = false;
	Entity* currentEntity = null;
	Brush currentBrush;

	while (fgets(lineBuf.ptr, MAX_LINE_LEN, file) !is null)
	{
		char* t = trimLine(lineBuf.ptr);
		if (t[0] == '\0') continue;
		if (t[0] == '/' && t[1] == '/') continue; // comment

		if (stringsEqual(t, "{"))
		{
			if (inEntity && !inBrush)
			{
				inBrush = true;
				currentBrush = Brush.init;
			}
			else if (!inEntity)
			{
				inEntity = true;
				currentEntity = g_scene.add();
			}
			continue;
		}

		if (stringsEqual(t, "}"))
		{
			if (inBrush)
			{
				finalizeBrush(currentBrush);
				currentEntity.addBrush(currentBrush);
				inBrush = false;
			}
			else if (inEntity)
			{
				// Transform entity origin from Z-up map space to Y-up render space
				// to match the brush geometry (which is transformed in finalizeBrush)
				currentEntity.origin = toRenderSpace(currentEntity.origin);
				TraceLog(TraceLogLevel.LOG_INFO, "Entity '%s' origin (render space): %.2f %.2f %.2f",
					currentEntity.classname.ptr,
					currentEntity.origin.x, currentEntity.origin.y, currentEntity.origin.z);

				inEntity = false;
				currentEntity = null;
			}
			continue;
		}

		if (inEntity && !inBrush)
		{
			char[MAX_KEY_LEN] key;
			char[MAX_VALUE_LEN] value;
			if (sscanf(t, "\"%31[^\"]\" \"%127[^\"]\"", key.ptr, value.ptr) == 2)
			{
				currentEntity.addPair(key.ptr, value.ptr);

				if (stringsEqual(key.ptr, "mapversion"))
				{
					g_scene.formatVersion = atoi(value.ptr);
					printf("Map version: %i\n", g_scene.formatVersion);
				}
			}
			continue;
		}

		if (inBrush)
		{
			FaceDef f;
			if (parseFaceLine(t, f))
				currentBrush.addFace(f);
			else
				printf("!!! Failed to parse brush face: %s\n", t);
		}
	}
	fclose(file);

	printf("Loaded %i entities, %i brushes\n", g_scene.entityCount, g_scene.totalBrushCount);
	return true;
}

void unloadMap()
{
	foreach (i; 0 .. g_scene.entityCount)
	{
		g_scene.entities[i].free_();
	}
	g_scene.entityCount = 0;
}
