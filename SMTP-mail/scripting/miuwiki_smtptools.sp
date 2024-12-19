#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <curl>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
	name = "[L4D2] SMTP Qucik tools",
	author = "Miuwiki",
	description = "Create some native to use SMTP mail provided by curl.ext.so .",
	version = PLUGIN_VERSION,
	url = "http://www.miuwiki.site"
}

enum Encryption
{
    Encryption_None,
    Encryption_STARTTLS,
    Encryption_SSL
}

enum struct SMTP
{
    // SMTP store
    Handle curl;
    Handle curl_list;
    char host[512];
    char sender[512];
    int  port;
    
    // mail info
    ArrayList infomation;
    int lineposition;
}

PrivateForward g_PriateForward_OnSend;

ArrayList g_list_SMTPList;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if( GetExtensionFileStatus("curl.ext") != 1 )
    {
        LogError("Failed to load extension curl.ext.so, name: \"cURL Extension\". Type \"sm exts load curl\" in console to check the problem.");
        return APLRes_Failure;
    }

    RegPluginLibrary("miuwiki_smtptools");
    /**
     * These for methodmap server
    */
    CreateNative("SMTP.SMTP", Native_Miuwiki_SMTP);
    CreateNative("SMTP.SetVerify", Native_Miuwiki_SMTPSetVerify);
    CreateNative("SMTP.SetSender", Native_Miuwiki_SMTPSetSender);
    CreateNative("SMTP.SetTitle", Native_Miuwiki_SMTPSetTitle);
    CreateNative("SMTP.AppendInfo", Native_Miuwiki_SMTPAppendInfo);
    CreateNative("SMTP.AddRecipient", Native_Miuwiki_SMTPAddRecipient);
    CreateNative("SMTP.Send", Native_Miuwiki_SMTPSend);

    return APLRes_Success;
}

// public void OnAllPluginsLoaded()
// {
//     if( !LibraryExists("curl.ext") )
//         SetFailState("Failed to load extension curl.ext.so, name: \"cURL Extension\". Type \"sm exts load curl\" in console to check the problem.");
// }

public void OnPluginStart()
{
    g_list_SMTPList = new ArrayList( sizeof(SMTP) );

    g_PriateForward_OnSend = new PrivateForward(ET_Ignore, Param_Cell, Param_String);
}

any Native_Miuwiki_SMTP(Handle plugin, int arg_num)
{
    SMTP smtp;
    
    GetNativeString(1, smtp.host, sizeof(smtp.host));
    smtp.port = GetNativeCell(2);
    int timeout = GetNativeCell(3);
    int connect_timeout = GetNativeCell(4);
    int verbosity = GetNativeCell(5);

    static int curl_defaultoption[4][2] = {
		{view_as<int>(CURLOPT_NOSIGNAL),       1 },
		{view_as<int>(CURLOPT_NOPROGRESS),     1 },
        {view_as<int>(CURLOPT_TIMEOUT),        30},
        {view_as<int>(CURLOPT_CONNECTTIMEOUT), 60}
	};
    
    curl_defaultoption[2][1] = timeout;
    curl_defaultoption[3][1] = connect_timeout;

    Handle curl = curl_easy_init();
    if( curl == INVALID_HANDLE )
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Failed to create a curl handle.");
        return INVALID_HANDLE;
    }

    Handle curl_list = curl_slist();
    if( curl_list == null )
    {
        delete curl;
        ThrowNativeError(SP_ERROR_NATIVE, "Failed to create a curl_list handle.");
        return INVALID_HANDLE;
    }

    curl_easy_setopt_int_array(curl, curl_defaultoption, sizeof(curl_defaultoption));
    curl_easy_setopt_int(curl, CURLOPT_VERBOSE, verbosity);
    smtp.curl = curl;
    smtp.curl_list = curl_list;

    g_list_SMTPList.PushArray(smtp);
    return curl;
}

any Native_Miuwiki_SMTPSetVerify(Handle plugin, int arg_num)
{
    char error[256];
    Handle curl = GetNativeCell(1);

    int index = GetIndexOfSMTP(curl, error, sizeof(error));
    if( index == -1 )
    {
        ThrowNativeError(SP_ERROR_NATIVE, error);
        return false;
    }

    Encryption encryption = GetNativeCell(2);
    int verifyhost = GetNativeCell(3);
    int verifypeer = GetNativeCell(4);

    SMTP smtp;
    g_list_SMTPList.GetArray(index, smtp);

    char url[512];
    switch( encryption )
    {
        case Encryption_None:
        {
            FormatEx(url, sizeof(url), "smtp://");
        }
        case Encryption_STARTTLS:
        {
            FormatEx(url, sizeof(url), "smtp://");
            curl_easy_setopt_int(curl, CURLOPT_USE_SSL, CURLUSESSL_ALL);
            curl_easy_setopt_int(curl, CURLOPT_SSL_VERIFYHOST, verifyhost);
            curl_easy_setopt_int(curl, CURLOPT_SSL_VERIFYPEER, verifypeer);
        }
        case Encryption_SSL:
        {
            FormatEx(url, sizeof(url), "smtps://");
            curl_easy_setopt_int(curl, CURLOPT_SSL_VERIFYHOST, verifyhost);
            curl_easy_setopt_int(curl, CURLOPT_SSL_VERIFYPEER, verifypeer);
        }
    }

    Format(url, sizeof(url), "%s%s", url, smtp.host);
    curl_easy_setopt_string(curl, CURLOPT_URL, url);
    curl_easy_setopt_int(curl, CURLOPT_PORT, smtp.port);
    return true;
}

any Native_Miuwiki_SMTPSetSender(Handle plugin, int arg_num)
{
    char error[256];
    Handle curl = GetNativeCell(1);

    int index = GetIndexOfSMTP(curl, error, sizeof(error));
    if( index == -1 )
    {
        ThrowNativeError(SP_ERROR_NATIVE, error);
        return false;
    }

    SMTP smtp;
    g_list_SMTPList.GetArray(index, smtp);

    char from[128], username[128], password[128];
    GetNativeString(2, username, sizeof(username));
    GetNativeString(3, password, sizeof(password));

    FormatEx(from, sizeof(from), "<%s>", username);
    curl_easy_setopt_string(curl, CURLOPT_MAIL_FROM, from);
    curl_easy_setopt_string(curl, CURLOPT_USERNAME, username);
    curl_easy_setopt_string(curl, CURLOPT_PASSWORD, password);
    
    // we need replace it because we change the sender.
    FormatEx(smtp.sender, sizeof(smtp.sender), "%s", username);
    g_list_SMTPList.SetArray(index, smtp);
    return true;
}

any Native_Miuwiki_SMTPSetTitle(Handle plugin, int arg_num)
{
    char error[256];
    Handle curl = GetNativeCell(1);
    
    int index = GetIndexOfSMTP(curl, error, sizeof(error));
    if( index == -1 )
    {
        ThrowNativeError(SP_ERROR_NATIVE, error);
        return false;
    }

    SMTP smtp;
    g_list_SMTPList.GetArray(index, smtp);
    smtp.infomation = new ArrayList(ByteCountToCells(512));

    char buffer[512];

    smtp.infomation.PushString("MIME-Version: 1.0\n");
    smtp.infomation.PushString("Content-type: text/html; charset=utf-8\n");

    FormatEx(buffer, sizeof(buffer), "From: <%s>\n", smtp.sender);
    smtp.infomation.PushString(buffer);

    GetNativeString(2, buffer, sizeof(buffer));
    Format(buffer, sizeof(buffer), "Subject: %s\n\n", buffer);
    smtp.infomation.PushString(buffer);

    // we need replace it because we create a arraylist in local.
    g_list_SMTPList.SetArray(index, smtp);
    return true;
}

any Native_Miuwiki_SMTPAppendInfo(Handle plugin, int arg_num)
{
    char error[256];
    Handle curl = GetNativeCell(1);
    
    int index = GetIndexOfSMTP(curl, error, sizeof(error));
    if( index == -1 )
    {
        ThrowNativeError(SP_ERROR_NATIVE, error);
        return false;
    }

    char info[512];
    GetNativeString(2, info, sizeof(info));
    Format(info, sizeof(info), "%s<br/>", info);

    SMTP smtp;
    g_list_SMTPList.GetArray(index, smtp);

    smtp.infomation.PushString(info);

    // we need replace it because we change the enum struct info in arraylist.
    g_list_SMTPList.SetArray(index, smtp);
    return true;
}

any Native_Miuwiki_SMTPAddRecipient(Handle plugin, int arg_num)
{
    char error[256];
    Handle curl = GetNativeCell(1);
    
    int index = GetIndexOfSMTP(curl, error, sizeof(error));
    if( index == -1 )
    {
        ThrowNativeError(SP_ERROR_NATIVE, error);
        return false;
    }

    char reciver[64];
    GetNativeString(2, reciver, sizeof(reciver));
    SMTP smtp;
    g_list_SMTPList.GetArray(index, smtp);

    curl_slist_append(smtp.curl_list, reciver);
    return true;
}


any Native_Miuwiki_SMTPSend(Handle plugin, int arg_num)
{
    char error[256];
    Handle curl = GetNativeCell(1);
    
    int index = GetIndexOfSMTP(curl, error, sizeof(error));
    if( index == -1 )
    {
        ThrowNativeError(SP_ERROR_NATIVE, error);
        return false;
    }

    SMTP smtp;
    g_list_SMTPList.GetArray(index, smtp);

    Handle curl_list = smtp.curl_list;
    if( curl_list == INVALID_HANDLE )
    {
        // we find a index but it's curl_list handle is invalid because some unkown error
        // delete curl and erase the index in th arraylist.
        delete curl;
        g_list_SMTPList.Erase(index);

        ThrowNativeError(SP_ERROR_NATIVE, "Invaild curl_list handle, something wrong.");
        return false;
    }

   
    // bind curl and curl_list
    curl_easy_setopt_handle(curl, CURLOPT_MAIL_RCPT, curl_list);
    curl_easy_setopt_function(curl, CURLOPT_READFUNCTION, CURL_ReadPayload);
    
    // send
    curl_easy_perform_thread(curl, CURL_OnComplete);
    g_PriateForward_OnSend.RemoveFunction(plugin, GetNativeFunction(2));
    g_PriateForward_OnSend.AddFunction(plugin, GetNativeFunction(2));
    return true;
}

void CURL_OnComplete(Handle curl, CURLcode code)
{
    char error[256];
    Call_StartForward(g_PriateForward_OnSend);
    Call_PushCell(code);

    int index = GetIndexOfSMTP(curl, error, sizeof(error));

    if( index == -1 )
    {
        Format(error, sizeof(error), "<Mail>: %s.", error);
        Call_PushString(error);
        Call_Finish();
        // LogError("Error sending mail: %s", error);
        return;
    }

    SMTP smtp;
    g_list_SMTPList.GetArray(index, smtp);

    if( code == CURLE_OK )
    {
        FormatEx(error, sizeof(error), "<Mail>: Succeed send mail from %s.", smtp.sender);
        Call_PushString(error);
    }
    else
    {
        curl_easy_strerror(code, error, sizeof(error));
        Format(error, sizeof(error), "<Mail>: %s.", error);
        Call_PushString(error);
        // LogError("Error sending mail: %s, code: %d", error, code);
    }

    Call_Finish();
    // 
    delete curl;
    delete smtp.curl_list;
    delete smtp.infomation;

    g_list_SMTPList.Erase(index);
}

int CURL_ReadPayload(Handle curl, int bytes, int nmemb)
{
    if( (bytes * nmemb) < 1 )
        return 0;
	
    char error[256];
    int index = GetIndexOfSMTP(curl, error, sizeof(error));
    if( index == -1 )
    {
        LogError(error);
        return 0;
    }

    SMTP smtp;
    g_list_SMTPList.GetArray(index, smtp);

    // Feed it line by line
    if( smtp.lineposition >= smtp.infomation.Length )
        return 0;

    char line[512];
    smtp.infomation.GetString(smtp.lineposition, line, sizeof(line));

    // we change the lineposition so we need to replace it.
    smtp.lineposition++;
    g_list_SMTPList.SetArray(index, smtp);

    // LogMessage("sending message: %s", line);
    curl_set_send_buffer(curl, line, sizeof(line));
    return strlen(line);
}

int GetIndexOfSMTP(Handle curl, char[] error, int error_length)
{
    if( curl == INVALID_HANDLE )
    {
        FormatEx(error, error_length, "The curl handle is invalid, something wrong.");
        return -1;
    }
    
    int index = g_list_SMTPList.FindValue(curl, 0); // 
    if( index == -1 )
    {
        delete curl;
        FormatEx(error, error_length, "The enum struct which contain the curl can't find, \
                                        delete the curl handle to prevent memory leak.\n     \
                                        But it still have the leak of curl_slist handle     \
                                        since curl_list handle is store base on the arraylist index, \
                                        but now it failed to find the index, emmmmmmmm.\
                                        I hope this wrong never happen to the user. ");
        return -1;
    }

    return index;
}