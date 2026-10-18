# Lab d’observabilité Prometheus et Grafana avec Docker Compose : écrire une règle d’alerte dans une copie privée

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md)

[![check](https://github.com/mitsurutech/lab-observability/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-observability/actions/workflows/check.yml)

Un **lab de supervision et d’observabilité** prêt à l’emploi pour la classe, issu de la [plateforme d’apprentissage MitsuruTech](https://mitsurutech.co.uk/fr/learning), où les établissements donnent à chaque élève ses propres bases de données, conteneurs et terminal dans le navigateur. Chaque élève reçoit sa propre copie d’un petit serveur web à surveiller, avec **Prometheus** qui collecte ses métriques et **Grafana** qui les affiche, déjà reliés entre eux. Il **écrit ensuite une règle d’alerte** dans Prometheus, casse le serveur volontairement et regarde l’alerte passer de l’état « pending » à l’état « firing ». Ce lab convient à une première approche de la supervision, de PromQL, des tableaux de bord et des alertes dans une unité DevOps, exploitation ou cloud, sans rien installer et sans risque pour la machine de qui que ce soit.

C’est un seul fichier `docker-compose`, `compose.yaml`, qui fonctionne de la même façon sur votre propre machine que sur la plateforme, où chaque élève dispose d’une copie privée sans accès à internet.

## Ce qu’il contient

| Service | Image | Mémoire | Ce que c’est |
| --- | --- | --- | --- |
| `app` | [`nginx:1.27-alpine`](https://hub.docker.com/_/nginx) | 64 Mo | le serveur web à surveiller, exécuté sous un compte non privilégié (101), avec sa page d’état sur un port à part |
| `exporter` | [`nginx/nginx-prometheus-exporter:1.5.3`](https://hub.docker.com/r/nginx/nginx-prometheus-exporter) | 32 Mo | lit la page d’état et la publie sous forme de métriques Prometheus, comme `nginx_up` et `nginx_http_requests_total` |
| `prometheus` | [`prom/prometheus:v3.13.4`](https://hub.docker.com/r/prom/prometheus) | 256 Mo | collecte les métriques toutes les cinq secondes, répond aux questions en PromQL et lit les règles d’alerte |
| `grafana` | [`grafana/grafana:13.2.4`](https://hub.docker.com/r/grafana/grafana) | 512 Mo | les affiche, connecté en tant que la seule personne qui utilise la copie et déjà relié à Prometheus |

Cela fait 864 Mo de limites. Au repos, une copie utilise environ 280 Mo, presque tout pour Grafana, et elle est opérationnelle moins de vingt secondes après son démarrage. Le premier démarrage télécharge les images, celle de Grafana étant la plus volumineuse.

Les images sont des programmes tiers, exécutés sans modification à partir des images publiques des projets eux-mêmes et figées sur une version (jamais `latest`), de sorte que le lab ne change pas sous les pieds d’une classe d’une leçon à l’autre. Rien n’est construit ici et rien de ce dépôt n’est distribué dans ces images. La configuration dont chacune a besoin est écrite par son propre point d’entrée à partir du fichier compose, il n’y a donc rien d’autre à télécharger.

## L’utiliser sur la plateforme

La [plateforme d’apprentissage MitsuruTech](https://mitsurutech.co.uk/fr/learning) donne à chaque élève sa propre copie d’un lab, dans le navigateur, avec un terminal à côté.

**Pour l’essayer :** ouvrez la [page des conteneurs](https://mitsurutech.co.uk/fr/container), trouvez ce lab dans **Sample labs** et appuyez sur Start. Aucun compte n’est nécessaire pour en essayer un. La page du manuel qui lui est consacrée est [Observability lab](https://mitsurutech.co.uk/fr/help/lab-observability), et la leçon **Observability Basics** le parcourt pas à pas.

**Pour le donner comme travail à une classe :**

1. Dans votre module, créez une tâche de type **Lab** et choisissez **In a GitHub repository**.
2. Indiquez `https://github.com/mitsurutech/lab-observability` avec la branche `main`. Le fichier compose est celui par défaut, `compose.yaml`. Faites d’abord un fork du dépôt si vous voulez modifier le fichier.
3. Publiez. La copie de chaque élève part du commit que vous avez publié, de sorte qu’une modification ultérieure ici ne change pas un lab déjà donné.
4. Précisez dans la tâche ce qu’il faut rendre (voir [Pour les enseignants](#pour-les-enseignants)), puis distribuez-la comme n’importe quelle autre tâche.

Le [guide des labs de conteneurs](https://mitsurutech.co.uk/fr/help/labs) du manuel couvre le reste : ce qu’un fichier compose peut dire, la mémoire dont dispose une copie, et comment un enseignant ouvre, observe et note la copie d’un élève.

Pas encore de compte pour votre établissement ? [Votre première année est gratuite](https://mitsurutech.co.uk/fr/pricing) jusqu’à 50 élèves, et [l’inscription](https://mitsurutech.co.uk/fr/signup) ne demande qu’une adresse e-mail.

## L’exécuter sur votre propre machine

Il vous faut Docker avec le plugin Compose. Le premier démarrage télécharge les images.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Ouvrez <http://localhost:9090> pour Prometheus et <http://localhost:3000> pour Grafana, qui ne demande aucune connexion. Le serveur web lui-même est sur <http://localhost:8080>.

`local.yaml` publie les ports sur `127.0.0.1` uniquement, de sorte que le lab n’est accessible que depuis votre propre ordinateur et nulle part ailleurs. Arrêtez-le avec `Ctrl-C` et supprimez-le, volumes compris, avec `docker compose -f compose.yaml -f local.yaml down -v`.

## Pas à pas

1. **Poser une question à Prometheus.** Dans Prometheus, exécutez `nginx_up` puis `rate(nginx_http_requests_total[1m])`. Depuis un terminal sur le réseau du lab, la même question s’écrit `curl 'http://prometheus:9090/api/v1/query?query=nginx_up'`.
2. **Générer du trafic.** `curl "http://app:8080/?n=[1-300]"` envoie trois cents requêtes en une seule commande, et le taux monte.
3. **Le dessiner.** Dans Grafana, ouvrez **Explore** (ou créez un tableau de bord), choisissez la source de données **Prometheus**, qui est déjà là, et exécutez la même requête.
4. **Écrire une règle d’alerte.** Placez un fichier `.yml` dans `/etc/prometheus/rules/` sur le service `prometheus`, avec `docker exec` (ou `docker compose exec` sur votre propre machine), par exemple une règle dont l’`expr` est `nginx_up == 0` et dont le `for` est `10s`. Rechargez ensuite Prometheus avec `curl -X POST http://prometheus:9090/-/reload` et regardez **Alerts**.
5. **La déclencher.** `docker stop app` arrête le serveur. L’alerte reste en attente pendant les dix secondes demandées par la règle, puis passe à « firing ». `docker start app` et elle disparaît.

La configuration de Prometheus (`/etc/prometheus/prometheus.yml`), vos règles et vos tableaux de bord Grafana sont sur des volumes nommés et survivent à l’arrêt du lab puis à son redémarrage. Les mesures ne sont pas enregistrées, un lab redémarré repart donc avec un graphique vide. La configuration n’est écrite qu’au tout premier démarrage : si vous la modifiez, un redémarrage ne la remet pas en place.

## Pour les enseignants

Rien dans ce lab n’est noté automatiquement. L’élève rend des preuves et vous les notez, comme pour n’importe quel autre lab.

**Demandez des preuves en deux volets.** D’abord, la preuve du travail : la règle elle-même, une capture d’écran de celle-ci en état **firing** sur la page Alerts de Prometheus, et un panneau Grafana du même signal. Ensuite, la compréhension : une ou deux phrases sur ce que demande la règle et pourquoi dix secondes, et sur ce que ferait une personne d’astreinte lorsqu’elle se déclenche. Pour un travail plus approfondi, demandez une seconde règle sur un autre signal, comme le taux de requêtes, et une explication de la raison pour laquelle alerter sur un symptôme qu’un utilisateur remarquerait vaut mieux qu’alerter sur chaque chiffre.

**Sa place dans un cursus.** Il convient à une première découverte de la supervision, des métriques, des tableaux de bord et des alertes dans une unité DevOps, exploitation, cloud ou systèmes, ainsi qu’à la notion d’exporter, c’est-à-dire la façon dont on surveille un logiciel qui ne publie aucune métrique. Vérifiez la formulation exacte dans l’unité de votre propre organisme de certification ; aucune n’est citée ici.

**Qui voit quoi.** Une copie est privée pour l’élève qui l’a démarrée. Un membre du personnel qui enseigne le module peut l’ouvrir pour voir ce que l’élève a fait, et l’ouverture du travail d’un élève est inscrite dans le journal d’accès, que l’élève peut lire.

## Ce qui ne fonctionne pas dans un lab

Le lab n’a aucun accès à internet : rien ne peut donc y être téléchargé, le catalogue de plugins et les vérifications de mises à jour de Grafana sont désactivés, et une alerte peut être observée mais envoyée nulle part : il n’y a ni e-mail ni messagerie pour la notifier. Les mesures ne sont pas enregistrées à l’arrêt du lab. `docker exec` dans le service Prometheus est la façon d’écrire une règle, et le terminal du lab sur la plateforme l’autorise ; sur une machine qui ne peut pas offrir la commande `docker` du lab, écrivez la règle avec votre propre Docker.

## Dépannage

- **La page Grafana est blanche juste après Start.** Attendez quelques secondes et appuyez de nouveau sur Open : le lab ne se déclare prêt qu’une fois que Prometheus répond, et Grafana suit.
- **L’alerte n’apparaît jamais après le rechargement.** Un fichier de règles contenant une erreur fait échouer le rechargement : `curl -s -X POST http://prometheus:9090/-/reload` affiche « failed to reload config », et Prometheus conserve les règles qu’il avait avant. La raison figure dans le journal du service (`docker logs prometheus`). Les règles ne sont lues que dans `/etc/prometheus/rules/*.yml`.
- **Sur votre propre machine, le port 9090, 3000 ou 8080 est déjà utilisé.** Changez les numéros de gauche dans `local.yaml` et ouvrez ces ports à la place.

## Vérification du lab

`test/check.sh` démarre le lab comme le fait l’exécuteur de la plateforme pour chaque service (toutes les capacités retirées, `no-new-privileges`, une limite de processus, des limites de mémoire et aucun accès à internet), puis vérifie depuis l’intérieur de son réseau ce que cette page promet : chaque service est sain, Prometheus collecte les données de l’exporter, une requête PromQL répond, Grafana est connecté et sa source de données fonctionne, une règle écrite sur le volume passe à l’état pending, puis firing, puis s’éteint, et la configuration et la règle survivent à un arrêt et à un redémarrage. Il nécessite Docker et s’exécute à chaque push, c’est le badge en haut de la page.

```bash
test/check.sh
```

## Versions et licences

[nginx](https://nginx.org) est sous BSD-2-Clause, l’[exporter NGINX pour Prometheus](https://github.com/nginx/nginx-prometheus-exporter) et [Prometheus](https://github.com/prometheus/prometheus) sous Apache-2.0, et [Grafana](https://github.com/grafana/grafana) sous AGPL-3.0. Ils sont exécutés sans modification à partir de leurs propres images et ne sont pas distribués ici. Les images sont `nginx:1.27-alpine`, `nginx/nginx-prometheus-exporter:1.5.3`, `prom/prometheus:v3.13.4` et `grafana/grafana:13.2.4`.

Le fichier compose, les tests et cette documentation sont les nôtres et relèvent de la [Licence](#licence) ci-dessous. Les applications qu’il contient conservent la licence de leurs propres projets, indiquée plus haut.

## À propos

Réalisé par [Mitsuru Technologies](https://mitsurutech.co.uk) pour la [plateforme d’apprentissage MitsuruTech](https://mitsurutech.co.uk/fr/learning) : Python, Java, Go, Node, SQL et Linux dans le navigateur pour les écoles et les établissements, avec des labs de conteneurs, des applications web déployées depuis GitHub et des quiz qui se corrigent tout seuls. Essayez du code sans compte dans le [bac à sable](https://mitsurutech.co.uk/fr/playground). Le [manuel d’aide](https://mitsurutech.co.uk/fr/help/labs) liste tous les labs.

D’autres labs du même éditeur : [lab-juice-shop](https://github.com/mitsurutech/lab-juice-shop), [lab-dvwa](https://github.com/mitsurutech/lab-dvwa), [lab-webgoat](https://github.com/mitsurutech/lab-webgoat), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) et [lab-sample](https://github.com/mitsurutech/lab-sample).

## Licence

Cette œuvre est sous licence [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Vous pouvez la partager et l’adapter pour apprendre et enseigner, à condition de citer Mitsuru Technologies Ltd, de ne pas l’utiliser commercialement et de partager tout ce que vous en tirez sous la même licence. Le texte complet est dans le fichier `LICENSE`.
