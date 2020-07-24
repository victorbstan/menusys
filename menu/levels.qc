//I'm feeling lazy, so I'm going to only provide X slots, like quake's menu.
// static string levels[] = {};

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

		float w = stringwidth(item_text, (engine==E_QSS?FALSE:TRUE), '1 1 0'*item_scale);
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

static string(string modname) scanlevels =
{
	string v;
	string l = 0;
	string filepath = sprintf("saves/%s/info.fsv", modname);
	float f = fopen(filepath, FILE_READ);
	if (f < 0)
		f = fopen(sprintf("%s.sav", modname), FILE_READ);
	if (f < 0)
		return __NULL__;	//weird
	
	v = fgets(f); //should be the version
	l = fgets(f); //description
	fclose(f);

	if (l)
	{
		l = strreplace("_", " ", l);
		// get modificaton date
		filepath = sprintf("%s.sav", modname); // correct path
		searchhandle sh = search_begin(filepath, TRUE, TRUE);
		if (sizeof(sh) > 0) {
			string moddt = search_getfilemtime(sh,0); // get date time
			// "%Y-%m-%d %H:%M:%S"
		}
		search_end(sh);
	}
	
	return l;
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

	// float i;
	float y=0;
	float modnamescale=10;
	float levelnamescale=8;

	float modscount = tokenizebyseparator(cvar_string("game"), ";"); 
	string currentgame = "";
	// gets last mod loaded
	for (float i = 0; i < modscount; i++)
	{
		currentgame = strtolower(argv(i));
	}
	// a default...
	if (currentgame == "" || currentgame == "fte") currentgame = "id1";

	float idirs;
	for (idirs = 0; ; idirs++)
	{
		// Game dir info
		string gamedir = getgamedirinfo(idirs, GGDI_GAMEDIR);
		if not(gamedir) // carefull...
			break;
		string desc = getgamedirinfo(idirs, GGDI_DESCRIPTION);
		string info = getgamedirinfo(idirs, GGDI_GAMEDIRLIST);
		string modcmd = getgamedirinfo(idirs, GGDI_LOADCOMMAND);
		// string icon = getgamedirinfo(idirs, GGDI_ICON);

		gamedir = strtolower(gamedir);
		
		float hasperiodinname = tokenizebyseparator(gamedir, ".") > 1;
		// basic dir name filtering for undesireable characters
		if (substring(gamedir, 0, 1) != "." && substring(gamedir, 0, 2) != ".." && hasperiodinname == 0) 
		{
			if (desc=="")
				desc = sprintf("^m%s", gamedir);
			else
				desc = sprintf("^m%s ^h%s", desc, gamedir);	//include the gamedir, faded somewhat.
			
			if not(modcmd) //for dp users, if they somehow run this
				modcmd = sprintf("gamedir %s", gamedir);
			// command to load the mod and open the levels menu again
			modcmd = strcat("m_pop;", modcmd, "; m_levels;\n");

			if (gamedir != "") 
			{
				// render mod info line
				fr.add(
					spawn(mitem_text, item_text:desc, item_command:modcmd, item_scale:modnamescale),
					RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
					[0, y], // top left
					[16, modnamescale]); // bottom right

				y+=modnamescale+2; // padding for the next line item

				// print(sprintf("gamedir: %s, currentgame: %s\n", gamedir, currentgame));
				if (currentgame == gamedir) 
				{
					// search for mod maps to list
					// print(sprintf("Searching for: %s\n", gamedir));
					searchhandle sh = search_begin("maps/*.bsp", 2, TRUE);
					if (search_getsize(sh) > 0)
					{
						float li;
						for(li=0;li<search_getsize(sh);li++)
						{
							// get filename
							string fname = search_getfilename(sh,li);
							// print(sprintf("fname: %s\n", fname)); // DEBUG
							// extract mod name from package path (id1): "id1/pack0.pak"
							string pkname = search_getpackagename(sh,li);
							// print(sprintf("idx %f, pkname: %s\n", li, pkname)); // DEBUG

							// parse name out of filepath
							tokenizebyseparator(argv(tokenizebyseparator(fname, "/")-1), "."); 
							string mapname = argv(0);
							print(sprintf("mapname: %s\n", mapname)); // DEBUG

							// exclude some files that may also be .bsp but are not maps
							if (strtolower(substring(mapname, 0, 2)) == "b_")
								continue;
							
							tokenizebyseparator(pkname, "/");
							string pkrootdir = argv(0);
							print(sprintf("gamedir: %s - pkrootdir: %s\n", gamedir, pkrootdir)); // DEBUG

							if (gamedir != pkrootdir)
								continue;
								
							// TODO: get more info on levels:
							// Spoike
							// first 12 bytes of a bsp are {int version; int entofs; int entlen;}
							// if you check that the version is either 29 or the bsp2 value, you can then fseek to the entofs, 
							// read entlen bytes from the file, and then parse it however you want (eg with tokenize)

							// command to load the level
							string lvlcmd = strcat("m_pop; map ", mapname, ";\n");
							// render level info line
							fr.add(
								spawn(mitem_text, item_text:mapname, item_command:lvlcmd, item_scale:levelnamescale, 
									item_rgb:RGB_TXT),
								RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
								[0, y], // top left
								[16, levelnamescale]); // bottom right

							y+=levelnamescale+2; // padding for the next line item
						}
					}
					search_end(sh);
				}
			}
		}
	}

	addmenuback(m);
};

