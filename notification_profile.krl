ruleset notification_profile {
  meta {

    use module key_module
    use module twilio alias twilio
      with account_sid = keys:twilio{"account_sid"}
        auth_token = keys:twilio{"auth_token"}
        
    use module manage_sensors
   
  }
  global {
    
    notification_from_phone_number = 12108800482
    notify_number_default = 12109134920
    
  }
  
  rule threshold_violation {
    
    select when manager threshold_violation
    
    pre {
      
      not_used = event:attrs.klog("TEMPERATUREVIOLATIONNOTIFICATION");
      message = "Your wovyn sensor at " 
        + event:attrs{"location"} + " exceeded the temperature threshold of " 
        + event:attrs{"threshold"} + " degrees fahrenheit with a temperature of " 
        + event:attrs{"temperature"} + " degrees fahrenheit."
    
    }
    
    twilio:send_sms(notify_number_default, notification_from_phone_number, message)
    
  }
  
  
}
