static class audiomenu : mitem_exmenu
{
	virtual float(string key) isvalid =
	{
		if (key == "sndspeed")
			return super::isvalid(key) && stof(super::get("snd_mixspeed"))==44100;
		return super::isvalid(key);
	};
	virtual string(string key) get =
	{
		if (key == "s_device" || key == "cl_voip_capturedevice")
		{
			//the cvar supports multiple options, but we only support one. :(
			//so just return the first to avoid getting too confused.
			tokenize(super::get(key));
			return argv(0);
		}
		return super::get(key);
	};
	virtual void(string key, string val) set =
	{
		if (key == "s_device" || key == "cl_voip_capturedevice")
		{
			//add some quotes.
			val = strcat("\"", val, "\"");
		}
		super::set(key, val);
	};
};

nonstatic void(mitem_desktop desktop) M_Options_Audio =
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
	mm = (mitem_exmenu)desktop.findchildtext(_("Audio Options"));
	if (mm) { mm.totop(); return; }
	// create a fullscreen frame
	mm = spawn(mitem_exmenu, item_text:_("Audio Options"), item_flags:IF_SELECTABLE|IF_NOCURSOR, item_command:"m_options");
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

	float by = 0;
	float bx = 0;
	float maxposx = -SCRLY-padding;
	float optionswidth = menux-SCRLY;
	vector optionsize = [optionswidth, TXT_NMSZ];

	// Headline
	fr.addc(spawn_headline("Audio"), by); by+=TXT_MDSZ+padding;

	// Button
	fr.add(spawn(mitem_text, item_text:_("Restart Sound"),
		item_command:"snd_restart",
		item_scale:TXT_MDSZ,
		item_flags:IF_CENTERALIGN),
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
		[0, by], [maxposx, TXT_MDSZ]
	); by += TXT_MDSZ+spacing;

	by += padding;
	
	float fl = RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN;

	if (engine!=E_QSS) {
		fr.add(spawn_combo(_("Sound Device"), "s_device", optionsize, cvar_string("_s_device_opts")), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing; }
	fr.add(spawn_hslider(_("Master Volume"),"volume", '0.0 1 0.1', optionsize), 
		fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	fr.add(spawn_hslider(_("Ambient Volume"), "ambient_level", '0 0.5 0.05', optionsize), 
		fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	if (engine!=E_QSS) {
		fr.add(spawn_hslider(_("Self Volume"), "s_localvolume", '0 1 0.1', optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing; }
	fr.add(spawn_hslider(_("Music Volume"), "bgmvolume", '0 0.5 0.05', optionsize), 
		fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	if (engine!=E_QSS) {
		fr.add(spawn_hslider(_("Channels"), "s_numspeakers", '1 6 1', optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing; }
	if (engine==E_QSS) 
	{
		fr.add(spawn_combo(_("Audio Filtering"), "sndspeed", optionsize, _(
			"\"\"	\"Off\" "
			"11025	\"On\" "
			)),	fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing; 
	}
	if (engine!=E_QSS) 
	{
		fr.add(spawn_combo(_("Audio Quality"), "s_khz", optionsize, _(
			"8 \"8000hz (telephone)\" "
			"11.025 \"11025hz (vanilla)\" "
			"22.05 \"22050hz\" "
			"44.1 \"44100hz (cd)\" "
			"48 \"48000hz (dvd)\" "
			//higher values are probably pointless when source data doesn't go that high, so not going to list them.
			//"96	\"96000hz (blu-ray quality)\" "
			//"192	\"192000hz (professional quality)\" "
		)),	fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	}
	if (engine!=E_QSS) 
	{
		fr.add(spawn_check(_("Doppler"), "s_doppler", optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
		fr.add(spawn_check(_("8bit audio"), "s_loadas8bit", optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	}
	if (engine!=E_QSS) 
	{
		fr.add(spawn_check(_("Swap Speakers"), "s_swapstereo", optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
		fr.add(spawn_hslider(_("Latency"), "s_mixahead", '0.1 0.3 0.01', optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	}
	fr.add(spawn_check(_("Disable Sound"), "nosound", optionsize), 
		fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	//ambient fade
	if (engine!=E_QSS) {
	fr.add(spawn_check(_("Static Sounds"), "cl_staticsounds", optionsize), 
		fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing; }
	if (engine!=E_QSS) {
		fr.add(spawn_check(_("Mix in Background"),"s_inactive", optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing; }

	by += padding;

	if (engine!=E_QSS)
	{
		fr.add(spawn_combo(_("Microphone Device"), "cl_voip_capturedevice", optionsize, cvar_string("_cl_voip_capturedevice_opts")), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
		fr.add(spawn_hslider(_("VOIP Playback Vol"),"cl_voip_play", '0 2 0.1', optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
		fr.add(spawn_check(_("VOIP Test"), "cl_voip_test", optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
		fr.add(spawn_hslider(_("VOIP Record Vol"), "cl_voip_micamp", '0 4 0.1', optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
		fr.add(spawn_combo(_("VOIP Mode"), "cl_voip_send", optionsize, _(
			"0 \"Push-To-Talk\" 1"
			"\"Voice Activation\""
			"2 \"Continuous\""
		)), fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
		//VAD threshhold
		//ducking
		//noise cancelation
		fr.add(spawn_combo(_("VOIP Codec"), "cl_voip_codec", optionsize, _(
			"\"\" \"Auto\""
			"0 \"speex (narrow 11khz)\""
			//"1 \"raw (wasteful)\""
			"2 \"opus\""
			"3 \"speex (narrow 8khz)\""
			"4 \"speex (wide 16khz)\""
			"5 \"speex (ultrawide 32khz)\""
		)), fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
		fr.add(spawn_hslider(_("Opus bitrate"), "cl_voip_bitrate", '0.5 128 0.5', optionsize), 
			fl, [bx, by], [maxposx, TXT_NMSZ]); by += TXT_NMSZ+spacing;
	}

	by += padding; 

	// extra spacing for drop-downs
	fr.add(spawn_mitem_spacer(16, -1), 
		fl, [bx, by], [maxposx, 24]);

	addmenuback(mm);
};
