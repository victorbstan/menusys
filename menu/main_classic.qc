/*
The main / root menu.
*/

/*
Adds a background tint to a (typically) exmenu parent.
In FTE, we use built-in stuff to give a sepia effect.
In DP, we just tint it black.
*/
nonstatic void(mitem_frame m) addmenuback =
{
	m.add(spawn (mitem_fill, item_rgb:-1, item_alpha:MENUBACK_ALPHA),
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, [0, 0], [0, 0]);
};

// helper functions to avoid blowing up in older clients.
#define cv2(dpc,qwc) (cvar_type(dpc)?dpc:qwc)
#define cv3(dpc,qs,qwc) (cvar_type(dpc)?dpc:(cvar_type(qs)?qs:qwc))
#ifdef CSQC
	#define ISMENUQC FALSE
#else
	#define ISMENUQC TRUE
#endif
float(string cmd, float assumption) checkcommand2 =
{
	if (!checkextension("FTE_QC_CHECKCOMMAND"))
		return assumption;
	return checkcommand(cmd);
};
float(__variant cmd, float assumption) checkbuiltin2 =
{
	//teehee. if the #0 stuff isn't working (DP) then it ends up calling an OP_DONE(0) instruction giving a return false.
	if (!checkbuiltin(checkbuiltin)) 
		return assumption;
	return checkbuiltin(cmd);
};

#ifdef CSQC
float() clientstate =
{
	if (serverkey("constate") != "disconnected")
		return 2;
	return 1;
};
#endif

nonstatic void(mitem_desktop desktop) M_Main =
{
	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;
	float qplaquewidth = 32;
	float plaquepadding = 24;
	float titleoffset = -12;

	// Main menu

	// no dupes please.
	local mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Main Menu"));
	if (mm) { mm.totop(); return; }
	// create a fullscreen frame
	mm = spawn(mitem_exmenu, item_text:_("Main Menu"), item_flags:IF_SELECTABLE|IF_NOCURSOR, item_command:"");
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

	// Left plaque

	m.add(spawn_pic("gfx/qplaque.lmp", '32 144'),
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN,
		[padding, padding], [qplaquewidth, 144]);

	// Title
	
	mitem_pic banner = spawn(mitem_pic, item_text:"gfx/ttl_main.lmp", item_size_y:24, item_flags:IF_CENTERALIGN);
	m.add(
		banner,
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN,
		[(banner.item_size_x*-0.5)+titleoffset, padding], [banner.item_size_x*0.5, 24]
	);

	// Content

	// Button overlay hotspots spawn
	float alpha = -1;
	mitem_filli btn1 = spawn(mitem_filli, item_command:"m_pop;m_single", 
		item_size:'10 10', item_rgb:'255 0 0', item_alpha:alpha); // single player
	mitem_filli btn2 = spawn(mitem_filli, item_command:"m_pop;m_multi", 
		item_size:'10 10', item_rgb:'255 0 0', item_alpha:alpha); // multiplayer
	mitem_filli btn3 = spawn(mitem_filli, item_command:"m_pop;m_options", 
		item_size:'10 10', item_rgb:'255 0 0', item_alpha:alpha); // options
	mitem_filli btn4 = spawn(mitem_filli, item_command:"m_pop;m_help", 
		item_size:'10 10', item_rgb:'255 0 0', item_alpha:alpha); // help/ordering
	mitem_filli btn5 = spawn(mitem_filli, item_command:"m_pop;m_quit", 
		item_size:'10 10', item_rgb:'255 0 0', item_alpha:alpha); // quit

	// buttons start location
	float bsx = qplaquewidth+padding+plaquepadding;
	float bsy = banner.item_size_y+(padding*2);
	// position hotspots over relevant image button location
	float by = bsy;
	#define bposrel RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN
	m.add(btn1, bposrel, [bsx, by], [240, 19]); by+=20; // single player
	m.add(btn2, bposrel, [bsx, by], [240, 19]); by+=20; // multiplayer
	m.add(btn3, bposrel, [bsx, by], [240, 19]); by+=20; // options
	m.add(btn4, bposrel, [bsx, by], [240, 19]); by+=20; // help/ordering
	m.add(btn5, bposrel, [bsx, by], [240, 19]); by+=20; // quit

	// Menu options image
	m.add(spawn(mitem_pic, item_text:"gfx/mainmenu.lmp"), 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN,
		[bsx, bsy], [240, 112]);

	//spinny quad/pent, for the luls
	// local string it = (random()<0.9)?"progs/quaddama.mdl":"progs/invulner.mdl";
	// m.add(spawn (mitem_spinnymodel, item_text: it), RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID | RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID, [offset_l, 12*-16/2], [0, 12*16/2]);

	addmenuback(mm);
};
