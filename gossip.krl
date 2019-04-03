ruleset gossip_protocol {
  meta {
    shares __testing, temps, track
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" },
        { "name": "temps"},
        { "name": "track"}
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    temps = function(){ent:temperature_logs}
    track = function(){ent:tracker}
    
    createMessage = function(data){
      {"MessageID": meta:picoId + ":" + ent:sequenceNum,
       "SensorID": meta:picoId,
       "Temperature": data{"temperature"},
       "Timestamp": data{"timestamp"},
      }
    }
    
    // returns true if there are messages data has not seen
    searchMessages = function(data){
      
    }
    
    getPeer = function(){
      // missing_my_temps = needsMyTemps().klog("NEEDSMYOWNTEMPS");
      all_subs = Subscriptions:established("Tx_role", "node");
      missing = all_subs.filter(function(x){
        seen_data = ent:tracker{x{"Tx"}}.klog("SEEN_DATA");
        seen_data => searchMessages(seen_data) | true;
      });
      
      {"test":1}
    }
    
    prepareMessage = function(subscriber){
      {"test":"Yo"}
    }
    
    update = function(){
      
    }
    
    // needsMyTemps = function(){
    //   subs = Subscriptions:established("Tx_role", "node").klog("SUBS");
    //   has_not_seen = subs.filter(function(x){
    //     node = ent:tracker{x{"Tx"}}.klog("NODE");
    //     node => (node{meta:picoId}.as("Number") < ent:sequenceNum => true | false) | true
    //   });
    //   has_not_seen
    // }
    
    getNumber = function(string){
      holder = string.split(re#:#);
      holder[1].as("Number");
    }
    
    getId = function(string){
      holder = string.split(re#:#);
      holder[0];
    }
    
  }
  
  // Gossip ********************************************************************
  rule gossip_hearbeat_repeat {
    select when gossip heartbeat
    always {
      schedule gossip event "heartbeat" 
        at time:add(time:now(), {"seconds": ent:period})
    }
  }
  
  rule propagate {
    select when gossip heartbeat where ent:process == "on"
    pre {
      // subscriber = getPeer().klog("GETTINGPEER")
      // m = prepareMessage(subscriber).klog("MESSAGEPREPARED")
    }
  }
  
  rule gossip_rumor {
    select when gossip rumor where ent:process == "on"
    pre {
      sensorId = event:attrs{"SensorID"}
      messageNum = getNumber(event:attrs{"MessageID"})
      message = {"MessageID": event:attrs{"MessageID"},
                 "SensorID": event:attrs{"SensorID"},
                 "Temperature": event:attrs{"Temperature"},
                 "Timestamp": event:attrs{"Timestamp"}
                }
    }
    
    if sensorId && message then noop()
    
    fired{
      holder = ent:temperature_logs{sensorId}.defaultsTo({}).put(messageNum,message);
      ent:temperature_logs{sensorId} := holder;
    }
  }
  
  rule gossip_seen {
    select when gossip seen where ent:process == "on"
  }
  
  // Helpers *******************************************************************
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }
  
  rule initialize {
    select when wrangler ruleset_added where rids >< meta:rid
    
    always {
      
      ent:period := 5;
      ent:process := "on";
      ent:sequenceNum := 0;
      ent:temperature_logs := {};
      ent:tracker := {};
      
      raise gossip event "heartbeat" attributes {"nothing":"nothing"}
    }
  }
  
  rule update_processing_state {
    select when gossip process
    pre {
      new_state = event:attrs{"process"}
    }
    if new_state then noop()
    fired {
      ent:process := new_state
    }
  }
  
  rule update_period {
    select when gossip update_period
    pre {
      new_period = event:attrs{"period"}
    }
    if new_period then noop()
    fired {
      ent:period := new_period
    }
  }
  
  rule new_temperature {
    select when wovyn new_temperature_reading
    pre {
      msg = createMessage({"temperature":event:attrs{"temperature"},"timestamp":time:now()});
    }
    always {
      // Add to messages
      tempOne = ent:temperature_logs.get(meta:picoId).defaultsTo({}).put(ent:sequenceNum, msg);
      ent:temperature_logs{meta:picoId} := tempOne;
      // Increment sequence
      ent:sequenceNum := ent:sequenceNum + 1;
    }
  }
}
