ruleset wovyn_base {

  meta {
    // use module twilio
    //     with sid = meta:rulesetConfig{"sid"}
    //     and auth_token =meta:rulesetConfig{"auth_token"}
    use module io.picolabs.subscription alias subs
    use module sensor_profile
  }

  global {
    send_notification = false
  }

  rule process_heartbeat {
    select when wovyn heartbeat where "genericThing"

    pre {
      temp = event:attrs{"genericThing"}{"data"}{"temperature"}[0]{"temperatureF"}
    }

    send_directive("Read temperature " + temp)

    always {
      raise wovyn event "new_temperature_reading" attributes 
      {"temperature": temp, "timestamp": event:time}
    }
  }

  rule find_high_temps {
    select when wovyn new_temperature_reading where event:attrs{"temperature"} > sensor_profile:get_threshold()

    foreach subs:established() setting (sub)

    if true || sub{"Rx_role"} == "manager" then
    event:send(
      {
        "eci": sub{"Tx"}, 
        "eid": "send-violation", // can be anything, used for correlation
        "domain": "wovyn",
        "type": "threshold_violation",
        "attrs": event:attrs
      }
    )
      //raise wovyn event "threshold_violation" attributes event:attrs
    
  }

  // rule threshold_notification {
  //   select when wovyn threshold_violation where send_notification == true

  //   twilio:send_message("Temperature is " + event:attrs{"temperature"}.klog("Sending message...", sensor_profile:get_notification_dest) + "!")
  // }
}