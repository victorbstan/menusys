// Classic player setup uses the active game's menuplyr artwork. The color
// selectors use the original fourteen Quake palette bands on both engines.
float(float lower) player_setup_color =
{
	if (cvar_type("topcolor"))
		return cvar(lower ? "bottomcolor" : "topcolor");
	float packed = cvar("_cl_color");
	return lower ? packed & 15 : floor(packed/16) & 15;
};
class mitem_playercolor : mitem_text
{
	float lower;
	virtual void(vector pos) item_draw =
	{
		float color = player_setup_color(lower);
		ui.drawstring(pos, sprintf("%s  %g", item_text, color), '8 8', menuitem_textcolour(this), 1, 0);
	};
	virtual float(vector pos, float scan, float chr, float down) item_keypress =
	{
		if (!down || !(item_flags & IF_KFOCUSED))
			return FALSE;
		if (scan != K_LEFTARROW && scan != K_RIGHTARROW && scan != K_ENTER && scan != K_MOUSE1)
			return FALSE;
		float color = floor(player_setup_color(lower));
		color += scan == K_LEFTARROW ? -1 : 1;
		if (color < 0) color = 13;
		if (color > 13) color = 0;
		float top = lower ? player_setup_color(FALSE) : color;
		float bottom = lower ? color : player_setup_color(TRUE);
		localcmd(sprintf("color %g %g\n", top, bottom));
		return TRUE;
	};
};

// Use the game's classic setup artwork on every engine. The local build
// splits menuplyr into three transparent
// layers: unchanged pixels, shirt pixels, and pants pixels. Selecting a color
// merely chooses another tiny translated layer, so changes are visible on the
// next frame and the original artwork remains pixel-exact.
class mitem_setupplayer2d : mitem
{
	virtual void(vector pos) item_draw =
	{
		ui.drawpic(pos, "menugfx/playerpreview/base.lmp", item_size, '1 1 1', 1, 0);
		ui.drawpic(pos, sprintf("menugfx/playerpreview/top%g.lmp",
			floor(player_setup_color(FALSE))), item_size, '1 1 1', 1, 0);
		ui.drawpic(pos, sprintf("menugfx/playerpreview/bottom%g.lmp",
			floor(player_setup_color(TRUE))), item_size, '1 1 1', 1, 0);
	};
};

void(mitem_desktop desktop) M_PlayerSetup =
{
	mitem_exmenu mm = (mitem_exmenu)desktop.findchildtext(_("Player Setup"));
	if (mm) { mm.totop(); return; }
	mm = spawn(mitem_exmenu, item_text:_("Player Setup"), item_flags:IF_SELECTABLE, item_command:"m_multi");
	desktop.add(mm, RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, '0 0', '0 0');
	desktop.item_focuschange(mm, IF_KFOCUSED);
	mm.totop();
	mitem_frame m = spawn(mitem_frame, item_text:"Setup panel", item_flags:IF_SELECTABLE|IF_FOCUSFOLLOWSMOUSE);
	mm.add(m, RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID|RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID,
		[-MENU_WIDTH/2, -MENU_HEIGHT/2], [MENU_WIDTH/2, MENU_HEIGHT/2]);
	mitem_pic banner = spawn(mitem_pic, item_text:"gfx/p_multi.lmp", item_size_y:24);
	m.add(banner, RS_X_MIN_PARENT_MID, [-banner.item_size.x/2, PADDING], banner.item_size);
	m.add(spawn_edit(_("Hostname"), "hostname", '280 8'), 0, [16, 40], '280 8');
	m.add(spawn_edit(_("Player Name"), cv2("_cl_name", "name"), '280 8'), 0, [16, 64], '280 8');
	m.add(spawn(mitem_playercolor, item_text:_("Shirt color"), item_flags:IF_SELECTABLE), 0, [16, 88], '180 16');
	m.add(spawn(mitem_playercolor, item_text:_("Pants color"), item_flags:IF_SELECTABLE, lower:TRUE), 0, [16, 112], '180 16');
	vector playersize = drawgetimagesize("menugfx/playerpreview/base.lmp");
	if (playersize.x > 0 && playersize.y > 0)
	{
		mitem_setupplayer2d player2d = spawn(mitem_setupplayer2d, item_text:"Player preview");
		m.add(player2d, 0, [216, 80], playersize);
	}
	else
	{
		mitem_pic playerpic = spawn(mitem_pic, item_text:"gfx/menuplyr.lmp");
		m.add(playerpic, 0, [216, 80], playerpic.item_size);
	}
	m.add(spawn_text(_("Accept changes"), "m_pop;m_multi", TXT_NMSZ), 0, [64, 160], '200 16');
	addmenuback(mm);
};
