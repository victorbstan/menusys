// Centered server browser using the engine's host cache.

//WARNING: make sure you only create one server browser widget otherwise they'll fight each other

#ifndef MOD_GAMEDIR
//look up what its meant to be.
//#define MOD_GAMEDIR cvar_string("game")
#endif

#include "../menusys/mitem_menu.qc"		//subwindow

var float autocvar_sb_shownumplayers = 1;
var float autocvar_sb_showmaxplayers = 0;
var float autocvar_sb_showfraglimit = 0;
var float autocvar_sb_showtimelimit = 0;
var float autocvar_sb_showping = 1;
var float autocvar_sb_showgamedir = 0;
var float autocvar_sb_showaddress = 0;
var float autocvar_sb_showmap = 1;
var float autocvar_sb_showname = 1;
var float autocvar_sb_onlyfavs = 0;

// Keep the FTE browser's saved protocol, proxy, and population preferences.
void() servers_filter =
{
	resethostcachemasks();
	float field = gethostcacheindexforkey("basegame");
	if (field >= 0)
	{
		sethostcachemasknumber(0, field, 0, SLIST_TEST_NOTEQUAL);
		if (cvar("sb_hidenetquake"))
		{
			sethostcachemasknumber(0, field, 2, SLIST_TEST_NOTEQUAL);
			sethostcachemasknumber(0, field, 3, SLIST_TEST_NOTEQUAL);
		}
		if (cvar("sb_hidequakeworld")) sethostcachemasknumber(0, field, 1, SLIST_TEST_NOTEQUAL);
	}
	field = gethostcacheindexforkey("flags");
	if (field >= 0)
	{
		if (cvar("sb_hideproxies")) sethostcachemasknumber(0, field, 128, SLIST_TEST_NOTCONTAIN);
		if (autocvar_sb_onlyfavs) sethostcachemasknumber(0, field, 32, SLIST_TEST_CONTAINS);
	}
	field = gethostcacheindexforkey("numhumans");
	if (field >= 0 && cvar("sb_hideempty")) sethostcachemasknumber(0, field, 0, SLIST_TEST_NOTEQUAL);
	field = gethostcacheindexforkey("freeslots");
	if (field >= 0 && cvar("sb_hidefull")) sethostcachemasknumber(0, field, 0, SLIST_TEST_NOTEQUAL);
	field = gethostcacheindexforkey("name");
	if (field >= 0 && cvar_string("sb_filtertext") != "")
		sethostcachemaskstring(0, field, cvar_string("sb_filtertext"), SLIST_TEST_CONTAINS);
#ifdef MOD_GAMEDIR
	field = gethostcacheindexforkey("gamedir");
	if (field >= 0 && MOD_GAMEDIR != "") sethostcachemaskstring(0, field, MOD_GAMEDIR, SLIST_TEST_EQUAL);
#endif
};

//#define COLUMN(width, sortname, title, draw)
#define COLUMN_NUMPLAYERS COLUMN(2*8, numplayers, "Pl", ui.drawstring(pos, sprintf("%-2g", gethostcachenumber(field_numplayers, sv)), '8 8', col, 1, 0);)
#define COLUMN_MAXPLAYERS COLUMN(2*8, maxplayers, "MP", ui.drawstring(pos, sprintf("%-2g", gethostcachenumber(field_maxplayers, sv)), '8 8', col, 1, 0);)
#define COLUMN_PING COLUMN(4*8, ping, "Ping", ui.drawstring(pos, sprintf("%-4g", gethostcachenumber(field_ping, sv)), '8 8', col, 1, 0);)
#define COLUMN_FRAGLIMIT COLUMN(4*8, fraglimit, "FL", ui.drawstring(pos, sprintf("%-3g", gethostcachenumber(field_fraglimit, sv)), '8 8', col, 1, 0);)
#define COLUMN_TIMELIMIT COLUMN(4*8, timelimit, "TL", ui.drawstring(pos, sprintf("%-3g", gethostcachenumber(field_timelimit, sv)), '8 8', col, 1, 0);)
#define COLUMN_GAMEDIR COLUMN(8*8, gamedir, "Gamedir", ui.drawstring(pos, sprintf("%-.8s", gethostcachestring(field_gamedir, sv)), '8 8', col, 1, 0);)
#define COLUMN_ADDRESS COLUMN(16*8, address, "Address", ui.drawstring(pos, sprintf("%-.16s", gethostcachestring(field_address, sv)), '8 8', col, 1, 0);)
#define COLUMN_MAP COLUMN(8*8, map, "Map", ui.drawstring(pos, sprintf("%-.8s", gethostcachestring(field_map, sv)), '8 8', col, 1, 0);)
#define COLUMN_HOSTNAME COLUMN(namewidth, name, "Name", ui.drawstring(pos, gethostcachestring(field_name, sv), '8 8', col, 1, 0);)
//FIXME: add a little * icon before the hostname for favourites or something

#define DETAIL_COLUMNS COLUMN_NUMPLAYERS COLUMN_MAXPLAYERS COLUMN_PING COLUMN_FRAGLIMIT COLUMN_TIMELIMIT COLUMN_GAMEDIR COLUMN_ADDRESS COLUMN_MAP
#define COLUMNS COLUMN_HOSTNAME DETAIL_COLUMNS

// Compact switches use text states so replacement conchars need no checkbox
// glyphs, and long labels stay inside their own column at small resolutions.
class mitem_servercheck : mitem_check
{
    virtual void(vector pos) item_draw =
    {
        vector col = menuitem_textcolour(this);
        ui.drawstring(pos, item_text, '8 8', col, item_alpha, 0);
        ui.drawstring(pos+[item_size.x-24, 0], stof(get(item_command)) ? "on" : "off", '8 8', col, item_alpha, 0);
    };
};
mitem_check(string title, string setting, vector size) spawn_servercheck =
{
    return spawn(mitem_servercheck, item_text:title, item_command:setting, item_size:size, item_scale:8);
};

class mitem_servers : mitem
{
	float server_selected;
	mitem_vslider slider;
	float dbltime;
	float dobound;
	float namewidth;
	float nextsort;

	void() mitem_servers =
	{
		dbltime = cltime - 10;
		this.item_flags |= IF_SELECTABLE;
		server_selected = -1;

		//clear the filter
		servers_filter();
		//sort by ping by default
		sethostcachesort(gethostcacheindexforkey("ping"), FALSE);
		//(re)query the servers.
		refreshhostcache();

		resorthostcache();
	};

	virtual void(vector pos) item_draw =
	{
		// Replies arrive asynchronously; refresh the sorted view as they arrive.
		if (cltime >= nextsort)
		{
			string selected = __NULL__;
			float addressfield = gethostcacheindexforkey("cname");
			if (server_selected >= 0)
				selected = strzone(gethostcachestring(addressfield, server_selected));
			servers_filter();
			resorthostcache();
			if (selected)
			{
				server_selected = -1;
				for (float index = 0; index < gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT); index++)
					if (gethostcachestring(addressfield, index) == selected) { server_selected = index; break; }
				strunzone(selected);
				dobound = TRUE;
			}
			nextsort = cltime + 0.5;
		}
		local float sv, maxsv = gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT);
		local float maxy = self.item_size_y;
		float left = pos_x;

		local vector omin = ui.drawrectmin, omax = ui.drawrectmax;
		local vector cmin = pos + '0 8', cmax = pos + item_size;

		cmin_x = max(omin_x, cmin_x);
		cmin_y = max(omin_y, cmin_y);
		cmax_x = min(omax_x, cmax_x);
		cmax_y = min(omax_y, cmax_y);

		slider.maxv = max(0, maxsv - (floor(maxy/8) - 1));
		slider.val = bound(0, slider.val, slider.maxv);
		if (server_selected >= maxsv) server_selected = maxsv - 1;

		//constrain the view the lazy way.
		if (dobound)
		{
			dobound = FALSE;
			if (slider.val < 0)
				slider.val = 0;
			while (slider.val + floor(maxy/8) - 1 <= server_selected)
				slider.val+=1;
			while (server_selected < slider.val && slider.val > 0)
				slider.val-=1;
			slider.val = bound(0, slider.val, slider.maxv);
		}

		float field_name = gethostcacheindexforkey("name");
		float field_ping = gethostcacheindexforkey("ping");
		float field_numplayers = gethostcacheindexforkey("numhumans");
		if (field_numplayers < 0)
			field_numplayers = gethostcacheindexforkey("numplayers");
		float field_maxplayers = gethostcacheindexforkey("maxplayers");
		float field_gamedir = gethostcacheindexforkey("gamedir");
		if (field_gamedir < 0)
			field_gamedir = gethostcacheindexforkey("mod");
		float field_address = gethostcacheindexforkey("cname");
		float field_map = gethostcacheindexforkey("map");
		float field_timelimit = gethostcacheindexforkey("timelimit");
		float field_fraglimit = gethostcacheindexforkey("fraglimit");
		float detailwidth = 0;
#define COLUMN(width, sortname, title, draw) if (field_##sortname<0) autocvar_sb_show##sortname = FALSE; if (autocvar_sb_show##sortname) detailwidth += width+8;
		DETAIL_COLUMNS
#undef COLUMN
		namewidth = max(64, item_size.x - detailwidth - 8);

		maxy = ceil(maxy/8) - 1;
		if (maxsv  > slider.val + maxy)
			maxsv = slider.val + maxy;

		float sort = gethostcachevalue(SLIST_SORTFIELD);
		string colkey = __NULL__;
#define COLUMN(width, sortname, title, draw) if (autocvar_sb_show##sortname) {if (mouseinbox(pos, [width, 8])) colkey = #sortname; pos_x += width+8;}
		COLUMNS
#undef COLUMN

		vector col;
		pos_x = left;
		ui_clipchild(left, pos.y, item_size.x, 8);
#define COLUMN(width, sortname, title, draw) if (autocvar_sb_show##sortname) {col = '1 1 1'; if (sort == field_##sortname) col_z = 0; if (colkey == #sortname) col = RGB_BGHOVERA; ui.drawstring(pos, title, '8 8', col, 1, 0); pos_x += width+8;}
		COLUMNS
#undef COLUMN

		//make sure things get cut off if we have too many rows (or fractional start)
		ui.setcliparea(cmin[0], cmin[1], max(0, cmax[0] - cmin[0]), max(0, cmax[1] - cmin[1]));
		ui.drawrectmin = cmin;
		ui.drawrectmax = cmax;

		pos_y += 8 * (1-(slider.val-floor(slider.val)));
		for (float y=pos_y,	sv = max(0, floor(slider.val)); sv < maxsv; sv+=1)
		{
			col = (sv&1) ? RGB_BGHOVERA : RGB_BGHOVERB;
			ui.drawfill([left, y], [item_size_x,8], col, 0.8, 0);
			y += 8;
		}
		for (	sv = max(0, floor(slider.val)); sv < maxsv; sv+=1)
		{
			col = ((server_selected==sv) ? RGB_TXTB : RGB_TXT);

			//if isproxy
			//if islocal
			//if isfavorite

			pos_x = left;
#define COLUMN(width, sortname, title, draw) if (autocvar_sb_show##sortname) { ui_clipchild(max(cmin.x, pos.x), pos.y, min(width, max(0, cmax.x-pos.x)), 8); draw pos_x += width+8; }
			COLUMNS
#undef COLUMN
			pos_y += 8;
		}
		if (!gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT))
		{
			ui.setcliparea(cmin.x, cmin.y, cmax.x-cmin.x, cmax.y-cmin.y);
			ui.drawstring([left, cmin.y+8], "Searching... R/F5 to refresh", '8 8', RGB_TXT, 1, 0);
		}

		ui.drawrectmin = omin;
		ui.drawrectmax = omax;
		ui.setcliparea(omin_x, omin_y, omax_x - omin_x, omax_y - omin_y);
	};
	virtual float(vector pos, float scan, float char, float down) item_keypress =
	{
		float displaysize;
		string addr;
		/*just sink all inputs*/
		if (!down)
			return FALSE;
		if (scan != K_MOUSE1)
			dbltime = cltime - 10;
		if (scan == K_MOUSE1)
		{
			if (!mouseinbox(pos, item_size)) return FALSE;
			float news = ui.mousepos[1] - (pos_y+8);
			news = floor(news / 8);
			if (news == -1)
			{
				string colkey = "";
#define COLUMN(width, sortname, title, draw) if (autocvar_sb_show##sortname) {if (mouseinbox(pos, [width, 8])) colkey = #sortname; pos_x += width+8;}
				COLUMNS
#undef COLUMN
				if (colkey != "")
				{
					float fld = gethostcacheindexforkey(colkey);
					if (colkey == "numplayers")
					{
						float humans = gethostcacheindexforkey("numhumans");
						if (humans >= 0) fld = humans;
						//favour descending order
						sethostcachesort(fld, (gethostcachevalue(SLIST_SORTFIELD) != fld) || !gethostcachevalue(SLIST_SORTDESCENDING));
					}
					else
					{
						//favour ascending order
						sethostcachesort(fld, (gethostcachevalue(SLIST_SORTFIELD) == fld) && !gethostcachevalue(SLIST_SORTDESCENDING));
					}
					resorthostcache();	//tell the engine that its okay to resort everything.
					dobound = TRUE;
				}
				return TRUE;
			}
			news += floor(slider.val);
			if (news < 0 || news >= gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT))
				return TRUE;

			if (server_selected == news && dbltime > cltime)
			{
				//connect on double clicks. because we can.
				addr = classic_filearg(gethostcachestring(gethostcacheindexforkey("cname"), server_selected));
				if (addr)
					localcmd(sprintf("m_pop;connect %s\n", addr));
			}
			else
				server_selected = news;
			dobound = TRUE;

			dbltime = cltime + 0.5;
		}
		else if (scan == K_ENTER)
		{	//connect normally
			if (server_selected < 0) return TRUE;
			addr = classic_filearg(gethostcachestring(gethostcacheindexforkey("cname"), server_selected));
			if (addr)
				localcmd(sprintf("m_pop;connect %s\n", addr));
		}
		else if (scan == 's')
		{	//s = join as a spectator
			if (server_selected < 0) return TRUE;
			addr = classic_filearg(gethostcachestring(gethostcacheindexforkey("cname"), server_selected));
			if (addr)
				localcmd(sprintf("m_pop;observe %s\n", addr));
		}
		else if (scan == 'j')
		{	//s = join as a spectator
			if (server_selected < 0) return TRUE;
			addr = classic_filearg(gethostcachestring(gethostcacheindexforkey("cname"), server_selected));
			if (addr)
				localcmd(sprintf("m_pop;join %s\n", addr));
		}
		else if (scan == K_UPARROW || scan == K_MWHEELUP)
		{
			this.server_selected -= 1;
			if (this.server_selected < 0)
			{
				this.server_selected = gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT);
				if (this.server_selected)
					this.server_selected -= 1;
			}
			dobound = TRUE;
		}
		else if (scan == K_DOWNARROW || scan == K_MWHEELDOWN)
		{
			this.server_selected += 1;
			if (this.server_selected >= gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT))
				this.server_selected = 0;
			dobound = TRUE;
		}
		else if (scan == K_PGUP)
		{
			displaysize = (item_size[1]-8)/(8);	//this many rows
			displaysize = floor(displaysize*0.5);
			if (displaysize < 1)
				displaysize = 1;
			this.server_selected -= displaysize ;
			if (this.server_selected < 0)
				this.server_selected = 0;
			dobound = TRUE;
		}
		else if (scan == K_PGDN)
		{
			displaysize = (item_size[1]-8)/(8);	//this many rows
			displaysize = floor(displaysize*0.5);
			if (displaysize < 1)
				displaysize = 1;
			this.server_selected += displaysize;
			if (this.server_selected >= gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT))
				this.server_selected = gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT)-1;
			dobound = TRUE;
		}
		else if (scan == K_HOME)
		{
			this.server_selected = 0;
			dobound = TRUE;
		}
		else if (scan == K_END)
		{
			this.server_selected = gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT)-1;
			if (this.server_selected < 0)
				this.server_selected = 0;
			dobound = TRUE;
		}
		else if (char == 'r' || char == 'R' || scan == K_F5)
		{
			refreshhostcache();
			resorthostcache();
		}
		else
			return FALSE;
		return TRUE;
	};
};

class mitem_servers_players : mitem
{
	mitem_servers listing;

	void() mitem_servers_players =
	{
//		this.item_flags |= IF_SELECTABLE;
	};

	virtual void(vector pos) item_draw =
	{
		float player;
		float y;
		float m;
		vector opos = pos;
		if (listing.server_selected < 0)
			return;
		vector oldmin = ui.drawrectmin, oldmax = ui.drawrectmax;
		ui_clipchild(pos.x, pos.y, item_size.x, item_size.y);
		for (player = 0, y = 0; player < 256; player++)
		{
			string playerinfo = gethostcachestring(gethostcacheindexforkey(sprintf("player%g", player)), listing.server_selected);
			if (!playerinfo)
				break;
			tokenize(playerinfo);
			float userid	= stof(argv(0));
			float frags		= stof(argv(1));
			float ontime	= stof(argv(2));
			float ping		= stof(argv(3));
			string name		= argv(4);
			string skin		= argv(5);
			vector top		= stov(argv(6));
			vector bot		= stov(argv(7));

			ui.drawfill(pos, '16 4', top, 1, 0);
			ui.drawfill(pos+'0 4 0', '16 4', bot, 1, 0);
			ui.drawstring(pos,	sprintf("%g", frags), '8 8', RGB_TXT, 1, 0);
			ui.drawstring(pos+'20 0', name, '8 8', RGB_TXT, 1, 0);
			pos_y += 8;
			if (++y == 8)
			{
				y-= 8;
				pos_y = opos_y;
				pos_x += 16*8;
			}
		}

		if (y)
		{
			pos_y = opos_y;
			pos_x += 16*6;
			y = 0;
		}
//		ui_textfield(opos, item_size, 3, gethostcachestring(gethostcacheindexforkey("serverinfo"), listing.server_selected));
		m = tokenizebyseparator(gethostcachestring(gethostcacheindexforkey("serverinfo"), listing.server_selected), "\\");
		for(player = 1; player+1 < m; player += 2)
		{
			ui_textfield(pos, '64 8', 6, argv(player), 8);
			ui_textfield(pos+'68 0', [32*8-40, 8], 3, argv(player+1), 8);

			pos_y += 8;
			if (++y == 8)
			{
				y-= 8;
				pos_y -= 8*8;
				pos_x += 32*8;
			}
		}
		ui.setcliparea(oldmin.x, oldmin.y, oldmax.x-oldmin.x, oldmax.y-oldmin.y);
	};
};


// The panel follows window resizing while keeping a useful list size on large
// displays. Its parent remains fullscreen for normal Escape/back behavior.
class mitem_serverpanel : mitem_frame
{
    virtual void(vector pos) item_draw =
    {
        ui.drawfill(pos, item_size, '0.03 0.03 0.03', 0.65, 0);
        super::item_draw(pos);
    };
    virtual void() item_resized =
    {
        item_size = [min(480, item_parent.item_size.x-8), min(280, item_parent.item_size.y-8)];
        item_position = (item_parent.item_size-item_size)*0.5;
        super::item_resized();
    };
};

nonstatic void(mitem_desktop desktop) M_Servers =
{
    // Prefer our layout whenever the host-cache API exists. An explicit native
    // request, or an older engine without the API, uses the engine browser.
    if (argv(1) == "native" || !checkbuiltin2(gethostcacheindexforkey, FALSE))
    {
        if (checkcommand2("menu_servers", FALSE)) localcmd("menu_servers\n");
        else print(_("Server browsing is unavailable in this engine.\n"));
        return;
    }

    mitem_exmenu existing = (mitem_exmenu)desktop.findchildtext(_("Servers List"));
    if (existing) { existing.totop(); return; }
    mitem_exmenu m = spawn(mitem_exmenu, item_text:_("Servers List"), item_flags:IF_SELECTABLE, item_command:"m_multi");
    desktop.add(m, RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, '0 0', '0 0');
    desktop.item_focuschange(m, IF_KFOCUSED);
    m.totop();
    mitem_serverpanel panel = spawn(mitem_serverpanel, item_flags:IF_SELECTABLE);
    m.add(panel, RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX, '0 0', '0 0');
    mitem_pic banner = spawn(mitem_pic, item_text:"gfx/p_multi.lmp", item_size_y:24);
    panel.add(banner, RS_X_MIN_PARENT_MID|RS_Y_MIN_PARENT_MIN | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN,
        [-banner.item_size.x*0.5, 4], banner.item_size);

    mitem_vslider sl = spawn(mitem_vslider, stride:4, item_flags:IF_SELECTABLE);
    mitem_servers ls = spawn(mitem_servers, slider:sl, item_text:"Server rows");
    panel.add(ls, RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX,
        '8 32', '-20 -80');
    panel.add(sl, RS_X_MIN_PARENT_MAX|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_PARENT_MAX,
        '-16 40', '-8 -80');

    float flags = RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MAX | RS_X_MAX_OWN_MIN|RS_Y_MAX_OWN_MIN;
    // Display switches retain the engine's sb_show* preferences.
    if (gethostcacheindexforkey("ping") >= 0)
        panel.add(spawn_servercheck(_("Ping"), "sb_showping", '144 8'), flags, '8 -72', '144 8');
    if (gethostcacheindexforkey("cname") >= 0)
        panel.add(spawn_servercheck(_("Address"), "sb_showaddress", '144 8'), flags, '8 -64', '144 8');
    if (gethostcacheindexforkey("map") >= 0)
        panel.add(spawn_servercheck(_("Map"), "sb_showmap", '144 8'), flags, '8 -56', '144 8');
    if (gethostcacheindexforkey("gamedir") >= 0 || gethostcacheindexforkey("mod") >= 0)
        panel.add(spawn_servercheck(_("Gamedir"), "sb_showgamedir", '144 8'), flags, '8 -48', '144 8');
    if (gethostcacheindexforkey("numplayers") >= 0)
        panel.add(spawn_servercheck(_("Players"), "sb_shownumplayers", '144 8'), flags, '8 -40', '144 8');
    if (gethostcacheindexforkey("maxplayers") >= 0)
        panel.add(spawn_servercheck(_("Capacity"), "sb_showmaxplayers", '144 8'), flags, '8 -32', '144 8');
    if (gethostcacheindexforkey("fraglimit") >= 0)
        panel.add(spawn_servercheck(_("Fraglimit"), "sb_showfraglimit", '144 8'), flags, '8 -24', '144 8');
    if (gethostcacheindexforkey("timelimit") >= 0)
        panel.add(spawn_servercheck(_("Timelimit"), "sb_showtimelimit", '144 8'), flags, '8 -16', '144 8');
    panel.add(spawn(mitem_text, item_text:_("Refresh (R/F5)"), item_command:"m_pop;m_servers", item_scale:8),
        flags, '168 -72', '112 8');
    if (gethostcacheindexforkey("basegame") >= 0)
    {
        panel.add(spawn_servercheck(_("Hide NQ"), "sb_hidenetquake", '128 8'), flags, '168 -60', '128 8');
        panel.add(spawn_servercheck(_("Hide QW"), "sb_hidequakeworld", '128 8'), flags, '168 -52', '128 8');
        panel.add(spawn_servercheck(_("Hide Proxy"), "sb_hideproxies", '128 8'), flags, '168 -44', '128 8');
        panel.add(spawn_servercheck(_("Hide Empty"), "sb_hideempty", '128 8'), flags, '168 -36', '128 8');
        panel.add(spawn_servercheck(_("Hide Full"), "sb_hidefull", '128 8'), flags, '168 -28', '128 8');
        panel.add(spawn_servercheck(_("Only Favs"), "sb_onlyfavs", '128 8'), flags, '168 -20', '128 8');
    }
    if (checkcommand2("menu_servers", FALSE))
        panel.add(spawn(mitem_text, item_text:_("Advanced browser"), item_command:"m_pop;m_servers native", item_scale:8),
            flags, '168 -8', '128 8');
    // Focus the actual list so arrows/Enter/R/F5 work immediately on entry.
    m.item_focuschange(panel, IF_KFOCUSED);
    panel.item_focuschange(ls, IF_KFOCUSED);
    addmenuback(m);
};
