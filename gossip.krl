ruleset gossip_protocol {
  meta {
    shares __testing, temps, track, blah, getFirstMessage
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" },
        { "name": "temps"},
        { "name": "track"},
        { "name": "blah"},
        { "name": "getFirstMessage"}
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "gossip", "type": "seen", "attrs": ["seen"] }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    // For testing
    temps = function(){ent:temperature_logs}
    track = function(){ent:tracker}
    blah = function(){random:integer(5)}
    // ***********
    
    createMessage = function(data){
      {"MessageID": meta:picoId + ":" + ent:sequenceNum,
       "SensorID": meta:picoId,
       "Temperature": data{"temperature"},
       "Timestamp": data{"timestamp"},
      }
    }
    
    // returns true if messages contains a message with a value higher than value
    compareMessagesToValue = function(messages, value){
      results = messages.filter(function(v, k){
        k.as("Number") > value.as("Number")
      });
      results.length() > 0
    }
    
    // returns true if there are messages I have that data has not seen
    searchMessages = function(data){
      missing = data.filter(function(v,k){
        messages = ent:temperature_logs{k};
        // If messages is null, I don't have any messages from that origin so just ingore
        messages => compareMessagesToValue(messages, v) | false;
      });
      missing.length() > 0
    }
    
    getPeer = function(){
      all_subs = Subscriptions:established("Tx_role", "node");
      missing = all_subs.filter(function(x){
        seen_data = ent:tracker{x{"Tx"}};
        seen_data => searchMessages(seen_data) | true;
      });
      // Pick a random eligible subscriber and return its channel
      (missing.length() == 0) => null | missing[random:integer(missing.length()-1)]{"Tx"}
    }
    
    prepareMessage = function(subscriber){
      prepareRumor(subscriber)
      // (random:integer(1) == 0) => prepareRumor(subscriber) | prepareSeen(subscriber)
    }
    
    // get the first message in your logs
    getFirstMessage = function(){
      msgs = ent:temperature_logs.values();
      msgs => msgs[0].values()[0] | null
    }
    
    getLowest = function(messages){
      keys = messages.keys();
      lowest = keys[0];
      messages.map(function(v,k){
        k.as("Number") < lowest.as("Number")
      });
      messages{lowest}
    }
    
    getMessageFromHighestVal = function(messages, value){
      higher = messages.filter(function(v,k){
        k.as("Number") > value
      });
      getLowest(higher)
    }
    
    getNextFromSeen = function(seen){
      filtered = seen.map(function(v,k){
        messages = ent:temperature_logs{k};
        // if i have no messages with this origin id, skip. Otherwise, check for larger
        messages => getMessageFromHighestVal(messages, v) | null
      });
      not_null = filtered.filter(function(v,k){
        v => true | false
      });
      final = not_null.values();
      final => final[0] | null
    }
    
    // should get the lowest number message i have that the subscriber hasn't seen
    prepareRumor = function(subscriber){
      seen = ent:tracker{subscriber};
      // if we don't know anything about what this subscriber has seen, send them the first message we have
      //  otherwise, use their seen to find a message to send
      seen => getNextFromSeen(seen) | getFirstMessage()
    }
    
    prepareSeen = function(){
      // look through your messages and prepare a seen structured message
    }
    
    update = function(){
      // update the seen if you sent a rumor (i don't think i need to if i only sent a seen)
    }
    
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
      subscriber = getPeer().klog("PEER")
      m = prepareMessage(subscriber).klog("MESSAGEPREPARED")
    }
    
    // send the message
    // if subscriber && m then noop()
    
    fired {
      //update seen
    }
  }
  
  rule gossip_rumor {
    select when gossip rumor where ent:process == "on"
    pre {
      message = event:attrs{"message"}
      sensorId = message{"SensorID"}
      messageNum = getNumber(message{"MessageID"})
    }
    
    if message then noop()
    
    fired {
      holder = ent:temperature_logs{sensorId}.defaultsTo({}).put(messageNum,message);
      ent:temperature_logs{sensorId} := holder;
    }
  }
  
  rule gossip_seen {
    select when gossip seen where ent:process == "on"
    pre {
      seen = event:attrs{"seen"}
      sender = Subscriptions:established("Rx",meta:eci)[0]{"Tx"}
    }
    
    if seen then noop()
    
    fired {
      ent:tracker{sender} := seen
      // send the sender the messages you have that they don't
    }
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
      holder = ent:temperature_logs.get(meta:picoId).defaultsTo({}).put(ent:sequenceNum, msg);
      ent:temperature_logs{meta:picoId} := holder;
      // Increment sequence
      ent:sequenceNum := ent:sequenceNum + 1;
    }
  }
  
  // Just for testing the seen message
  rule send_seen {
    select when testing send_seen
    event:send({"eci":"YL21dYzzX719qSY7Uf7CM8", "domain":"gossip", "type":"seen", "attrs":event:attrs})
  }
}
    // NOT NEEDED - DELETE BEFORE TURN IN
    // keeping just in case
    // needsMyTemps = function(){
    //   subs = Subscriptions:established("Tx_role", "node").klog("SUBS");
    //   has_not_seen = subs.filter(function(x){
    //     node = ent:tracker{x{"Tx"}}.klog("NODE");
    //     node => (node{meta:picoId}.as("Number") < ent:sequenceNum => true | false) | true
    //   });
    //   has_not_seen
    // }
