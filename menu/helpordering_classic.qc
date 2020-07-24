void(mitem_desktop desktop, float mode) M_HelpOrdering =
{
	float ssx = ui.screensize.x;
	float ssy = ui.screensize.y;
	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;

	// Main menu

	// no dupes please.
	local mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Help/Ordering"));
	if (mm) { mm.totop(); return; }
	mm = spawn(mitem_exmenu, item_text:"Help/Ordering", item_flags:IF_SELECTABLE, item_command:"m_main");
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
	float da = 0; // debug alpha
	// Button overlay hotspots spawn
	mitem_filli btn0 = spawn(mitem_filli, item_command:"m_pop;m_help", 
		item_size:'100 200', item_rgb:'1 0 0', item_alpha:0+da); // help 0
	mitem_filli btn1 = spawn(mitem_filli, item_command:"m_pop;m_help1", 
		item_size:'100 200', item_rgb:'1 0.1 0.1', item_alpha:0+da); // help 1
	mitem_filli btn2 = spawn(mitem_filli, item_command:"m_pop;m_help2", 
		item_size:'100 200', item_rgb:'1 0.2 0.2', item_alpha:0+da); // help 2
	mitem_filli btn3 = spawn(mitem_filli, item_command:"m_pop;m_help3", 
		item_size:'100 200', item_rgb:'1 0.3 0.3', item_alpha:0+da); // help 3
	mitem_filli btn4 = spawn(mitem_filli, item_command:"m_pop;m_help4", 
		item_size:'100 200', item_rgb:'1 0.4 0.4', item_alpha:0+da); // help 4
	mitem_filli btn5 = spawn(mitem_filli, item_command:"m_pop;m_help5", 
		item_size:'100 200', item_rgb:'1 0.5 0.5', item_alpha:0+da); // help 5
	// buttons start location
	float bsx = 0;
	float bsy = 0;
	#define bposrel RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN
	// help pages switcher
	if (mode == 1) {
		// help 1
		m.add(btn0.s_hover_text("<"), bposrel, [bsx, bsy], [100, 200]); // help 0 -- prev
		m.add(btn2.s_hover_text(">"), bposrel, [bsx+220, bsy], [100, 200]); // help 2 -- next
		m.addm(spawn(mitem_pic, item_text:"gfx/help1.lmp"), '-160 -100', '160 100');
	} else if (mode == 2) {
		// help 2
		m.add(btn1.s_hover_text("<"), bposrel, [bsx, bsy], [100, 200]); // help 1 -- prev
		m.add(btn3.s_hover_text(">"), bposrel, [bsx+220, bsy], [100, 200]); // help 3 -- next
		m.addm(spawn(mitem_pic, item_text:"gfx/help2.lmp"), '-160 -100', '160 100');
	} else if (mode == 3) {
		// help 3
		m.add(btn2.s_hover_text("<"), bposrel, [bsx, bsy], [100, 200]); // help 2 -- prev
		m.add(btn4.s_hover_text(">"), bposrel, [bsx+220, bsy], [100, 200]); // help 4 -- next
		m.addm(spawn(mitem_pic, item_text:"gfx/help3.lmp"), '-160 -100', '160 100');
	} else if (mode == 4) {
		// help 4
		m.add(btn3.s_hover_text("<"), bposrel, [bsx, bsy], [100, 200]); // help 3 -- prev
		m.add(btn5.s_hover_text(">"), bposrel, [bsx+220, bsy], [100, 200]); // help 5 -- next
		m.addm(spawn(mitem_pic, item_text:"gfx/help4.lmp"), '-160 -100', '160 100');
	} else if (mode == 5) {
		// help 5
		m.add(btn4.s_hover_text("<"), bposrel, [bsx, bsy], [100, 200]); // help 4 -- prev
		m.add(btn0.s_hover_text(">"), bposrel, [bsx+220, bsy], [100, 200]); // help 0 -- next
		m.addm(spawn(mitem_pic, item_text:"gfx/help5.lmp"), '-160 -100', '160 100');
	} else { // first and default
		// help
		m.add(btn5.s_hover_text("<"), bposrel, [bsx, bsy], [100, 200]); // help 5 -- prev
		m.add(btn1.s_hover_text(">"), bposrel, [bsx+220, bsy], [100, 200]); // help 1 -- next
		m.addm(spawn(mitem_pic, item_text:"gfx/help0.lmp"), '-160 -100', '160 100');
	}

	

	// m.addm(spawn(mitem_savepreview), [-320, -240], [320, 240]);
	addmenuback(m);
};

// define "fake" pages, points back to same class
void(mitem_desktop desktop) M_Help  = { M_HelpOrdering(desktop, 0); };
void(mitem_desktop desktop) M_Help1 = { M_HelpOrdering(desktop, 1); };
void(mitem_desktop desktop) M_Help2 = { M_HelpOrdering(desktop, 2); };
void(mitem_desktop desktop) M_Help3 = { M_HelpOrdering(desktop, 3); };
void(mitem_desktop desktop) M_Help4 = { M_HelpOrdering(desktop, 4); };
void(mitem_desktop desktop) M_Help5 = { M_HelpOrdering(desktop, 5); };
