module raydrench.transform;

import raylib;
import core.stdc.math : cosf, sinf;

@nogc nothrow:

enum float WORLD_TO_RENDER_SCALE = 0.1f;

/*
	toRenderSpace
	- map editors in the Valve220/TrenchBroom family are Z-up
	- (raylib is Y-up, so (x, y, z) -> (x, z, -y)
	- then applies an optional yaw around the render-space Y axis and a
		uniform scale
*/
Vector3 toRenderSpace(Vector3 p, float scale = WORLD_TO_RENDER_SCALE, float yawRadians = 0.0f)
{
	float rx = p.x;
	float ry = p.z;
	float rz = -p.y;

	float cosYaw = cosf(yawRadians);
	float sinYaw = sinf(yawRadians);

	float rotatedX = rx * cosYaw - rz * sinYaw;
	float rotatedZ = rx * sinYaw + rz * cosYaw;

	return Vector3(rotatedX * scale, ry * scale, rotatedZ * scale);
}
