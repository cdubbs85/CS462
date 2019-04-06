ruleset gossip_protocol {
  meta {
    shares __testing, temps, track, getFirstMessage
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" },
        { "name": "temps"},
        { "name": "track"}
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "gossip", "type": "seen", "attrs": ["seen"] },
        { "domain": "testing", "type": "update_period", "attrs": ["period"] }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    // For testing
    temps = function(){ent:temperature_logs}
    track = function(){ent:tracker}
    // ***********
    
    createMessage = function(data){
      {"MessageID": meta:picoId + ":" + ent:sequenceNum,
       "SensorID": meta:picoId,
       "Temperature": data{"temperature"},
       "Timestamp": data{"timestamp"},
      }
    }
    
    // returns true if i have messages of higher number than the subscriber has seen
    checkSeenAll = function(highestSeen, messages){
      missing = messages.filter(function(v,k){
        k.as("Number") > highestSeen
      });
      missing.length() > 0
    }
    
    // loop through seen messages, returns true if I have messagse subscriber needs
    loopMessages = function(subscriber){
      missing = ent:temperature_logs.filter(function(v,k){
        seenAtLeastOne = ent:tracker{[subscriber,k]};
        // if null, i have messages from a source from which the subscriber hasn't seen any messages
        seenAtLeastOne.isnull() => true | checkSeenAll(seenAtLeastOne.as("Number"),v)
      });
      missing.length() > 0
    }
    
    // selects a single peer from those peers who need info from me
    getPeer = function(){
      all_subs = Subscriptions:established("Tx_role", "node");
      missing = all_subs.filter(function(x){
        loopMessages(x{"Tx"})
      });
      // Pick a random eligible subscriber and return its channel
      (missing.length() == 0) => null | missing[random:integer(missing.length()-1)]{"Tx"}
    }
    
    // get the first message in logs
    getFirstMessage = function(){
      msgs = ent:temperature_logs.values();
      msgs => msgs[0].values()[0] | null
    }
    
    // return all messages with a higher number
    checkHaveHigherNumberMessage = function(highestSeen, messages){
      messages.filter(function(v,k){
        k.as("Number") > highestSeen
      })
    }
    
    getAllMissingMessages = function(seen){
      unseenMessages = ent:temperature_logs.map(function(v, k){
        highestSeen = seen{k};
        highestSeen.isnull() => v | checkHaveHigherNumberMessage(highestSeen,v)
      });
      vals = unseenMessages.values();
      not_null = vals.filter(function(x){
        x.keys().length > 0
      });
      not_null.reduce(function(a,b){
        a.append(b.values())
      }, []);
    }
    
    // get the oldest unseen message
    getNextSingleMessage = function(seen){
      seen_messages = getAllMissingMessages(seen);
      seen_messages.length() > 0 => seen_messages[0] | null
    }
    
    // should get the lowest number message i have that the subscriber hasn't seen
    prepareRumor = function(subscriber){
      seen = ent:tracker{subscriber};
      // if we don't know anything about what this subscriber has seen, send them the first message we have
      //  otherwise, use their seen to find a message to send
      // UPDATE - I probably don't need getFirstMessage() after now. getNext should handle it. But I'm afraid to remove it
      msg = seen => getNextSingleMessage(seen) | getFirstMessage();
      msg => {"type":"rumor", "msg":msg} | null;
    }
    
    prepareSeen = function(){
      // look through your messages and prepare a seen structured message
      vals = ent:temperature_logs.map(function(v,k){
        vals = (v.keys().map(function(x){x.as("Number")})).sort();
        highest = vals.reduce(function(f, s){ s == f + 1 => s | -1 });
        highest;
      });
      vals.keys().length() > 0 => {"type":"seen", "msg":vals} | null
    }
    
    prepareMessage = function(subscriber){
      // prepareRumor(subscriber);
      // prepareSeen();
      (random:integer(1) == 0) => prepareRumor(subscriber) | prepareSeen(subscriber)
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
    if subscriber && m then noop()
    
    fired {
      raise send event "rumor" attributes {"to":subscriber,"msg": m{"msg"}} if m{"type"} == "rumor";
      raise send event "seen" attributes {"to":subscriber,"msg": m{"msg"}} if m{"type"} == "seen";
    }
  }
  
  rule send_rumor {
    select when send rumor
    pre {
      to = event:attrs{"to"}
      msg = event:attrs{"msg"}
    }
    
    event:send({"eci":to, "domain":"gossip", "type":"rumor", "attrs":{"rumor": msg}})
    
    always {
      ent:tracker{to} := ent:tracker{to}.defaultsTo({}).put(msg{"SensorID"},getNumber(msg{"MessageID"}) )
    }
  }
  
  rule send_seen {
    select when send seen
    event:send({"eci":event:attrs{"to"}, "domain":"gossip", "type":"seen", "attrs":{"seen": event:attrs{"msg"}}})
  }
  
  rule gossip_rumor {
    select when gossip rumor where ent:process == "on"
    pre {
      message = event:attrs{"rumor"}
      sensorId = message{"SensorID"}
      messageNum = getNumber(message{"MessageID"})
      sender = Subscriptions:established("Rx",meta:eci)[0]{"Tx"}
    }
    
    if message then noop()
    
    fired {
      holder = ent:temperature_logs{sensorId}.defaultsTo({}).put(messageNum,message);
      ent:temperature_logs{sensorId} := holder;
      // Not sure if I want to keep this
      holder2 = ent:tracker{sender}.defaultsTo({}).put(sensorId,messageNum);
      ent:tracker{sender} := holder2;
      // send a seen response to whoever sent me this
      // raise gossip event "respond_to_rumor" attributes {"to"
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
      ent:tracker{sender} := seen;
      // send the sender the messages you have that they don't
      raise gossip event "respond_to_rumor" attributes {"to":sender, "seen":seen}
    }
  }
  
  rule rumor_respond {
    select when gossip respond_to_rumor
    foreach getAllMissingMessages(event:attrs{"seen"}) setting (msg)
    pre{
      to = event:attrs{"to"}
    }
    event:send({"eci":to, "domain":"gossip", "type":"rumor", "attrs":{"rumor": msg}})
    always {
      ent:tracker{to} := ent:tracker{to}.defaultsTo({}).put(msg{"SensorID"},getNumber(msg{"MessageID"}) )
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
  
  // When going from process off to on, update all peers of my seen state
  rule processing_send_seen {
    select when gossip process where process == "on"
    foreach Subscriptions:established("Tx_role", "node") setting (sub)
    pre {
      to = sub{"Tx"}
      msg = prepareSeen()
    }
    
    event:send({"eci": to, "domain":"gossip", "type":"seen", "attrs":{"seen": msg}})
    
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
  
  rule just_for_testing {
    select when testing update_period
    always{
      ent:period := event:attrs{"period"}.as("Number")
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

}
