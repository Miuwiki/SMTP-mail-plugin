#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <miuwiki_smtptools>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =    
{
    name = "[L4D2] Update Mail",   
	author = "Miuwiki | help from \"fdxx\"",   
	description = "Sending mail to admin when server is out of date.",   
	version = PLUGIN_VERSION,   
	url = "https://miuwiki.site"  
}


#define GAMEDATA "l4d2_update_check"

Handle  g_SDKCall_ServerRestart;

ConVar
    hibernate_when_empty,

	cvar_smtphost,
	cvar_smtpport,
	cvar_smtpencryption,
	cvar_verifyhost,
	cvar_verifypeer,
	cvar_verbose,
	cvar_smtpusername,
	cvar_smtppassword,
	cvar_smtpreciver;

enum struct SMTPINFO
{
	char host[512];
	int  port;
	Encryption encryption;
	int verifyhost;
	int verifypeer;
	int verbose;

	char username[256];
	char password[256];

	ArrayList reciver;

    void StoreMailRecipent()
    {
        char buffer[512];
        cvar_smtpreciver.GetString(buffer, sizeof(buffer));

        char mail[256]; int split;
        do
        {
            if( IsNullString(buffer) )
                break;
            
            split = SplitString(buffer, ",", mail, sizeof(mail));

            if( split == -1 )
                break;
            
            this.reciver.PushString(mail);
            Format(buffer, sizeof(buffer), "%s", buffer[split]);

            LogMessage("store recipient %s", mail);
        }
        while( split != -1 );
    }
}

SMTPINFO g_smtp;

public void OnPluginStart()
{
    LoadGameData();
    hibernate_when_empty = FindConVar("sv_hibernate_when_empty");

    g_smtp.reciver      = new ArrayList(ByteCountToCells(512));
    cvar_smtphost       = CreateConVar("l4d2_update_smtp_host", "smtp.qq.com", "SMTP 服务器域名/ip", FCVAR_PROTECTED);
    cvar_smtpport       = CreateConVar("l4d2_update_smtp_port", "465", "SMTP 服务器端口", FCVAR_PROTECTED, true, 1.0, true, 65535.0);
    cvar_smtpencryption = CreateConVar("l4d2_update_smtp_encryption", "2", "SMTP 服务器加密协议. 0 = 不适用加密, 1 = 自动, 2 = SSL", _, true, 0.0, true, 2.0);
    cvar_verifyhost     = CreateConVar("l4d2_update_smtp_verifyhost", "2", "如果启用加密, 是否确认服务器的证书有效性. 0 = 不确认, 其余为拓展的确认方式, 不清楚请勿改动.", _, true, 0.0);
    cvar_verifypeer     = CreateConVar("l4d2_update_smtp_verifypeer", "0", "如果启用加密, 是否确认服务器返回的数据. 0 = 不确认, 其余为拓展的确认方式, 不清楚请勿改动.", _, true, 0.0);
    cvar_verbose        = CreateConVar("l4d2_update_smtp_verbose", "0", "是否开启curl 的 debug 调试", _, true, 0.0);
    cvar_smtpusername   = CreateConVar("l4d2_update_smtp_username", "", "SMTP 服务器的用户名", FCVAR_PROTECTED);
    cvar_smtppassword   = CreateConVar("l4d2_update_smtp_password", "", "SMTP 服务器的用户密码", FCVAR_PROTECTED);
    cvar_smtpreciver    = CreateConVar("l4d2_update_smtp_reciver", "", "需要发送给哪些邮箱, 每个邮箱都需要用\",\"结尾", FCVAR_PROTECTED);
    cvar_smtpreciver.AddChangeHook(Hook_CvarChange);
}

public void OnConfigsExecuted()
{
    char buffer[512];

    cvar_smtphost.GetString(buffer, sizeof(buffer));
    FormatEx(g_smtp.host, sizeof(g_smtp.host), "%s", buffer);

    g_smtp.port       	= cvar_smtpport.IntValue;
    g_smtp.encryption 	= view_as<Encryption>(cvar_smtpencryption.IntValue);
    g_smtp.verifyhost   = cvar_verifyhost.IntValue;
    g_smtp.verifypeer   = cvar_verifypeer.IntValue;
    g_smtp.verbose      = cvar_verbose.IntValue;

    cvar_smtpusername.GetString(buffer, sizeof(buffer));
    FormatEx(g_smtp.username, sizeof(g_smtp.username), "%s", buffer);

    cvar_smtppassword.GetString(buffer, sizeof(buffer));
    FormatEx(g_smtp.password, sizeof(g_smtp.password), "%s", buffer);

    g_smtp.reciver.Clear();
    cvar_smtpreciver.GetString(buffer, sizeof(buffer));

    g_smtp.StoreMailRecipent();

}

void Hook_CvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_smtp.reciver.Clear();
	g_smtp.StoreMailRecipent();
}

void GetServerInfomation(char[][] info, int length, int size)
{
	if( length < 6 )
		return;

	char buffer[512], temp[7][256], playerstate[2][128];

	ServerCommandEx(buffer, sizeof(buffer), "status");
	ExplodeString(buffer, ": ", temp, sizeof(temp), sizeof(temp[]));

	FormatEx(buffer, strlen(temp[1]) - 7, "%s", temp[1]); // strlen("version") = 7
	Format(buffer, sizeof(buffer), "服务器: %s", buffer);
	strcopy(info[0], size, buffer);

	FormatEx(buffer, strlen(temp[2]) - 7, "%s", temp[2]); // strlen("udp/ip ") = 7
	Format(buffer, sizeof(buffer), "版本: %s", buffer);
	strcopy(info[1], size, buffer);

	FormatEx(buffer, strlen(temp[3]) - 7, "%s", temp[3]); // strlen("os     ") = 7
	Format(buffer, sizeof(buffer), "ip信息: %s", buffer);
	strcopy(info[2], size, buffer);

	FormatEx(buffer, strlen(temp[4]) - 7, "%s", temp[4]); // strlen("map     ") = 7
	Format(buffer, sizeof(buffer), "服务器类型: %s", buffer);
	strcopy(info[3], size, buffer);

	FormatEx(buffer, strlen(temp[5]) - 7, "%s", temp[5]); // strlen("players ") = 7
	Format(buffer, sizeof(buffer), "当前地图: %s", buffer);
	strcopy(info[4], size, buffer);

	ExplodeString(temp[6], "#", playerstate, sizeof(playerstate), sizeof(playerstate[]));
	FormatEx(buffer, sizeof(buffer), "玩家信息: %s", playerstate[0]); 
	strcopy(info[5], size, buffer);
}

void SendEmail()
{
    char buffer[512],serverinfo[6][256];
    GetServerInfomation(serverinfo, sizeof(serverinfo), sizeof(serverinfo[]));

    if( g_smtp.reciver.Length <= 0 )
    {
        LogMessage("No mail reciver found in config, can't send mail of update.");
    }

    SMTP mail = new SMTP(g_smtp.host, g_smtp.port);
    mail.SetVerify(g_smtp.encryption, g_smtp.verifyhost, g_smtp.verifypeer);
    mail.SetSender(g_smtp.username, g_smtp.password);
    
    mail.SetTitle("您的L4D2服务器需要更新!");
    for(int i = 0; i < sizeof(serverinfo); i++)
    {
        mail.AppendInfo(serverinfo[i]);
    }

    for(int i = 0; i < g_smtp.reciver.Length; i++)
    {
        g_smtp.reciver.GetString(i, buffer, sizeof(buffer));
        mail.AddRecipient(buffer);
    }
    mail.Send(MailSendResult);
    LogMessage("Send mail compelete!");
}

void MailSendResult(int code, const char[] message)
{
	if( code != SEND_SUCCESS )
	{
		LogError("Got error when sending mail: %s", message);
		return;
	}

	LogMessage("%s", message);
}

MRESReturn DetourCallback_CheckMasterRequester(Address address, DHookReturn hReturn)
{
    static bool init;
    static bool hassendmail;
    static GameData hGameData;

    if( !init )
    {
        // FindConVar("sv_hibernate_when_empty").IntValue = 0;
        
        char path[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, path, sizeof(path), "gamedata/%s.txt", GAMEDATA);

        if( !FileExists(path) )
            SetFailState("\n==========\nMissing required file: \"%s\".\n==========", path);

        hGameData = new GameData(GAMEDATA);
        init = true;
    }
   
    if( hGameData == null )
        SetFailState("Failed to load \"l4d2_update_check.txt\" gamedata. (%s)", PLUGIN_VERSION);

    if( hassendmail )
        return MRES_Ignored;
    
    if( hibernate_when_empty.IntValue != 0 ) // mail need to run at not hibernate
        hibernate_when_empty.IntValue = 0;

    Address Steam3Server = hGameData.GetAddress("Steam3Server");
    if( Steam3Server == Address_Null )
        SetFailState("Failed to get address \"Steam3Server\" (%s)", PLUGIN_VERSION);

    bool update = SDKCall(g_SDKCall_ServerRestart, Steam3Server);
    if( update )
    {
        LogMessage("Server need update, sending mail!");
        SendEmail();
        hassendmail = true;
    }

    return MRES_Ignored;
}

void LoadGameData()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "gamedata/%s.txt", GAMEDATA);

    if( !FileExists(path) )
        SetFailState("\n==========\nMissing required file: \"%s\".\n==========", path);

    GameData hGameData = new GameData(GAMEDATA);
    if (hGameData == null)
        SetFailState("Failed to load \"l4d2_update_check.txt\" gamedata. (%s)", PLUGIN_VERSION);
    
    DynamicDetour Detour_CheckMasterRequester = DynamicDetour.FromConf(hGameData, "CheckMasterServerRequestRestart");
    if( Detour_CheckMasterRequester == null )
        SetFailState("Failed to create DynamicDetour: CheckMasterServerRequestRestart");

    if( !Detour_CheckMasterRequester.Enable(Hook_Pre, DetourCallback_CheckMasterRequester) )
        SetFailState("Failed to enable DynamicDetour: CheckMasterServerRequestRestart");

    StartPrepSDKCall(SDKCall_Raw);
    if( !PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CheckRestart") )
        SetFailState("Failed to create SDKCall: \"%s\" (%s)", "CheckRestart", PLUGIN_VERSION);
    PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
    if(!(g_SDKCall_ServerRestart = EndPrepSDKCall()))
        SetFailState("Failed to create SDKCall: \"%s\" (%s)", "CheckRestart", PLUGIN_VERSION);

    delete hGameData;
}