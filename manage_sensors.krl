ruleset manage_sensors {
  
  meta {
    
    use module io.picolabs.wrangler alias Wrangler
    use module io.picolabs.subscription alias Subscriptions
    
    shares sensors, temperatures
    provides threshold_default
  
  }
  
  global {
    
    threshold_default = 90;
    default_location = "TestLocation";
    
    getChildSensorName = function(name){
      "child_sensor_" + name;
    };
    
    getNameFromTx = function(tx){
      found = ent:sensors.defaultsTo({}).filter(function(v, k){v{"tx"} == tx});
      found.keys()[0];
    }
    
    sensors = function(){
      Subscriptions:established("Tx_role","sensor").map(function(sub){
        sub.put("name", getNameFromTx(sub{"Tx"}))
      })
    };
  
    temperatures = function(){
      Subscriptions:established("Tx_role", "sensor").map(function(sub){
        { "name" : getNameFromTx(sub{"Tx"}),
          "tx": sub{"Tx"}, 
          "data": http:get("http://localhost:8080/sky/cloud/" + sub{"Tx"} +"/temperature_store/temperatures"){"content"}}
      })
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
                     "role" : event:attrs{"role"}.defaultsTo("DefaultRole"),
                     "host" : event:attrs{"host"}.defaultsTo("http://localhost:8080"),
                     "location" : event:attrs{"location"}.defaultsTo(default_location),
                     "rids" : ["sensor_profile",
                               "temperature_store",
                               "wovyn_base",
                               "io.picolabs.logging"]
        };
        
    }
    
  }
  
  rule child_sensor_created {
    select when wrangler child_initialized
    
    pre {
      not_used = event:attrs.klog("CHILDCREATED");
      name = event:attrs{["rs_attrs", "provided_name"]};
      eci = event:attrs{"eci"};
      role = event:attrs{["rs_attrs", "role"]};
      host = event:attrs{["rs_attrs", "host"]};
      location = event:attrs{["rs_attrs", "location"]};
    }
    
    noop()
    
    always {
      
      ent:sensors := ent:sensors.defaultsTo({}).put(name, {"eci": eci, "location": location} );
      
      raise manage_sensors event "subscribe"
        attributes {"name": name, 
                    "eci": eci, 
                    "role": role,
                    "host": host
        }
      
    }
    
  }
  
  rule subscribe_to_child {
    select when manage_sensors subscribe
    
    event:send(
      { "eci": Wrangler:myself(){"eci"}, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "Tx_host": event:attrs{"host"},
        "attrs": { "name": event:attrs{"name"},
                   "Rx_role": "sensor_manager",
                   "Tx_role": event:attrs{"role"},
                   "channel_type": "subscription",
                   "wellKnown_Tx": event:attrs{"eci"}}})
  }
  
  rule map_tx_to_name {
    select when wrangler subscription_added
    
    pre {
      
      not_used = event:attrs.klog("SUBSCRIPTIONADDED")
      name = event:attrs{"name"}
      tx = event:attrs{"Tx"}
      
    }

    noop()
    
    always {
      ent:sensors := ent:sensors.defaultsTo({}).put(name, ent:sensors{name}.put("tx", event:attrs{"Tx"})).klog("SUBSCRIPTIONMAPPED");

      raise manage_sensors event "init_profile"
        attributes {"name": name, "tx": tx, "Tx_host": event:attrs{"Tx_host"}}
      
    }
  }
  
  rule initialize_profile {
    select when manage_sensors init_profile
    
    pre {
      not_used = event:attrs.klog("PROFILEINIT")
      name = event:attrs{"name"}
      args = {"name": name, "location": ent:sensors{[name,"location"]}, "threshold": threshold_default};
      host = "http://localhost:8080";
      url = (event:attrs{"Tx_host"} + "/sky/event/" + event:attrs{"tx"} + "/fromManageSensors/sensor/profile_updated").klog("URL");
    
    }
    
    http:post(url,args)
    
  }
  
  rule add_existing_sensor_pico {
    select when sensor add_existing
    
    pre {
      name = event:attrs{"name"};
      eci = event:attrs{"eci"};
      host = event:attrs{"host"};
      role = event:attrs{"role"};
      key_exists = ent:sensors >< event:attrs{"name"};
    }
    
    if name && eci && host && role && not key_exists then noop()
    
    fired {
      raise sensor event "add_existing_ready"
        attributes event:attrs
    }
  }
  
  rule create_sub_to_seperate_host {
    select when sensor add_existing_ready
    
    event:send(
      { "eci": Wrangler:myself(){"eci"}, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "Tx_host" : event:attrs{"host"},
        "attrs": { "name": event:attrs{"name"},
                   "Rx_role": "sensor_manager",
                   "Tx_role": event:attrs{"role"},
                   "channel_type": "subscription",
                   "wellKnown_Tx": event:attrs{"eci"} } } )
    
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
