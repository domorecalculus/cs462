<template>
  <div>
    <router-link id="home-link" to="/">Home</router-link>
    <h1>Sensor Profile</h1>
    <div id="container">
      <div class="column left">
        <div class="row">Name:</div>
        <div class="row">Location:</div>
        <div class="row">Threshold:</div>
        <div class="row">Notification number:</div>
      </div>
      <div class="column right">
        <div class="row"><input type="text" v-model="name"></div>
        <div class="row"><input type="text" v-model="location"></div>
        <div class="row"><input type="number" v-model="threshold"></div>
        <div class="row"><input type="text" v-model="notificationDest"></div>
      </div>
    </div>
    <button :disabled="shouldSave" v-on:click="save">Save</button>
  </div>
</template>

<script>
export default {
  data() {
    return {
      name: "",
      location: "",
      threshold: 0,
      notificationDest: "",
      lastName: "",
      lastLocation: "",
      lastThreshold: 0,
      lastNotificationDest: "",
      loading: true
    }
  },
  async created() {
    const response = await fetch("http://localhost:3000/sky/cloud/cl0rm37r9000f3376el71ffnj/sensor_profile/get_sensor_profile")
    const res = await response.json()
    console.log(res);
    this.name = res['name']
    this.location = res['location']
    this.threshold = res['threshold']
    this.notificationDest = res['notification_dest']
    this.lastName = res['name']
    this.lastLocation = res['location']
    this.lastThreshold = res['threshold']
    this.lastNotificationDest = res['notification_dest']
  },
  computed: {
    shouldSave() {
      return this.name == this.lastName && this.location == this.lastLocation && this.threshold == this.lastThreshold && this.notificationDest == this.lastNotificationDest
    }
  },
  methods: {
    async save() {
      const options = {
        method: "POST",
        body: JSON.stringify({"name": this.name, "threshold": this.threshold, "location": this.location, "notification_dest": this.notificationDest}),
        headers: {
          "Content-Type": "application/json"
        }
      }
      const response = await fetch("http://localhost:3000/sky/event/cl0rm37r9000f3376el71ffnj/1/sensor/profile_updated", options)
      
      if (response.status == 200) {
        this.lastName = this.name
        this.lastLocation = this.location
        this.lastThreshold = this.threshold
        this.lastNotificationDest = this.notificationDest
      } else {
        console.log(response);
      }
    }
  }
}
</script>

<style scoped>
#container {
  width: 400px;
  margin: auto;
  display: flex;
}
.column {
  width: 200px;
}
.left {
  text-align: right;
}
</style>