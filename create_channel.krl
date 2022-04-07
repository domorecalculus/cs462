ruleset create_channel {

  meta {
    use module io.picolabs.wrangler alias wrangler
  }

  rule create_channel {
    select when wrangler ruleset_installed
    always {
      raise wrangler event "new_channel_request" attributes {
        "tags":[event:attrs{"name"}],
        "eventPolicy": {"allow": [{"domain": "*", "name": "*"}], "deny": []},
        "queryPolicy": {"allow": [{"rid": "*", "name": "*"}], "deny": []},
      }
    }
  }

  rule send_channel{
    select when wrangler channel_created

    every {
      event:send(
        { "eci": wrangler:parent_eci(), 
          "eid": "send-channel", // can be anything, used for correlation
          "domain": "sensor", "type": "channel_created",
          "attrs": {
            "name": event:attrs{"tags"}[0],
            "eci": event:attrs{"channel"}{"id"},
          }
        }
      )
    }
  }
}