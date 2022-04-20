ruleset manage_sensors {
  
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subs
    use module sensor_profile alias profile
    shares sensors, testing, all_temperatures, subscriptions, last_five, last_five_reports, test
  }
  
  global {
    test = function() {
      {"1": "val"} >< 1
    }
    last_five = function() {
      ent:last_five_indicies
    }

    last_five_reports = function() {
      ent:last_five_indicies.reduce(function(a, b) {
        a.put(b, ent:reports{b})
      }, {})
    }
    
    sensors = function() {
      ent:sensors.defaultsTo({})
    }
    
    testing = function() {
      ent:testing.defaultsTo({})
    }
    
    subscriptions = function() {
      subs:established()
    }
    
    sensor_subscriptions = function() {
      subs:established().filter(function(x) {x{"Tx_role"}.match(re#^sensor-#)})
    }
    
    all_temperatures = function() {
      subs = sensor_subscriptions()
      subs.reduce(function(a, b) {
        subChannel = b{"Tx"}
        subHost = (b{"Tx_host"} || meta:host)
        temps = wrangler:picoQuery(subChannel, "temperature_store", "temperatures", null, subHost)
        a.put(b{"Tx"}, temps)
      }, {})
    }
    
    send_notification = false
    rulesets = ["file:///Users/caseystrong/cs462/lab4/sensor_profile.krl", "file:///Users/caseystrong/cs462/lab7/temperature_store.krl", "file:///Users/caseystrong/cs462/lab6/wovyn_base.krl", "file:///Users/caseystrong/cs462/lab2/emitter.krl", "file:///Users/caseystrong/cs462/lab6/create_channel.krl"]
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
        {
          "eci": event:attrs{"eci"}, 
          "eid": "install-ruleset", // can be anything, used for correlation
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "url": url,
            "config": {"sid": meta:rulesetConfig{"sid"}, "auth_token": meta:rulesetConfig{"auth_token"}},
            "name": event:attrs{"name"},
            "wellknown_rx": subs:wellKnown_Rx(){"id"}
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

  rule auto_accept_mine {
    select when wrangler inbound_pending_subscription_added

    always {
      raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }

  rule add_external_subscription {
    select when sensor add_external

    every {
      event:send({"eci":event:attrs{"wellknown_rx"},
        "domain":"wrangler", "name":"subscription",
        "attrs": {
          "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
          "Tx_role":"manager", 
          "Rx_role":"sensor-"+event:attrs{"name"},
          "Tx_host": meta:host,
          "name":event:attrs{"name"}, 
          "channel_type":"subscription"
        }
      }, event:attrs{"host"})
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

  rule threshold_notification {
    select when wovyn threshold_violation where send_notification == true

    profile:send_message("The temperature was " + event:attrs{"temperature"} + "!")
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

  rule request_sensor_reports {
    select when manager request_reports
    
    foreach sensor_subscriptions() setting (sub)
    pre {
      subChannel = sub{"Tx"}
      subHost = (sub{"Tx_host"} || meta:host)
      reportId = ent:last_five_indicies.defaultsTo([0])[0] + 1
      defaultReport = {"temperature_sensors": sensor_subscriptions().length(), "responding": 0, "temperatures": []}
    }
    event:send(
      {
        "eci": subChannel,
        "domain": "sensor", 
        "name": "send_report",
        "attrs": {
          "eci": sub{"Rx"},
          "report_id": reportId,
          "host": meta:host,
        }
      }, 
      subHost
    )

    always {
      ent:last_five_indicies := reportId.append(ent:last_five_indicies.isnull() => [] | ent:last_five_indicies.defaultsTo([]).length() < 5 => ent:last_five_indicies | ent:last_five_indicies.slice(0, 3)) on final
      ent:reports := ent:reports.isnull() => {}.put(reportId, defaultReport) | ent:reports >< reportId => ent:reports | ent:reports.put(reportId, defaultReport) on final
    }
  }

  rule clear_last_five {
    select when testing clear_last_five

    always {
      ent:last_five_indicies := null
      ent:reports := null
    }
  }

  rule receive_sensor_reports {
    select when sensor report_temperature
    
    pre {
      report_id = event:attrs{"report_id"}
      defaultReport = {"temperature_sensors": sensor_subscriptions().length(), "responding": 0, "temperatures": []}
    }

    // ent:temperature
    always {
      ent:reports := ent:reports.isnull() => {} | ent:reports.klog("reports")
      ent:reports := ent:reports >< report_id => ent:reports.put([report_id, "responding"], ent:reports{[report_id, "responding"]} + 1).put([report_id, "temperatures"], ent:reports{[report_id, "temperatures"]}.append(event:attrs{"temperature"})).klog("resultmap1") | ent:reports.put(report_id, defaultReport).put([report_id, "responding"], 1).put([report_id, "temperatures"], [event:attrs{"temperature"}]).klog("resultmap2")
    }
  }
}