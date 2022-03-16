ruleset twilio_test {
    meta {
        use module twilio
            with sid = meta:rulesetConfig{"sid"}
            and auth_token =meta:rulesetConfig{"auth_token"}
    }

    rule test_send {
        select when test send
        twilio:send_message("Hello there")
    }

    rule test_retrieve {
        select when test retrieve
        pre {
            res = twilio:messages(event:attrs{"pageLimit"}, event:attrs{"sendingNumber"}, event:attrs{"receivingNumber"}).klog("res: ")
        }

        send_directive("say", res)
    }
}