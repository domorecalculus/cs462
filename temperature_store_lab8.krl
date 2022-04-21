ruleset temperature_store {

  meta {
    shares temperatures, threshold_violations, inrange_temperatures, most_recent_temp
    provides temperatures, threshold_violations, inrange_temperatures, most_recent_temp
  }

  global {
    most_recent_temp = function() {
      ent:temperature_log[ent:temperature_log.length() - 1]
    }

    temperatures = function() {
      ent:temperature_log
    }
    threshold_violations = function() {
      ent:violation_log
    }
    inrange_temperatures = function() {
      ent:temperature_log.difference(ent:violation_log)
    }
  }

  rule collect_temperatures {
    select when wovyn new_temperature_reading

    always {
      ent:temperature_log := ent:temperature_log => ent:temperature_log.append(event:attrs) | [].append(event:attrs)
    }
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation
    
    always {
      ent:violation_log := ent:violation_log => ent:violation_log.append(event:attrs) | [].append(event:attrs)
    }
  }

  rule clear_temperatures {
    select when sensor reading_reset

    always {
      ent:temperature_log := []
      ent:violation_log := []
    }
  }

  rule send_report {
    select when sensor send_report 

    pre {
      temp = ent:temperature_log[ent:temperature_log.length() - 1]{"temperature"}
    }

    event:send(
      {
        "eci": event:attrs{"eci"}, 
        "eid": "report" + event:attrs{"report_id"}, // can be anything, used for correlation
        "domain": "sensor", "type": "report_temperature",
        "attrs": {
          "report_id": event:attrs{"report_id"}.klog("reportid"),
          "temperature": temp
        }
      },
      event:attrs{"host"}
    )
  }
}