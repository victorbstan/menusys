/*
Interactive hotspot used by the classic image-based menus.

The stock menu artwork contains the option labels, so the button itself is
invisible. When selected, it draws Quake's animated menudot to the left of
the corresponding label.
*/
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
