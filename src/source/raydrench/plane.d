module raydrench.plane;

import raylib;
import raylib.raymath;
import core.stdc.math : sqrtf;

@nogc nothrow:

/*
	Halfspace
	- a plane stored as (normal, d) such that normal.dot(p) + d == 0 on the
		plane, > 0 in front (outside a brush), < 0 behind (inside a brush)
*/

struct Halfspace
{
	Vector3 normal = Vector3(0, 0, 1);
	float d = 0.0f;

	@nogc nothrow
	static Halfspace fromTriangle(Vector3 a, Vector3 b, Vector3 c)
	{
		Vector3 edge1 = Vector3Subtract(b, a);
		Vector3 edge2 = Vector3Subtract(c, a);
		Vector3 raw = Vector3CrossProduct(edge1, edge2);

		// Guard against degenerate (near-collinear) triangles instead of
		// silently normalizing a near-zero vector into garbage/NaN.
		float lenSq = Vector3DotProduct(raw, raw);
		if (lenSq < 1e-12f)
			return Halfspace(Vector3(0, 0, 1), 0.0f);

		Vector3 n = Vector3Scale(raw, 1.0f / sqrtf(lenSq));
		return Halfspace(n, -Vector3DotProduct(n, a));
	}

	@nogc nothrow
	float distanceTo(Vector3 p) const
	{
		return Vector3DotProduct(normal, p) + d;
	}
}
