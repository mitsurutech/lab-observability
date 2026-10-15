#!/usr/bin/env bash
# What the README promises, checked from inside the lab's own network: run by check.sh.
set -euo pipefail
: "${NET:?run through test/check.sh}"
: "${PROJECT:?run through test/check.sh}"
probe() { docker run --rm --network "$NET" observability-check-probe bash -c "$1"; }
box() { docker ps -aq --filter "label=com.docker.compose.project=$PROJECT" --filter "label=com.docker.compose.service=$1"; }
# Asks Prometheus one question and prints the value of the first answer, or nothing. The
# question travels in the environment so its own quotes need no escaping.
ask() { docker run --rm -e "Q=$1" --network "$NET" observability-check-probe bash -c \
  'curl -fsG --data-urlencode "query=$Q" http://prometheus:9090/api/v1/query' \
  | python3 -c 'import json,sys; r=json.load(sys.stdin)["data"]["result"]; print(r[0]["value"][1] if r else "")'; }
# Tries a command for up to a minute, because the lab is measuring in real time.
until_ok() { for _ in $(seq 60); do if eval "$1"; then return 0; fi; sleep 2; done; echo "never true: $1" >&2; return 1; }

echo "- the application answers, and its status page is on its own port"
probe 'curl -fs http://app:8080/' | grep -q 'hello from the example app'
probe 'curl -fs http://app:8081/stub_status' | grep -q 'Active connections'

echo "- the exporter publishes what the status page says, and counts requests"
probe 'curl -fs http://exporter:9113/metrics' | grep -q '^nginx_up 1'
before=$(probe 'curl -fs http://exporter:9113/metrics' | sed -n 's/^nginx_http_requests_total //p')
probe 'curl -s -o /dev/null "http://app:8080/?n=[1-50]"'
after=$(probe 'curl -fs http://exporter:9113/metrics' | sed -n 's/^nginx_http_requests_total //p')
[ $((after - before)) -ge 50 ]

echo "- Prometheus scrapes the exporter and itself, and a PromQL query answers"
until_ok '[ "$(ask "up{job=\"app\"}")" = 1 ]'
until_ok '[ "$(ask "up{job=\"prometheus\"}")" = 1 ]'
until_ok '[ "$(ask "nginx_up")" = 1 ]'
probe 'curl -s -o /dev/null "http://app:8080/?n=[1-100]"'
until_ok '[ -n "$(ask "rate(nginx_http_requests_total[30s]) > 0")" ]'

echo "- Grafana is signed in, and its Prometheus data source is already there and works"
probe 'curl -fs http://grafana:3000/api/datasources' | grep -q '"name":"Prometheus"'
probe 'curl -fs http://grafana:3000/api/datasources/uid/prometheus/health' | grep -q '"status":"OK"'
# No login, and the signed-in visitor may save a dashboard (kept on the volume, checked again after the restart).
probe 'curl -fs http://grafana:3000/api/org' | grep -q '"name":"Main Org."'
probe 'curl -fs -H "Content-Type: application/json" -d "{\"dashboard\":{\"uid\":\"mine\",\"title\":\"My panel\",\"panels\":[]},\"overwrite\":true}" http://grafana:3000/api/dashboards/db' | grep -q '"status":"success"'
probe 'curl -fs -G --data-urlencode "query=up" http://grafana:3000/api/datasources/proxy/uid/prometheus/api/v1/query' | grep -q '"status":"success"'

echo "- an alerting rule written onto the volume and reloaded goes pending, then firing, then clears"
docker exec "$(box prometheus)" sh -c 'echo "$0" > /etc/prometheus/rules/lab.yml' \
  '{"groups":[{"name":"lab","rules":[{"alert":"AppDown","expr":"nginx_up == 0","for":"10s","labels":{"severity":"page"}}]}]}'
probe 'curl -fs -X POST http://prometheus:9090/-/reload'
until_ok 'probe "curl -fs http://prometheus:9090/api/v1/rules" | grep -q AppDown'
state() { probe 'curl -fs http://prometheus:9090/api/v1/alerts' | python3 -c 'import json,sys; a=json.load(sys.stdin)["data"]["alerts"]; print(a[0]["state"] if a else "none")'; }
# Quiet while the application is well.
[ "$(state)" = none ]
docker stop "$(box app)" >/dev/null
until_ok '[ "$(state)" = pending ] || [ "$(state)" = firing ]'
until_ok '[ "$(state)" = firing ]'
docker start "$(box app)" >/dev/null
until_ok '[ "$(state)" = none ]'

echo "- the configuration and the rule survive a stop and a start, and the config is not written back"
docker exec "$(box prometheus)" sh -c 'echo "# edited by a student" >> /etc/prometheus/prometheus.yml'
docker stop "$(box prometheus)" "$(box grafana)" >/dev/null
docker start "$(box prometheus)" >/dev/null
until_ok '[ "$(docker inspect -f "{{.State.Health.Status}}" "$(box prometheus)")" = healthy ]'
docker exec "$(box prometheus)" grep -q "edited by a student" /etc/prometheus/prometheus.yml
docker exec "$(box prometheus)" test -f /etc/prometheus/rules/lab.yml
probe 'curl -fs http://prometheus:9090/api/v1/rules' | grep -q AppDown
docker start "$(box grafana)" >/dev/null
until_ok '[ "$(docker inspect -f "{{.State.Health.Status}}" "$(box grafana)")" = healthy ]'
probe 'curl -fs http://grafana:3000/api/datasources/uid/prometheus/health' | grep -q '"status":"OK"'
probe 'curl -fs http://grafana:3000/api/dashboards/uid/mine' | grep -q '"title":"My panel"'
echo "  ok"
