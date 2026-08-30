module raydrench.hud;

import raylib;

import raydrench.player : g_playerHealth, g_playerStartPos;
import raydrench.projectiles : g_projectiles;

import std.string : toStringz;
import std.format : format;

void drawHUD()
{
	int activeBullets = 0;
	foreach (ref proj; g_projectiles)
	{
		if (proj.active) activeBullets++;
	}

	Rectangle hudBg = { 10, 10, 260, 120 };
	DrawRectangleRec(hudBg, Color(0, 0, 0, 150));

	DrawText(toStringz(format("Health: %d", g_playerHealth)), 20, 20, 20, Colors.WHITE);
	DrawText(toStringz(format("Bullets: %d", activeBullets)), 20, 50, 20, Colors.WHITE);
	DrawText(toStringz(format("X: %.2f", g_playerStartPos.x)), 20, 80, 20, Colors.WHITE);
	DrawText(toStringz(format("Y: %.2f", g_playerStartPos.y)), 140, 80, 20, Colors.WHITE);
}
