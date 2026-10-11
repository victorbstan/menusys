// QSS retains its existing automatic flags. -1 restores native defaults.
var float autocvar_menu_consoleauto = 1;
var float autocvar_menu_hudauto = 0;
// FTE's old console control was an alias of its global UI scale. Leave saved
// native text settings alone until this independent control is selected.
var float autocvar_menu_fteconsolezoom = -1;
void(string key, string value) M_SaveZoom =
{
    cvar_set(key, value);
    localcmd(strcat("seta ", key, " ", value, "\n"));
};
void() M_ConsolePreferences =
{
    vector physical = (vector)getproperty(VF_SCREENPSIZE);
    if (physical.x <= 0 || physical.y <= 0) return;
    float automatic = max(1, min(physical.x/MENU_REFERENCE_WIDTH, physical.y/MENU_REFERENCE_HEIGHT));
    if (engine == E_QSS)
    {
        // MenuQC is not called during intermission; native scores inherit the
        // last applied menu/message scale. Native overlays have a x1 minimum.
        float zoom = max(1, autocvar_menu_zoom > 0 ? autocvar_menu_zoom : automatic);
        if (cvar("scr_menuscale") != zoom) cvar_set("scr_menuscale", ftos(zoom));
        if (autocvar_menu_consoleauto > 0)
        {
            if (cvar("scr_conwidth") != 0) cvar_set("scr_conwidth", "0");
            if (cvar("scr_conscale") != automatic) cvar_set("scr_conscale", ftos(automatic));
        }
        if (autocvar_menu_hudauto > 0 && cvar("scr_sbarscale") != automatic)
            cvar_set("scr_sbarscale", ftos(automatic));
    }
    else if (engine == E_FTE)
    {
        if (autocvar_menu_hudauto > 0 && cvar("vid_conautoscale") != automatic)
            cvar_set("vid_conautoscale", ftos(automatic));
        if (autocvar_menu_fteconsolezoom >= 0 && cvar_type("con_textsize"))
        {
            // Negative con_textsize is physical pixels, independent of FTE's
            // global UI canvas (vid_conautoscale / scr_conscale alias).
            float textsize = -8 * (autocvar_menu_fteconsolezoom > 0 ? autocvar_menu_fteconsolezoom : automatic);
            if (cvar("con_textsize") != textsize) cvar_set("con_textsize", ftos(textsize));
        }
    }
};
// 160 Is "half screen", assuming screen size is 320
static float offset_l = -160;
static float offset_r = 160;

static string() PrepareVideoModes =
{
	string s = _("\"0x0\" \"Default\"");

	for (float i = 0; ; i++)
	{
		vector m = getresolution(i);
		if (!m_x || !m_y)
			break;
		s = sprintf("%s \"%dx%d\" \"%d x %d\"", s, m_x, m_y, m_x, m_y);
	}
	return s;
};

class options_video : mitem_exmenu
{
	string videomode;
	void() options_video =
	{
		videomode = strzone(strcat(super::get("vid_width"), "x", super::get("vid_height")));
	};

	virtual float(string key) isvalid =
	{
		if (key == "menu_consolezoom" || key == "menu_zoom" || key == "menu_hudzoom") return TRUE;
		if (key == cv2("vid_mode", "vid_describemodes"))
			return super::isvalid("vid_width") && super::isvalid("vid_height");
		return super::isvalid(key);
	};
	virtual string(string key) get =
	{
		if (key == cv2("vid_mode", "vid_describemodes"))
			return videomode;
        if (key == "menu_consolezoom")
        {
            if (engine == E_FTE) return ftos(autocvar_menu_fteconsolezoom);
            return autocvar_menu_consoleauto < 0 ? "-1" : (autocvar_menu_consoleauto > 0 ? "0" : super::get("scr_conscale"));
        }
        if (key == "menu_zoom") return ftos(autocvar_menu_zoom);
        if (key == "menu_hudzoom")
        {
            if (autocvar_menu_hudauto < 0) return "-1";
            if (autocvar_menu_hudauto > 0) return "0";
            float zoom = cvar(engine == E_QSS ? "scr_sbarscale" : "vid_conautoscale");
            return zoom > 0 ? ftos(zoom) : "-1";
        }
		return super::get(key);
	};
	virtual void(string key, string newval) set =
	{
        if (engine == E_FTE && key == "cl_sbaralpha")
        {
            // FTE's classic opaque and heads-up modes ignore background alpha.
            // Only switch to the translucent classic bar when explicitly edited.
            super::set("cl_sbar", "2");
        }
        if (key == "menu_consolezoom")
        {
            float zoom = stof(newval);
            if (engine == E_FTE)
            {
                M_SaveZoom("menu_fteconsolezoom", newval);
                if (zoom < 0) M_SaveZoom("con_textsize", "8");
                else
                {
                    M_ConsolePreferences();
                    M_SaveZoom("con_textsize", cvar_string("con_textsize"));
                }
            }
            else
            {
                M_SaveZoom("menu_consoleauto", zoom < 0 ? "-1" : (zoom == 0 ? "1" : "0"));
                cvar_set("scr_conwidth", "0");
                cvar_set("scr_conscale", zoom > 0 ? newval : "1");
                M_ConsolePreferences();
            }
        }
        else if (key == "menu_zoom")
        {
            M_SaveZoom("menu_zoom", newval);
            M_ConsolePreferences();
        }
        else if (key == "menu_hudzoom")
        {
            float hudzoom = stof(newval);
            M_SaveZoom("menu_hudauto", hudzoom < 0 ? "-1" : (hudzoom == 0 ? "1" : "0"));
            cvar_set(engine == E_QSS ? "scr_sbarscale" : "vid_conautoscale", hudzoom > 0 ? newval : (engine == E_QSS ? "1" : "0"));
            M_ConsolePreferences();
        }
		else if (key == cv2("vid_mode", "vid_describemodes"))
		{
			string old = videomode;
			videomode = strzone(newval);
			tokenizebyseparator(newval, "x");
			super::set("vid_width", argv(0));
			super::set("vid_height", argv(1));
			if (old)
				strunzone(old);
		}
		else
			super::set(key, newval);
	};
};

nonstatic void(mitem_desktop desktop) M_Options_Video =
{
	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;
	float spacing = SPACING;
	float qplaquewidth = 32;
	float plaquepadding = 24;

	// Main menu

	// no dupes please.
	local mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("Video Options"));
	if (mm) { mm.totop(); return; }
	// create a fullscreen frame
	mm = spawn(options_video, item_text:_("Video Options"), item_flags:IF_SELECTABLE|IF_NOCURSOR, item_command:"m_options");
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
		[-banner.item_size_x*0.5, padding], [banner.item_size_x*0.5, 24]
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
	fr.addc(spawn_headline("Video"), posy); posy+=TXT_MDSZ+padding;

	// Button
	fr.add(spawn(mitem_text, item_text:_("Restart Video"),
		item_command:"vid_restart",
		// item_rgb: RGB_TXTB,
		item_scale:TXT_MDSZ,
		item_flags:IF_CENTERALIGN),
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
		[0, posy], [maxposx, TXT_MDSZ]
	); posy += TXT_MDSZ+spacing;

	posy+=padding;

	float fl = RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN;

	if (cvar_type("vid_renderer")) {
		fr.add(spawn_combo(_("Renderer"), "vid_renderer", optionsize,
			cvar_string("_vid_renderer_opts")),
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing; }

	//add the options
	if (!dp_workarounds)
	{
		fr.add(spawn_combo(_("Display Mode"), "vid_fullscreen", optionsize,
			engine==E_FTE?
			"0 \"Windowed\""
			"1 \"Fullscreen\""
			"2 \"Borderless Windowed\""
			:
			"0 \"Windowed\""
			"1 \"Fullscreen\""
		), fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	}
	else
	{
		fr.add(spawn_check(_("Fullscreen"), "vid_fullscreen", optionsize),
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	}
	if (cvar_type("vid_resizable")) {
		fr.add(spawn_check(_("Resizable"), "vid_resizable", optionsize),
			fl, [posx, posy], [maxposx, TXT_NMSZ]), posy+=TXT_NMSZ+spacing; }

	fr.add(spawn_combo(_("MSAA"), cv3("vid_samples"/*dp*/, "vid_fsaa"/*qs*/, "vid_multisample"/*fte*/), optionsize,
		"0 \"Off\""
		"2 \"2x\""
		"4 \"4x\""
	), fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;

	if (cv2("vid_mode", "vid_describemodes")) {
		fr.add(spawn_combo(_("Video Mode"), cv2("vid_mode", "vid_describemodes"), optionsize, PrepareVideoModes()),
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;	}

    static const string fixedzooms = _("1 \"1x\" 2 \"2x\" 3 \"3x\" 4 \"4x\"");
    string autozooms = strcat(_("0 \"Automatic\" "), fixedzooms);
    string nativezooms = strcat(autozooms, _(" -1 \"Default\""));
    if (engine == E_QSS ? cvar_type("scr_conscale") : cvar_type("con_textsize")) {
        fr.add(spawn_combo(_("Console Zoom"), "menu_consolezoom", optionsize, nativezooms),
            fl, [posx, posy], [maxposx, TXT_NMSZ]), posy+=TXT_NMSZ+spacing; }
    fr.add(spawn_combo(_("Menu Zoom"), "menu_zoom", optionsize, autozooms),
        fl, [posx, posy], [maxposx, TXT_NMSZ]), posy+=TXT_NMSZ+spacing;
    if (engine == E_QSS ? cvar_type("scr_sbarscale") : cvar_type("vid_conautoscale")) {
        fr.add(spawn_combo(engine == E_QSS ? _("HUD Zoom") : _("HUD/UI Zoom"), "menu_hudzoom", optionsize, nativezooms),
            fl, [posx, posy], [maxposx, TXT_NMSZ]), posy+=TXT_NMSZ+spacing; }
    string hudalpha = engine == E_FTE ? "cl_sbaralpha" : "scr_sbaralpha";
    if (cvar_type(hudalpha)) {
        fr.add(spawn_hslider(_("HUD Alpha"), hudalpha, '0 1 0.05', optionsize),
            fl, [posx, posy], [maxposx, TXT_NMSZ]), posy+=TXT_NMSZ+spacing; }
	fr.add(spawn_combo(_("Colour Depth"), cv2("vid_bitsperpixel", "vid_bpp"), optionsize, _(
		"16 \"16bit (No Win10)\"" //r5g6b5, or so. unsupported on win10.
		"24 \"24bit (Default)\"" //rgba8 - we don't count the alpha.
		"30 \"30bit (No Nvidia)\"" //rgb10a2 - we don't count the alpha. unsupported on nvidia.
		"48 \"48bit (No Nvidia)\"" //half-floats - we don't count the alpha. unsupported on nvidia.
	)),	fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	if (cvar_type("vid_refreshrate")) {
		fr.add(spawn_combo(_("Refresh Rate"),"vid_refreshrate"/*qs*/, optionsize, _(
			"0 \"Default\""
			"60 \"60\""
			"120 \"120\""
			"144 \"144\""
			"240 \"240\""
		)),	fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing; }
	if (cvar_type("vid_displayfrequency")) {
		fr.add(spawn_combo(_("Refresh Rate"), "vid_displayfrequency", optionsize, _(
			"0 \"Default\""
			"60 \"60\" "
			"120 \"120\""
			"144 \"144\""
			"240 \"240\""
		)),	fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing; }
	fr.add(spawn_check(_("VSync"), cv2("vid_vsync", "vid_wait"), optionsize),
		fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	fr.add(spawn_check(_("Show Framerate"), cv3("showfps"/*dp*/, "scr_showfps"/*qs*/, "show_fps"/*id/qw*/), optionsize),
		fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	fr.add(spawn_hslider(_("View Size"), "viewsize", '50 120 10', optionsize),
		fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	fr.add(spawn_hslider(_("Field Of View"), "fov", '50 140 5', optionsize),
		fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	fr.add(spawn_hslider(_("Gamma"), "gamma", '1.3 0.5 -0.1', optionsize),
		fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	fr.add(spawn_hslider(_("Contrast"), "contrast", '0.7 2 0.1', optionsize),
		fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	if (engine!=E_QSS) {
		fr.add(spawn_hslider(_("Brightness"), "brightness", '0 0.4 0.05', optionsize),
			fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
		fr.add(spawn_combo(_("Hardware Gamma"), "vid_hardwaregamma", optionsize,
			"0 \"Off\" "
			"1 \"Auto\" "
			"2 \"Soft\" "
			"3 \"Hard\" "
			"4 \"Scene Only\" "
		), fl, [posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+spacing;
	}
	posy+=padding;

	// extra spacing for drop-downs
	fr.add(spawn_mitem_spacer(16, -1),
		fl, [posx, posy], [maxposx, 24]);

	addmenuback(mm);
};

