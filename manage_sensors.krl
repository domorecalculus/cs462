ruleset manage_sensors {
  
  meta {
    use module io.picolabs.wrangler alias wrangler
    shares sensors, testing, all_temperatures
  }
  
  global {
    sensors = function() {
      ent:sensors.defaultsTo({})
    }

    testing = function() {
      ent:testing.defaultsTo({})
    }

    all_temperatures = function() {
      ecis = testing().values()
      ecis.reduce(function(a, b) {
        response = http:get("http://localhost:3000/sky/cloud/" + b + "/temperature_store/temperatures").klog("response: ")
        a.append(response{"content"}.decode())
      }, [])
    }
    
    rulesets = ["file:///Users/caseystrong/cs462/lab4/sensor_profile.krl", "file:///Users/caseystrong/cs462/lab3/temperature_store.krl", "file:///Users/caseystrong/cs462/lab5/wovyn_base.krl", "file:///Users/caseystrong/cs462/lab2/emitter.krl", "file:///Users/caseystrong/cs462/lab5/create_channel.krl"]
  }

  rule create_sensor {
    select when sensor new_sensor

    pre {
      name = event:attrs{"name"}.klog()
      exists = ent:sensors && ent:sensors >< name
    }
    if exists then
      send_directive("sensor already exists", {"name":name})
    notfired {
      ent:sensors := ent:sensors.defaultsTo({}).put(name, "")
      ent:testing := ent:testing.defaultsTo({}).put(name, "")
      raise wrangler event "new_child_request"
        attributes { "name": name, "backgroundColor": "#ff69b4" }
    }
  }

  rule add_eci {
    select when wrangler new_child_created

    always {
      ent:sensors{event:attrs{"name"}} := event:attrs{"eci"}
    }
  }

  
  rule add_rulesets {
    select when wrangler new_child_created
    
    foreach rulesets setting (url)
    
    every {
      event:send(
        { "eci": event:attrs{"eci"}, 
        "eid": "install-ruleset", // can be anything, used for correlation
        "domain": "wrangler", "type": "install_ruleset_request",
        "attrs": {
          "url": url,
          "config": {"sid": meta:rulesetConfig{"sid"}, "auth_token": meta:rulesetConfig{"auth_token"}},
          "name": event:attrs{"name"}
        }
      }
      )
    }
    
    always {
      raise sensor event "finished_setup"
      attributes {"name": event:attrs{"name"}, "eci": event:attrs{"eci"}}
    }
    
  }
  
  rule track_test_eci {
    select when sensor channel_created
    always {
      ent:testing{event:attrs{"name"}} := event:attrs{"eci"}
    }
  }

  rule update_profile {
    select when sensor finished_setup

    every {
      event:send(
        { "eci": event:attrs{"eci"}, 
          "eid": "update-profile", // can be anything, used for correlation
          "domain": "sensor", "type": "profile_updated",
          "attrs": {
            "name": event:attrs{"name"},
            "threshold": 74,
            "notification_dest": "+17125773253"
          }
        }
      )
    }    
  }

  rule delete_sensor {
    select when sensor unneeded_sensor
    
    fired {
      raise wrangler event "child_deletion_request"
        attributes { "eci": ent:sensors{event:attrs{"name"}}}
      
      clear ent:sensors{event:attrs{"name"}}
      clear ent:testing{event:attrs{"name"}}
    }
  }
}