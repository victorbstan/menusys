static float offset_l = (MENU_WIDTH/2*-1);
static float offset_r = (MENU_WIDTH/2);

class mitem_playerpreview : mitem_spinnymodel
{
	virtual void(vector pos) item_draw =
	{
		if (checkbuiltin2(setcustomskin, FALSE))
		{
			//if you wanted to get more advanced, you could use q3 skins here.
			if (cvar("noskins")==1)
				setcustomskin(self, "", sprintf("q1upper \"%s\"\nq1lower \"%s\"\n\n", cvar_string("topcolor"), cvar_string("bottomcolor")));
			else if (cvar_string("cl_teamskin") != "")
				setcustomskin(self, "", sprintf("q1upper \"%s\"\nq1lower \"%s\"\nqwskin \"%s\"\n", cvar_string("topcolor"), cvar_string("bottomcolor"), cvar_string("cl_teamskin")));
			else
				setcustomskin(self, "", sprintf("q1upper \"%s\"\nq1lower \"%s\"\nqwskin \"%s\"\n", cvar_string("topcolor"), cvar_string("bottomcolor"), cvar_string("skin")));
		}

		super::item_draw(pos);
	};
};

/***************************************************************************
Options menu.
just a simple list.
*/
nonstatic void(mitem_desktop desktop) M_Options =
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
	mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Options"));
	if (mm) { mm.totop(); return; }
	// create a fullscreen frame
	mm = spawn(mitem_exmenu, item_text:_("Options"), item_flags:IF_SELECTABLE|IF_NOCURSOR, item_command:"m_main");
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
	
	mitem_pic banner = spawn(mitem_pic, item_text:"gfx/p_option.lmp", item_size_y:24, item_flags:IF_CENTERALIGN);
	m.add(
		banner,
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN,
		[(banner.item_size_x*-0.5)+titleoffset, padding], [banner.item_size_x*0.5, 24]
	);

	// Content

	// buttons start location
	float modelsize = 100;
	float menuoffset = modelsize-plaquepadding;
	float bsx = qplaquewidth+plaquepadding+padding*2;
	// float bsx = menuoffset;
	float bsy = banner.item_size_y+(padding*2);
	float by = 0;

	// spawn a container frame for the actual options. this provides a scrollbar if we have too many items.
	mitem_frame fr = spawn(mitem_frame, item_flags: IF_SELECTABLE, frame_hasscroll:TRUE,
		item_framesize_x: padding, // sides
		item_framesize_y: padding, // top
		item_framesize_z: padding // bottom
	);
	m.add(
		fr,
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, // top-left|bottom-right relation
		[qplaquewidth+padding, banner.item_size_y+padding], // top-left
		[0, 0] // bottom-right
	);
	
	bsx += 48; // some extra padding to give more space for the 3d character to show through
	by += padding;

	// show the options.
	float fl = RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN;
	if (checkcommand2("fps_preset", FALSE)) {
		fr.add(spawn(mitem_text, item_text:"Graphical Presets", item_command:"m_pop;m_preset", item_scale:TXT_NMSZ), 
			fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing; }
	fr.add(spawn(mitem_text, item_text:"Game Configs", item_command:"m_pop;m_configs", item_scale:TXT_NMSZ), 
		fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	fr.add(spawn(mitem_text, item_text:"Basic Setup", item_command:"m_pop;m_basicopts",	item_scale:TXT_NMSZ), 
		fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	fr.add(spawn(mitem_text, item_text:"Keys", item_command:"m_pop;m_keys", item_scale:TXT_NMSZ), 
		fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	fr.add(spawn(mitem_text, item_text:"Audio", item_command:"m_pop;m_audio", item_scale:TXT_NMSZ), 
		fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	fr.add(spawn(mitem_text, item_text:"Video", item_command:"m_pop;m_video", item_scale:TXT_NMSZ), 
		fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	fr.add(spawn(mitem_text, item_text:"Effects", item_command:"m_pop;m_effects", item_scale:TXT_NMSZ), 
		fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	if (checkcommand2("r_particledesc", FALSE)) {
		fr.add(spawn(mitem_text, item_text:"Particles", item_command:"m_pop;m_particles", item_scale:TXT_NMSZ), 
			fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing; }
	if (checkcommand2("ezhud_nquake", FALSE)) {
		fr.add(spawn(mitem_text, item_text:"Hud", item_command:"m_pop;m_hud", item_scale:TXT_NMSZ), 
			fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing; }
	if (checkcommand2("pkg", FALSE)) {
		fr.add(spawn(mitem_text, item_text:"Updates", item_command:"m_pop;m_updates", item_scale:TXT_NMSZ), 
			fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing; }

	by += padding*2; 

	if (checkbuiltin2(buf_cvarlist, TRUE)) {
		fr.add(spawn(mitem_text, item_text:"Advanced Settings", item_command:"m_pop;m_cvars", item_scale:TXT_NMSZ), 
			fl, [bsx, by], [0, TXT_NMSZ]); by += TXT_NMSZ+spacing; }

	by += padding*4; 

	// FTE
	if (checkcommand2("cvarreset", FALSE)) {
		fr.add(spawn(mitem_text, item_text:strcat("^d", XRGB_DANGER, "Reset Settings"), item_command:"m_reset", item_scale:TXT_NMSZ), 
			fl, [bsx, by], [0, TXT_MDSZ]); by += TXT_MDSZ+padding; }
	if (checkcommand2("cfg_save", FALSE)) {
		fr.add(spawn(mitem_text, item_text:strcat("^d", XRGB_SUCCESS, "Save Settings"), item_command:"cfg_save", item_scale:TXT_MDSZ), 
			fl, [bsx, by], [0, TXT_MDSZ]); by += TXT_MDSZ+spacing; }

	//random art for style
	// m.addm(spawn (mitem_spinnymodel, item_text: "progs/suit.mdl"), [0, 12*-16/2], [160, 12*16/2]);

	// by += padding;

	// Player model
	m.add(spawn (mitem_playerpreview, item_text: "progs/player.mdl", firstframe:0, framecount:6, shootframe:119, shootframes:6), 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, 
		[0, 0], [-menux/2+qplaquewidth, 0]);
	
	addmenuback(m);
};

// Rest settings prompt

static void(
	mitem_desktop desktop, 
	string question, 
	string affirmitive, 
	string affirmitiveaction, 
	string negative, 
	string negativeaction
) M_SimplePrompt =
{
	local float pos;
	// no dupes please.
	mitem_exmenu mp;
	mp = (mitem_exmenu)desktop.findchildtext(_("Reset"));
	if (mp) { mp.totop(); return; }
	mp = spawn(mitem_exmenu, item_text:_("Reset"), item_flags:IF_SELECTABLE, item_command:"m_options");
	desktop.add(mp, RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, '0 0', '0 0');
	desktop.item_exclusive = mp;
	desktop.item_focuschange(mp, IF_KFOCUSED);
	mp.totop();

	//center the actual items
	pos = MENU_HEIGHT/2-TXT_NMSZ*4;

	mp.addc(spawn(mitem_text, item_text:question, 
		item_scale:TXT_MDSZ, item_flags:IF_CENTERALIGN), pos); pos+=TXT_MDSZ+PADDING;
	mp.addc(spawn(mitem_text, item_text:affirmitive, 
		item_command:affirmitiveaction, item_scale:TXT_NMSZ, item_flags:IF_CENTERALIGN), pos); pos+=TXT_NMSZ+PADDING;
	mp.addc(spawn(mitem_text, item_text:negative, 
		item_command:negativeaction, item_scale:TXT_NMSZ, item_flags:IF_CENTERALIGN), pos); pos+=TXT_NMSZ+SPACING;

	addmenuback(mp);
};

// NOTE: only keyboard interaction works?
nonstatic void(mitem_desktop desktop) M_Reset =
{
	string cmd = "m_pop;cvarreset *;exec default.cfg;m_options;";
	if (!checkcommand2("cvarreset", FALSE))
		cmd = "m_pop;resetall;exec default.cfg;m_options;";
	M_SimplePrompt(desktop, 
		"Reset All Settings?", 
		strcat(XRGB_DANGER, "Yes"), cmd, 
		strcat(XRGB_TXT, "Cancel"), "m_pop;m_options;"
	);
};
