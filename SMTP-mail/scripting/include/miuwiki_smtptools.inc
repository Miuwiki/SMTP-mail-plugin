/** Double-include prevention */
#if defined _miuwiki_smtp_included_
  #endinput
#endif
#define _miuwiki_smtp_included_

#define SEND_SUCCESS 0

enum Encryption
{
    Encryption_None,
    Encryption_STARTTLS,
    Encryption_SSL
}

/**
     * Init a curl to use smtp tools.
     *
     * @param  send_code	  the curl code of the send result. check it's means in curl_header.
     * @param  message		  message of this send, it is error on fail and a message on success.
     * 
     */
typeset MailSendCallback 
{
    function void (int send_code, const char[] message);
};

methodmap SMTP < Handle
{
    /**
     * Init a curl to use smtp tools.
     *
     * @param  host	            SMTP host
     * @param  port		          SMTP port
     * @param  timeout          Time to start a curl
     * @param  connect_timeout  Time to check a send mail is complete or not
     * @param  verbosity        Start curl debug or not.
     * 
     * @return                  A handle of the curl to use SMTP. or invalid_handle on fail.
     */
    public native SMTP(const char[] host, int port, int timeout = 30, int connect_timeout = 60, int verbosity = 0);

    /**
     * Set the smtp protocol and verify mode in the curl.
     *
     * @param  type	        The SMTP server encryption type, usually use SSL
     * @param  verifyhost		The SMTP server need verify host? Most of time it is 2.
     * @param  verifypeer	  The SMTP server need verify peer? if set to 1, need ca-bundle.crt.
     * 
     * @return 				    True on success. false if something cause wrong.
     */
    public native bool SetVerify(Encryption type, int verifyhost = 2, int verifypeer = 0);

    /**
     * Set the username and password of the sender.
     *
     * @param  username		SMTP username to login.
     * @param  password	  SMTP password.
     * 
     * @return 				    True on success. false if something cause wrong.
     */
    public native bool SetSender(const char[] username, const char[] password);

    /**
     * Set the mail titile, can hold 512 byte.
     *
     * @param  title	 The title of the mail.
     * 
     * @return 				 True on success. false if something cause wrong.
     */
    public native bool SetTitle(const char[] title);

    /**
     * Set the infomation of the mail, can hold 512 byte.
     *
     * @param  buffer	 The infomation to send, always start on a new line.
     * 
     * @note           You must call SetTitle() before append your info in the mail!
     * 
     * @return 				 True on success. false if something cause wrong.
     */
    public native bool AppendInfo(const char[] buffer);

    /**
     * Set recipients for emails, one email can have multiple recipients.
     *
     * @param  email	 The email addres that recive the mail.
     * 
     * @note Please confirm the recipient before adding, and be careful not to fill in an empty string, 
     *       otherwise the email will not be sent
     * 
     * @return 				 True on success. false if something cause wrong.
     */
    public native bool AddRecipient(const char[] email);

    /**
     * Send the mail through the curl handle.
     * 
     * @param callback The callback function of the send result.
     * 
     * @note The handle will auot delete when send complete even if it get wrong.
     *       Don't delete it after this function.
     * 
     * @return True if success, false otherwise.
    */
    public native bool Send(MailSendCallback callback);
}