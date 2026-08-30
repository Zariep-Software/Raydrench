module raydrench.projectiles;

import raylib;
import raylib.raymath;

import raydrench.collision;

enum TRAIL_LENGTH = 12;
enum DOT_INTERVAL = 0.02f;
enum MAX_DOTS_PER_PROJ = 150;

struct TrailDot
{
	Vector3 position;
	bool active;
}

struct Projectile
{
	Vector3 position;
	Vector3 velocity;
	float lifetime;
	float dotTimer;
	bool active;

	TrailDot[MAX_DOTS_PER_PROJ] dots;
	int dotWriteIndex;
}

enum MAX_PROJECTILES = 64;
enum PROJECTILE_SPEED = 40.0f;
enum PROJECTILE_LIFETIME = 3.0f;
enum PROJECTILE_RADIUS = 0.2f;

__gshared Projectile[MAX_PROJECTILES] g_projectiles;

void spawnProjectile(Vector3 origin, Vector3 direction)
{
	foreach (ref proj; g_projectiles)
	{
		if (proj.active) continue;

		proj.position = origin;
		proj.velocity = Vector3Scale(Vector3Normalize(direction), PROJECTILE_SPEED);
		proj.lifetime = PROJECTILE_LIFETIME;
		proj.active = true;
		proj.dotTimer = 0.0f;
		proj.dotWriteIndex = 0;

		foreach (ref dot; proj.dots)
		{
			dot.active = false;
		}

		return;
	}
}

void updateProjectiles(float dt)
{
	foreach (ref proj; g_projectiles)
	{
		if (!proj.active) continue;

		Vector3 nextPos = Vector3Add(proj.position, Vector3Scale(proj.velocity, dt));

		Vector3 testPos = Vector3(nextPos.x, proj.position.y, proj.position.z);
		Vector3 resolvedX = testPos;
		resolvePlayerCollisions(&resolvedX);
		if (resolvedX.x != nextPos.x) proj.velocity.x *= -1.0f;

		testPos = Vector3(proj.position.x, nextPos.y, proj.position.z);
		Vector3 resolvedY = testPos;
		resolvePlayerCollisions(&resolvedY);
		if (resolvedY.y != nextPos.y) proj.velocity.y *= -1.0f;

		testPos = Vector3(proj.position.x, proj.position.y, nextPos.z);
		Vector3 resolvedZ = testPos;
		resolvePlayerCollisions(&resolvedZ);
		if (resolvedZ.z != nextPos.z) proj.velocity.z *= -1.0f;

		proj.position = Vector3Add(proj.position, Vector3Scale(proj.velocity, dt));
		proj.lifetime -= dt;

		proj.dotTimer += dt;
		if (proj.dotTimer >= DOT_INTERVAL)
		{
			proj.dotTimer -= DOT_INTERVAL;

			proj.dots[proj.dotWriteIndex].position = proj.position;
			proj.dots[proj.dotWriteIndex].active = true;

			proj.dotWriteIndex++;
			if (proj.dotWriteIndex >= MAX_DOTS_PER_PROJ)
				proj.dotWriteIndex = 0;
		}

		if (proj.lifetime <= 0.0f)
		{
			proj.active = false;
		}
	}
}

void drawProjectiles()
{
	foreach (ref proj; g_projectiles)
	{
		if (!proj.active) continue;

		foreach (ref dot; proj.dots)
		{
			if (!dot.active) continue;
			DrawSphere(dot.position, 0.05f, Colors.GREEN);
		}

		DrawSphere(proj.position, PROJECTILE_RADIUS, Colors.WHITE);
		DrawSphere(proj.position, PROJECTILE_RADIUS * 2.0f, Color(255, 200, 50, 120));
	}
}
