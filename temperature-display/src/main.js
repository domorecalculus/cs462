import App from './App.vue'
import DisplayHome from './components/DisplayHome.vue'
import SensorProfile from './components/SensorProfile.vue'
import {createApp} from 'vue'
import {createRouter, createWebHistory} from 'vue-router'

const routes = [
  { path: '/', component: DisplayHome },
  { path: '/sensor-profile', component: SensorProfile },
]

const router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes, 
})

const app = createApp(App)

app.use(router)

app.mount('#app')
