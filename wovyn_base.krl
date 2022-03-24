ruleset wovyn_base {

  meta {
    use module twilio
        with sid = meta:rulesetConfig{"sid"}
        and auth_token =meta:rulesetConfig{"auth_token"}
  }

  global {
    temperature_threshold = 74
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
    select when wovyn new_temperature_reading where event:attrs{"temperature"} > temperature_threshold

    always {
      raise wovyn event "threshold_violation" attributes event:attrs
    }
  }

  rule threshold_notification {
    select when wovyn threshold_violation where send_notification == true

    twilio:send_message("Temperature is " + event:attrs{"temperature"}.klog("Sending message...") + "!")
  }
}