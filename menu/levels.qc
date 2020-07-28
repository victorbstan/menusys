// defined until the official support is released
string(searchhandle handle, float num) search_getpackagename = #0;

class mitem_levelsoption : mitem_text
{
	string slot;
	string pic;

	virtual void() mitem_levelsoption =
	{
		item_flags |= IF_SELECTABLE;
	};

	virtual void(vector pos) item_draw =
	{
		// if (pic)
		// 	drawpic(pos, pic, [item_size_y,item_size_y], '1 1 1', 1, 0); 
		// pos_x += item_size_y;
		// super::item_draw(pos);

		//some sort of pulsing if its active.
		if (item_flags & IF_KFOCUSED)
			ui.drawfill(pos, item_size, '1 0 0', sin(cltime)*0.125+0.150, 0);

		float w = stringwidth(item_text, TRUE, '1 1 0'*item_scale);
		ui.drawstring(pos + [(item_size_x-w)/2, 0], item_text, '1 1 0' * item_scale, menuitem_textcolour(this), item_alpha, 0);
	};

	virtual float(vector pos, float scan, float char, float down) item_keypress =
	{
		if (!down)
			return FALSE;
		if (scan == K_ENTER || (scan == K_MOUSE1 && mouseinbox(pos, this.item_size)))
		{
			if (item_flags & IF_KFOCUSED)
			{
				localcmd(sprintf("m_pop;load %s\n", slot));
			}
			else
			{
				item_parent.item_focuschange(this, IF_KFOCUSED);
			}
			return TRUE;
		}
		return FALSE;
	};
};

// get map description
static string(string fname, string pkname) getmapdesciption =
{
	float f = fopen(fname, FILE_READ);
	if (f < 0) {
		fclose(f);
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

float (string gamedir, mitem_frame fr, float y) listlevelsfor =
{
	float levelnamescale=TXT_NMSZ;

	// search for mod maps to list
	searchhandle sh = search_begin("maps/*.bsp", 2, TRUE);
	float mapsearchsize = search_getsize(sh);
	if (mapsearchsize > 0)
	{
		string fname = "";
		string pkname = "";
		string pkrootdir = "";
		string mapname = "";
		string lvlcmd = "";
		string mapinfo = "";
		float li;
		for(li=0;li<mapsearchsize;li++)
		{
			fname = __NULL__;
			pkname = __NULL__;
			pkrootdir = __NULL__;
			mapname = __NULL__;
			lvlcmd = __NULL__;
			mapinfo = __NULL__;

			// get filename
			fname = strzone(search_getfilename(sh,li));

			// parse name out of filepath
			tokenizebyseparator(argv(tokenizebyseparator(fname, "/")-1), "."); 
			mapname = strzone(argv(0));

			// exclude some files that may also be .bsp but are not maps
			if (strtolower(substring(mapname, 0, 2)) == "b_")
				continue;

			if (checkbuiltin2(search_getpackagename, FALSE)) 
			{
				// extract mod name from package path (id1): "id1/pack0.pak"
				pkname = strzone(search_getpackagename(sh,li));
				
				tokenizebyseparator(pkname, "/");
				pkrootdir = strzone(argv(0));

				if (gamedir != pkrootdir)
					continue;

				// get map description
				mapinfo = getmapdesciption(fname, pkname);
			}
		
			if not(mapinfo)
				mapinfo = strzone(mapname);
			else
				mapinfo = strzone(strcat(mapname, " ", XRGB_TXTB, mapinfo));

			// command to load the level
			lvlcmd = strzone(strcat("m_pop; map ", mapname, ";\n"));
			// render level info line
			fr.add(
				spawn(mitem_text, item_text:mapinfo, item_command:lvlcmd, item_scale:levelnamescale, 
					item_rgb:RGB_TXT),
				RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
				[0, y], // top left
				[16, levelnamescale]); // bottom right

			y+=levelnamescale+2; // padding for the next line item
		}
		strunzone(fname);
		strunzone(pkname);
		strunzone(mapname);
		strunzone(lvlcmd);
		strunzone(pkrootdir);
		strunzone(mapinfo);
	}
	search_end(sh);

	return y;
};

float(mitem_frame fr, float y) listmodsandlevels =
{
	float modnamescale=TXT_LGSZ;
	
	float idirs;
	string gamedir = "";
	string desc = "";
	string info = "";
	string modcmd = "";
	for (idirs = 0; ; idirs++)
	{
		gamedir = __NULL__;
		desc = __NULL__;
		info = __NULL__;
		modcmd = __NULL__;

		// Game dir info
		gamedir = getgamedirinfo(idirs, GGDI_GAMEDIR);
		if not(gamedir) // end of loop
			break;
		desc = getgamedirinfo(idirs, GGDI_DESCRIPTION);
		info = strzone(getgamedirinfo(idirs, GGDI_GAMEDIRLIST));
		modcmd = getgamedirinfo(idirs, GGDI_LOADCOMMAND);
		// string icon = getgamedirinfo(idirs, GGDI_ICON);

		gamedir = strzone(strtolower(gamedir));

		// basic dir name filtering for undesireable characters
		float hasperiodinname = tokenizebyseparator(gamedir, ".") > 1;
		if (substring(gamedir, 0, 1) == "." || substring(gamedir, 0, 2) == ".." || hasperiodinname > 0)
			continue;
		
		if (desc=="")
			desc = sprintf("^m%s", gamedir);
		else
			desc = sprintf("^m%s ^h%s", desc, gamedir); //include the gamedir, faded somewhat.
		desc = strzone(desc);

		if not(modcmd) //for dp users, if they somehow run this
			modcmd = sprintf("gamedir %s", gamedir);
		// command to load the mod and open the levels menu again
		modcmd = strcat("m_pop;", modcmd, "; m_levels;\n");
		modcmd = strzone(modcmd);

		if (gamedir == "")
			continue;
		
		// render mod info line
		fr.add(
			spawn(mitem_text, item_text:desc, item_command:modcmd, item_scale:modnamescale),
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[0, y], // top left
			[16, modnamescale]); // bottom right

		y+=modnamescale+2; // padding for the next line item

		// Get loaded mods

		string currentgame = "";
		float modscount = tokenizebyseparator(cvar_string("game"), ";");
		// gets last mod loaded
		for (float i = 0; i < modscount; i++)
		{
			currentgame = strzone(strtolower(argv(i)));
			if (currentgame == "")
				return y;
			if (currentgame == gamedir) 
				y = listlevelsfor(gamedir, fr, y);
		}
		strunzone(currentgame);
		
	}
	strunzone(gamedir);
	strunzone(desc);
	strunzone(info);
	strunzone(modcmd);

	return y;
};

void(mitem_desktop desktop) M_Levels =
{
	string saveorload = "menugfx/levels.lmp";
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
	mitem_pic banner = spawn(mitem_pic, item_text:saveorload, item_size_y:24, item_flags:IF_CENTERALIGN);
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
	y += listmodsandlevels(fr, y);

	addmenuback(m);
};

