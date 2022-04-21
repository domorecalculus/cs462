ruleset gossip_protocol {
  meta {
    use module temperature_store alias temp_store
    use module io.picolabs.subscription alias subs

    shares sensor_id, peers_sub, message_log, test
  }

  global {
    test = function() {
      {"a": 1, "b": 2}.intersection({"b": 2})
    }

    sensor_id = function() {
      ent:sensor_id
    }

    peers_sub = function() {
      ent:peers_sub
    }

    message_log = function() {
      ent:message_log
    }

    update_seen = function(sensor_id, sequence_max) {
      ent:message_log{sensor_id} >< (sequence_max + 1).as("String") => update_seen(sensor_id, sequence_max + 1) | sequence_max
    }

    get_potential_actions = function() {
      ["seen"].append(ent:peers_seen.keys().filter(function(x) {
        ent:current_seen.keys().difference(ent:peers_seen{x}.keys()).length() > 0 
          || ent:current_seen.keys().filter(function(y) {ent:peers_seen{x}{y} < ent:current_seen{y}}).length() > 0
      }))
    }

    get_rumors = function(dest_sensor_id) {
      rumors = ent:current_seen.keys().difference(ent:peers_seen{dest_sensor_id}.keys()).reduce(function(a,b) {
        a.append(message_log{b}.keys().map(function(x) {message_log{b}{x}.put("message_id", b + ":" + x)}))
      }, [])
      rumors2 = rumors.append(ent:current_seen.keys().intersection(ent:peers_seen{dest_sensor_id}.keys()).filter(function(y) {ent:peers_seen{dest_sensor_id}{y} < ent:current_seen{y}}).reduce(function(a,b){
        a.append(message_log{b}.keys().filter(function(x) { x.as("Number") > ent:peers_seen{dest_sensor_id}{b}}).map(function(x) {message_log{b}{x}.put("message_id", b + ":" + x)}))
      }, []))
      rumors2
    }
  }

  rule initialization {
    select when wrangler ruleset_installed where event:attr("rids") >< meta:rid

    always {
      ent:sensor_id := random:uuid()
      ent:current_id := 0
      
      ent:message_log := {} // {sensor_uuid: sequence_id: {temp, time}}
      ent:current_seen := {} // {sensor_uuid: highest_consec}
      ent:peers_seen := {} // {peer_uuid: {sensor_uuid: highest_consec}}
      ent:peers_sub := {} // {peer_uuid: peer_tx}

      schedule gossip event "gossip_heartbeat" repeat << */5 * * * * * >> attributes {}
    }
  }

  rule gossip_heartbeat {
    select when gossip gossip_heartbeat

    pre {
      potential_actions = get_potential_actions()
      action = potential_actions[random:integer(potential_actions.length() - 1)]
      peers = subs:established().filter(function(x) {ent:peers_sub.values() >< x{"Id"}})
    }

    if event:attrs{"action"} == "seen" then
      noop()
    fired {
      raise gossip event "send_seen" attributes {"peers": peers}
    } else {
      raise gossip event "send_rumor" attributes {"action": action}
    }
  }

  rule send_seen_rule {
    select when gossip send_seen
    foreach event:attrs{"peers"} setting (peer)

    event:send(
      {
        "eci": peer{"Tx"},
        "domain": "gossip", 
        "name": "seen_message",
        "attrs": {"sensor_id": ent:sensor_id}.put(ent:sensor_id, ent:current_seen)
      }, 
      peer{"Tx_host"}
    )
  }

  rule send_rumor_rule {
    select when gossip send_rumor
    foreach get_rumors(event:attrs{"action"}) setting (rumor)

    pre {
      sub = subs:established().filter(function(x) {x{"Id"} == ent:peers_sub{event:attrs{"action"}}})
    }

    event:send(
      {
        "eci": sub{"Tx"},
        "domain": "gossip", 
        "name": "seen_message",
        "attrs": rumor
      }, 
      sub{"Tx_host"}
    )

    // always {
    //   // ent:peers_seen{sensor_id} := ent:peers 
    // }
  }

  rule receive_rumor {
    select when gossip rumor_message

    pre {
      sensor_id = event:attrs{"message_id"}.split(re#:#)[0]
      sequence_id = event:attrs{"message_id"}.split(re#:#)[1]
    }

    always {
      ent:message_log{[sensor_id, sequence_id]} := {"temperature": event:attrs{"temperature"}, "timestamp": event:attrs{"timestamp"}}
      ent:current_seen{sensor_id} := update_seen(sensor_id, ent:current_seen{sensor_id})
    }
  }

  rule receive_seen {
    select when gossip seen_message
    
    pre {
      sensor_id = event:attrs{"sensor_id"}
    }

    always {
      ent:peers_seen{sensor_id} := event:attrs{sensor_id}
    }
  }

  rule add_peer {
    select when gossip add_peer

    every {
      event:send(
        {
          "eci": event:attrs{"wellknown_rx"},
          "domain": "wrangler", 
          "name": "subscription",
          "attrs": {
            "wellKnown_Tx": subs:wellKnown_Rx(){"id"},
            "Tx_role": "peer", 
            "Rx_role": "peer",
            "Tx_host": meta:host,
            "channel_type": "subscription"
          }
        }, 
        event:attrs{"host"}
      )
    }
  }

  rule accept_peer {
    select when wrangler inbound_pending_subscription_added where event:attrs{"Rx_role"} == "peer"

    always {
      raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }

  rule send_uuid {
    select when wrangler subscription_added where event:attrs{"Rx_role"} == "peer"

    event:send(
      {
        "eci": event:attrs{"Tx"},
        "domain": "gossip", 
        "name": "peer_uuid",
        "attrs": {
          "uuid": ent:sensor_id,
          "Id": event:attrs{"Id"}
        }
      }, 
      event:attrs{"Tx_host"}
    )
  }

  rule receive_uuid {
    select when gossip peer_uuid

    always {
      ent:peers_sub{event:attrs{"uuid"}} := event:attrs{"Id"}
    }
  }

  rule clear_peers {
    select when management clear_peers

    always {
      ent:peers_sub := {}
    }
  }
}