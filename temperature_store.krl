ruleset temperature_store {

  meta {
    shares temperatures, threshold_violations, inrange_temperatures
    provides temperatures, threshold_violations, inrange_temperatures
  }

  global {
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
}