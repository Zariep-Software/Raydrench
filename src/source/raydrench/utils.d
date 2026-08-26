module raydrench.utils;

import core.stdc.string : strcmp;

@nogc nothrow:

bool stringsEqual(const(char)* a, const(char)* b)
{
	return strcmp(a, b) == 0;
}
