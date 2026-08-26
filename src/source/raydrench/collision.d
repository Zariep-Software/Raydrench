module raydrench.collision;

import raylib;
import raylib.raymath;

import raydrench.maploader : g_scene;
import raydrench.brush;

@nogc nothrow:

enum float PLAYER_RADIUS = 0.5f;

enum int RESOLUTION_PASSES = 4;

void resolvePlayerCollisions(Vector3* pos)
{
	foreach (_; 0 .. RESOLUTION_PASSES)
	{
		bool anyPush = false;
		foreach (i; 0 .. g_scene.brushCount)
		{
			if (resolveAgainstBrush(&g_scene.brushes[i], pos))
				anyPush = true;
		}
		if (!anyPush) break; // early out once the player has settled
	}
}

// Pushes *pos out of a single brush along its shallowest-penetration face
private bool resolveAgainstBrush(Brush* b, Vector3* pos)
{
	float minPenetration = float.max;
	Vector3 pushNormal;
	bool inside = true;

	foreach (j; 0 .. b.faceCount)
	{
		// brush halfspace normals face inward (outside == positive
		// distance per Halfspace's convention); collision wants outward
		// push normals, hence the negation.
		Vector3 outwardNormal = Vector3Negate(b.halfspaces[j].normal);
		float dist = Vector3DotProduct(outwardNormal, *pos) - b.halfspaces[j].d;

		if (dist > PLAYER_RADIUS)
		{
			inside = false; break;
		}

		float depth = PLAYER_RADIUS - dist;
		if (depth < minPenetration)
		{
			minPenetration = depth;
			pushNormal = outwardNormal;
		}
	}

	if (inside && minPenetration > 0.0f && minPenetration < float.max)
	{
		*pos = Vector3Add(*pos, Vector3Scale(pushNormal, minPenetration));
		return true;
	}
	return false;
}
