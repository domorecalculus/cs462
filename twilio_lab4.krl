ruleset twilio {
  meta {
    name "Twilio SDK"
    description <<Abstraction for the Twilio API>>
    configure using sid = "" auth_token = ""
    provides send_message, messages
  }

  global {
    base_uri = "https://api.twilio.com/2010-04-01"

    send_message = defaction(msg, dest) {
      http:post(base_uri + "/Accounts/" + sid + "/Messages.json", auth={"username": sid, "password": auth_token}, form={"From": "+16065521639", "Body": msg, "To": dest})
    }

    messages = function(pageLimit, sendingNumber, receivingNumber) {
      http:get(base_uri + "/Accounts/" + sid + "/Messages.json", auth={"username": sid, "password": auth_token}, qs = {}.put((pageLimit) => {"PageSize":pageLimit} | {}).put((sendingNumber) => {"From":sendingNumber} | {}).put((receivingNumber) => {"To":receivingNumber} | {}))
    }
  }
}
