/*
Interactive hotspot used by the classic image-based menus.

The stock menu artwork contains the option labels, so the button itself is
invisible. When selected, it draws Quake's animated menudot to the left of
the corresponding label.
*/
// Game-supplied artwork wins over the private packaged fallback. Keeping the
// fallback under menugfx avoids overriding a game's gfx/ assets in the PAK.
string(string gamepic, string fallback) classic_art =
{
	float f = fopen(gamepic, FILE_READ);
	if (f >= 0)
	{
		fclose(f);
		return gamepic;
	}
	return fallback;
};

// LibreQuake 0.09 uses a 172x63 Solo canvas and 116x20 extra rows.
// Their opaque bounds differ: Solo 37..138, Levels 31..112, Demos 45..112.
// Match that artwork profile by size, preserving Quake/Mark V's left alignment
// and leaving differently sized replacement artwork at its authored origin.
float(vector menu_size, vector row_size, float row, float classic_x) classic_solo_x =
{
    if (menu_size.x != 172 || menu_size.y != 63) return classic_x;
    if (row == 0) return (MENU_WIDTH-37-138)*0.5;
    if (row_size.x != 116 || row_size.y != 20) return classic_x;
    if (row == 3) return (MENU_WIDTH-31-112)*0.5;
    return (MENU_WIDTH-45-112)*0.5;
};

// Older QSS builds do not implement argescape. Quote file arguments directly
// and omit names that cannot be represented by the engines' command parser.
string(string filename) classic_filearg =
{
	if (filename == "") return __NULL__;
	if (strstrofs(filename, "\"", 0) >= 0 || strstrofs(filename, "\n", 0) >= 0 || strstrofs(filename, "\r", 0) >= 0)
		return __NULL__;
	return strcat("\"", filename, "\"");
};

class mitem_classicbutton : mitem_filli
{
	virtual void(vector pos) item_draw =
	{
		if (!(item_flags & IF_KFOCUSED))
			return;

		float frame = floor(cltime * 10);
		frame -= floor(frame / 6) * 6;

		string pic = "gfx/menudot6.lmp";
		switch (frame)
		{
		case 0: pic = "gfx/menudot1.lmp"; break;
		case 1: pic = "gfx/menudot2.lmp"; break;
		case 2: pic = "gfx/menudot3.lmp"; break;
		case 3: pic = "gfx/menudot4.lmp"; break;
		case 4: pic = "gfx/menudot5.lmp"; break;
		default: break;
		}

		vector picsize = drawgetimagesize(pic);
		if (picsize_x <= 0 || picsize_y <= 0)
			picsize = [16, 24];

		ui.drawpic(pos + [-18, 0], pic, picsize, '1 1 1', 1, 0);
	};
};

void() classic_menudots_precache =
{
	precache_pic("gfx/menudot1.lmp");
	precache_pic("gfx/menudot2.lmp");
	precache_pic("gfx/menudot3.lmp");
	precache_pic("gfx/menudot4.lmp");
	precache_pic("gfx/menudot5.lmp");
	precache_pic("gfx/menudot6.lmp");
};
