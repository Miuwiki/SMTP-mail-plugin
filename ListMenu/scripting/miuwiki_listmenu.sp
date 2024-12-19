#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[L4D2] List Menu",
	author = "Miuwiki",
	description = "Create a menu that contain description for each item",
	version = PLUGIN_VERSION,
	url = "http://www.miuwiki.site"
}

/**
 * =========================================================================
 * Code start
 * 
 * Logic of panel is 
 * 
 * (g_panel)panel["panelhandle"] => (stringmap)data
 * (stringmap)data["0"] => title
 *  		  data["1"] => (struct)ListData 1.name 2.description 3.stringmap
 * 		      data["2"] => (struct)ListData 1.name 2.description 3.stringmap
 *            ...
 * 
 * client will store the panel they first open, plugin will find data base on
 * client panel, even through it has a new panel handle by select to new page.
 * 
 * =========================================================================
 */

#define L4D2_MAXPLAYERS 64

#define PLUGIN_TRANSLATION_FILE "miuwiki_listmenu.phrase.txt"

ConVar
	cvar_panelmenu_each_count;

enum struct GlobalCvarData
{
	int panel_eachcount;
}

enum struct GlobalPluginData
{
	GlobalCvarData cvar;

	StringMap panel;
	ArrayList panelusing;

	int currentpanel[L4D2_MAXPLAYERS + 1];
	int currentpageindex[L4D2_MAXPLAYERS + 1];
}

GlobalPluginData
	plugin;

enum struct ListData
{
    char name[128];
    char description[128];
	StringMap passdata;
}

PrivateForward
	g_PrivateForward_OnArrayList;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead2 ) // only support left4dead2
		return APLRes_SilentFailure;

	RegPluginLibrary("miuwiki_listmenu");
	CreateNative("ListMenu.ListMenu", Miuwiki_ListMenu_Init);
	CreateNative("ListMenu.SetTitle", Miuwiki_ListMenu_SetTitle);
	CreateNative("ListMenu.AddItem", Miuwiki_ListMenu_AddItem);
	CreateNative("ListMenu.Send", Miuwiki_ListMenu_Send);
	return APLRes_Success;
}

int Miuwiki_ListMenu_Send(Handle nativeplugin, int numParams)
{
	Panel panel = GetNativeCell(1);
	static char key[64];
	IntToString(view_as<int>(panel), key, sizeof(key));
	if( !plugin.panel.ContainsKey(key) )
	{
		ThrowError("ListMenu can't find the menu handle of itself, SetTitlfe failed.");
		return 0;
	}
	int   client = GetNativeCell(2);
	int   time   = GetNativeCell(3);

	DrawPanelItemByList(panel, client, time);
	plugin.currentpanel[client] = view_as<int>(panel);
	return 0;
}

int Miuwiki_ListMenu_AddItem(Handle nativeplugin, int numParams)
{
	Panel panel = GetNativeCell(1);
	static char key[128];
	IntToString(view_as<int>(panel), key, sizeof(key));
	if( !plugin.panel.ContainsKey(key) )
	{
		ThrowError("ListMenu can't find the menu handle of itself, AddItem failed.");
		return 0;
	}
	ListData item; 
	GetNativeString(2, item.name, sizeof(item.name));
	GetNativeString(3, item.description, sizeof(item.description));
	item.passdata = view_as<StringMap>( GetNativeCell(4) );

	StringMap data;
	plugin.panel.GetValue(key, data);

	IntToString(data.Size, key, sizeof(key)); 
	data.SetArray(key, item, sizeof(item));   // use stringmap for data in item.
	return 0;
}

any Miuwiki_ListMenu_Init(Handle nativeplugin, int numParams)
{
	Panel     panel = new Panel();
	StringMap data  = new StringMap();
	static char key[64];
	IntToString(view_as<int>(panel), key, sizeof(key));
	plugin.panel.SetValue(key, data);
	data.SetString("0", "");    // set data["0"] to empty string.

	g_PrivateForward_OnArrayList.RemoveFunction(nativeplugin, GetNativeFunction(1));
	g_PrivateForward_OnArrayList.AddFunction(nativeplugin, GetNativeFunction(1));

	return panel;
}

int Miuwiki_ListMenu_SetTitle(Handle nativeplugin, int numParams)
{
	Panel panel = GetNativeCell(1);
	char title[512];

	GetNativeString(2, title, sizeof(title));
	static char key[64];
	IntToString(view_as<int>(panel), key, sizeof(key));
	if( !plugin.panel.ContainsKey(key) )
	{
		ThrowError("ListMenu can't find the menu handle of itself, SetTitlfe failed.");
		return 0;
	}
	StringMap data;
	plugin.panel.GetValue(key, data);
	data.SetString("0", title, true);
	return 0;
}

public void OnPluginStart()
{
	LoadTranslations(PLUGIN_TRANSLATION_FILE);
	plugin.panel      = new StringMap();
	plugin.panelusing = new ArrayList();
	g_PrivateForward_OnArrayList = new PrivateForward(ET_Ignore, Param_Cell, Param_Array, Param_Array);

	cvar_panelmenu_each_count = CreateConVar("l4d2_panelmenu_each_count", "5", "each page can show item", 0, true, 1.0, true, 7.0);
}

public void OnConfigsExecuted()
{
    plugin.cvar.panel_eachcount = cvar_panelmenu_each_count.IntValue;
}

public void OnMapStart()
{
	char key[128], indexkey[128];
	StringMap data; ListData list;
	StringMapSnapshot snapshot = plugin.panel.Snapshot();
	for(int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, key, sizeof(key));
		plugin.panel.GetValue(key, data);

		int index = 1;   // 0 is title.
		while( index < data.Size )
		{
			IntToString(index, indexkey, sizeof(indexkey));
			data.GetArray(indexkey, list, sizeof(list));

			delete list.passdata;
			index++;
		}
		delete data;
	}
	delete snapshot;

	plugin.panel.Clear();

	CreateTimer(1.0, Timer_ClearUselessPanelHandle, _, (TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE));
}

Action Timer_ClearUselessPanelHandle(Handle timer)
{
	for(int i = 0; i < sizeof(plugin.currentpanel); i++)
	{
		if( plugin.currentpanel[i] == 0 )
			continue;
			
		if( plugin.panelusing.FindValue(plugin.currentpanel[i]) != -1 )
			continue;

		plugin.panelusing.Push(plugin.currentpanel[i]);
	}

	static char key[128], indexkey[128];
	StringMap data; ListData list;
	StringMapSnapshot snapshot = plugin.panel.Snapshot();
	for(int i = 0; i < snapshot.Length; i++)
	{
		snapshot.GetKey(i, key, sizeof(key));
		plugin.panel.GetValue(key, data);

		// no player using this panel, free panel data.
		if( plugin.panelusing.Length == 0 || plugin.panelusing.FindValue( StringToInt(key) ) == -1 )
		{
			int index = 1;   // 0 is title.
			while( index < data.Size )
			{
				IntToString(index, indexkey, sizeof(indexkey));
				data.GetArray(indexkey, list, sizeof(list));

				delete list.passdata;
				index++;
			}
			
			delete data;
			plugin.panel.Remove(key);
		}
	}

	delete snapshot;
	plugin.panelusing.Clear();
	return Plugin_Continue;
}
public void OnClientDisconnect(int client)
{
	plugin.currentpanel[client]     = 0;
	plugin.currentpageindex[client] = 0;
}

void DrawPanelItemByList(Panel panel, int client, int time)
{
	static char title[128], key[128];
	IntToString(view_as<int>(panel), key, sizeof(key));
	StringMap data;
	plugin.panel.GetValue(key, data);
	data.GetString("0", title, sizeof(title));
	panel.SetTitle(title);

	// for(int i = 0; i < reciver.Length; i++)
	// {
	// 	IntToString(GetClientUserId(reciver.Get(i)), key, sizeof(key));
	// 	plugin.PanelData.SetValue(key, list);
	// 	plugin.PanelTitle.SetString(key, title);
	// }

	int count     = 0;
	int itemcount = data.Size - 1;
	int maxpage   = itemcount / plugin.cvar.panel_eachcount;
	maxpage       = itemcount % plugin.cvar.panel_eachcount == 0 ? maxpage : maxpage + 1; 
	ListData item;
	for(int i = 1; i <= plugin.cvar.panel_eachcount; i++) // item start from 1.
	{
		if( i > itemcount ) // if equal, then we are in the last item.
			break;

		IntToString(i, key, sizeof(key));
		data.GetArray(key, item, sizeof(item));

		panel.DrawItem(item.name, ITEMDRAW_DEFAULT);
		FormatEx(key, sizeof(key), "   -%s", item.description);
		panel.DrawItem(key, ITEMDRAW_RAWLINE);
		count++;
	}

	static char translate[64];

	int remain = 7 - count;
	for(int i = 0; i < remain ; i++)
	{
		panel.DrawItem("",ITEMDRAW_SPACER);
	}

	if( maxpage == 1 )
	{
		panel.DrawItem("", ITEMDRAW_SPACER);
		panel.DrawItem("", ITEMDRAW_SPACER);
	}
	else
	{
		panel.DrawItem("", ITEMDRAW_SPACER);
		FormatEx(translate, sizeof(translate), "%T", "GONEXT", LANG_SERVER);
		panel.DrawItem(translate, ITEMDRAW_DEFAULT);
	}
	
	// page index start from 0 so maxpage need -1.
	plugin.currentpageindex[client] = 0;
	FormatEx(translate, sizeof(translate), "%T", "CANCEL", LANG_SERVER);
	panel.DrawItem(translate, ITEMDRAW_DEFAULT);
	panel.Send(client, Panel_Callback, time);
}

int Panel_Callback(Menu menu, MenuAction action, int client, int item_index)
{
	if( client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) )
	{
		// don't worry the remain arraylist handle, we delete it at map start.
		LogMessage("Failed to show item for %N, client is invalid or fake client.", client);
		return 0;
	}

	char key[128];
	// IntToString(GetClientUserId(client), key, sizeof(key));
	IntToString(plugin.currentpanel[client], key, sizeof(key));
	if( !plugin.panel.ContainsKey(key) )
	{
		LogMessage("Panel menu failed to find data through menu handle.");
		return 0;
	}

	switch(action)
	{
		case MenuAction_Select:
		{
			StringMap data;
			plugin.panel.GetValue(key, data);
			int itemcount = data.Size - 1;
			int maxpage   = itemcount / plugin.cvar.panel_eachcount;
			maxpage       = itemcount % plugin.cvar.panel_eachcount == 0 ? maxpage : maxpage + 1; 
			if( 0 < item_index < 7 )
			{
				// plugin.currentpageindex always start from 0
				int list_index = plugin.currentpageindex[client] * plugin.cvar.panel_eachcount + item_index;

				ListData item;
				IntToString(list_index, key, sizeof(key));
				data.GetArray(key, item, sizeof(item));

				int index[2];
				index[0] = item_index;
				index[1] = list_index;
				Call_StartForward(g_PrivateForward_OnArrayList);
				Call_PushCell(client);
				Call_PushArray(index, sizeof(index));
				Call_PushArray(item, sizeof(item));
				Call_Finish();

				plugin.currentpageindex[client] = 0;
				plugin.currentpanel[client] = 0;
			}
			else if( item_index == 8 && plugin.currentpageindex[client] > 0 ) // go back 
			{
				plugin.currentpageindex[client] -= 1;
				SetPanelByPage(client); // push which page client to go  
			}
			else if( item_index == 9 && plugin.currentpageindex[client] < (maxpage - 1) ) // go next
			{
				plugin.currentpageindex[client] += 1;
				SetPanelByPage(client); // push which page client to go  
			}
			else if( item_index == 10 )
			{
				// nothing to do.
				plugin.currentpageindex[client] = 0;
				plugin.currentpanel[client] = 0;
			}
		}
		case MenuAction_End:
		{
			plugin.currentpageindex[client] = 0;
			plugin.currentpanel[client] = 0;
		}
	}
	return 0;
}

void SetPanelByPage(int client) // reset which page client at last 
{
	if( client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) )
		return;

	char key[128], title[128];
	IntToString(plugin.currentpanel[client], key, sizeof(key));
	if( !plugin.panel.ContainsKey(key) )
	{
		LogMessage("Panel menu failed to find data through client userid in next page.");
		return;
	}

	StringMap data;
	plugin.panel.GetValue(key, data);

	Panel panel = new Panel();
	data.GetString("0", title, sizeof(title));
	panel.SetTitle(title);

	// ArrayList list;
	// plugin.PanelData.GetValue(key, list);
	// plugin.PanelTitle.GetString(key, title, sizeof(title));
	int count     = 0;
	int itemcount = data.Size - 1;
	int start     = plugin.currentpageindex[client]       * plugin.cvar.panel_eachcount + 1;
	int end       = (plugin.currentpageindex[client] + 1) * plugin.cvar.panel_eachcount;
	int maxpage   = itemcount / plugin.cvar.panel_eachcount;
	maxpage       = itemcount % plugin.cvar.panel_eachcount == 0 ? maxpage : maxpage + 1; 

	ListData item;
	for(int i = start; i <= end; i++)
	{
		if( i > itemcount )
			break;

		IntToString(i, key, sizeof(key));
		data.GetArray(key, item, sizeof(item));

		panel.DrawItem(item.name, ITEMDRAW_DEFAULT);
		FormatEx(key, sizeof(key), "   -%s", item.description);
		panel.DrawItem(key, ITEMDRAW_RAWLINE);
		count++;
	}

	int remain = 7 - count;
	for(int i = 0; i < remain ; i++)
	{
		panel.DrawItem("",ITEMDRAW_SPACER);
	}

	static char translate[64];
	FormatEx(translate, sizeof(translate), "%T", "GOBACK", LANG_SERVER);
	plugin.currentpageindex[client] == 0             ? panel.DrawItem("", ITEMDRAW_SPACER) : panel.DrawItem(translate, ITEMDRAW_DEFAULT);
	FormatEx(translate, sizeof(translate), "%T", "GONEXT", LANG_SERVER);
	plugin.currentpageindex[client] == (maxpage - 1) ? panel.DrawItem("", ITEMDRAW_SPACER) : panel.DrawItem(translate, ITEMDRAW_DEFAULT);
	FormatEx(translate, sizeof(translate), "%T", "CANCEL", LANG_SERVER);
	panel.DrawItem(translate, ITEMDRAW_DEFAULT);
	panel.Send(client, Panel_Callback, MENU_TIME_FOREVER);
}