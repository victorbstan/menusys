/*
The main / root menu.
*/
nonstatic void(mitem_desktop desktop) M_Single =
{
	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;
	float plaquepadding = 24;
	float titleoffset = -12;

	// Main menu

	// no dupes please.
	local mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Singleplayer Menu"));
	if (mm) { mm.totop(); return; }
	// create a fullscreen frame, target previous menu
	mm = spawn(mitem_exmenu, item_text:_("Singleplayer Menu"), item_flags:IF_SELECTABLE , item_command:"m_main");
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
	
	float qplaquewidth = 32;
	m.add(spawn_pic("gfx/qplaque.lmp", '32 144'),
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN,
		[padding, padding], [qplaquewidth, 144]);

	// Title
	
	mitem_pic banner = spawn(mitem_pic, item_text:"gfx/ttl_sgl.lmp", item_size_y:24, item_flags:IF_CENTERALIGN);
	m.add(
		banner,
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN,
		[(banner.item_size_x*-0.5)+titleoffset, padding], [banner.item_size_x*0.5, 24]
	);

	// Content

	// Button overlay hotspots spawn
	float alpha = -1;
	mitem_filli btn1 = spawn(mitem_filli, item_command:"m_pop;m_newgame sp", 
		item_size:'10 10', item_rgb:'255 0 0', item_alpha:alpha); // new game
	mitem_filli btn2 = spawn(mitem_filli, item_command:"m_pop;m_load", 
		item_size:'10 10', item_rgb:'255 0 0', item_alpha:alpha); // load
	mitem_filli btn3 = spawn(mitem_filli, item_command:"m_pop;m_save", 
		item_size:'10 10', item_rgb:'255 0 0', item_alpha:alpha); // save
	mitem_filli btn4 = spawn(mitem_filli, item_command:"m_pop;m_levels",  // m_levels
		item_size:'10 10', item_rgb:'255 0 0', item_alpha:alpha); // levels

	// buttons start location
	float bsx = qplaquewidth+padding+plaquepadding;
	float bsy = banner.item_size_y+(padding*2);
	// position hotspots over relevant image button location
	float by = bsy;
	#define bposrel RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN
	m.add(btn1, bposrel, [bsx, by], [240, 19]); by+=20; // new game
	m.add(btn2, bposrel, [bsx, by], [240, 19]); by+=20; // load
	m.add(btn3, bposrel, [bsx, by], [240, 19]); by+=20; // save
	m.add(btn4, bposrel, [bsx, by], [240, 19]); by+=20; // levels

	// Menu options image
	vector msize = [232, 64];
	m.add(spawn(mitem_pic, item_text:"gfx/sp_menu.lmp"), 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN,
		[bsx, bsy], msize);

	// "Levels" menu image, from MarkV
	m.add(spawn(mitem_pic, item_text:"menugfx/levels.lmp"),
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN,
		[bsx, bsy+msize.y-4], [120, 20]);

	//spinny quad/pent, for the luls
	// local string it = (random()<0.9)?"progs/quaddama.mdl":"progs/invulner.mdl";
	// m.add(spawn (mitem_spinnymodel, item_text: it), RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID | RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID, [offset_l, 12*-16/2], [0, 12*16/2]);

	addmenuback(mm);
};
