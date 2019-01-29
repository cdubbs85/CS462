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
      // result = twilio:messages(){"content"}
      result = twilio:messages(to = event:attr("to"), 
                              from = event:attr("from"), 
                              max_messages = event:attr("max_messages")){"content"}
      
      messages = result.decode().get(["messages"])
      }
    
    send_directive(messages.encode())
  }
}
