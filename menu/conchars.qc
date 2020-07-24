void(mitem_desktop desktop) M_Conchars =
{
	string saveorload = "Conchars";
	float ssx = ui.screensize.x;
	float ssy = ui.screensize.y;
	float menux = 306;
	float menuy = 276;
	float padding = 2;
	float bpadding = 8;

	// Main menu
	// no dupes please.
	local mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Conchars"));
	if (mm) { mm.totop(); return; }
	mm = spawn(mitem_exmenu, item_text:"Conchars", item_flags:IF_SELECTABLE, item_command:"m_main");
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
	mitem_text banner = spawn(mitem_text, item_text:"Conchars", item_scale:8, item_flags:IF_CENTERALIGN);
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
		[0, banner.item_size_y+(bpadding)], // top-left
		[0, 0] // bottom-right
	);

	// Conchars

	fr.add(spawn(mitem_conchars), 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN, 
		[0, bpadding], [256, 256]);

	addmenuback(m);
};

