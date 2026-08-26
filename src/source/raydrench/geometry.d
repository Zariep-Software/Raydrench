module raydrench.geometry;

import raylib;
import raylib.raymath;
import core.stdc.stdlib : malloc, realloc, free;
import raydrench.plane;

@nogc nothrow:

/*
	ConvexHull
		- Represents a 2D manifold polygon in 3D space.
		- Uses Sutherland-Hodgman clipping
*/
struct ConvexHull
{
	Vector3* verts;
	int count;
	int capacity;

	@nogc nothrow
	void grow(int needed)
	{
		if (needed <= capacity) return;
		int newCap = capacity == 0 ? 8 : capacity * 2;
		if (newCap < needed) newCap = needed;
		verts = cast(Vector3*) realloc(verts, newCap * Vector3.sizeof);
		capacity = newCap;
	}

	@nogc nothrow
	void add(Vector3 v)
	{
		grow(count + 1);
		verts[count++] = v;
	}

	@nogc nothrow
	void clear()
	{
		count = 0;
	}

	@nogc nothrow
	void free_()
	{
		if (verts) free(verts);
		verts = null;
		count = 0;
		capacity = 0;
	}

	/*
		clipToHalfspace
		- Sutherland-Hodgman algorithm. Clips this polygon to the
			inside (negative side) of the provided halfspace
		- Returns a new ConvexHull containing the resulting geometry
	*/
	@nogc nothrow
	ConvexHull clipToHalfspace(Halfspace hs) const
	{
		ConvexHull result;
		result.clear();
		if (count == 0) return result;

		for (int i = 0; i < count; i++)
		{
			Vector3 current = verts[i];
			Vector3 next = verts[(i + 1) % count];

			float d0 = hs.distanceTo(current);
			float d1 = hs.distanceTo(next);

			// Valve220 normals point INWARD, so distance >= 0 means INSIDE the brush
			if (d0 >= 0.0f)
			{
				result.add(current);
			}

			// edge crosses the plane boundary, find and add the intersection
			if ((d0 > 0.0f && d1 < 0.0f) || (d0 < 0.0f && d1 > 0.0f))
			{
				float t = d0 / (d0 - d1);
				result.add(Vector3Add(current, Vector3Scale(Vector3Subtract(next, current), t)));
			}
		}
		return result;
	}
}