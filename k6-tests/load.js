import http from 'k6/http'
import { check, sleep } from 'k6'
import { WEB_URL, WEB_PAGES } from './constants.js'

export const options = {
    // used in localhost
    //insecureSkipTLSVerify: true,

    // Key configurations for avg load test in this section
    stages: [
      { duration: '15s', target: 50 }, // traffic ramp-up from 1 to 100 users over 5 minutes.
      { duration: '30s', target: 50 }, // stay at 100 users for 30 minutes
      { duration: '15s', target: 0 }, // ramp-down to 0 users
    ],

    thresholds: {
        http_req_failed: ['rate < 0.01'],
        http_req_duration: ['p(95) < 1000'],
    }
  };
  
  export default () => {
     const res = http.get(`${WEB_URL}/${WEB_PAGES[Math.floor(Math.random() * WEB_PAGES.length)]}`)
    //const res = http.get(`${WEB_URL}/health`)
    check(res, {
        'status code 200': (r) => r.status === 200
    })

    sleep(1);
  };