# SMTP Mail Plugin(linux only)
> *English introduction please view [this](https://forums.alliedmods.net/showthread.php?p=2815083#post2815083)*
* * * 
这是一个通过curl拓展实现sourcemod 发送邮件的插件, 旨在简化curl拓展提供的api. 

* * * 
## 代码实例: 

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

* * *
## 注意: 
+ 目前暂时只支持 linux 服务器, 因为目前 curl 拓展只有linux版本的. 
+ 不会自动生成.cfg配置文件, 请手动更改源码内的cvar 或者写在server.cfg中.
+ 请注意curl拓展是否生效, curl拓展兼容性非常不行, 不同linux的发行版本和不同的gcc都会导致curl拓展不一定生效
+ curl拓展不生效请在控制台输入 sm exts load curl 检查不生效原因, 并自行查找解决办法.