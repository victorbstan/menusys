/***************************************************************************
simple block-fill item
non-interactable.
*/
class mitem_fill : mitem
{
	virtual void(vector pos) item_draw =
	{
		ui.drawfill(pos, this.item_size, this.item_rgb, this.item_alpha, 0);
	};
};
#define menuitemfill_spawn(sz,rgb,alpha) spawn(mitem_fill, item_size:sz, item_rgb:rgb, item_alpha:alpha)

/***************************************************************************
simple spacing item, like block-fill, but invisible 
non-interactable.
*/
class mitem_spacer : mitem
{
	virtual void(vector pos) item_draw =
	{
		// -1 is no alpha, and 0 is full alpha?
		// ugly pink for debugging if alpha is not -1
		ui.drawfill(pos, this.item_size, '1 0 1', item_alpha, 0); 
	};
};
#define spawn_mitem_spacer(sz,alpha) spawn(mitem_spacer, item_size:sz, item_alpha:alpha)

/***************************************************************************
interactive block-fill item
can be used like a click-area / hotspot over images, etc.
*/
class mitem_filli : mitem
{
	float alpha;
	
	// shows hover text by cursor when over relevant items, 
	// could be done better, more generic
	string hover_text; 
	float hovtyoffset;
	float hovtsize;

	virtual void(vector pos) item_draw =
	{
		ui.drawfill(pos, item_size, item_rgb, alpha, 0);
		// draw something that follows cursor pos
		if (hover_text != "" && mouseinbox(pos, item_size)) {
			// note: will draw within widget area, might get cropped
			ui.drawstring(ui.mousepos - [0, hovtyoffset], hover_text, hovtsize*'1 1', RGB_TXT, 1, 0);
		}
	};

	virtual mitem(string ht, float htyo=-16, float hts=TXT_NMSZ) s_hover_text =
	{
		hover_text = strzone(ht);
		hovtyoffset = htyo;
		hovtsize = hts;
		return self;
	};

	void() mitem_filli = 
	{
		alpha = item_alpha;
		
		item_command = strzone(item_command);
		if (item_command != "")
		{
			item_command = strzone(item_command);
			item_flags |= IF_SELECTABLE;
		}
	};

	virtual float(vector pos, float scan, float char, float down) item_keypress =
	{
		if (item_command)
		{
			if (!down)
				return FALSE;
			if (scan == K_ENTER || (scan == K_MOUSE1 && mouseinbox(pos, item_size)))
			{
				item_parent.item_execcommand(this, item_command);
				return TRUE;
			}
		}
		return FALSE;
	};

	virtual void() item_remove =
	{
		if (item_command)
			strunzone(item_command);
		if (hover_text)
			strunzone(hover_text);
		super::item_remove();
	};
};
#define spawn_filli(c,sz,rgb,alph,ht) spawn(mitem_filli, item_command:c, item_size:sz, item_rgb:rgb, item_alpha:alph, hover_text:ht)


/***************************************************************************
picture item.
non-interactable.

item_text: the normal image to use
item_text_mactive: the image to use when the mouse is over it.
item_size: if not set, will be set to the size of the image named by item_text. if only y is set, x will be sized to match aspect with y.
*/
class mitem_pic : mitem
{
	string item_text_mactive;
	virtual void(vector pos) item_draw =
	{
		if (item_text_mactive != "" && (item_flags & IF_MFOCUSED))
			ui.drawpic(pos, item_text_mactive, item_size, item_rgb, item_alpha, 0);
		else
			ui.drawpic(pos, item_text, item_size, item_rgb, item_alpha, 0);
	};
	void() mitem_pic =
	{
		if (dp_workarounds)
		{
			if (substring(item_text, -4, 4) == ".lmp")
				item_text = substring(item_text, 0, -5);
			if (substring(item_text_mactive , -4, 5) == ".lmp")
				item_text_mactive = substring(item_text_mactive, 0, -4);
		}

		if (item_text)
			item_text = strzone(item_text);
		precache_pic(item_text);
		if (item_text_mactive)
		{
			item_text_mactive = strzone(item_text_mactive);
			precache_pic(item_text_mactive);
		}

		if (!item_size[0])
		{
			float y = item_size[1];
			item_size = drawgetimagesize(item_text);
			if (y)	//rescale x to ma
			{
				if (!item_size[1])	//bad image? don't glitch out too much.
					item_size = item_size[0] * '1 1 0';
				else
					item_size = [item_size[0] * (y / item_size[1]), y, 0];
			}
		}
	};
	virtual void() item_remove =
	{
		if (item_text)
			strunzone(item_text);
		if (item_text_mactive)
			strunzone(item_text_mactive);
		super::item_remove();
	};
};
#define spawn_pic(img,sz) spawn(mitem_pic, item_text:img, item_size:sz)


/***************************************************************************
interactive picture item.

item_command: the command to execute
item_text: the normal image to use
item_text_mactive: the image to use when the mouse is over it.
item_size: if not set, will be set to the size of the image named by item_text. if only y is set, x will be sized to match aspect with y.
*/
class mitem_pici : mitem
{
	string item_text_mactive;
	virtual void(vector pos) item_draw =
	{
		if (item_text_mactive != "" && (item_flags & IF_MFOCUSED))
			ui.drawpic(pos, item_text_mactive, item_size, item_rgb, item_alpha, 0);
		else
			ui.drawpic(pos, item_text, item_size, item_rgb, item_alpha, 0);
	};

	void() mitem_pici =
	{
		if (dp_workarounds)
		{
			if (substring(item_text, -4, 4) == ".lmp")
				item_text = substring(item_text, 0, -5);
			if (substring(item_text_mactive , -4, 5) == ".lmp")
				item_text_mactive = substring(item_text_mactive, 0, -4);
		}

		if (item_text)
			item_text = strzone(item_text);
		precache_pic(item_text);
		if (item_text_mactive)
		{
			item_text_mactive = strzone(item_text_mactive);
			precache_pic(item_text_mactive);
		}

		item_command = strzone(item_command);
		if (item_command != "")
		{
			item_command = strzone(item_command);
			item_flags |= IF_SELECTABLE;
		}

		if (!item_size[0])
		{
			float y = item_size[1];
			item_size = drawgetimagesize(item_text);
			if (y)	//rescale x to ma
			{
				if (!item_size[1])	//bad image? don't glitch out too much.
					item_size = item_size[0] * '1 1 0';
				else
					item_size = [item_size[0] * (y / item_size[1]), y, 0];
			}
		}
	};

	virtual float(vector pos, float scan, float char, float down) item_keypress =
	{
		if (this.item_command)
		{
			if (!down)
				return FALSE;
			if (scan == K_ENTER || (scan == K_MOUSE1 && mouseinbox(pos, this.item_size)))
			{
				item_parent.item_execcommand(this, this.item_command);
				return TRUE;
			}
		}
		return FALSE;
	};

	virtual void() item_remove =
	{
		if (item_text)
			strunzone(item_text);
		if (item_text_mactive)
			strunzone(item_text_mactive);
		if (item_command)
			strunzone(item_command);
		super::item_remove();
	};
};
#define menuitempici_spawn(img,command,sz) spawn(mitem_pici, item_text:img, item_command:command, item_size:sz)
// mitem(string img, string command, float sz) menuitempici_spawn =
// {
// 	return spawn(mitem_pici, item_text:img, item_command:command, item_size:sz);
// };

/***************************************************************************
text item.
interactable - executes a given console command.
*/
class mitem_text : mitem
{
	virtual void(vector pos) item_draw =
	{
		vector rgb = menuitem_textcolour(this);
		float w;
		if (item_flags & IF_CENTERALIGN)
		{
			w = stringwidth(item_text, (engine==E_QSS?FALSE:TRUE), '1 1 0'*item_scale);
			ui.drawstring(pos + [(item_size_x-w)/2, 0], item_text, '1 1 0' * item_scale, rgb, item_alpha, 0);
		}
		else if (item_flags & IF_RIGHTALIGN)
		{
			w = stringwidth(item_text, (engine==E_QSS?FALSE:TRUE), '1 1 0'*item_scale);
			ui.drawstring(pos + [(item_size_x-w), 0], item_text, '1 1 0' * item_scale, rgb, item_alpha, 0);
		}
		else
			ui.drawstring(pos, item_text, '1 1 0' * item_scale, rgb, item_alpha, 0);
	};
	virtual float(vector pos, float scan, float char, float down) item_keypress =
	{
		if (this.item_command)
		{
			if (!down)
				return FALSE;
			if (scan == K_ENTER || (scan == K_MOUSE1 && mouseinbox(pos, this.item_size)))
			{
				item_parent.item_execcommand(this, this.item_command);
				return TRUE;
			}
		}
		return FALSE;
	};

	void() mitem_text =
	{
		if (item_text) // keep last as it depends on condition above
			item_text = strzone(item_text);
		if (item_command != "") {
			item_command = strzone(item_command);
			item_flags |= IF_SELECTABLE;
		}
	};

	//zone+unzone input strings as needed
	virtual void() item_remove =
	{
		if (item_text)
			strunzone(item_text);
		if (item_command)
			strunzone(item_command);
		super::item_remove();
	};
};
mitem(string text, string command, float height) spawn_text =
{
	return spawn(mitem_text, 
		item_scale:height, 
		item_text:text, 
		item_command:command, 
		item_size:[stringwidth(text, (engine==E_QSS?FALSE:TRUE), '1 1 0'*height), height, 0]
	);
};
mitem(string text, float height=TXT_NMSZ) spawn_headline =
{
	return spawn(mitem_text, 
		item_scale:height, 
		item_text: text, 
		item_rgb: RGB_MUTED,
		item_size:[stringwidth(text, (engine==E_QSS?FALSE:TRUE), '1 1 0'*height), height, 0]
	);
};


/***************************************************************************
label item.
*/
class mitem_label : mitem
{	//class that queries its frame to find the text to show.
	mitem_vslider vslider;
	virtual void(vector pos) item_draw =
	{
		// vector rgb = this.item_rgb ? this.item_rgb : menuitem_textcolour(this);
		vector rgb = menuitem_textcolour(this);
		string text = get(item_text);
		float fl = 2;	//top-align
		vector textpos = pos;
		vector clientsize = item_size;
		if (item_flags & IF_CENTERALIGN)
			fl |= 0;	//default is to center align
		else if (item_flags & IF_RIGHTALIGN)
			fl |= 4;	//right align.
		else
			fl |= 1;	//left align.

		if (vslider)
		{
			textpos[1] -= vslider.val;
			clientsize[1] += vslider.val;
			clientsize[0] -= vslider.item_size[0];
		}

		local vector omin = ui.drawrectmin, omax = ui.drawrectmax;

		//clip the draw rect to our area, so text doesn't appear outside it. don't draw if its inverted.
		if (pos_x > ui.drawrectmin[0])
			ui.drawrectmin[0] = pos_x;
		if (pos_y > ui.drawrectmin[1])
			ui.drawrectmin[1] = pos_y;
		if (pos_x+clientsize_x < ui.drawrectmax[0])
			ui.drawrectmax[0] = pos_x+clientsize_x;
		if (pos_y+clientsize_y < ui.drawrectmax[1])
			ui.drawrectmax[1] = pos_y+clientsize[1];
		if (ui.drawrectmax[0] > ui.drawrectmin[0] && ui.drawrectmax[1] > ui.drawrectmin[1])
		{
			ui.setcliparea(ui.drawrectmin[0], ui.drawrectmin[1], ui.drawrectmax[0] - ui.drawrectmin[0], ui.drawrectmax[1] - ui.drawrectmin[1]);
			clientsize[1] = drawtextfield(textpos, clientsize, fl, text) * item_scale;
			ui.setcliparea(omin_x, omin_y, omax_x - omin_x, omax_y - omin_y);

			if (vslider)
			{
				vslider.item_size[1] = item_size[1];
				if (ui.mousepos != ui.oldmousepos)
				{
					if (mouseinbox(pos + [clientsize[0], 0], vslider.item_size))
						this.item_focuschange(vslider, IF_MFOCUSED);
				}
				vslider.item_draw(pos + [clientsize[0], 0]);
			}
		}
		ui.drawrectmin = omin;
		ui.drawrectmax = omax;

		if (clientsize[1] > item_size[1])
		{	//enough text that we need a scrollbar.
			if (!vslider)
				vslider = spawn(mitem_vslider, val:0, stride:8);
			vslider.maxv = clientsize[1] - item_size[1];
			item_flags |= IF_SELECTABLE;
		}
		else if (vslider)
		{	//the text got shorter...
			vslider.item_remove();
			vslider = (mitem_vslider)__NULL__;
			if (item_command == "")
				item_flags &~= IF_SELECTABLE;
		}
	};
	virtual float(vector pos, float scan, float char, float down) item_keypress =
	{
		if (vslider)
			if (vslider.item_keypress(pos, scan, char, down))
				return TRUE;
		if (this.item_command)
		{
			if (!down)
				return FALSE;
			if (scan == K_ENTER || (scan == K_MOUSE1 && mouseinbox(pos, this.item_size)))
			{
				item_parent.item_execcommand(this, this.item_command);
//				localcmd(strcat(this.item_command, "\n"));
				return TRUE;
			}
		}
		return FALSE;
	};

	void() mitem_label =
	{
		if (item_text)
			item_text = strzone(item_text);
		if (item_command != "")
		{
			item_command = strzone(item_command);
			item_flags |= IF_SELECTABLE;
		}
	};

	//zone+unzone input strings as needed
	virtual void() item_remove =
	{
		if (item_text)
			strunzone(item_text);
		if (item_command)
			strunzone(item_command);
		if (vslider)
		{
			vslider.item_remove();
			vslider = (mitem_vslider)__NULL__;
		}
		super::item_remove();
	};
};


/***************************************************************************
button item.
identical to text, but includes a 3dish border.
*/
class mitem_button : mitem
{
	virtual void(vector pos) item_draw =
	{
		ui.drawfill(pos, [this.item_size[0], 1], TD_TOP, this.item_alpha, 0);
		ui.drawfill(pos, [1, this.item_size[1] - 1], TD_LFT, this.item_alpha, 0);
		ui.drawfill(pos + [this.item_size[0]-1, 1], [1, this.item_size[1] - 1], TD_RGT, this.item_alpha, 0);
		ui.drawfill(pos + [0, this.item_size[1]-1], [this.item_size[0], 1], TD_BOT, this.item_alpha, 0);

		pos_x += (this.item_size[0] - stringwidth(this.item_text, (engine==E_QSS?FALSE:TRUE), '1 1 0'*this.item_scale)) * 0.5;
		pos_y += (this.item_size[1] - this.item_scale)*0.5;
		ui.drawstring(pos, this.item_text, '1 1 0' * this.item_scale, menuitem_textcolour(this), this.item_alpha, 0);
	};
	virtual float(vector pos, float scan, float char, float down) item_keypress =
	{
		if (!down)
			return FALSE;
		if (scan == K_ENTER || (scan == K_MOUSE1 && mouseinbox(pos, this.item_size)))
			item_parent.item_execcommand(this, item_command);
		else
			return FALSE;
		return TRUE;
	};
	void () mitem_button =
	{
		if (item_text)
			item_text = strzone(item_text);
		if (item_command)
			item_command = strzone(item_command);
		if (isvalid(item_command))
			item_flags |= IF_SELECTABLE;
	};
	virtual void() item_remove =
	{
		strunzone(item_text);
		if (item_command)
			strunzone(item_command);
		super::item_remove();
	};
};
mitem_button(string text, string command, vector sz) spawn_button =
{
	return spawn(mitem_button,
		item_scale: sz_y - 4,
		item_text: text,
		item_size: sz,
		item_command: command
	);
};

