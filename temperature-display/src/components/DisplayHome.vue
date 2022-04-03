<template>
  <div id="base-container">
    <router-link id="sensor-profile-link" to="/sensor-profile">Sensor Profile</router-link>
    <div id="temperature-display">
      <div class="sub-container">
        <h2>Current temperature</h2>
        <p id="current-temp">{{temperature}}ºF</p>
      </div>
      <div class="sub-container">
        <h2>Recent Readings</h2>
        <table>
          <thead>
            <tr>
              <td>Time</td>
              <td>Temperature</td>
            </tr>
          </thead>
          <tbody>
            <tr v-for="reading, i in recentReadings" v-bind:key="i">
              <td>{{new Date(reading.timestamp).toISOString()}}</td>
              <td>{{reading.temperature}}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="sub-container">
        <h2>Recent Violations</h2>
        <table>
          <thead>
            <tr>
              <td>Time</td>
              <td>Temperature</td>
            </tr>
          </thead>
          <tbody>
            <tr v-for="reading, i in recentViolations" v-bind:key="i">
              <td>{{new Date(reading.timestamp).toISOString()}}</td>
              <td>{{reading.temperature}}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      temperature: "73.2",
      recentReadings: [],
      recentViolations: [],
    }
  },
  created() {
    this.getTemperatures();
    setInterval(this.getTemperatures, 10000);
  },
  methods: {
    async getTemperatures() {
      const res = await fetch("http://localhost:3000/sky/cloud/cl0rm37r9000f3376el71ffnj/temperature_store/temperatures");
      const res2 = await fetch("http://localhost:3000/sky/cloud/cl0rm37r9000f3376el71ffnj/temperature_store/threshold_violations");
      let temps = await res.json();
      let tempViols = await res2.json();

      temps = temps.reverse()
      tempViols = tempViols.reverse()

      this.temperature = temps[0].temperature;
      this.recentReadings = temps.length > 25 ? temps.slice(0,25) : temps;
      this.recentViolations = tempViols.length > 25 ? tempViols.slice(0,25) : tempViols;

      // this.recentReadings = this.recentReadings.map(x => x.temperature = Date(x.temperature))
    }
  }
}
</script>

<style scoped>

#base-container {
  text-align: right;
}

#sensor-profile-link {
  margin-right: 40px;
  text-decoration: underline;
}

#sensor-profile-link:hover {
  opacity: .8;
  cursor: pointer;
}

#temperature-display {
  display: flex;
  justify-content: space-around;
  text-align: center;
}

#current-temp {
  font-size: 120px;
}

.sub-container {
  width: 100%;
}

.sub-container > table {
  width: 100%;
}

tbody {
  /* text-align: left; */
}
</style>