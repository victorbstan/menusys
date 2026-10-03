// get map description
static string(string fname) getmapdesciption =
{
	float f = fopen(fname, FILE_READ);
	if (f < 0) {
		return __NULL__; //weird
	}
	// Spoike:
	// first 12 bytes of a bsp are {int version; int entofs; int entlen;}
	// if you check that the version is either 29 or the bsp2 value, you can then fseek to the entofs,
	// read entlen bytes from the file, and then parse it however you want (eg with tokenize)

	// Paril:
	// seek to byte 4 of the file, read 4 bytes as int32, read 4 bytes as int32, seek to first number,
	// then you have a string from there of second number len
	// as for how you want to extract the message, that's up to you;
	// you could write a proper key/value pair parser, or just use assumptions
	// for instance, worldspawn should always be the first entity in the list,
	// so the first instance of "message" you find before the first } will belong to it

	// NOTE: pointers don't work in QSS
	// fseek(f, 4);
	// int entofs, entlen;
	// fread(f, &entofs, 4);
	// print(sprintf("entofs: %i\n", entofs));
	// fread(f, &entlen, 4);
	// print(sprintf("entlen: %i\n", entlen)

	// brute force, read every line until match found
	float i;
	for(i=0; ;i++)
	{
		string mapline = fgets(f);
		if not(mapline)
			break;

		// match
		if (strncmp(mapline, "\"message\"", 9) == 0)
		{
			tokenizebyseparator(substring(mapline, 9, strlen(mapline)), "\"");
			string mapdesc = argv(1);
			fclose(f);
			return mapdesc;
		}
	}

	fclose(f);
	return __NULL__;
};

float (mitem_frame fr, float y) listlevelsfor =
{
	float levelnamescale=TXT_NMSZ;

	// search for mod maps to list
	searchhandle sh = search_begin("maps/*.bsp", 2, TRUE);
	if (sh < 0)
		return y;
	float mapsearchsize = search_getsize(sh);
	if (mapsearchsize > 0)
	{
		string fname = "";
		string lmapname = "";
		string lvlcmd = "";
		string mapinfo = "";
		float li;
		for(li=0;li<mapsearchsize;li++)
		{
			fname = __NULL__;
			lmapname = __NULL__;
			lvlcmd = __NULL__;
			mapinfo = __NULL__;

			// get filename
			fname = strzone(search_getfilename(sh,li));

			// parse name out of filepath
			tokenizebyseparator(argv(tokenizebyseparator(fname, "/")-1), ".");
			lmapname = strzone(argv(0));

			// exclude some files that may also be .bsp but are not maps
			if (strtolower(substring(lmapname, 0, 2)) == "b_")
			{
				strunzone(fname);
				strunzone(lmapname);
				continue;
			}

			// The active search path already contains exactly the maps the engine
			// can load. Do not infer a game directory from the package filename:
			// FTE may return an absolute Windows path here, which used to reject
			// every BSP and leave only game-directory headings on this screen.
			mapinfo = getmapdesciption(fname);

			if not(mapinfo)
				mapinfo = strzone(lmapname);
			else
				mapinfo = strzone(strcat(lmapname, " ", XRGB_TXTB, mapinfo));

			// command to load the level
			string argument = classic_filearg(lmapname);
			if (!argument)
			{
				strunzone(fname);
				strunzone(lmapname);
				strunzone(mapinfo);
				continue;
			}
			lvlcmd = strzone(sprintf("m_pop;map %s\n", argument));
			// render level info line
			fr.add(
				spawn(mitem_text, item_text:mapinfo, item_command:lvlcmd, item_scale:levelnamescale,
					item_rgb:RGB_TXT),
				RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
				[0, y], // top left
				[16, levelnamescale]); // bottom right

			y+=levelnamescale+2; // padding for the next line item
			strunzone(fname);
			strunzone(lmapname);
			strunzone(lvlcmd);
			strunzone(mapinfo);
		}
	}
	search_end(sh);

	return y;
};

void(mitem_desktop desktop) M_Levels =
{
	string saveorload = classic_art("gfx/p_levels.lmp", "menugfx/p_levels.lmp");
	float ssx = ui.screensize.x;
	float ssy = ui.screensize.y;
	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;

	// Main menu

	// no dupes please.
	local mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Levels"));
	if (mm) { mm.totop(); return; }
	mm = spawn(mitem_exmenu, item_text:"Levels", item_flags:IF_SELECTABLE, item_command:"m_single");
	desktop.add(mm, RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, [0, 0], [0, 0]);
	desktop.item_focuschange(mm, IF_KFOCUSED);
	mm.totop();

	// Frame menu

	// center h and v
	mitem_frame m = spawn(mitem_frame, item_flags:IF_SELECTABLE, frame_hasscroll:FALSE);
	mm.add(
		m,
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID | RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID, // top-left|bottom-right relation
		[menux*-0.5, menuy*-0.5], // top-left
		[menux*0.5, menuy*0.5] // bottom-right
	);

	// Content

	// banner image
	mitem_pic banner = spawn(mitem_pic, item_text:saveorload, item_flags:IF_CENTERALIGN);
	m.add(banner, RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN, // top-left|bottom-right relation
		[banner.item_size_x*-0.5, padding], // top-left
		[banner.item_size_x*0.5, banner.item_size_y]); // bottom-right

	// bellow banner image, full screen height
	// spawn a container frame for the actual options. this provides a scrollbar if we have too many items.
	mitem_frame fr = spawn(mitem_frame, item_flags: IF_SELECTABLE, frame_hasscroll:TRUE,
		item_framesize_x: padding, // sides
		item_framesize_y: padding, // top
		item_framesize_z: padding // bottom
	);
	m.add(
		fr,
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, // top-left|bottom-right relation
		[0, banner.item_size_y+(padding)], // top-left
		[0, 0] // bottom-right
	);

	float y=0;
	y += listlevelsfor(fr, y);
	if (!y)
		fr.addc(spawn_text(_("No maps found"), "", TXT_NMSZ), 0);

	addmenuback(mm);
};
