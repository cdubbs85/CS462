ruleset twilio {
 meta {
    configure using account_sid = ""
                    auth_token = ""
    provides
        send_sms,
        messages
  }
 
  global {
    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
                "From":from,
                "To":to,
                "Body":message
            })
    }
    messages = function(to = "", from = "", max_messages = "") {
      sender = from => "From=" + from | "";
      reciever = to => "To=" + to | "";
      max = max_messages => "PageSize=" + max_messages | "";
      
      options = sender + "&" + reciever + "&" + max;
      
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>;
      url = base_url + "Messages.json?" + options;
      result = http:get(url);
      result
    }
  }
}
