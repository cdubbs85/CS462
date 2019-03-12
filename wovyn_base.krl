ruleset wovyn_base {
  meta {
    shares __testing
    
    use module sensor_profile
    use module io.picolabs.subscription alias Subscriptions
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
    
    foreach Subscriptions:established("Tx_role","sensor_manager") setting (manager)
      pre {
        man_host = manager{"Tx_host"};
        tx = manager{"Tx"};
      }
      
      if man_host && tx then event:send({"eci":tx, 
                                         "domain":"manager",
                                         "type":"threshold_violation",
                                         "attrs": {"temperature":event:attrs{"temperature"},
                                                   "threshold": sensor_profile:threshold(),
                                                   "location": sensor_profile:location()
                                         }}, 
                                         host=man_host) 

  }
  
  
}
