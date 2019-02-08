ruleset temperature_store {
  meta {
    shares __testing
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
}
