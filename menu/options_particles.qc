//menu that configues r_particledesc according to the files available in the particles/ subdir, including the (known) internal effects.

class particlesmenu : mitem_frame
{
	string thelist;
	void() particlesmenu =
	{
		thelist = cvar_string("r_particledesc");
	};
	virtual void() item_remove =
	{
		cvar_set("r_particledesc", thelist);
	};
	
	//to reconfigure colours for when something changees.
	nonvirtual void() UpdateSelections =
	{
		float sc = tokenize(thelist);
		for (mitem ch = item_children; ch; ch = ch.item_next)
		{
			ch.item_rgb = '1 0.5 0.5';
			for (float i = 0; i < sc; i++)
			{
				if (!strcasecmp(argv(i), ch.item_command))
				{
					ch.item_rgb = '1 1 1';
					break;
				}
			}
		}
	};
	virtual void(mitem fromitem, string cmd) item_execcommand =
	{
		float sc = tokenize(thelist);
		for (float i = 0; i < sc; i++)
		{
			if (!strcasecmp(argv(i), cmd))
			{
				thelist = strtrim(strcat(strtrim(substring(thelist, 0, argv_start_index(i))), " ", strtrim(substring(thelist, argv_end_index(i), -1))));
				UpdateSelections();
				return;
			}
		}
		
		if (strstrofs(cmd, "\t") >= 0 || strstrofs(cmd, " ") >= 0 || strstrofs(cmd, "\"") >= 0 || strstrofs(cmd, ";") >= 0 || strstrofs(cmd, "\n") >= 0)
			thelist = strtrim(strcat(thelist, " \"", cmd, "\""));
		else
			thelist = strtrim(strcat(thelist, " ", cmd));
		UpdateSelections();
	};
};

string(string fname, string dflt) GetFirstLineComment =
{
	float f = fopen(fname, FILE_READ);
	if (f < 0)
		return 0;
	string l = strtrim(fgets(f));
	fclose(f);
	if (!strcasecmp(substring(l, 0, 9), "//private"))
		return 0;
	if (!strcasecmp(substring(l, 0, 8), "//hidden"))
		return 0;
	if (!strcasecmp(substring(l, 0, 7), "//desc:"))
		return strtrim(substring(l, 7, -1));
//	if (substring(l, 0, 1) == "#")
//		return strtrim(substring(l, 1, -1));
	return dflt;
};

nonstatic void(mitem_desktop desktop) M_Options_Particles =
{
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
	mm = (mitem_exmenu)desktop.findchildtext(_("Particles"));
	if (mm) { mm.totop(); return; }
	// create a fullscreen frame
	mm = spawn(mitem_exmenu, item_text:_("Particles"), item_flags:IF_SELECTABLE|IF_NOCURSOR, item_command:"m_options");
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

	// Content

	// spawn a container frame for the actual options. this provides a scrollbar if we have too many items.
	mitem_frame ffr = spawn(mitem_frame, item_flags: IF_SELECTABLE, frame_hasscroll:TRUE,
		item_framesize_x: padding, // sides
		item_framesize_y: padding, // top
		item_framesize_z: padding // bottom
	);
	m.add(
		ffr,
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
	ffr.addc(spawn_headline("Particles"), posy); posy+=TXT_MDSZ+padding;
	
	// Special frame for particles option
	particlesmenu fr = spawn(particlesmenu, item_flags: IF_SELECTABLE, frame_hasscroll:FALSE);
	ffr.add(
		fr, 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, 
		[0, 0], // top-left
		[0, 0] // bottom-right
	);

	float fl = RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN;

	//FIXME: this stuff should be listed in order of selection, to reflect the priorities given to the various effects.
	//FIXME: these should not be listed if its a no-compat/no-legacy build. this'll do for now, but its a bit wrong
	if (checkextension("FTE_PART_NAMESPACE_EFFECTINFO"))
	{
		fr.add(spawn(mitem_text, item_text:"Classic Particles",	item_command:"classic", item_scale:TXT_NMSZ, item_flags:IF_CENTERALIGN), 
			fl, [posx, posy], [0, TXT_NMSZ]); posy += TXT_NMSZ+spacing;
		fr.add(spawn(mitem_text, item_text:"High Quality",	item_command:"high", item_scale:TXT_NMSZ, item_flags:IF_CENTERALIGN), 
			fl, [posx, posy], [0, TXT_NMSZ]); posy += TXT_NMSZ+spacing;
		fr.add(spawn(mitem_text, item_text:"TimeServ's Shaft", item_command:"tsshaft", item_scale:TXT_NMSZ, item_flags:IF_CENTERALIGN), 
			fl, [posx, posy], [0, TXT_NMSZ]); posy += TXT_NMSZ+spacing;
	
		string efi = GetFirstLineComment("effectinfo.txt", "Effectinfo");
		if (efi) {
			fr.add(spawn(mitem_text, item_text:efi, item_command:"effectinfo", item_scale:TXT_NMSZ, item_flags:IF_CENTERALIGN), 
				fl, [posx, posy], [0, TXT_NMSZ]); posy += TXT_NMSZ+spacing; }
	}

	float fs;
	fs = search_begin("particles/*.cfg", TRUE, TRUE);	
	for (float c = search_getsize(fs), float i = 0; i < c; i++)
	{
		string fname = search_getfilename(fs, i);
		string iname = substring(fname, 10, -5);
		string dname = GetFirstLineComment(fname, iname);
		if (dname && !fr.findchildcmd(iname)) {
			fr.add(spawn(mitem_text, item_text:dname, item_command:iname, item_scale:TXT_NMSZ, item_flags:IF_CENTERALIGN), 
				fl, [posx, posy], [0, TXT_NMSZ]); posy += TXT_NMSZ+spacing; }
	}
	search_end(fs);
	fs = search_begin("particles/*/*.cfg", TRUE, TRUE);	
	for (float c = search_getsize(fs), float i = 0; i < c; i++)
	{
		string fname = search_getfilename(fs, i);
		string iname = substring(fname, 10, -5);
		string dname = GetFirstLineComment(fname, iname);
		if (dname && !fr.findchildcmd(iname)) {
			fr.add(spawn(mitem_text, item_text:dname, item_command:iname, item_scale:TXT_NMSZ, item_flags:IF_CENTERALIGN), 
				fl, [posx, posy], [0, TXT_NMSZ]); posy += TXT_NMSZ+spacing; }
	}
	search_end(fs);

	fr.UpdateSelections();

	// extra spacing for drop-downs
	fr.add(spawn_mitem_spacer(16, -1), 
		fl, [posx, posy], [maxposx, 24]);

	addmenuback(m);
};
