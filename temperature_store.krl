ruleset temperature_store {
  meta {

    provides temperatures, threshold_violations, inrange_temperatures
    shares temperatures, threshold_violations, inrange_temperatures
    
    use module sensor_profile
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    
    temperatures = function(){
      ent:temp_readings.defaultsTo([])
    }
    
    threshold_violations = function(){
      ent:threshold_violations.defaultsTo([])
    }
    
    inrange_temperatures = function(){
      ent:temp_readings.defaultsTo([]).difference(ent:threshold_violations.defaultsTo([]))
    }
  }
  
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    noop()
    always {
      ent:temp_readings := ent:temp_readings.defaultsTo([]).append(event:attrs).klog("COLLECTED")
    }
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    noop()
    always {
      ent:threshold_violations := ent:threshold_violations.defaultsTo([]).append(event:attrs).klog("COLLECTED")
    }
  }
  
  rule clear_temeratures {
    select when sensor reading_reset
    pre {
      not_used = ent.klog("CLEARING ENTITY VAR")
    }
    send_directive("Clearing entity var")
    always {
      clear ent:temp_readings;
      clear ent:threshold_violations;
    }
  }
  
  rule update_threshold_violations {
    select when store update_threshold_values
    noop()
    always {
      clear ent:threshold_violations;
      ent:threshold_violations := ent:temp_readings.defaultsTo([]).filter(function(x){ x{"temperature"} > sensor_profile:threshold()}).klog("Violations updated.");
    }
  }
  
  rule collection_request {
    select when sensor temperatures
    pre {
      eid = event:eid.klog("REQUESTING_TEMPS");
      subscription = Subscriptions:established("Rx",meta:eci)[0]
    }
    event:send({"eci": subscription{"Tx"}, 
                "eid": eid, 
                "domain":"manage_sensors", 
                "type":"collect", 
                "attrs":{"data":temperatures()}}, 
                host=subscription{"Tx_host"})
  }
  
}
