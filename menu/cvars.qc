#include "../menusys/mitem_grid.qc"

class mitem_cvargrid : mitem_grid
{
	strbuf grid_buf_names; //left column (
	static void(strbuf newbuf) grid_setbuf =
	{
		if (grid_buf_names >= 0)
			buf_del(grid_buf_names);
		grid_buf_names = newbuf;
		grid_numchildren = buf_getsize(grid_buf_names);
		item_resized();
		grid_kactive = grid_numchildren?0:-1;
		grid_selectionchanged(-1,grid_kactive);
	};
	float 	cursorpos;
	string 	newval;
	static void() mitem_cvargrid =
	{
		grid_buf_names = -1;
		cursorpos = -1;
	};
	static void(float idx) startedit =
	{
		if (cursorpos < 0)
		{
			string v = bufstr_get(grid_buf_names, idx);
			float flags = cvar_type(v);
			if (!(flags&1) || (flags&32)) //(!exists || readonly). we don't bother to check for private - we can still set them (they'll just read as empty).
				return;
			newval = strzone(cvar_string(v));
			cursorpos = strlen(newval);
		}
	};
	static string() getdesc =
	{
		float idx = grid_kactive;
		if (idx < 0 || idx >= grid_numchildren)
			return __NULL__;
		string v = bufstr_get(grid_buf_names, idx);
		return strcat(XRGB_MUTED, cvar_description(v));
	};
	virtual void(vector pos, float idx) grid_draw;
	virtual float(vector pos, float scan, float char, float down, float idx) grid_keypress;
	virtual void(float olditem, float newitem) grid_selectionchanged;
};

void(vector pos, float idx) mitem_cvargrid::grid_draw =
{
	string text = bufstr_get(grid_buf_names, idx);
	string value = cvar_string(text);
	string defvalue = cvar_defstring(text);
	float flags;

	vector col = item_rgb;
	if (item_flags & IF_MFOCUSED && idx == grid_mactive)
		col = RGB_MFOCUS; 
	if (item_flags & IF_KFOCUSED && idx == grid_kactive)
		col = RGB_KFOCUS;

	flags = cvar_type(text);
	if (!(flags&1))
		value = "<INVALID>";
//	if (flags & 2)	//archive
//		text = strcat("^hseta^h ", text);
	if (flags & 4)	//private
	{
		if (!value)	//should always be true...
			value = "*"; // chr2str(0xe010, 0xe011); // []
		if (checkextension("FTE_EXTENDEDTEXTCODES"))
			value = strcat(XRGB_WARNING, value);	// value is meaningless.
	}
	//8 means engine, or something
	//16 just means it has a description. who even cares?
	if (flags & 32)
	{
		if (checkextension("FTE_EXTENDEDTEXTCODES"))
			value = strcat(XRGB_DANGER, value);	// pointless trying to change it.
	}

	if (idx == grid_kactive && cursorpos >= 0)
	{	//we're editing...
		value = newval;
		if (value == defvalue)
			col *= 0.5;
		if (((cltime*4)&1) && (item_flags & IF_KFOCUSED))
			value = strcat(substring(value, 0, cursorpos), chr2str(0xe00b), substring(value, cursorpos+1, -1)); //box
	}
	else if (value == defvalue)
		col *= 0.5;

	vector valuepos = [pos_x+item_size_x/2, pos_y];
	pos_x = valuepos_x - stringwidth(text, TRUE, '1 1 0'*this.item_scale) - 8;
	valuepos_x += 1;
	ui.drawstring(pos, text, '1 1 0' * item_scale, col, item_alpha, 0);
	ui.drawstring(valuepos, value, '1 1 0' * item_scale, col, item_alpha, 0);
};

void(float olditem, float newitem) mitem_cvargrid::grid_selectionchanged =
{
	if (olditem == newitem)
		return;
	if (olditem && cursorpos >= 0)
	{	//we were editing... change it now.
		string v = bufstr_get(grid_buf_names, olditem);
		cvar_set(v, newval);
	}
	cursorpos = -1;	//stop editing now.
	newval = "";
};

float(vector pos, float scan, float char, float down, float idx) mitem_cvargrid::grid_keypress =
{
	if (!down)
		return FALSE;
	else if (scan == K_ESCAPE)
	{
		if (cursorpos >= 0)
			cursorpos = -1;	//cancel editing, forgetting the change.
		else
			return FALSE;
	}
	else if (scan == K_ENTER)
	{
		if (cursorpos >= 0)
			grid_selectionchanged(idx, -1);
		else
			startedit(idx);
	}
	else if (scan == K_LEFTARROW && cursorpos>=0)
		cursorpos = max(cursorpos-1, 0);
	else if (scan == K_RIGHTARROW && cursorpos>=0)
		cursorpos+=1;
	else if (scan == K_MOUSE1)
	{
		startedit(idx);
		if (cursorpos>=0)
		{
			float valuepos = pos_x+(item_size_x/2)+1;
			cursorpos = strlen(newval);
			if (ui.mousepos[0] > valuepos-8)
				while (cursorpos>0 && ui.mousepos[0] < valuepos+stringwidth(substring(newval, 0, cursorpos), TRUE, '1 1 0'*item_scale))
					cursorpos--;
		}
	}
	else if (scan == K_DEL && cursorpos<0)
	{	//reset to default
		string v = bufstr_get(grid_buf_names, idx);
		cvar_set(v, cvar_defstring(v));
	}
	else if (scan == K_HOME && cursorpos>= 0)
		cursorpos = 0;
	else if (scan == K_END && cursorpos>= 0)
		cursorpos = strlen(newval);
	else if (scan == K_DEL && cursorpos>=0 && cursorpos<strlen(newval))
		newval = strzone(strcat(substring(newval, 0, cursorpos), substring(newval, cursorpos+1, -1)));
	else if ((scan == K_BACKSPACE || scan == K_DEL) && cursorpos>=0)
	{
		if (cursorpos>0)
		{
			newval = strzone(strcat(substring(newval, 0, cursorpos-1), substring(newval, cursorpos, -1)));
			cursorpos -= 1;
		}
	}
	else if (char >= ' ' && cursorpos>=0)
	{
		string ins = chr2str(char);
		newval = strzone(strcat(substring(newval, 0, cursorpos), ins, substring(newval, cursorpos, -1)));
		cursorpos += strlen(ins);
	}
	else
		return FALSE;
	return TRUE;
};

class cvarsmenu : mitem_exmenu
{
	string filter;
	float modifiedonly;

	mitem_cvargrid grid;

	static void(void) updatefilters =
	{
		strbuf b = buf_create();
		buf_cvarlist(b, filter, "_*");
		if (modifiedonly)
		{
			for (float i = buf_getsize(b); i --> 0; )
			{
				string v = bufstr_get(b, i);
				if (cvar_string(v) == cvar_defstring(v))
					bufstr_free(b, i);
				else if (cvar_type(v)&32)
					bufstr_free(b, i); //also remove read-only cvars. we can't reset them or anything so there's no point listing them here.
			}
			buf_sort(b, 0, 0); //sort the names, to clean up any gaps
		}

		grid.grid_setbuf(b);
	};

	virtual string(string key) get =
	{
		if (key == "*filter")
			return filter;
		if (key == "*modified")
			return ftos(modifiedonly);
		if (key == "*desc")
			return grid.getdesc();
		return super::get(key);
	};

	virtual void(string key, string newval) set =
	{
		if (key == "*filter")
		{
			string old = filter;
			filter = strzone(newval);
			if (old)
				strunzone(old);
		}
		else if (key == "*modified")
			modifiedonly = stof(newval);
		else
			return super::set(key, newval);
		updatefilters();
	};

	virtual float(string key) isvalid =
	{
		if (key == "*filter")
			return TRUE;
		if (key == "*modified")
			return TRUE;
		return super::isvalid(key);
	};
};

void(mitem_desktop desktop) M_Menu_Cvars =
{
	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;

	// Main menu

	// no dupes please.
	local mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Cvars Edit"));
	if (mm) { mm.totop(); return; }
	mm = spawn(mitem_exmenu, item_text:_("Cvars Edit"), item_flags:IF_SELECTABLE, item_command:"m_options");
	desktop.add(mm, RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, '0 0', '0 0');
	desktop.item_focuschange(mm, IF_KFOCUSED);
	mm.totop();

	// Frame menu

	// center h and v
	mitem_frame m = spawn(mitem_frame, item_flags:IF_SELECTABLE, frame_hasscroll:FALSE);
	mm.add(m,
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID | RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID, // top-left|bottom-right relation
		[menux*-0.5, menuy*-0.5], // top-left
		[menux*0.5, menuy*0.5] // bottom-right
	);

	// Content
	
	// banner image
	mitem_pic banner = spawn(mitem_pic, item_text:"gfx/ttl_cstm.lmp", item_size_y:24, item_flags:IF_CENTERALIGN);
	m.add(banner, 
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN, // top-left|bottom-right relation
		[banner.item_size_x*-0.5, padding], // top-left
		[banner.item_size_x*0.5, banner.item_size_y]); // bottom-right

	// spawn a container frame for the actual options.
	cvarsmenu fr = spawn(cvarsmenu, item_flags: IF_SELECTABLE, frame_hasscroll:FALSE,
		item_framesize_x: padding, // sides
		item_framesize_y: padding, // top
		item_framesize_z: padding // bottom
	);
	m.add(fr,
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, // top-left|bottom-right relation
		[0, banner.item_size_y+padding], // top-left
		[0, 0] // bottom-right
	);

	float posy = 0;
	float posx = 0;
	float maxposx = -SCRLY-padding;
	float optionswidth = menux-SCRLY;
	vector optionsize = [optionswidth, TXT_NMSZ];

	// Headline

	fr.addc(spawn_headline("Advanced"), posy); posy+=TXT_MDSZ+padding;

	// Toggles & Filters at the top

	fr.add(spawn_check("Modified Only", "*modified", [menux/2-(padding*2), TXT_NMSZ]), 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN, 
		[posx, posy], [(menux)-(padding*2), TXT_NMSZ]); posy+=TXT_NMSZ+SPACING;
	
	fr.add(spawn_edit("Cvar Filter", "*filter", [menux/2-(padding*2), TXT_NMSZ]), 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN, 
		[posx, posy], [(menux)-(padding*2), TXT_NMSZ]); posy+=TXT_NMSZ+padding;

	// Grid

	//spawn our grid for the actual options. this provides a scrollbar if we have too many items.\
	float gridheight = engine==E_FTE?100:128;
	fr.grid = spawn(mitem_cvargrid, item_flags: IF_SELECTABLE, item_scale: 6);
	fr.add(fr.grid, RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN, 
		[0, posy], [menux-(padding*2), gridheight]); posy+=gridheight+padding;

	// I wish QSS could show the description text for cvars, but it can't...
	if (engine==E_FTE)
	{
		// description at bottom of page
		// can't seem to be able to set text size for textfields?
		fr.add(spawn(mitem_label, item_text: "*desc", item_flags: 0, item_scale: 6), 
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN, 
			[0, posy], [menux-(padding*2), 24]);
	}
	

	fr.updatefilters();
	
	//and give us a suitable menu tint too, just because.
	addmenuback(m);
};
