module raydrench.androidinput;

import raylib;
import raylib.raymath;

version(Android):

struct AndroidInputState
{
	Vector2 moveDir = Vector2(0, 0); // -1..1 on each axis, local to dpad
	Vector2 lookDelta = Vector2(0, 0); // accumulated look delta this frame
	bool shootPressed = false;
	bool jumpPressed = false; // true on the frame the button is first touched
	bool jumpHeld = false; // true every frame while held
}

__gshared AndroidInputState g_androidInput;

private enum DPAD_RADIUS = 70.0f;
private enum DPAD_MARGIN = 100.0f;
private enum DPAD_DEADZONE = 12.0f;

private enum SHOOT_BTN_RADIUS = 55.0f;
private enum SHOOT_BTN_MARGIN_X = 100.0f;
private enum SHOOT_BTN_MARGIN_Y = 100.0f;

private enum JUMP_BTN_RADIUS = 55.0f;
private enum JUMP_BTN_MARGIN_X = 100.0f;
private enum JUMP_BTN_MARGIN_Y = 220.0f; // stacked above the shoot button

private enum LOOK_SENSITIVITY = 0.0025f;

// Track per-finger state across frames
private struct TouchTrack
{
	bool active;
	int id;
	Vector2 startPos;
	Vector2 lastPos;
}

private TouchTrack dpadTouch;
private TouchTrack shootTouch;
private TouchTrack jumpTouch;
private TouchTrack lookTouch;

private Vector2 dpadCenter;
private Vector2 shootCenter;
private Vector2 jumpCenter;

void initAndroidInput()
{
	recalcLayout();
}

private void recalcLayout()
{
	int sw = GetScreenWidth();
	int sh = GetScreenHeight();
	dpadCenter = Vector2(DPAD_MARGIN, sh - DPAD_MARGIN);
	shootCenter = Vector2(sw - SHOOT_BTN_MARGIN_X, sh - SHOOT_BTN_MARGIN_Y);
	jumpCenter = Vector2(sw - JUMP_BTN_MARGIN_X, sh - JUMP_BTN_MARGIN_Y);
}

private bool inCircle(Vector2 p, Vector2 center, float radius)
{
	return lenSq(Vector2Subtract(p, center)) <= radius * radius;
}

private float lenSq(Vector2 v)
{
	return v.x * v.x + v.y * v.y;
}

// Call once per frame, before using g_androidInput
void updateAndroidInput()
{
	g_androidInput.lookDelta = Vector2(0, 0);
	g_androidInput.shootPressed = false;
	g_androidInput.jumpPressed = false;

	recalcLayout();

	int sw = GetScreenWidth();

	int count = GetTouchPointCount();

	bool dpadSeen = false;
	bool shootSeen = false;
	bool jumpSeen = false;
	bool lookSeen = false;

	foreach (i; 0 .. count)
	{
		int id = GetTouchPointId(i);
		Vector2 pos = GetTouchPosition(i);
		bool isLeftHalf = pos.x < sw * 0.5f;

		if (isLeftHalf)
		{
			if (!dpadTouch.active)
			{
				dpadTouch.active = true;
				dpadTouch.id = id;
				dpadTouch.startPos = dpadCenter;
				dpadTouch.lastPos = pos;
			}
			if (dpadTouch.active && dpadTouch.id == id)
			{
				dpadSeen = true;
				dpadTouch.lastPos = pos;
			}
		}
		else
		{
			// Claim shoot button
			if (!shootTouch.active && inCircle(pos, shootCenter, SHOOT_BTN_RADIUS))
			{
				shootTouch.active = true;
				shootTouch.id = id;
				shootTouch.startPos = pos;
				shootTouch.lastPos = pos;
			}

			// Claim jump button
			if (!jumpTouch.active && inCircle(pos, jumpCenter, JUMP_BTN_RADIUS))
			{
				jumpTouch.active = true;
				jumpTouch.id = id;
				jumpTouch.startPos = pos;
				jumpTouch.lastPos = pos;
			}

			if (shootTouch.active && shootTouch.id == id)
			{
				shootSeen = true;
			}
			else if (jumpTouch.active && jumpTouch.id == id)
			{
				jumpSeen = true;
			}
			else
			{
				if (!lookTouch.active)
				{
					lookTouch.active = true;
					lookTouch.id = id;
					lookTouch.startPos = pos;
					lookTouch.lastPos = pos;
				}
				if (lookTouch.active && lookTouch.id == id)
				{
					lookSeen = true;
					Vector2 delta = Vector2Subtract(pos, lookTouch.lastPos);
					g_androidInput.lookDelta.x += delta.x * LOOK_SENSITIVITY;
					g_androidInput.lookDelta.y += delta.y * LOOK_SENSITIVITY;
					lookTouch.lastPos = pos;
				}
			}
		}
	}

	if (!dpadSeen) dpadTouch.active = false;
	if (!shootSeen) shootTouch.active = false;
	if (!jumpSeen) jumpTouch.active = false;
	if (!lookSeen) lookTouch.active = false;

	// Compute dpad move vector
	if (dpadTouch.active)
	{
		Vector2 diff = Vector2Subtract(dpadTouch.lastPos, dpadCenter);
		float len = Vector2Length(diff);
		if (len < DPAD_DEADZONE)
		{
			g_androidInput.moveDir = Vector2(0, 0);
		}
		else
		{
			float clamped = len > DPAD_RADIUS ? DPAD_RADIUS : len;
			Vector2 norm = Vector2Scale(diff, 1.0f / len);
			g_androidInput.moveDir = Vector2Scale(norm, clamped / DPAD_RADIUS);
		}
	}
	else
	{
		g_androidInput.moveDir = Vector2(0, 0);
	}

	g_androidInput.shootPressed = shootTouch.active && !wasShootActiveLastFrame;
	wasShootActiveLastFrame = shootTouch.active;

	g_androidInput.jumpHeld = jumpTouch.active;
	g_androidInput.jumpPressed = jumpTouch.active && !wasJumpActiveLastFrame;
	wasJumpActiveLastFrame = jumpTouch.active;
}

private bool wasShootActiveLastFrame = false;
private bool wasJumpActiveLastFrame = false;

void drawAndroidControls()
{
	// Dpad base
	DrawCircleV(dpadCenter, DPAD_RADIUS, Fade(Colors.GRAY, 0.35f));
	DrawCircleLines(cast(int)dpadCenter.x, cast(int)dpadCenter.y, DPAD_RADIUS, Fade(Colors.WHITE, 0.6f));

	// Dpad knob
	Vector2 knobPos = dpadCenter;
	if (dpadTouch.active)
	{
		Vector2 diff = Vector2Subtract(dpadTouch.lastPos, dpadCenter);
		float len = Vector2Length(diff);
		float clamped = len > DPAD_RADIUS ? DPAD_RADIUS : len;
		if (len > 0.001f)
		{
			Vector2 norm = Vector2Scale(diff, 1.0f / len);
			knobPos = Vector2Add(dpadCenter, Vector2Scale(norm, clamped));
		}
	}
	DrawCircleV(knobPos, DPAD_RADIUS * 0.4f, Fade(Colors.LIGHTGRAY, 0.8f));

	// Shoot button
	Color shootColor = shootTouch.active ? Fade(Colors.RED, 0.7f) : Fade(Colors.MAROON, 0.45f);
	DrawCircleV(shootCenter, SHOOT_BTN_RADIUS, shootColor);
	DrawCircleLines(cast(int)shootCenter.x, cast(int)shootCenter.y, SHOOT_BTN_RADIUS, Fade(Colors.WHITE, 0.6f));
	DrawText("F".ptr, cast(int)(shootCenter.x - 22), cast(int)(shootCenter.y - 8), 18, Colors.WHITE);

	// Jump button
	Color jumpColor = jumpTouch.active ? Fade(Colors.SKYBLUE, 0.7f) : Fade(Colors.DARKBLUE, 0.45f);
	DrawCircleV(jumpCenter, JUMP_BTN_RADIUS, jumpColor);
	DrawCircleLines(cast(int)jumpCenter.x, cast(int)jumpCenter.y, JUMP_BTN_RADIUS, Fade(Colors.WHITE, 0.6f));
	DrawText("J".ptr, cast(int)(jumpCenter.x - 24), cast(int)(jumpCenter.y - 8), 18, Colors.WHITE);
}