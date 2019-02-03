ruleset wovyn_base {
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
    
    temperature_threshold = 75
    notification_from_phone_number = 12108800482
    notification_to_phone_number = 12109134920
    
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat
    
    pre {
      
      // fullObject = event:attrs.klog("fullObject")
      // genericThing = event:attrs.klog("genericThing")
      temperatureData = event:attrs{["genericThing", "data", "temperature"]}[0]{"temperatureF"}.klog("tempData")
    
      
    }
    
    if temperatureData then send_directive(temperatureData.encode());
    
    fired {
      
      raise wovyn event "new_temperature_reading" 
        attributes { "temperature": temperatureData, "timestamp": time:now()}
        
    }
    
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    
    pre {
      
      directive_message = (event:attrs{"temperature"} > temperature_threshold => "There was a temperature violation." | "There was not a temperature violation.").klog("result")
   
    }
    
    if event:attrs{"temperature"} > temperature_threshold 
      then send_directive(directive_message)
    
    fired {

      raise wovyn event "threshold_violation" 
        attributes event:attrs
        
    } else {
      
      thingTwo = event:attrs.klog("No temperature violation.")
      
    }
    
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    
    pre {
      
      // holder = event:attrs.klog("temperature violation");
      message = "Your wovyn sensor exceeded the temperature threshold of " 
        + temperature_threshold + " degrees fahrenheit with a temperature of " 
        + event:attrs{"temperature"} + " degrees fahrenheit."
    
    }
    
    twilio:send_sms(notification_to_phone_number, notification_from_phone_number, message)
  
  }
  
}
