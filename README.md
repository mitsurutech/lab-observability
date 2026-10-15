# Prometheus and Grafana observability lab with Docker Compose: write an alerting rule in a private copy

[![check](https://github.com/mitsurutech/lab-observability/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-observability/actions/workflows/check.yml)

A ready-made **monitoring and observability lab** for classrooms, from the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning), where schools and colleges give every student their own databases, containers and terminal in the browser. Each student gets their own copy of a small web server to watch, **Prometheus** collecting its metrics and **Grafana** drawing them, already connected, and then **writes an alerting rule** in Prometheus, breaks the server on purpose and watches the alert go from pending to firing. It suits a first introduction to monitoring, PromQL, dashboards and alerting in a DevOps, operations or cloud unit, with nothing installed and no risk to anybody else's machine.

It is one `docker-compose` file, `compose.yaml`, and it runs the same on your own machine as it does on the platform, where every student gets a private copy with no way out to the internet.

## What is in it

| Service | Image | Memory | What it is |
| --- | --- | --- | --- |
| `app` | [`nginx:1.27-alpine`](https://hub.docker.com/_/nginx) | 64 MB | the web server to watch, running as an unprivileged account (101), with its status page on a port of its own |
| `exporter` | [`nginx/nginx-prometheus-exporter:1.5.3`](https://hub.docker.com/r/nginx/nginx-prometheus-exporter) | 32 MB | reads the status page and publishes it as Prometheus metrics, such as `nginx_up` and `nginx_http_requests_total` |
| `prometheus` | [`prom/prometheus:v3.13.4`](https://hub.docker.com/r/prom/prometheus) | 256 MB | collects the metrics every five seconds and answers questions in PromQL, and reads the alerting rules |
| `grafana` | [`grafana/grafana:13.2.4`](https://hub.docker.com/r/grafana/grafana) | 512 MB | draws them, signed in as the one person using the copy and already connected to Prometheus |

That is 864 MB of limits. Idle, a copy uses roughly 280 MB, almost all of it Grafana, and it is healthy within twenty seconds of starting. The first start downloads the images, Grafana's being the large one.

The images are third-party programs, run unmodified from the projects' own public images and pinned to a version (never `latest`), so the lab does not change under a class between one lesson and the next. Nothing is built here and nothing from this repository is distributed in them. The configuration each one needs is written by its own entrypoint from the compose file, so there is nothing else to download.

## Using it on the platform

The [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning) gives every student their own copy of a lab, in the browser, with a terminal beside it.

**To try it:** open the [container page](https://mitsurutech.co.uk/container), find this lab in **Sample labs** and press Start. No account is needed to try one. The manual page for it is [Observability lab](https://mitsurutech.co.uk/help/lab-observability), and the lesson **Observability Basics** works through it.

**To set it as work for a class:**

1. In your module, make a task of type **Lab** and choose **In a GitHub repository**.
2. Give `https://github.com/mitsurutech/lab-observability` with the branch `main`. The compose file is the default, `compose.yaml`. Fork the repository first if you want to change the file.
3. Publish. Every student's copy starts from the commit you published, so a later change here does not alter a lab already set.
4. Say in the task what to hand in (see [For teachers](#for-teachers)), and assign it like any other task.

The help manual's [guide to container labs](https://mitsurutech.co.uk/help/labs) covers the rest: what a compose file may say, how much memory a copy gets, and how a teacher opens, watches and marks a student's copy.

No college account yet? [Your first year is free](https://mitsurutech.co.uk/pricing) for up to 50 students, and [signing up](https://mitsurutech.co.uk/signup) takes an email address.

## Running it on your own machine

You need Docker with the Compose plugin. The first start downloads the images.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Open <http://localhost:9090> for Prometheus and <http://localhost:3000> for Grafana, which needs no sign-in. The web server itself is on <http://localhost:8080>.

`local.yaml` publishes the ports on `127.0.0.1` only, so the lab is reachable from your own computer and from nowhere else. Stop it with `Ctrl-C`, and remove it, volumes included, with `docker compose -f compose.yaml -f local.yaml down -v`.

## Working through it

1. **Ask Prometheus a question.** In Prometheus, run `nginx_up` and then `rate(nginx_http_requests_total[1m])`. From a terminal on the lab's network the same question is `curl 'http://prometheus:9090/api/v1/query?query=nginx_up'`.
2. **Make some traffic.** `curl "http://app:8080/?n=[1-300]"` sends three hundred requests in one command, and the rate rises.
3. **Draw it.** In Grafana, open **Explore** (or build a dashboard), choose the **Prometheus** data source, which is already there, and run the same query.
4. **Write an alerting rule.** Put a `.yml` file in `/etc/prometheus/rules/` on the `prometheus` service, with `docker exec` (or `docker compose exec` on your own machine), for example a rule whose `expr` is `nginx_up == 0` and whose `for` is `10s`. Then reload Prometheus with `curl -X POST http://prometheus:9090/-/reload` and look at **Alerts**.
5. **Make it fire.** `docker stop app` stops the server. The alert is pending for the ten seconds the rule asked for and then firing. `docker start app` and it clears.

The Prometheus configuration (`/etc/prometheus/prometheus.yml`), your rules and your Grafana dashboards are on named volumes and survive stopping the lab and starting it again. The measurements are not saved, so a restarted lab starts with an empty graph. The configuration is written only on the very first start: if you change it, a restart does not put it back.

## For teachers

Nothing in this lab is marked automatically. The student hands in evidence and you mark it, the way you mark any other lab.

**Ask for evidence in two halves.** First, proof of the work: the rule itself, a screenshot of it **firing** on the Prometheus Alerts page, and a Grafana panel of the same signal. Second, the understanding: a sentence or two on what the rule asks and why ten seconds, and what a person on call would do when it fired. For stronger work ask for a second rule on a different signal, such as the request rate, and for an explanation of why alerting on a symptom a user would notice beats alerting on every number.

**Where it sits in a course.** It suits a first look at monitoring, metrics, dashboards and alerting in a DevOps, operations, cloud or systems unit, and the idea of an exporter, which is how software that publishes no metrics is watched. Check your own awarding body's unit for the exact wording; none is quoted here.

**Who sees what.** A copy is private to the student who started it. A member of staff who teaches the module can open it to see what the student has done, and opening a student's work is written to the access log, which the student can read.

## What does not work in a lab

The lab has no way out to the internet, so nothing can be downloaded into it, Grafana's plugin catalogue and update checks are switched off, and an alert can be watched but not sent anywhere: there is no email or chat to notify. The measurements are not saved when the lab stops. `docker exec` into the Prometheus service is how a rule is written, and the lab's terminal on the platform allows it; on a machine that cannot offer the lab's `docker` command, write the rule with your own Docker.

## Troubleshooting

- **The Grafana page is blank straight after Start.** Wait a few seconds and press Open again: the lab reports itself ready only once Prometheus answers, and Grafana follows it.
- **The alert never appears after the reload.** A rule file with a mistake in it makes the reload fail: `curl -s -X POST http://prometheus:9090/-/reload` prints "failed to reload config", and Prometheus keeps the rules it had before. The reason is in the service's log (`docker logs prometheus`). Rules are read from `/etc/prometheus/rules/*.yml` only.
- **On your own machine, port 9090, 3000 or 8080 is already in use.** Change the left-hand numbers in `local.yaml` and open those ports instead.

## Checking the lab

`test/check.sh` starts the lab the way the platform's runner starts every service (all capabilities dropped, `no-new-privileges`, a process limit, memory limits, and no way out to the internet) and then checks from inside its network what this page promises: every service is healthy, Prometheus scrapes the exporter, a PromQL query answers, Grafana is signed in and its data source works, a rule written onto the volume goes pending, then firing, then clears, and the configuration and the rule survive a stop and a start. It needs Docker and runs on every push, which is the badge at the top.

```bash
test/check.sh
```

## Versions and licences

[nginx](https://nginx.org) is BSD-2-Clause, the [NGINX Prometheus exporter](https://github.com/nginx/nginx-prometheus-exporter) and [Prometheus](https://github.com/prometheus/prometheus) are Apache-2.0, and [Grafana](https://github.com/grafana/grafana) is AGPL-3.0. They are run unmodified from their own images and are not distributed here. The images are `nginx:1.27-alpine`, `nginx/nginx-prometheus-exporter:1.5.3`, `prom/prometheus:v3.13.4` and `grafana/grafana:13.2.4`.

The compose file, the tests and this documentation are MIT licensed, see [LICENSE](LICENSE): copy it, change it, teach with it. The applications inside keep the licence of their own projects, linked above.

## About

Made by [Mitsuru Technologies](https://mitsurutech.co.uk) for the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning): Python, Java, Go, Node, SQL and Linux in the browser for schools and colleges, with container labs, web apps deployed from GitHub, and quizzes that mark themselves. Try code with no account in the [playground](https://mitsurutech.co.uk/playground). The [help manual](https://mitsurutech.co.uk/help/labs) lists every lab.

More labs from the same place: [lab-juice-shop](https://github.com/mitsurutech/lab-juice-shop), [lab-dvwa](https://github.com/mitsurutech/lab-dvwa), [lab-webgoat](https://github.com/mitsurutech/lab-webgoat), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) and [lab-sample](https://github.com/mitsurutech/lab-sample).
