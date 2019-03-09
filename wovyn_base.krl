ruleset wovyn_base {
  meta {
    shares __testing
    use module key_module
    use module twilio alias twilio
      with account_sid = keys:twilio{"account_sid"}
            auth_token = keys:twilio{"auth_token"}
    
    use module sensor_profile
  }
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }

  
  rule process_heartbeat {
    select when wovyn heartbeat
    
    pre {

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
      
      directive_message = (event:attrs{"temperature"} > sensor_profile:threshold() => "There was a temperature violation." | "There was not a temperature violation.").klog("result")
      
    }
    
    send_directive(directive_message)
    
    fired {

      raise wovyn event "threshold_violation" 
        attributes event:attrs if event:attrs{"temperature"} > sensor_profile:threshold()
        
    }
    
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    
    pre {
      
      not_used = event:attrs.klog("Temperature Violation Notification");
      message = "Your wovyn sensor exceeded the temperature threshold of " 
        + sensor_profile:threshold() + " degrees fahrenheit with a temperature of " 
        + event:attrs{"temperature"} + " degrees fahrenheit."
    
    }
    
    twilio:send_sms(sensor_profile:notify_number(), sensor_profile:notification_from_phone_number, message)
  
  }
  
  
}
