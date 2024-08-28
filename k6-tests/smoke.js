import http from 'k6/http'
import { sleep } from 'k6'
import { WEB_URL } from './constants.js'

export const options = {
    vus: 3, // Key for Smoke test. Keep it at 2, 3, max 5 VUs
    duration: '1m', // This can be shorter or just a few iterations
    thresholds: {
        http_req_failed: ['rate < 0.01'],
        http_req_duration: ['p(95) < 500']
    }
}

export default () => {
    http.get(WEB_URL)
    sleep(1)
}