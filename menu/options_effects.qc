nonstatic void(mitem_desktop desktop) M_Options_Effects =
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
	mm = (mitem_exmenu)desktop.findchildtext(_("Effects Options"));
	if (mm) { mm.totop(); return; }
	// create a fullscreen frame
	mm = spawn(mitem_exmenu, item_text:_("Effects Options"), item_flags:IF_SELECTABLE|IF_NOCURSOR, item_command:"m_options");
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
	
	// Options

	float posy = 0;
	float posx = 0;
	float maxposx = -SCRLY-padding;
	float optionswidth = menux-SCRLY;
	vector optionsize = [optionswidth, TXT_NMSZ];

	// Headline
	fr.addc(spawn_headline("Effects"), posy); posy+=TXT_MDSZ+padding;

	// Button
	fr.add(spawn(mitem_text, item_text:_("Restart Video"), 
		item_command:"vid_restart", 
		item_scale:TXT_MDSZ,
		item_flags:IF_CENTERALIGN),
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
		[0, posy], [maxposx, TXT_MDSZ]
	); posy += TXT_MDSZ+spacing;

	posy+=padding;

	float fl = RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN;
	// fr.add(spawn_check(_("Show Framerate"), cv3("showfps", "scr_showfps", "show_fps"), optionsize), 
	// 	fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	fr.add(spawn_combo(_("Texture Mode"), "gl_texturemode", optionsize, _(
		"GL_NEAREST	\"Nearest\""
		"GL_NEAREST_MIPMAP_NEAREST \"Nearest (Nearest mips)\""
		"GL_NEAREST_MIPMAP_LINEAR \"Nearest (Linear mips)\""
		"GL_LINEAR \"Linear\" "
		"GL_LINEAR_MIPMAP_NEAREST \"Linear (Nearest mips)\""
		"GL_LINEAR_MIPMAP_LINEAR \"Linear (Linear mips)\""
		"n.l \"Nearest (Smooth)\""
		//"l.n \"Linear (Unsmooth)\""
		//"nnl \"Nearest (Nearest mips, Smooth)\""
		//"lnn \"Linear (Nearest mips, Unsmooth)\""
		"nll \"Nearest (Smooth mips)\""
		//"lln \"Linear (Linear mips, Unsmooth)\""
	)), fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	fr.add(spawn_combo(_("Anistrophy"), "gl_texture_anisotropic_filtering", optionsize, _(
		"0 \"Off\""
		"2 \"2\""
		"4 \"4\""
		"8 \"8\""
		"16 \"16\""
	)),	fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	fr.add(spawn_check(_("Lightmaps Only"), "r_lightmap", optionsize),
		fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	fr.add(spawn_check(_("High Res Textures"), "gl_load24bit", optionsize), 
		fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	if (engine == E_QSS)
	{
		fr.add(spawn_check(_("Wireframe"), "r_showtris", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_check(_("Simple DLights"), "gl_flashblend", optionsize),
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_hslider(_("Stereo"), "r_stereo", '0 8 0.25', optionsize),
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	}
	else
	{
		fr.add(spawn_check(_("Wireframe"), "r_wireframe", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_check(_("Bloom"), "r_bloom", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_check(_("Simple Textures"), "r_drawflat", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_check(_("Paletted Rendering"), "r_softwarebanding", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_check(_("HDR"), "r_hdr_irisadaptation", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_check(_("Coronas"), "r_coronas", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_check(_("Relief Mapping"), "r_glsl_offsetmapping", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_check(_("Rt. Dynamic Light"), "r_shadow_realtime_dlight", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_check(_("Rt. World Light"), "r_shadow_realtime_world", optionsize), 
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_combo(_("Water Effects"), "r_waterstyle", optionsize, _(
			"1 \"Classic\""
			"2 \"Ripples\""
			"3 \"Reflections\""
		)), fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_combo(_("View Projection"), "r_projection", optionsize, _(
			"0 \"Standard\""
			"1 \"Stereographic / Pannini\""
			"2 \"Fish-Eye\""
			"3 \"Panoramic\""
			"4 \"Lambert Azimuthal Equal-Area\""
			"5 \"Equirectangular\""
		)), fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_combo(_("Fov Projection"), "ffov", optionsize, _(
			"90 \"Normal\""
			"180 \"180 degrees\""
			"270 \"270 degrees\""
			"360 \"360 degrees\""
		)),	fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	}
	fr.add(spawn_hslider(_("Particle Density"), "r_part_density", '0.25 4 0.25', optionsize), 
		fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;

	posy+=padding;

	// extra spacing for drop-downs
	fr.add(spawn_mitem_spacer(16, -1), 
		fl, [posx, posy], [maxposx, 24]);
	
	addmenuback(m);
};

