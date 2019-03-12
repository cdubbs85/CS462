ruleset sensor_profile {
  
  meta {
    shares get_profile
    provides threshold, location
  }
  
  global {
    threshold_default = 0;
    
    get_profile = function() {
      {"name" : ent:sensor_name.defaultsTo("SensorDefault"), 
        "location" : ent:sensor_location.defaultsTo("LocationDefault"),
        "threshold" : ent:temperature_threshold.defaultsTo(threshold_default)
      };
    }
    
    threshold = function() {
      ent:temperature_threshold.defaultsTo(threshold_default)
    }
    
    location = function() {
      ent:sensor_location.defaultsTo("LocationDefault")
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
      
      raise store event "update_threshold_values"
    }
  }
  
  rule sensor_profile_reset {
    select when sensor profile_reset
    noop()
    fired {
      clear ent:sensor_name;
      clear ent:sensor_location;
      clear ent:temperature_threshold;
      
      raise store event "update_threshold_values"
    }
  }
  
}
