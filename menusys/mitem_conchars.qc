/***************************************************************************
Draws a conchars table with row/col in hex, 
the hex values can be used with other functions to render the conchar.
For reference purposes mainly.
*/

// enable this function, converts string to int/float
// useful for string-hex to float-hex conversion
int(string) stoh = #0;

// Draw conchars table
class mitem_conchars : mitem
{
	string item_text_mactive;
	virtual void(vector pos) item_draw =
	{
		float doonce = 1;
		if (doonce)
		{
			float ir;
			for(ir=0; ir<16; ir++) 
			{
				string irhex = sprintf("%x", ir);

				float ic;	
				for(ic=0; ic<16; ic++) 
				{
					string ichex = sprintf("%x", ic);

					string svalue = strcat("0x",irhex,ichex);
					float value = stoh(svalue);
					ui.drawcharacter(
						[pos.x+(ic*19), pos.y+(ir*16)], 
						value, 
						'8 8', // size
						'1 1 1', // color 
						1, // alpha
						0 // flag (unused)
					);
					// alternative way to represent and render hex values
					// ui.drawstring(pos, sprintf("^{e080}^", or ^a...^a, or ^xABC, or ^h...^h, or ^&AB
					// https://quakewiki.org/wiki/FTE_EXTENDEDTEXTCODES

					// coord label for each conchar
					ui.drawstring(
						[pos.x+(ic*19), pos.y+(ir*16)+10], 
						svalue, 
						'4 4', // size
						'1 1 1', // color 
						1, // alpha
						0 // flag (unused)
					);
				}
			}
			// done, no need to keep calculating this
			doonce = 0; 
		}
	};

	void() mitem_conchars =
	{
	};
};