module raydrench.main;
import raylib;
import raylib.raymath;
import raydrench.constants;
import raydrench.maploader;
import raydrench.meshbuilder;
import raydrench.collision;
import raydrench.texcache;
import raydrench.entity;
import raydrench.player;
import raydrench.projectiles;
import raydrench.pickups;
import raydrench.hud;
import raydrench.debugdraw;
version(Android) import raydrench.androidinput;
import core.stdc.string : strcmp;
import core.stdc.math : cosf, sinf;

enum WINDOW_WIDTH = 1280;
enum WINDOW_HEIGHT = 720;
enum WINDOW_TITLE = "Raydrench";
enum TARGET_FPS = 240;

extern(C) int main(int argc, char** argv)
{
	runGame(argc, argv);
	return 0;
}

void runGame(int argc, char** argv)
{
	version(Android)
	{
		InitWindow(0, 0, WINDOW_TITLE.ptr);
	}
	else
	{
		InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE.ptr);
	}

	SetTargetFPS(TARGET_FPS);
	version(Android) {} else DisableCursor();

	const(char)* mapPath = "test.map".ptr;
	bool solid = false;
	bool playerMode = false;
	foreach (i; 1 .. argc)
	{
		const(char)* arg = argv[i];
		if (strcmp(arg, "--solid".ptr) == 0)
			solid = true;
		else if (strcmp(arg, "--player".ptr) == 0)
			playerMode = true;
		else
			mapPath = arg;
	}

	if (playerMode)
		solid = true;

	version(Android)
	{
		playerMode = true;
		solid = true;
	}

	fallbackTexture = LoadTexture("textures/__TB_empty.png".ptr);
	registerEntity("info_player_start", &spawnPlayerStart);
	registerEntity("item_health", &spawnHealthPack);

	if (!loadMap(mapPath))
	{
		CloseWindow();
		return;
	}
	buildAllModels();

	loadMedkitModel();

	Camera3D camera;
	Vector3 startPos = g_havePlayerStart ? g_playerStartPos : Vector3(10.0f, 10.0f, 10.0f);
	float startYaw = g_havePlayerStart ? g_playerStartYaw : 0.0f;
	if (playerMode)
		startPos = Vector3Add(startPos, Vector3(0, EYE_HEIGHT, 0));
	camera.position = startPos;
	Vector3 startForward = Vector3(sinf(startYaw), 0, -cosf(startYaw));
	camera.target = Vector3Add(camera.position, startForward);
	camera.up = Vector3(0.0f, 1.0f, 0.0f);
	camera.fovy = 60.0f;
	camera.projection = CameraProjection.CAMERA_PERSPECTIVE;

	if (playerMode)
		initPlayerPhysics(&camera, startYaw);

	version(Android)
		initAndroidInput();

	bool wireframe = false;
	float medkitSpinAngle = 0.0f;

	while (!WindowShouldClose())
	{
		version(Android) {} else
		{
			if (!IsCursorHidden())
				DisableCursor();
		}

		float dt = GetFrameTime();

		version(Android)
			updateAndroidInput();

		if (playerMode)
		{
			updatePlayerPhysics(&camera, dt);
			g_playerStartPos = camera.position;
		}
		else
		{
			updateCameraFree(&camera, dt);
			if (solid)
			{
				Vector3 beforeResolve = camera.position;
				resolvePlayerCollisions(&camera.position);
				Vector3 correction = Vector3Subtract(camera.position, beforeResolve);
				camera.target = Vector3Add(camera.target, correction);
			}
			g_playerStartPos = camera.position;
		}

		medkitSpinAngle += dt * 90.0f;
		if (medkitSpinAngle >= 360.0f) medkitSpinAngle -= 360.0f;

		foreach (ref pk; g_pickups[0 .. g_pickupCount])
		{
			if (pk.collected) continue;
			if (Vector3Distance(camera.position, pk.position) < 1.5f)
			{
				pk.collected = true;
				g_playerHealth += pk.healAmount;
				if (g_playerHealth > 100) g_playerHealth = 100;
			}
		}

		updateProjectiles(dt);

		version(Android)
		{
			if (playerMode && g_androidInput.shootPressed)
			{
				Vector3 forward = Vector3Normalize(Vector3Subtract(camera.target, camera.position));
				spawnProjectile(camera.position, forward);
			}
		}
		else
		{
			if (playerMode && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT))
			{
				Vector3 forward = Vector3Normalize(Vector3Subtract(camera.target, camera.position));
				spawnProjectile(camera.position, forward);
			}
		}

		if (IsKeyPressed(KeyboardKey.KEY_TAB))
			wireframe = !wireframe;

		BeginDrawing();
		ClearBackground(Colors.BLACK);
		BeginMode3D(camera);
		if (wireframe)
			drawAllWireframes();
		else
			drawAllModels();
		drawPickups(medkitSpinAngle);
		drawProjectiles();
		if (playerMode)
			drawDebugRaycast(camera);
		DrawGrid(60, 1.0f);
		EndMode3D();

		if (playerMode)
		{
			drawHUD();
			version(Android)
				drawAndroidControls();
		}
		else
		{
			DrawFPS(10, 10);
		}
		EndDrawing();
	}

	unloadMedkitModel();
	unloadAllModels();
	unloadMap();
	CloseWindow();
}