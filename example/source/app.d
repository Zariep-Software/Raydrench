module raydrench.main;

import raylib;
import raylib.raymath;

import raydrench.constants;
import raydrench.maploader;
import raydrench.meshbuilder;
import raydrench.collision;
import raydrench.texcache;

import std.string : startsWith, toStringz;

enum WINDOW_WIDTH = 1280;
enum WINDOW_HEIGHT = 720;
enum WINDOW_TITLE = "Raydrench";
enum TARGET_FPS = 240;

void main(string[] args)
{
	InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE);
	SetTargetFPS(TARGET_FPS);
	DisableCursor();

	string mapPath = "test.map";
	bool solid = false;

	foreach (arg; args[1 .. $])
	{
		if (arg == "--solid")
		{
			solid = true;
		}
		else
		{
			mapPath = arg;
		}
	}
	fallbackTexture = LoadTexture("textures/__TB_empty.png");

	if (!loadMap(mapPath.toStringz))
	{
		CloseWindow();
		return;
	}

	buildAllModels();

	Camera3D camera;
	camera.position = Vector3(10.0f, 10.0f, 10.0f);
	camera.target = Vector3(0.0f, 0.0f, 0.0f);
	camera.up = Vector3(0.0f, 1.0f, 0.0f);
	camera.fovy = 60.0f;
	camera.projection = CameraProjection.CAMERA_PERSPECTIVE;

	bool wireframe = false;

	while (!WindowShouldClose())
	{
		if (!IsCursorHidden())
		{
			DisableCursor();
		}

		updateCameraFree(&camera, GetFrameTime());

		if (solid)
		{
			Vector3 beforeResolve = camera.position;

			resolvePlayerCollisions(&camera.position);

			Vector3 correction = Vector3Subtract(camera.position, beforeResolve);

			camera.target = Vector3Add(camera.target, correction);
		}

		if (IsKeyPressed(KeyboardKey.KEY_TAB))
		{
			wireframe = !wireframe;
		}

		BeginDrawing();
		ClearBackground(Colors.BLACK);

		BeginMode3D(camera);

		if (wireframe)
			drawAllWireframes();
		else
			drawAllModels();

		DrawGrid(60, 1.0f);

		EndMode3D();

		DrawFPS(10, 10);

		EndDrawing();
	}

	unloadAllModels();
	unloadMap();
	CloseWindow();
}


void updateCameraFree(Camera3D* camera, float dt)
{
	enum float MOVE_SPEED = 20.0f;
	enum float MOUSE_SENSITIVITY = 0.003f;

	Vector2 mouseDelta = GetMouseDelta();

	Vector3 forward =
		Vector3Normalize(
			Vector3Subtract(camera.target, camera.position)
		);

	Vector3 right =
		Vector3Normalize(
			Vector3CrossProduct(forward, camera.up)
		);

	forward = Vector3RotateByAxisAngle(
		forward,
		camera.up,
		-mouseDelta.x * MOUSE_SENSITIVITY
	);

	forward = Vector3RotateByAxisAngle(
		forward,
		right,
		-mouseDelta.y * MOUSE_SENSITIVITY
	);


	camera.target = Vector3Add(camera.position, forward);


	right =
		Vector3Normalize(
			Vector3CrossProduct(forward, camera.up)
		);


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
		move = Vector3Scale(
			Vector3Normalize(move),
			speed
		);

		camera.position = Vector3Add(camera.position, move);
		camera.target = Vector3Add(camera.target, move);
	}
}