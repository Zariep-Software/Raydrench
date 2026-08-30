module raydrench.entity;

import raylib;
import core.stdc.string : strncpy, strcmp;
import core.stdc.stdlib : realloc, free, strtof;

import raydrench.brush;

@nogc nothrow:

enum MAX_CLASSNAME_LEN = 64;
enum MAX_KEY_LEN = 32;
enum MAX_VALUE_LEN = 128;

struct KeyValue
{
	char[MAX_KEY_LEN] key;
	char[MAX_VALUE_LEN] value;
}

struct Entity
{
	char[MAX_CLASSNAME_LEN] classname;

	KeyValue* pairs;
	int pairCount;
	int pairCapacity;

	Brush* brushes;
	int brushCount;
	int brushCapacity;

	Vector3 origin;
	bool spawned;

	@nogc nothrow
	void addPair(const(char)* key, const(char)* value)
	{
		if (pairCount >= pairCapacity)
		{
			int newCap = pairCapacity == 0 ? 8 : pairCapacity * 2;
			pairs = cast(KeyValue*) realloc(pairs, newCap * KeyValue.sizeof);
			pairCapacity = newCap;
		}
		strncpy(pairs[pairCount].key.ptr, key, MAX_KEY_LEN - 1);
		pairs[pairCount].key[MAX_KEY_LEN - 1] = '\0';
		strncpy(pairs[pairCount].value.ptr, value, MAX_VALUE_LEN - 1);
		pairs[pairCount].value[MAX_VALUE_LEN - 1] = '\0';
		pairCount++;

		if (strcmp(key, "classname") == 0)
		{
			strncpy(classname.ptr, value, MAX_CLASSNAME_LEN - 1);
			classname[MAX_CLASSNAME_LEN - 1] = '\0';
		}
		else if (strcmp(key, "origin") == 0)
		{
			const(char)* p = value;
			origin.x = strtof(p, &p);
			origin.y = strtof(p, &p);
			origin.z = strtof(p, &p);
		}
	}

	@nogc nothrow
	void addBrush(Brush b)
	{
		if (brushCount >= brushCapacity)
		{
			int newCap = brushCapacity == 0 ? 4 : brushCapacity * 2;
			brushes = cast(Brush*) realloc(brushes, newCap * Brush.sizeof);
			brushCapacity = newCap;
		}
		brushes[brushCount++] = b;
	}

	@nogc nothrow
	const(char)* get(const(char)* key, const(char)* fallback = "") const
	{
		foreach (i; 0 .. pairCount)
		{
			if (strcmp(pairs[i].key.ptr, key) == 0) return pairs[i].value.ptr;
		}
		return fallback;
	}

	@nogc nothrow
	int getInt(const(char)* key, int fallback = 0) const
	{
		const(char)* v = get(key, null);
		if (v is null) return fallback;
		import core.stdc.stdlib : atoi;
		return atoi(v);
	}

	@nogc nothrow
	float getFloat(const(char)* key, float fallback = 0.0f) const
	{
		const(char)* v = get(key, null);
		if (v is null) return fallback;
		return strtof(v, null);
	}

	@nogc nothrow
	void free_()
	{
		foreach (i; 0 .. brushCount) brushes[i].free_();
		if (pairs)   free(pairs);
		if (brushes) free(brushes);
		pairs = null; brushes = null;
		pairCount = pairCapacity = 0;
		brushCount = brushCapacity = 0;
	}
}

// ------------------------------------------------------------------
// Spawn registry
// ------------------------------------------------------------------

alias SpawnFn = void function(Entity*) @nogc nothrow;

private struct Registration
{
	char[MAX_CLASSNAME_LEN] classname;
	SpawnFn fn;
}

enum MAX_REGISTERED_CLASSES = 256;
private __gshared Registration[MAX_REGISTERED_CLASSES] g_registry;
private __gshared int g_registryCount = 0;

@nogc nothrow
void registerEntity(string classname, SpawnFn fn)
{
	assert(g_registryCount < MAX_REGISTERED_CLASSES, "entity registry full");
	strncpy(g_registry[g_registryCount].classname.ptr, classname.ptr, MAX_CLASSNAME_LEN - 1);
	g_registry[g_registryCount].classname[MAX_CLASSNAME_LEN - 1] = '\0';
	g_registry[g_registryCount].fn = fn;
	g_registryCount++;
}

@nogc nothrow
private SpawnFn findSpawnFn(const(char)* classname)
{
	foreach (i; 0 .. g_registryCount)
	{
		if (strcmp(g_registry[i].classname.ptr, classname) == 0)
			return g_registry[i].fn;
	}
	return null;
}

@nogc nothrow
void spawnEntity(Entity* e)
{
	if (e.spawned) return;
	SpawnFn fn = findSpawnFn(e.classname.ptr);
	if (fn !is null) fn(e);
	e.spawned = true;
}

@nogc nothrow
void spawnAllEntities(Entity[] entities)
{
	foreach (ref e; entities) spawnEntity(&e);
}