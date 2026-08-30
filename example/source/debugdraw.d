module raydrench.debugdraw;

import raylib;
import raylib.raymath;

void drawDebugRaycast(Camera3D camera)
{
	enum float RAY_MAX_DISTANCE = 100.0f;

	Vector3 forward = Vector3Normalize(Vector3Subtract(camera.target, camera.position));
	Vector3 right = Vector3Normalize(Vector3CrossProduct(forward, camera.up));

	// offset the origin so the ray isn't collinear with the view axis
	Vector3 origin = Vector3Add(camera.position, Vector3Add(
		Vector3Scale(camera.up, -0.3f),
		Vector3Scale(right, 0.2f)
	));

	Vector3 endPoint = Vector3Add(origin, Vector3Scale(forward, RAY_MAX_DISTANCE));

	DrawLine3D(origin, endPoint, Colors.BLUE);
	DrawSphere(endPoint, 0.2f, Colors.BLUE);
}
