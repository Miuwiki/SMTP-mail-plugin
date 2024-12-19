# Sourcemod L4D2 开发向插件
该仓库面向具有一定插件写作能力的玩家
* * *
### SMTP Mail(linux only)
> *English introduction please view [this](https://forums.alliedmods.net/showthread.php?p=2815083#post2815083)*
这是一个基于sm curl拓展实现发送邮件的插件, 旨在简化curl拓展提供的api. curl拓展作者以及后续fork 请到上方英文介绍页底部鸣谢寻找
#### 接口使用: 
```sourcepawn
Action Cmd_Status(int client, int args)
{
    if( client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) )
        return Plugin_Handled;

    SMTP mail = new SMTP(smtp_host, smtp_port);
    mail.SetVerify(smtp_encryption, smtp_verifyhost, smtp_verifypeer);
    mail.SetSender(account_username, account_password);
    mail.SetTitle("mail title");
    mail.AppendInfo("your mail info first line");
    mail.AppendInfo("your mail info second line");
    mail.AppendInfo("your mail info third line");

    mail.AddRecipient("xxx@xxx.com");
    mail.AddRecipient("zzz@zzz.com");

    mail.Send(MailSendResult);

    return Plugin_Handled;
}
void MailSendResult(int code, const char[] message)
{
    if( code != SEND_SUCCESS )
    {
        LogError(message);
        return;
    }

    LogMessage(message);
}  
```
#### 已确认问题: 
+ 仅支持 linux 服务器, 因为目前 curl 拓展只有linux版本的.
+ 请注意curl拓展是否生效, curl拓展不生效请在控制台输入 sm exts load curl 检查不生效原因, 并自行查找解决办法.
+ curl拓展在服务器处于休眠状态下无法正确运行, 不清楚是什么问题引起的. 未来的SMTP Tool将会强制锁定服务器不能处于休眠状态. 额外插件中 l4d2_updatecheck 已经使用该功能. 请确保服务器"sv_hibernate_when_empty"的值为0
#### 可选插件说明:
##### => l4d2_updatecheck(推荐)
该插件提供服务器更新提示, 当服务器过期时会发送邮件给管理员提示更新服务器. 
+ 使用本插件时请检查主插件是否正常运行!
+ 本插件不会自动生成.cfg配置文件, 请手动更改源码内的cvar或者写在server.cfg中.
+ 添加收件人邮箱务必在每个邮箱后添加","号, 最后一个也要添加.
* * *

### List Menu
> *English introduction please view [this](https://forums.alliedmods.net/showthread.php?p=2815083#post2815083)*
提供附带说明的菜单, 简化二级菜单操作流程
#### 接口使用: 
```sourcepawn
Action Cmd_ShowTest(int client, int args)
{
    ListMenu listmenu = ListMenu(ListMenuHandler_ShowData);
    char title[128], name[128], description[128];

    Format(title, sizeof(title), "this is my test title");
    listmenu.SetTitle(title);
    
    int count = GetCmdArgInt(1);
    count = count == 0 ? 3 : count;

    for(int i = 1; i <= count; i++)
    {
        FormatEx(name, sizeof(name), "name %d", i);
        FormatEx(description, sizeof(description), "description %d", i);

        listmenu.AddItem(name, description);
    }

    listmenu.Send(client, 20);
    return Plugin_Handled;
}

void ListMenuHandler_ShowData(int client, int index[2], ListData item)
{
    if( client < 1 || client > MaxClients || !IsClientInGame(client) )
        return;
    
    PrintToChatAll("item passdata handle %d", item.passdata);
    if( item.passdata != INVALID_HANDLE )
    {
        // StringMap can be use here.
        // e.x: item.passdata.GetValue();
    }
    else
    {
        PrintToChatAll("no data pass by item");
    }

    PrintToChat(client, "you select item index %d\n /
                        data index %d\n /
                        item_name: %s\n /
                        item_description: %s\n /
                        passdata: %d-%d", 
                        index[0], index[1], item.name, item.description,);
}
```
#### 已确认问题: 
+ 暂无
#### 可选插件说明:
+ 暂无
* * *