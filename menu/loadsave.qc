#ifndef LOADSAVE_QC
#define LOADSAVE_QC

//I'm feeling lazy, so I'm going to only provide X slots, like quake's menu.
static string savenames[] =
{
	"quick",
	"s0",
	"s1",
	"s2",
	"s3",
	"s4",
	"s5",
	"s6",
	"s7",
	"s8",
	"s9",
	"s10",
	"s11",
	"a0",
	"a1",
	"a2",
};
#define NUMSAVESLOTS savenames.length

/*
class mitem_savescreeny : mitem
{
	virtual void(vector pos) item_draw =
	{
		string s = sprintf("saves/s%g/screeny.png", selectedsaveslot);
		if not(whichpack(s))
			if (drawgetimagesize(s) != '0 0 0')
				ui.drawpic(pos, s, item_size, item_rgb, item_alpha, 0);
	};
};
*/
class mitem_saveoption : mitem_text
{
	string slot;
	float mode;

	virtual void() mitem_saveoption =
	{
		if (mode)
			item_flags |= IF_SELECTABLE;
	};

	virtual void(vector pos) item_draw =
	{
		//some sort of pulsing if its active.
		if (item_flags & IF_KFOCUSED)
			ui.drawfill(pos, item_size, '1 0 0', sin(cltime)*0.125+0.150, 0);

		float w = stringwidth(item_text, TRUE, '1 1 0'*item_scale);
		ui.drawstring(pos + [(item_size_x-w)/2, 0], item_text, '1 1 0' * item_scale, menuitem_textcolour(this), item_alpha, 0);
	};

	virtual float(vector pos, float scan, float char, float down) item_keypress =
	{
		if (!down)
			return FALSE;
		if (scan == K_ENTER || (scan == K_MOUSE1 && mouseinbox(pos, this.item_size)))
		{
			if (item_flags & IF_KFOCUSED)
			{
				switch(mode)
				{
				case 0:
					break;	//can't load a slot which is empty.
				case 1:
					localcmd(sprintf("m_pop;load %s\n", slot));
					break;
				case 2:
					//FTE has a savegame_legacy command if you want compatibility with other engines.
					localcmd(sprintf("m_pop;wait;echo \"%s\";save %s\n", _("Saving Game"), slot));
					//localcmd(sprintf("m_pop;wait;screenshot saves/s%g/screeny.png;echo \"%s\";save s%g\n", slot, _("Saving Game"), slot));
					break;
				}
			}
			else
			{
				item_parent.item_focuschange(this, IF_KFOCUSED);
			}
			return TRUE;
		}
		return FALSE;
	};
};

class mitem_savepreview : mitem
{
	//assumption: the only selectable children in the parent are save options.
	virtual void(vector pos) item_draw =
	{
		mitem_saveoption sel;
		sel = (mitem_saveoption)item_parent.item_kactivechild;
		if (sel)
		{
			string s = sprintf("saves/%s/screeny.tga", sel.slot);
			if (drawgetimagesize(s) != '0 0 0')
				ui.drawpic(pos, s, item_size, item_rgb, item_alpha, 0);
		}
	};
};

static string(string savename) scansave =
{
	string v;
	string l;
	string filepath = sprintf("saves/%s/info.fsv", savename);
	float f = fopen(filepath, FILE_READ);
	if (f < 0)
		f = fopen(sprintf("%s.sav", savename), FILE_READ);
	if (f < 0)
		return __NULL__;	//weird

	v = fgets(f); //should be the version
	l = fgets(f); //description
	fclose(f);

	if (l)
	{
		l = strreplace("_", " ", l);
		// Legacy saves pad the description with underscores. Discard that
		// padding before centering, otherwise the visible title shifts left.
		while (strlen(l) && substring(l, -1, 1) == " ")
			l = substring(l, 0, strlen(l)-1);

		// TODO: get modificaton date - VBS
		// filepath = sprintf("%s.sav", savename); // correct path
		// searchhandle sh = search_begin(filepath, 0, 0);
		// if (sizeof(sh) > 0) {
		// 	string moddt = search_getfilemtime(sh,0); // get date time
		// 	// "%Y-%m-%d %H:%M:%S"
		// }
		// search_end(sh);
	}

	return l;
};

void(mitem_desktop desktop, float mode) M_LoadSave =
{
	float smode;
	string saveorload = ((mode==2)?"gfx/p_save.lmp":"gfx/p_load.lmp"); // pick banner
	float ssx = ui.screensize.x;
	float ssy = ui.screensize.y;
	float menux = MENU_WIDTH;
	float menuy = MENU_HEIGHT;
	float padding = PADDING;

	// Main menu

	// no dupes please.
	local mitem_exmenu mm;
	string title = mode == 2 ? _("Save Game") : _("Load Game");
	mm = (mitem_exmenu)desktop.findchildtext(title);
	if (mm) { mm.totop(); return; }
	mm = spawn(mitem_exmenu, item_text:title, item_flags:IF_SELECTABLE, item_command:"m_single");
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
	mitem_pic banner = spawn(mitem_pic, item_text:saveorload, item_size_y:24, item_flags:IF_CENTERALIGN);
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
		[0, banner.item_size_y+padding], // top-left
		[0, 0] // bottom-right
	);

	string l;
	float i;
	float y=0;
	float itemscale=8;
	float cansave = isserver() || dp_workarounds;
	if (mode == 2 && !cansave)
	{
		fr.addc(spawn_text(_("Start a single-player game to save"), "", itemscale), y);
		y += itemscale+PADDING;
	}
	for (i = 0; i < NUMSAVESLOTS; i++)
	{
		// Headings are separate, non-interactive widgets, never save slots.
		if (savenames[i] == "quick" || savenames[i] == "s0" || savenames[i] == "a0")
		{
			string heading = savenames[i] == "quick" ? _("QUICK SAVE") :
				savenames[i] == "s0" ? _("MY SAVES") : _("AUTO SAVE");
			fr.addc(spawn_headline(heading, itemscale), y);
			y += itemscale+2;
		}
		l = scansave(savenames[i]);
		smode = mode;
		if (l=="")
		{
			l = "--- Empty Slot ---";
			if (mode==1)
				smode = 0;
		}

		if (mode == 2 && !cansave)
			smode = 0;

		// line item
		fr.add(
			spawn(mitem_saveoption, item_scale:itemscale, slot:savenames[i], mode:smode, item_text:l),
			RS_X_MIN_PARENT_MIN|RS_Y_MIN_PARENT_MIN | RS_X_MAX_PARENT_MAX|RS_Y_MAX_OWN_MIN,
			[0, y], // top left
			[-SCRLY, itemscale]); // leave room for the scrollbar

		y+=itemscale+2; // a little padding for the next line item
	}

	addmenuback(mm);
};

void(mitem_desktop desktop) M_Load =
{
	M_LoadSave(desktop, 1);
};
void(mitem_desktop desktop) M_Save =
{
	M_LoadSave(desktop, 2);
};
#endif
