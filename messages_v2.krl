ruleset messaging {
  meta {
    shares __testing
    use module key_module
    use module twilio alias twilio
      with account_sid = keys:twilio{"account_sid"}
            auth_token = keys:twilio{"auth_token"}
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
  }
  
  rule test_send_sms {
    select when test new_message
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }
  
  rule get_messages {
    select when test get_messages
     pre {
      sender = event:attr("to") => "To=" + event:attr("to") | ""
      reciever = event:attr("from") => "From=" + event:attr("from") | ""
      max = event:attr("max_messages") => "PageSize=" + event:attr("max_messages") | ""
      // page = event:attr("max_messages") && event:attr("page") && event:attr("token") => "Page=" + event:attr("page") | ""
      // next_page_token = event:attr("max_messages") && event:attr("token") && event:attr("page") => "PageToken=" + event:attr("token") | ""
      // info = sender + "&" + reciever + "&" + max + "&" + page + "&" + next_page_token
      
      info = sender + "&" + reciever + "&" + max
      
      result = twilio:messages(info){"content"}
      messages = result.decode().get(["messages"])
      
      // temp = result.decode().get(["next_page_uri"]).split(re#&#)
      // return_data = {"messages" : messages, "next_page" : result.decode().get(["next_page_uri"])}
    }
    
    send_directive(messages.encode())
    
    always {
      // log debug "result:"+result;
      // log debug "content:"+content;
      // log debug "messages:"+messages
      log debug "stuff"+temp
    }
  }
}
