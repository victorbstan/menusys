/***************************************************************************
Uses the engine command to apply the preset, and tries an exec instead if a config file exists.
Doesn't track the current one or anything.
Really simple and stupid menu.
no background tint, so the game is still visible so you can preview it.
*/

nonstatic void(mitem_desktop desktop) M_Configs =
{
	local float i;

	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;
	float spacing = SPACING;
	float qplaquewidth = 32;
	float plaquepadding = 24;
	float titleoffset = -12;

	// Main menu

	// no dupes please.
	local mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Game Presets"));
	if (mm) { mm.totop(); return; }
	mm = spawn(mitem_exmenu, item_text:_("Game Presets"), item_flags:IF_SELECTABLE|IF_NOCURSOR, item_command:"m_options");
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
	
	mitem_pic banner = spawn(mitem_pic, item_text:"gfx/p_option.lmp", item_size_y:24, item_flags:IF_CENTERALIGN);
	m.add(
		banner,
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN,
		[(banner.item_size_x*-0.5)+titleoffset, padding], [banner.item_size_x*0.5, 24]
	);

	// Content container

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
	
	// Options content

	float posy = 0;
	float posx = -SCRLY;

	// Headline
	fr.addc(spawn_headline("Game Configs"), posy); posy+=TXT_MDSZ+padding;

	float fs;
	fs = search_begin("configs/game_*.cfg", TRUE, TRUE);
	float c = search_getsize(fs);
	for (i = 0; i < c; i++)
	{
		string fname = search_getfilename(fs, i);
		string iname = strzone(substring(fname, 13, -5));
		string dname = GetFirstLineComment(fname, iname);
		iname = sprintf("exec \"%s\"", fname);
		if (dname && !fr.findchildcmd(iname))
			fr.add(spawn(mitem_text, item_text:dname, item_command:iname, item_scale:TXT_NMSZ, item_flags:IF_CENTERALIGN), 
				RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN, 
				[0, posy], [posx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	}
	search_end(fs);
	if (c <= 0)
		fr.add(spawn(mitem_text, item_text:strcat(XRGB_WARNING, "No configs found"), item_scale:TXT_MDSZ, item_flags:IF_CENTERALIGN), 
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN, 
			[0, posy], [posx, TXT_MDSZ]); posy+=TXT_NMSZ+spacing;

	//random art for style
	// m.addm(spawn (mitem_spinnymodel, item_text: "progs/g_rock2.mdl", zbias:-16), [offset_l-60, 12*-16/2], [-60, 12*16/2]);

	addmenuback(m);
};

