module raydrench.meshbuilder;

import raylib;
import raylib.raymath;
import core.stdc.string : memset;

import raydrench.brush;
import raydrench.geometry : ConvexHull;
import raydrench.maploader : g_scene;
import raydrench.texcache;
import raydrench.transform;

@nogc nothrow:

enum MAX_MODEL_SLOTS = 10000;

__gshared Model[MAX_MODEL_SLOTS] g_models;
__gshared int g_modelCount = 0;

/*
	projectUV
	- computes Valve220-style UV coordinates for a point on a brush face
*/
Vector2 projectUV(Vector3 point, const(FaceDef)* face)
{
	Texture2D tex = getTexture(face.textureName.ptr);
	float texW = tex.width  > 0 ? cast(float) tex.width  : 1.0f;
	float texH = tex.height > 0 ? cast(float) tex.height : 1.0f;

	Vector3 axisU = Vector3(face.axisU.x, face.axisU.y, face.axisU.z);
	Vector3 axisV = Vector3(face.axisV.x, face.axisV.y, face.axisV.z);

	int scaleU = face.scaleU != 0 ? face.scaleU : 1; // guard against a 0 scale in a malformed .map
	int scaleV = face.scaleV != 0 ? face.scaleV : 1;

	float u = Vector3DotProduct(point, axisU) / (texW * scaleU) + face.axisU.w / texW;
	float v = Vector3DotProduct(point, axisV) / (texH * scaleV) + face.axisV.w / texH;

	return Vector2(u, v);
}

/*
	buildAllModels
	- fans every brush face's convex hull into a triangle mesh and uploads it
	One Model per face, transforming vertices into render space as it goes
*/
void buildAllModels(float yawRadians = 0.0f)
{
	foreach (i; 0 .. g_scene.brushCount)
	{
		Brush* b = &g_scene.brushes[i];

		foreach (j; 0 .. b.faceCount)
		{
			ConvexHull* hull = &b.hulls[j];
			if (hull.count < 3) continue;

			FaceDef* face = &b.faces[j];
			Texture2D faceTexture = getTexture(face.textureName.ptr);

			// A triangle fan of N points has exactly N-2 triangles.
			int triCount = hull.count - 2;
			if (triCount < 1) continue;

			Mesh mesh;
			memset(&mesh, 0, Mesh.sizeof);
			mesh.triangleCount = triCount;
			mesh.vertexCount = triCount * 3;
			mesh.vertices  = cast(float*) MemAlloc(mesh.vertexCount * 3 * cast(int) float.sizeof);
			mesh.texcoords = cast(float*) MemAlloc(mesh.vertexCount * 2 * cast(int) float.sizeof);

			int idx = 0;

			for (int k = 1; k < hull.count - 1; k++)
			{
				// Reversed winding order (k+1, k, 0) to make them CCW
				Vector3[3] tri = [
					hull.verts[k + 1],
					hull.verts[k],
					hull.verts[0]
				];
				Vector2[3] uvs = [
					projectUV(tri[0], face),
					projectUV(tri[1], face),
					projectUV(tri[2], face)
				];

				foreach (v; 0 .. 3)
				{
					Vector3 renderPos = toRenderSpace(tri[v], WORLD_TO_RENDER_SCALE, yawRadians);
					mesh.vertices[idx * 3 + 0] = renderPos.x;
					mesh.vertices[idx * 3 + 1] = renderPos.y;
					mesh.vertices[idx * 3 + 2] = renderPos.z;
					mesh.texcoords[idx * 2 + 0] = uvs[v].x;
					mesh.texcoords[idx * 2 + 1] = uvs[v].y;
					idx++;
				}
			}

			UploadMesh(&mesh, false);
			Model model = LoadModelFromMesh(mesh);
			model.materials[0].maps[MaterialMapIndex.MATERIAL_MAP_ALBEDO].texture = faceTexture;

			g_models[g_modelCount++] = model;
		}
	}
}

void drawAllModels()
{
	foreach (i; 0 .. g_modelCount)
	{
		DrawModel(g_models[i], Vector3(0, 0, 0), 1.0f, Colors.WHITE);
	}
}

void drawAllWireframes()
{
	foreach (i; 0 .. g_modelCount)
	{
		DrawModelWires(g_models[i], Vector3(0, 0, 0), 1.0f, Colors.RED);
	}
}

void unloadAllModels()
{
	foreach (i; 0 .. g_modelCount)
	{
		UnloadModel(g_models[i]);
	}
	g_modelCount = 0;
}
