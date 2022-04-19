ruleset create_channel {

  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subs
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

  rule create_subscription {
    select when wrangler ruleset_installed

    every {
      event:send({"eci":event:attrs{"wellknown_rx"},
        "domain":"wrangler", "name":"subscription",
        "attrs": {
          "wellKnown_Tx":subs:wellKnown_Rx(){"id"},
          "Rx_role":"manager", 
          "Tx_role":"sensor-"+event:attrs{"name"},
          "name":event:attrs{"name"}, 
          "channel_type":"subscription"
        }
      })
    }
  }

  rule auto_accept_mine {
    select when wrangler inbound_pending_subscription_added

    always {
      raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }
}