module raydrench.brush;

import raylib;
import raylib.raymath;
import core.stdc.stdlib : realloc, free;
import core.stdc.stdio : printf;
import core.stdc.math : fabs;

import raydrench.plane;
import raydrench.geometry;

@nogc nothrow:

struct FaceDef
{
	Vector3 a, b, c;
	char[64] textureName;
	Vector4 axisU;
	Vector4 axisV;
	int rotationDegrees;
	int scaleU = 1;
	int scaleV = 1;

	@nogc nothrow
	Halfspace toHalfspace() const
	{
		return Halfspace.fromTriangle(a, b, c);
	}

	void debugPrint(int index) const
	{
		printf("Face %i: %s\n", index, textureName.ptr);
	}
}

struct Brush
{
	FaceDef* faces;
	Halfspace* halfspaces;
	ConvexHull* hulls;

	int faceCount;
	int faceCapacity;

	@nogc nothrow
	void reserve(int needed)
	{
		if (needed <= faceCapacity) return;
		int newCap = faceCapacity == 0 ? 16 : faceCapacity * 2;
		if (newCap < needed) newCap = needed;

		faces = cast(FaceDef*) realloc(faces, newCap * FaceDef.sizeof);
		halfspaces = cast(Halfspace*) realloc(halfspaces, newCap * Halfspace.sizeof);
		hulls = cast(ConvexHull*) realloc(hulls, newCap * ConvexHull.sizeof);

		foreach (i; faceCapacity .. newCap)
		{
			hulls[i] = ConvexHull.init;
		}

		faceCapacity = newCap;
	}

	@nogc nothrow
	void addFace(FaceDef f)
	{
		reserve(faceCount + 1);
		faces[faceCount] = f;
		halfspaces[faceCount] = f.toHalfspace();
		faceCount++;
	}

	@nogc nothrow
	void refreshHalfspaces()
	{
		foreach (i; 0 .. faceCount) halfspaces[i] = faces[i].toHalfspace();
	}

	/*
		buildPolygon seed a massive bounding box, and clip it against every plane
		EXCEPT the target plane to reveal the face polygon.
	*/
	@nogc nothrow
	void buildPolygons()
	{
		foreach (i; 0 .. faceCapacity) hulls[i].clear();
		if (faceCount < 4) return;

		enum float BOUNDS = 32768.0f;

		for (int i = 0; i < faceCount; i++)
		{
			hulls[i].clear();

			// Get the plane normal
			Vector3 n = halfspaces[i].normal;

			// Pick a stable "up" reference that isn't parallel to n
			Vector3 up = (fabs(n.x) < 0.9f) ? Vector3(1, 0, 0) : Vector3(0, 1, 0);

			// Create an orthonormal basis (tangent and bitangent) lying on the plane
			Vector3 tangent  = Vector3Normalize(Vector3CrossProduct(up, n));
			Vector3 bitangent = Vector3CrossProduct(n, tangent);

			// Calculate a center point directly from the halfspace equation:
			// n . p + d == 0  =>  p0 = -d * n
			Vector3 p0 = Vector3Scale(n, -halfspaces[i].d);

			// Build a massive quad on this plane that is guaranteed to encompass any brush
			Vector3 right = Vector3Scale(tangent, BOUNDS);
			Vector3 fwd   = Vector3Scale(bitangent, BOUNDS);

			hulls[i].add(Vector3Subtract(Vector3Subtract(p0, right), fwd));
			hulls[i].add(Vector3Subtract(Vector3Add(p0, right), fwd));
			hulls[i].add(Vector3Add(Vector3Add(p0, right), fwd));
			hulls[i].add(Vector3Add(Vector3Subtract(p0, right), fwd));

			// Clip away everything outside of the other planes to reveal the face polygon
			for (int j = 0; j < faceCount; j++)
			{
				if (i == j) continue;

				ConvexHull clipped = hulls[i].clipToHalfspace(halfspaces[j]);
				hulls[i].free_();
				hulls[i] = clipped;

				if (hulls[i].count == 0) break; // Fully clipped, move to next face
			}
		}
	}

	@nogc nothrow
	void free_()
	{
		foreach (i; 0 .. faceCapacity)
		{
			hulls[i].free_();
		}

		if (faces)      free(faces);
		if (halfspaces) free(halfspaces);
		if (hulls)      free(hulls);
		faces = null;
		halfspaces = null;
		hulls = null;
		faceCount = faceCapacity = 0;
	}
}