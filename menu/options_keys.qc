const static struct
{
	string name;
	string cmd;
} binds[] =
{
	{_("Forwards"), 		"+forward"},
	{_("Back"),	 			"+back"},
	{_("Move Left"),		"+moveleft"},
	{_("Move Right"),		"+moveright"},
	{_("Turn Left"),		"+left"},
	{_("Turn Right"),		"+right"},
	{_("Look Up"),			"+lookup"},
	{_("Look Down"),		"+lookdown"},
	{_("Swim Up"),			"+moveup"},
	{_("Swim Down"),		"+movedown"},
	{_("Center view"),		"centerview"},
	{_("Jump"),	 			"+jump"},
	{_("Attack"),	 		"+attack"},
	{_("Next Weapon"),		"impulse 10"},
	{_("Prev Weapon"),		"impulse 12"},
	{_("Scores"),			"+showscores"},
	{_("Server Chat"),		"messagemode"},
	{_("Team Chat"),		"messagemode2"},
	{_("Voice Chat"),		"+voip"},
	{_("Mouse Look"),		"+mlook"},
	{_("Keyboard Look"),	"+klook"},
	{_("Strafe"),			"+strafe"},
	{_("Run"),				"+speed"},
	{0,						0},
	{_("Axe"),				"impulse 1"},
	{_("Shotgun"),			"impulse 2"},
	{_("Super Shotgun"),	"impulse 3"},
	{_("Nailgun"),			"impulse 4"},
	{_("Super Nailgun"),	"impulse 5"},
	{_("Grenade Launcher"),	"impulse 6"},
	{_("Rocket Launcher"),	"impulse 7"},
	{_("Lightning Gun"),	"impulse 8"},
//	{_("Railgun"),			"impulse 9"},

	{0,						0},
	{_("Ready Up"),			"ready"},
	{_("Break Match"),		"break"},
};
void(mitem_desktop desktop) M_Options_Keys =
{

	// float h;

	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;
	float spacing = SPACING;
	float qplaquewidth = 32;
	float plaquepadding = 24;
	float titleoffset = -12;

	// Main menu
	
	// no dupes please.
	mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Key Options"));
	if (mm) { mm.totop(); return; }
	// create a fullscreen frame
	mm = spawn(mitem_exmenu, item_text:_("Key Options"), item_flags:IF_SELECTABLE|IF_NOCURSOR, item_command:"m_options");
	desktop.add(mm, RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, '0 0', '0 0');
	desktop.item_focuschange(mm, IF_KFOCUSED);
	mm.totop();

	// Frame menu

	mitem_frame m = spawn(mitem_frame, item_flags:IF_SELECTABLE|IF_NOCURSOR, frame_hasscroll:FALSE);
	mm.add(
		m,
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID | RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID, // top-left|bottom-right relation
		[menux*-0.5, menuy*-0.5], // top-left
		[menux*0.5, menuy*0.5] // bottom-right
	);

	// Title
	
	mitem_pic banner = spawn(mitem_pic, item_text:"gfx/ttl_cstm.lmp", item_size_y:24, item_flags:IF_CENTERALIGN);
	m.add(
		banner,
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN,
		[(banner.item_size_x*-0.5)+titleoffset, padding], [banner.item_size_x*0.5, 24]
	);

	// Content

	// spawn a container frame for the actual options. this provides a scrollbar if we have too many items.
	mitem_frame fr = spawn(mitem_frame, item_flags: IF_SELECTABLE, frame_hasscroll:TRUE,
		item_framesize_x: padding, // sides
		item_framesize_y: padding, // top
		item_framesize_z: padding // bottom
	);
	m.add(
		fr,
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, // top-left|bottom-right relation
		[0, banner.item_size_y+padding], // top-left
		[0, 0] // bottom-right
	);
	
	// Options

	float posy = 0;
	float posx = 0;
	float maxposx = -SCRLY-padding;
	float optionswidth = menux-SCRLY;
	vector optionsize = [optionswidth, TXT_NMSZ];

	// Headline

	fr.addc(spawn_headline("Enter to change, Backspace to clear"), posy); posy+=TXT_MDSZ+padding;

	posy += padding;

	// Key bindings

	float i;
	float f = fopen("bindlist.lst", FILE_READ);
	if (f >= 0)
	{
		//throw a load of bind options onto it by reading from the array.
		for (i = 0; ; )
		{
			string line = fgets(f);
			if not (line)
				break;	//eof
			float args = tokenize(line);
			if (!args)
				continue;	//blank line
			string c = argv(0);
			string n = argv(1);
			string t = argv(2);
			if (c == "-")	//command only
			{
				if (n != "")
				{
					mitem it = spawn_text(n, "", TXT_NMSZ);
					it.item_flags &= ~IF_SELECTABLE;
					fr.add(it, 
						RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN, 
						[posx, posy], it.item_size); posy+=TXT_NMSZ+spacing;
				}
			}
			else
			{
				fr.add(spawn_bind(n, c, optionsize), 
					RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN, 
					[posx, posy], [0, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
			}
			i += 8;
		}
		fclose(f);
	}
	else
	{
		//throw a load of bind options onto it by reading from the array.
		for (i = 0; i < sizeof(binds) / sizeof(binds[0]); i++)
		{
			if (binds[i].name == "") //no name is a spacer
				continue;
			fr.add(spawn_bind(binds[i].name, binds[i].cmd, optionsize), 
				RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN, 
				[posx, posy], [0, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		}
	}
	
	addmenuback(mm);
};
