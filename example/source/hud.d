module raydrench.hud;

import raylib;

import raydrench.player : g_playerHealth, g_playerStartPos;
import raydrench.projectiles : g_projectiles;

import core.stdc.stdio : sprintf;

// Helper to write integers into a buffer for betterC compatibility
private char* itoa(int value, char* buffer)
{
	if (value == 0)
	{
		buffer[0] = '0';
		buffer[1] = '\0';
		return buffer;
	}

	int i = 0;
	bool isNeg = value < 0;
	if (isNeg) value = -value;

	while (value > 0)
	{
		buffer[i++] = (value % 10) + '0';
		value /= 10;
	}
	if (isNeg) buffer[i++] = '-';

	buffer[i] = '\0';

	// Reverse string
	int len = i;
	for (int j = 0; j < len / 2; j++)
	{
		char tmp = buffer[j];
		buffer[j] = buffer[len - j - 1];
		buffer[len - j - 1] = tmp;
	}

	return buffer;
}

void drawHUD()
{
	int activeBullets = 0;
	foreach (ref proj; g_projectiles)
	{
		if (proj.active) activeBullets++;
	}

	Rectangle hudBg = { 10, 10, 260, 120 };
	DrawRectangleRec(hudBg, Color(0, 0, 0, 150));

	char[64] buf;

	char[16] numBuf;

	sprintf(buf.ptr, "Health: %s", itoa(g_playerHealth, numBuf.ptr));
	DrawText(buf.ptr, 20, 20, 20, Colors.WHITE);

	sprintf(buf.ptr, "Bullets: %s", itoa(activeBullets, numBuf.ptr));
	DrawText(buf.ptr, 20, 50, 20, Colors.WHITE);

	sprintf(buf.ptr, "X: %.2f", g_playerStartPos.x);
	DrawText(buf.ptr, 20, 80, 20, Colors.WHITE);

	sprintf(buf.ptr, "Y: %.2f", g_playerStartPos.y);
	DrawText(buf.ptr, 140, 80, 20, Colors.WHITE);
}