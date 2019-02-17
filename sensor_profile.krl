ruleset sensor_profile {
  
  meta {
    shares get_profile
    use module wovyn_base
  }
  
  global {
    get_profile = function() {
      {"name" : ent:sensor_name.defaultsTo("SensorDefault"), 
        "location" : ent:sensor_location.defaultsTo("LocationDefault"),
        "threshold" : ent:temperature_threshold.defaultsTo(wovyn_base:threshold_default),
        "notify" : ent:notify_number.defaultsTo(wovyn_base:notify_number_default)
      };
      // ent:sensor_name.defaultsTo("default")
    }
    
  }
  
  rule sensor_profile {
      select when sensor profile_updated
      
      if event:attrs{"name"} && event:attrs{"location"} then noop();
      
      fired {
        ent:sensor_name := event:attrs{"name"}.klog("Name updated");
        ent:sensor_location := event:attrs{"location"}.klog("Location updated");
      }
    
  }
  
  rule sensor_profile_threshold {
    select when sensor profile_updated
    
    if event:attrs{"threshold"} then noop();
    
    fired {
      ent:temperature_threshold := event:attrs{"threshold"}.klog("Threshold updated");
    }
  }
  
  rule sensor_profile_notify {
    select when sensor profile_updated
    
    if event:attrs{"notify"} then noop();
    
    fired {
      ent:notify_number := event:attrs{"notify"}.klog("Notify updated");
    }
  }
  
  rule sensor_profile_reset {
    select when sensor profile_reset
    noop()
    fired {
      clear ent:sensor_name;
      clear ent:sensor_location;
      clear ent:temperature_threshold;
      clear ent:notify_number;
    }
  }
  
}
