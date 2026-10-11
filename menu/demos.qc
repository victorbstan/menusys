void(mitem_desktop desktop) M_Demos =
{
	mitem_exmenu mm = (mitem_exmenu)desktop.findchildtext(_("Demos"));
	if (mm) { mm.totop(); return; }
	mm = spawn(mitem_exmenu, item_text:_("Demos"), item_flags:IF_SELECTABLE, item_command:"m_single");
	desktop.add(mm, RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, '0 0', '0 0');
	desktop.item_focuschange(mm, IF_KFOCUSED);
	mm.totop();
	mitem_frame m = spawn(mitem_frame, item_flags:IF_SELECTABLE);
	mm.add(m, RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID|RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID,
		[-MENU_WIDTH/2, -MENU_HEIGHT/2], [MENU_WIDTH/2, MENU_HEIGHT/2]);
	mitem_pic banner = spawn(mitem_pic, item_text:classic_art("gfx/p_demos.lmp", "menugfx/p_demos.lmp"), item_size_y:24);
	m.add(banner, RS_X_MIN_PARENT_MID, [-banner.item_size.x/2, PADDING], banner.item_size);
	mitem_frame fr = spawn(mitem_frame, item_flags:IF_SELECTABLE|IF_FOCUSFOLLOWSMOUSE,
		frame_hasscroll:TRUE, item_framesize:[PADDING, PADDING, PADDING]);
	m.add(fr, RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, [0, banner.item_size.y+PADDING], '0 0');
	float y = 0;
	// DEM is portable across both engines. FTE's MVD/QWD formats are included
	// only there; don't offer QSS recordings it cannot play.
	for (float format = 0; format < (engine == E_FTE ? 3 : 1); format++)
	{
		string pattern = format == 0 ? "*.dem" : format == 1 ? "*.mvd" : "*.qwd";
		searchhandle sh = search_begin(pattern, TRUE, TRUE);
		if (sh < 0)
			continue;
		for (float i = 0; i < search_getsize(sh); i++)
		{
			string name = search_getfilename(sh, i);
			string argument = classic_filearg(name);
			if (!argument)
				continue;
			fr.add(spawn_text(name, sprintf("m_pop;playdemo %s", argument), TXT_NMSZ),
				RS_X_MAX_PARENT_MAX, [0, y], [-SCRLY, TXT_NMSZ]);
			y += TXT_NMSZ+2;
		}
		search_end(sh);
	}
	if (!y)
		fr.addc(spawn_text(_("No demos found"), "", TXT_NMSZ), 0);
	addmenuback(mm);
};
