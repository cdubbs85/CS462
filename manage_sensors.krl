ruleset manage_sensors {
  
  meta {
    
    use module io.picolabs.wrangler alias Wrangler
    
    shares sensors, temperatures
  
  }
  
  global {
    
    threshold_default = 90;
    default_location = "TestLocation";
    notify_number_default = 12109134920;
    
    getChildSensorName = function(name){
      "child_sensor_" + name;
    };
    
    sensors = function(){
      ent:sensors.defaultsTo({})
    };
    
    temperatures = function(){
      ent:sensors.defaultsTo({}).map(function(v, k){
        url = "http://localhost:8080/sky/cloud/" + v +"/temperature_store/temperatures";
        temps = http:get(url);
        temps{"content"};
      });
    };
    
  }
  
  rule new_sensor_request {
    select when sensor new_sensor
    
    pre {
      
      key_exists = ent:sensors >< event:attrs{"name"};
      
    }
    
    if key_exists then
      send_directive("sensor_already_exists", { "existing_name": event:attrs{"name"}});
      
    notfired {
      
      // name not found in ent:sensors -> create new pico for this sensor
      raise wrangler event "child_creation"
        attributes { "name" : getChildSensorName(event:attrs{"name"}),
                     "color" : "#ffff00",
                     "provided_name" : event:attrs{"name"},
                     "rids" : ["key_module", 
                               "sensor_profile",
                               "temperature_store",
                               "twilio",
                               "wovyn_base",
                               "io.picolabs.logging"]
        };
        
    }
    
  }
  
  rule child_sensor_created {
    select when wrangler child_initialized
    
    pre {
      
      name = event:attrs{["rs_attrs", "provided_name"]}.klog("CHILDCREATED");
      eci = event:attrs{"eci"};
      args = {"name": name, "location": default_location, "threshold": threshold_default, "notify": notify_number_default};
      host = "http://localhost:8080";
      url = host + "/sky/event/" + eci + "/fromManageSensors/sensor/profile_updated";
      response = http:get(url,args);
      answer = response{"content"}.decode();
      
    }
    
    noop()
    
    always {
      
      ent:sensors := ent:sensors.defaultsTo({}).put(name, eci);
      // ent:all_sensors := ent:sensors.defaultTo({}).put(name, eci);
      
    }
    
  }
  
  rule delete_child_sensor {
    select when sensor unneeded
    
    if event:attrs{"name"} then noop()
    
    fired {
      
      raise wrangler event "child_deletion"
        attributes {"name" : getChildSensorName(event:attrs{"name"})};
        
      clear ent:sensors{event:attrs{"name"}};
      
    }
    
  }
  
  rule remove_all_child_sensors {
    select when sensor remove_all
    
    foreach ent:sensors.keys() setting (name)
    
    noop()
    
    fired {
      
      blank = name.klog(name);
      
      raise wrangler event "child_deletion"
        attributes {"name" : getChildSensorName(name)};
        
      clear ent:sensors{name};
      
    }
    
  }
  
}
