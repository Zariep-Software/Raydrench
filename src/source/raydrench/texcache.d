module raydrench.texcache;

import raylib;
import core.stdc.stdio : printf, snprintf;
import core.stdc.string : strcmp, strncpy;

import raydrench.constants;

@nogc nothrow:

private struct Entry
{
	char[64] name;
	Texture2D texture;
}

private __gshared Entry[MAX_TEXTURE_SLOTS] cache;
private __gshared int cacheCount = 0;
__gshared Texture2D fallbackTexture; // final fallback if even __TB_empty fails to load

// raylib-supported image extensions, tried in this order
private immutable(char)*[] supportedExtensions = [
	"png", "qoi", "bmp", "tga", "jpg", "gif",
	"psd", "dds", "hdr", "ktx", "astc", "pkm", "pvr"
];

private Texture2D loadFromDisk(const(char)* name)
{
	char[128] path;
	foreach (ext; supportedExtensions)
	{
		snprintf(path.ptr, path.length, "textures/%s.%s", name, ext);

		version(Android)
		{
			Texture2D tex = LoadTexture(path.ptr);
			if (tex.id != 0) return tex;
		}
		else
		{
			if (!FileExists(path.ptr)) continue;
			Texture2D tex = LoadTexture(path.ptr);
			if (tex.id != 0) return tex;
		}
	}
	Texture2D none; none.id = 0;
	return none;
}

private int indexOf(const(char)* name)
{
	foreach (i; 0 .. cacheCount)
	{
		if (strcmp(cache[i].name.ptr, name) == 0) return i;
	}
	return -1;
}

private Texture2D remember(const(char)* name, Texture2D tex)
{
	if (cacheCount >= MAX_TEXTURE_SLOTS)
	{
		printf("Texture cache is full! Returning uncached texture: %s\n", name);
		return tex;
	}
	strncpy(cache[cacheCount].name.ptr, name, 63);
	cache[cacheCount].name[63] = '\0';
	cache[cacheCount].texture = tex;
	cacheCount++;
	return tex;
}

/*
	getTexture
	- looks up `name` in the cache, loading it (trying every supported
		extension) on a miss; falls back to "__TB_empty" and finally to
		`fallbackTexture` if nothing can be loaded.
*/
Texture2D getTexture(const(char)* name)
{
	int idx = indexOf(name);
	if (idx >= 0) return cache[idx].texture;

	Texture2D tex = loadFromDisk(name);
	if (tex.id != 0) return remember(name, tex);

	printf("Failed to load texture '%s' (tried all supported formats)\n", name);

	int fallbackIdx = indexOf("__TB_empty");
	if (fallbackIdx >= 0) return cache[fallbackIdx].texture;

	Texture2D fallback = loadFromDisk("__TB_empty");
	if (fallback.id != 0) return remember("__TB_empty", fallback);

	printf("FATAL: Failed to load fallback texture __TB_empty\n");
	return fallbackTexture;
}
