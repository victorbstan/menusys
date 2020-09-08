//FIXME: maxclients is a QW thing. NQ engines use maxplayers (which requires a disconnect to apply)
static string newgameinfo;

class mitem_newgame : mitem_exmenu
{
	virtual string(string key) get =
	{
		return infoget(newgameinfo, key);
	};
	virtual void(string key, string newval) set =
	{
		string old = newgameinfo;
		newgameinfo = strzone(infoadd(newgameinfo, key, newval));
		if (old)
			strunzone(old);
	};
};

nonstatic void(mitem_desktop desktop) M_NewGame =
{
	mitem_pic banner;
	string gametype = argv(1);

	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;
	float qplaquewidth = 32;
	float plaquepadding = 24;
	float titleoffset = -12;
	// text sizes

	if (gametype == "sp")
	{
		//single player has no options. the start map itself gives skill+episode options.
		localcmd("\ndisconnect; deathmatch 0; coop 0; maxplayers 0; timelimit 0; fraglimit 0; teamplay 0; samelevel 0; startmap_sp\n");
		return;
	}

	if (gametype == "begin")
	{
		cvar_set("hostname", 	infoget(newgameinfo, "hostname"));
		cvar_set("deathmatch", 	infoget(newgameinfo, "deathmatch"));
		cvar_set("coop", 		infoget(newgameinfo, "coop"));
		cvar_set("teamplay", 	infoget(newgameinfo, "teamplay"));
		cvar_set("sv_public", 	infoget(newgameinfo, "sv_public"));
		if (cvar_type("maxclients"))
		{
			cvar_set("maxclients", 	infoget(newgameinfo, "maxclients"));
		} else {
			localcmd(sprintf("disconnect;maxplayers \"%s\"\n", infoget(newgameinfo, "maxplayers")));
		}
		cvar_set("timelimit", 	infoget(newgameinfo, "timelimit"));
		cvar_set("fraglimit", 	infoget(newgameinfo, "fraglimit"));
		string map = 			infoget(newgameinfo, "map");
		if (map == "")
			map = sprintf("dm%g", floor(random(1, 6)));
		localcmd(sprintf("\nmap \"%s\"\n", map));
		return;
	}

	if (newgameinfo)
		strunzone(newgameinfo);
	newgameinfo = "";
	newgameinfo = infoadd(newgameinfo, "hostname", cvar_string("hostname"));
	newgameinfo = infoadd(newgameinfo, "deathmatch", cvar_string("deathmatch"));
	newgameinfo = infoadd(newgameinfo, "teamplay", cvar_string("teamplay"));
	newgameinfo = infoadd(newgameinfo, "sv_public", cvar_string("sv_public"));
	if (cvar_type("maxclients"))
		newgameinfo = infoadd(newgameinfo, "maxclients", cvar_string("maxclients"));
	newgameinfo = infoadd(newgameinfo, "timelimit", cvar_string("timelimit"));
	newgameinfo = infoadd(newgameinfo, "fraglimit", cvar_string("fraglimit"));
	newgameinfo = strzone(newgameinfo);

	// Main

	// no dupes please.
	local mitem_exmenu mm;
	mm = (mitem_exmenu)desktop.findchildtext(_("New Game"));
	if (mm) { mm.totop(); return; }
	// create a fullscreen frame, target previous menu
	mm = spawn(mitem_newgame, item_text:_("New Game"), item_flags:IF_SELECTABLE, item_command:"m_multi");
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
	
	// float qplaquewidth = 32;
	// m.add(spawn_pic("gfx/qplaque.lmp", '32 144'),
	// 	RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN,
	// 	[padding, padding], [qplaquewidth, 144]);

	// Title
	
	banner = spawn(mitem_pic, item_text:"gfx/p_multi.lmp", item_size_y:24, item_flags:IF_CENTERALIGN);
	m.add(
		banner,
		RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN,
		[(banner.item_size_x*-0.5)+titleoffset, padding], [banner.item_size_x*0.5, 24]
	);

	// Content

	// user for offsetting content
	float posx = 0;
	float posy = banner.item_size_y+(padding*2);
	float maxposx = -SCRLY-padding;
	float optionswidth = menux-SCRLY;
	vector optionsize = [optionswidth, TXT_NMSZ];

	//show game type selection
	switch(gametype)
	{
	case "tdm":
		break;
	case "dm":
		break;
	case "coop":
		break;
	case "sp":
		// NOTE: Deprecated. There is a single player entry from main menu
		// Title - single
		banner = spawn(mitem_pic, item_text:"gfx/ttl_sgl.lmp", item_size_y:24, item_flags:IF_CENTERALIGN);
		m.add(banner,
			RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN,
			[(banner.item_size_x*-0.5)+titleoffset, padding], [banner.item_size_x*0.5, 24]
		);

		// Options - single
		m.add(spawn(mitem_text, item_text:"Single Player", item_command:"m_pop;m_newgame sp", item_scale:TXT_LGSZ), 
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[qplaquewidth+plaquepadding, posy], [0, TXT_LGSZ]); posy+=TXT_LGSZ+padding;

		addmenuback(mm);
		break;
	default:
		// Title - multi
		banner = spawn(mitem_pic, item_text:"gfx/p_multi.lmp", item_size_y:24, item_flags:IF_CENTERALIGN);
		m.add(banner,
			RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MID|RS_Y_MAX_OWN_MIN,
			[(banner.item_size_x*-0.5)+titleoffset, padding], [banner.item_size_x*0.5, 24]
		);

		// Options - multi
		// NOTE: Could this simply be a drop-down selection in a new MP game setup screen?
		m.add(spawn(mitem_text, item_text:"Cooperative", item_command:"m_pop;m_newgame coop", item_scale:TXT_LGSZ), 
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[qplaquewidth+plaquepadding, posy], [0, TXT_LGSZ]); posy+=TXT_LGSZ+padding;
		m.add(spawn(mitem_text, item_text:"Deathmatch", item_command:"m_pop;m_newgame dm", item_scale:TXT_LGSZ), 
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[qplaquewidth+plaquepadding, posy], [0, TXT_LGSZ]); posy+=TXT_LGSZ+padding;
		m.add(spawn(mitem_text, item_text:"Team Deathmatch", item_command:"m_pop;m_newgame tdm", item_scale:TXT_LGSZ), 
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[qplaquewidth+plaquepadding, posy], [0, TXT_LGSZ]); posy+=TXT_LGSZ+padding;

		// m.add(spawn (mitem_spinnymodel, item_text: "progs/soldier.mdl",firstframe:73, framecount:8, shootframe:81, shootframes:9), RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID | RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID, [-160, 12*-16/2], [0, 12*16/2]);

		addmenuback(mm);
		return;
	}

	// Headline

	if (gametype == "dm")
		m.addc(spawn_headline("Deathmatch"), posy); 
	if (gametype == "tdm")
		m.addc(spawn_headline("Team Deathmatch"), posy);
	if (gametype == "coop")
		m.addc(spawn_headline("Cooperative"), posy);

	posy+=TXT_MDSZ+padding;

	// Settings

	m.add(spawn_edit(_("Hostname"), "hostname", optionsize), 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
		[posx, posy], [maxposx, TXT_NMSZ]
	); posy+=TXT_NMSZ+SPACING;
	
	m.add(spawn_combo(_("Public"), "sv_public", optionsize, _(
			"-1	\"Splitscreen\" "
			"0	\"Manual IP Sharing\" "
			"1	\"Public (Manual Config)\" "
			"2	\"Public (Holepunch)\" "
		)), 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
		[posx, posy], [maxposx, TXT_NMSZ]
	); posy+=TXT_NMSZ+SPACING;
	
	if (cvar_type("maxclients"))
	{
		m.add(spawn_combo(_("Max Clients"), "maxclients", optionsize, _(
				"2	\"Two\" "
				"3	\"Three\" "
				"4	\"Four\" "
				"8	\"Eight\" "
				"16	\"Sixteen\" "
				"32	\"Thirty Two\" "
			)),
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[posx, posy], [maxposx, TXT_NMSZ]
		); posy+=TXT_NMSZ+SPACING;
	} 
	else 
	{
		m.add(spawn_combo(_("Max Clients"), "maxplayers", optionsize, _(
				"2	\"Two\" "
				"3	\"Three\" "
				"4	\"Four\" "
			)),
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[posx, posy], [maxposx, TXT_NMSZ]
		); posy+=TXT_NMSZ+SPACING;
	}
	
	
	if (gametype == "dm" || gametype == "tdm")
	{
		if (m.get("deathmatch") == "0")
		{
			m.set("deathmatch", "1");
			m.set("coop", "0");
		}
		m.add(spawn_combo(_("Deathmatch Mode"), "deathmatch", optionsize, _(
				"1	\"Weapons Respawn\" "
				"2	\"Weapons Stay\" "
				"3	\"Powerups Respawn\" "
				"4	\"Start With Weapons\" "
			)),	
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[posx, posy], [maxposx, TXT_NMSZ]
		); posy+=TXT_NMSZ+SPACING;
	}
	else
	{
		if (m.get("coop") == "0")
		{
			m.set("deathmatch", "0");
			m.set("coop", "1");
		}
	}
	if (gametype == "tdm")
	{
		if (m.get("teamplay") == "0")
			m.set("teamplay", "1");
	}
	if (gametype == "dm")
	{
		if (m.get("teamplay") != "0")
			m.set("teamplay", "0");
	}
	if (gametype == "coop")
	{
		m.add(spawn_check(_("No Friendly Fire"), "teamplay", optionsize), 
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[posx, posy], [maxposx, TXT_NMSZ]
		); posy+=TXT_NMSZ+SPACING;
	}

	if (gametype == "coop")
		m.set("map", "start");
	else
	{
		m.add(spawn_combo(_("Time Limit"), "timelimit", optionsize, _(
				"0 \"No Limit\" "
				"5 \"5 minutes\" "
				"10 \"10 minutes\" "
				"15 \"15 minutes\" "
				"20 \"20 minutes\" "
				"25 \"25 minutes\" "
				"30 \"30 minutes\" "
				"35 \"35 minutes\" "
				"40 \"40 minutes\" "
				"45 \"45 minutes\" "
				"50 \"50 minutes\" "
				"55 \"55 minutes\" "
				"60 \"1 hour\" "
			)),	
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[posx, posy], [maxposx, TXT_NMSZ]
		); posy+=TXT_NMSZ+SPACING;

		m.add(spawn_combo(_("Frag Limit"), "fraglimit", optionsize, _(
				"0 \"No Limit\" "
				"10 \"10 frags\" "
				"20 \"20 frags\" "
				"30 \"30 frags\" "
				"40 \"40 frags\" "
				"50 \"50 frags\" "
				"60 \"60 frags\" "
				"70 \"70 frags\" "
				"80 \"80 frags\" "
				"90 \"90 frags\" "
				"100 \"100 frags\" "
			)),
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[posx, posy], [maxposx, TXT_NMSZ]
		); posy+=TXT_NMSZ+SPACING;

		m.set("map", ""); // will be random
		m.add(spawn_combo(_("Initial Map"), "map", optionsize, _(
				"dm1 \"DM1 (dm1)\" "
				"dm2 \"DM2 (dm2)\" "
				"dm3 \"DM3 (dm3)\" "
				"dm4 \"DM4 (dm4)\" "
				"dm5 \"DM5 (dm5)\" "
				"dm6 \"DM6 (dm6)\" "
				"start \"Start (Introduction)\" "
				"e1m1 \"E1M1 (The Slipgate Complex)\" "
				"e1m2 \"E1M2 (Castle Of The Damned)\" "
				"e1m3 \"E1M3 (The Necropolis)\" "
				"e1m4 \"E1M4 (The Grisly Grotto)\" "
				"e1m5 \"E1M5 (Gloom Keep)\" "
				"e1m6 \"E1M6 (The Door To Chthon)\" "
				"e1m7 \"E1M7 (The House Of Chthon)\" "
				"e1m8 \"E1M8 (Ziggarat Vertigo)\" "
				"e2m1 \"E2M1 (The Installation)\" "
				"e2m2 \"E2M2 (The Ogre Citadel)\" "
				"e2m3 \"E2M3 (The Crypt Of Decay)\" "
				"e2m4 \"E2M4 (The Ebon Fortress)\" "
				"e2m5 \"E2M5 (The Wizard's Manse)\" "
				"e2m6 \"E2M6 (The Dismal Oubliette\" "
				"e2m7 \"E2M7 (The Underearth)\" "
				"e3m1 \"E3M1 (Termination Central)\" "
				"e3m2 \"E3M2 (The Vaults Of Zin)\" "
				"e3m3 \"E3M3 (The Tomb Of Terror)\" "
				"e3m4 \"E3M4 (Satan's Dark Delight)\" "
				"e3m5 \"E3M5 (The Wind Tunnels)\" "
				"e3m6 \"E3M6 (Chambers Of Torment)\" "
				"e3m7 \"E3M7 (Tha Haunted Halls)\" "
				"e4m1 \"E4M1 (The Sewage System)\" "
				"e4m2 \"E4M2 (The Tower Of Despair)\" "
				"e4m3 \"E4M3 (The Elder God Shrine)\" "
				"e4m4 \"E4M4 (The Palace Of Hate)\" "
				"e4m5 \"E4M5 (Hell's Atrium)\" "
				"e4m6 \"E4M6 (The Pain Maze)\" "
				"e4m7 \"E4M7 (Azure Agony)\" "
				"e4m8 \"E4M8 (The Nameless City)\" "
				"end \"End (Shub-Niggurath's Pit)\" "
			)),	
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[posx, posy], [maxposx, TXT_NMSZ]
		); posy+=TXT_NMSZ+SPACING;
	}

	posy+=padding;

	m.add(spawn(mitem_text, item_text:"START", item_command:"m_pop;m_newgame begin", item_flags:IF_CENTERALIGN, item_scale:TXT_NMSZ), 
		RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
		[posx, posy], [maxposx, TXT_NMSZ]); posy+=TXT_NMSZ+padding;

	//random art for style
	// if (gametype == "coop")
		// m.add(spawn (mitem_spinnymodel, item_text: "progs/soldier.mdl", firstframe:73, framecount:8, shootframe:81, shootframes:9), RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID | RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID, [-160, -240/2], [0, 240/2]);
	// else
		// m.add(spawn (mitem_spinnymodel, item_text: "progs/player.mdl", firstframe:0, framecount:6, shootframe:119, shootframes:6), RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MID | RS_X_MAX_PARENT_MID|RS_Y_MAX_PARENT_MID, [-160, 12*-16/2], [0, 12*16/2]);

	addmenuback(mm);
};
