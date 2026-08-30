module raydrench.player;

import raylib;
import raylib.raymath;

import raydrench.collision;
import raydrench.entity;

import core.stdc.stdlib : strtof;
import core.stdc.math : cosf, sinf;

enum float GRAVITY = 30.0f;
enum float JUMP_SPEED = 9.0f;
enum float WALK_SPEED = 12.0f;
enum float RUN_MULTIPLIER = 1.8f;
enum float MOUSE_SENSITIVITY = 0.003f;
enum float EYE_HEIGHT = 1.7f;

__gshared Vector3 g_playerStartPos = Vector3(0, 0, 0);
__gshared float g_playerStartYaw = 0.0f;
__gshared bool g_havePlayerStart = false;

__gshared float g_playerYaw = 0.0f;
__gshared float g_playerPitch = 0.0f;
__gshared float g_playerVerticalVelocity = 0.0f;
__gshared bool g_playerGrounded = false;

__gshared int g_playerHealth = 100;

@nogc nothrow
void spawnPlayerStart(Entity* e)
{
	g_playerStartPos = e.origin;
	g_havePlayerStart = true;

	const(char)* anglesStr = e.get("angles", "0 0 0");
	const(char)* p = anglesStr;
	strtof(p, &p);
	float yawDegrees = strtof(p, &p);
	g_playerStartYaw = yawDegrees * (3.14159265f / 180.0f);
}

void initPlayerPhysics(Camera3D* camera, float startYaw)
{
	g_playerYaw = startYaw;
	g_playerPitch = 0.0f;
	g_playerVerticalVelocity = 0.0f;
	g_playerGrounded = false;
	g_playerHealth = 100;
}

void updatePlayerPhysics(Camera3D* camera, float dt)
{
	Vector2 mouseDelta = GetMouseDelta();

	g_playerYaw += mouseDelta.x * MOUSE_SENSITIVITY;
	g_playerPitch -= mouseDelta.y * MOUSE_SENSITIVITY;

	enum float PITCH_LIMIT = 1.5f;
	if (g_playerPitch > PITCH_LIMIT) g_playerPitch = PITCH_LIMIT;
	if (g_playerPitch < -PITCH_LIMIT) g_playerPitch = -PITCH_LIMIT;

	Vector3 forward = Vector3(
		sinf(g_playerYaw) * cosf(g_playerPitch),
		sinf(g_playerPitch),
		-cosf(g_playerYaw) * cosf(g_playerPitch)
	);

	Vector3 flatForward = Vector3Normalize(Vector3(sinf(g_playerYaw), 0, -cosf(g_playerYaw)));
	Vector3 flatRight = Vector3Normalize(Vector3CrossProduct(flatForward, Vector3(0, 1, 0)));

	float speed = WALK_SPEED;
	if (IsKeyDown(KeyboardKey.KEY_LEFT_SHIFT))
		speed *= RUN_MULTIPLIER;

	Vector3 move = Vector3Zero();

	if (IsKeyDown(KeyboardKey.KEY_W))
		move = Vector3Add(move, flatForward);
	if (IsKeyDown(KeyboardKey.KEY_S))
		move = Vector3Subtract(move, flatForward);
	if (IsKeyDown(KeyboardKey.KEY_D))
		move = Vector3Add(move, flatRight);
	if (IsKeyDown(KeyboardKey.KEY_A))
		move = Vector3Subtract(move, flatRight);

	if (Vector3Length(move) > 0.0f)
		move = Vector3Scale(Vector3Normalize(move), speed * dt);

	if ((IsKeyDown(KeyboardKey.KEY_LEFT_CONTROL) || IsKeyDown(KeyboardKey.KEY_RIGHT_CONTROL)) && IsKeyDown(KeyboardKey.KEY_SPACE))
	{
		g_playerVerticalVelocity = JUMP_SPEED;
		g_playerGrounded = false;
	}
	else if (g_playerGrounded && IsKeyPressed(KeyboardKey.KEY_SPACE))
	{
		g_playerVerticalVelocity = JUMP_SPEED;
		g_playerGrounded = false;
	}

	g_playerVerticalVelocity -= GRAVITY * dt;

	Vector3 delta = Vector3(move.x, g_playerVerticalVelocity * dt, move.z);
	camera.position = Vector3Add(camera.position, delta);

	Vector3 beforeResolve = camera.position;
	resolvePlayerCollisions(&camera.position);
	Vector3 correction = Vector3Subtract(camera.position, beforeResolve);

	enum float GROUND_PUSH_THRESHOLD = 0.001f;
	if (correction.y > GROUND_PUSH_THRESHOLD)
	{
		g_playerGrounded = true;
		g_playerVerticalVelocity = 0.0f;
	}
	else
	{
		g_playerGrounded = false;
	}

	camera.target = Vector3Add(camera.position, forward);
}

void updateCameraFree(Camera3D* camera, float dt)
{
	enum float MOVE_SPEED = 20.0f;
	enum float SENS = 0.003f;

	Vector2 mouseDelta = GetMouseDelta();

	Vector3 forward =
		Vector3Normalize(
			Vector3Subtract(camera.target, camera.position)
		);

	Vector3 right =
		Vector3Normalize(
			Vector3CrossProduct(forward, camera.up)
		);

	forward = Vector3RotateByAxisAngle(forward, camera.up, -mouseDelta.x * SENS);
	forward = Vector3RotateByAxisAngle(forward, right, -mouseDelta.y * SENS);

	camera.target = Vector3Add(camera.position, forward);

	right = Vector3Normalize(Vector3CrossProduct(forward, camera.up));

	float speed = MOVE_SPEED * dt;
	if (IsKeyDown(KeyboardKey.KEY_LEFT_SHIFT))
		speed *= 3.0f;

	Vector3 move = Vector3Zero();

	if (IsKeyDown(KeyboardKey.KEY_W))
		move = Vector3Add(move, forward);
	if (IsKeyDown(KeyboardKey.KEY_S))
		move = Vector3Subtract(move, forward);
	if (IsKeyDown(KeyboardKey.KEY_D))
		move = Vector3Add(move, right);
	if (IsKeyDown(KeyboardKey.KEY_A))
		move = Vector3Subtract(move, right);
	if (IsKeyDown(KeyboardKey.KEY_SPACE))
		move = Vector3Add(move, camera.up);
	if (IsKeyDown(KeyboardKey.KEY_LEFT_CONTROL))
		move = Vector3Subtract(move, camera.up);

	if (Vector3Length(move) > 0.0f)
	{
		move = Vector3Scale(Vector3Normalize(move), speed);
		camera.position = Vector3Add(camera.position, move);
		camera.target = Vector3Add(camera.target, move);
	}
}
