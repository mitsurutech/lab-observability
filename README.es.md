# Laboratorio de observabilidad con Prometheus y Grafana en Docker Compose: escribe una regla de alerta en una copia privada

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md)

[![check](https://github.com/mitsurutech/lab-observability/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-observability/actions/workflows/check.yml)

Un **laboratorio de monitorización y observabilidad** listo para usar en el aula, de la [plataforma de aprendizaje MitsuruTech](https://mitsurutech.co.uk/es/learning), donde los centros dan a cada alumno sus propias bases de datos, contenedores y terminal en el navegador. Cada alumno recibe su propia copia de un pequeño servidor web que vigilar, con **Prometheus** recogiendo sus métricas y **Grafana** dibujándolas, ya conectados entre sí. Después **escribe una regla de alerta** en Prometheus, rompe el servidor a propósito y ve cómo la alerta pasa de «pending» a «firing». Es adecuado para una primera introducción a la monitorización, PromQL, los paneles y las alertas en una unidad de DevOps, operaciones o nube, sin instalar nada y sin riesgo para el equipo de nadie.

Es un solo archivo `docker-compose`, `compose.yaml`, y funciona igual en tu propio equipo que en la plataforma, donde cada alumno tiene una copia privada sin salida a internet.

## Qué incluye

| Servicio | Imagen | Memoria | Qué es |
| --- | --- | --- | --- |
| `app` | [`nginx:1.27-alpine`](https://hub.docker.com/_/nginx) | 64 MB | el servidor web que vigilar, ejecutado con una cuenta sin privilegios (101), con su página de estado en un puerto propio |
| `exporter` | [`nginx/nginx-prometheus-exporter:1.5.3`](https://hub.docker.com/r/nginx/nginx-prometheus-exporter) | 32 MB | lee la página de estado y la publica como métricas de Prometheus, como `nginx_up` y `nginx_http_requests_total` |
| `prometheus` | [`prom/prometheus:v3.13.4`](https://hub.docker.com/r/prom/prometheus) | 256 MB | recoge las métricas cada cinco segundos, responde a consultas en PromQL y lee las reglas de alerta |
| `grafana` | [`grafana/grafana:13.2.4`](https://hub.docker.com/r/grafana/grafana) | 512 MB | las dibuja, con la sesión iniciada como la única persona que usa la copia y ya conectado a Prometheus |

Son 864 MB de límites. En reposo, una copia usa unos 280 MB, casi todos de Grafana, y está lista en menos de veinte segundos desde que arranca. El primer arranque descarga las imágenes, siendo la de Grafana la más grande.

Las imágenes son programas de terceros, ejecutados sin modificar a partir de las imágenes públicas de los propios proyectos y fijadas a una versión (nunca `latest`), de modo que el laboratorio no cambia a mitad de curso entre una lección y la siguiente. Aquí no se construye nada y nada de este repositorio se distribuye dentro de ellas. La configuración que necesita cada una la escribe su propio punto de entrada a partir del archivo compose, así que no hay nada más que descargar.

## Usarlo en la plataforma

La [plataforma de aprendizaje MitsuruTech](https://mitsurutech.co.uk/es/learning) da a cada alumno su propia copia de un laboratorio, en el navegador, con una terminal al lado.

**Para probarlo:** abre la [página de contenedores](https://mitsurutech.co.uk/es/container), busca este laboratorio en **Sample labs** y pulsa Start. No hace falta una cuenta para probar uno. La página del manual dedicada a él es [Observability lab](https://mitsurutech.co.uk/es/help/lab-observability), y la lección **Observability Basics** lo recorre paso a paso.

**Para asignarlo como trabajo a una clase:**

1. En tu módulo, crea una tarea de tipo **Lab** y elige **In a GitHub repository**.
2. Indica `https://github.com/mitsurutech/lab-observability` con la rama `main`. El archivo compose es el predeterminado, `compose.yaml`. Haz antes un fork del repositorio si quieres cambiar el archivo.
3. Publica. La copia de cada alumno parte del commit que publicaste, así que un cambio posterior aquí no altera un laboratorio ya asignado.
4. Di en la tarea qué hay que entregar (consulta [Para el profesorado](#para-el-profesorado)) y asígnala como cualquier otra tarea.

La [guía de laboratorios de contenedores](https://mitsurutech.co.uk/es/help/labs) del manual cubre el resto: qué puede decir un archivo compose, cuánta memoria recibe una copia y cómo abre, observa y califica un profesor la copia de un alumno.

¿Todavía no tienes una cuenta para tu centro? [Tu primer año es gratuito](https://mitsurutech.co.uk/es/pricing) hasta 50 alumnos, y [crear una cuenta](https://mitsurutech.co.uk/es/signup) solo requiere una dirección de correo electrónico.

## Ejecutarlo en tu propio equipo

Necesitas Docker con el plugin Compose. El primer arranque descarga las imágenes.

```bash
docker compose -f compose.yaml -f local.yaml up
```

Abre <http://localhost:9090> para Prometheus y <http://localhost:3000> para Grafana, que no pide iniciar sesión. El propio servidor web está en <http://localhost:8080>.

`local.yaml` publica los puertos solo en `127.0.0.1`, de modo que el laboratorio es accesible desde tu propio ordenador y desde ningún otro sitio. Detenlo con `Ctrl-C` y elimínalo, volúmenes incluidos, con `docker compose -f compose.yaml -f local.yaml down -v`.

## Paso a paso

1. **Hazle una pregunta a Prometheus.** En Prometheus, ejecuta `nginx_up` y después `rate(nginx_http_requests_total[1m])`. Desde una terminal en la red del laboratorio, la misma pregunta es `curl 'http://prometheus:9090/api/v1/query?query=nginx_up'`.
2. **Genera tráfico.** `curl "http://app:8080/?n=[1-300]"` envía trescientas peticiones con un solo comando, y la tasa sube.
3. **Dibújalo.** En Grafana, abre **Explore** (o crea un panel), elige el origen de datos **Prometheus**, que ya está ahí, y ejecuta la misma consulta.
4. **Escribe una regla de alerta.** Coloca un archivo `.yml` en `/etc/prometheus/rules/` del servicio `prometheus`, con `docker exec` (o `docker compose exec` en tu propio equipo), por ejemplo una regla cuya `expr` sea `nginx_up == 0` y cuyo `for` sea `10s`. Luego recarga Prometheus con `curl -X POST http://prometheus:9090/-/reload` y mira **Alerts**.
5. **Haz que salte.** `docker stop app` detiene el servidor. La alerta queda pendiente durante los diez segundos que pedía la regla y después pasa a «firing». Con `docker start app` se apaga.

La configuración de Prometheus (`/etc/prometheus/prometheus.yml`), tus reglas y tus paneles de Grafana están en volúmenes con nombre y sobreviven a detener el laboratorio y volver a arrancarlo. Las mediciones no se guardan, así que un laboratorio reiniciado empieza con el gráfico vacío. La configuración se escribe solo en el primer arranque: si la cambias, un reinicio no la repone.

## Para el profesorado

Nada de este laboratorio se califica automáticamente. El alumno entrega pruebas y tú las calificas, como cualquier otro laboratorio.

**Pide pruebas en dos mitades.** Primero, la prueba del trabajo: la propia regla, una captura de pantalla de ella en estado **firing** en la página Alerts de Prometheus y un panel de Grafana de la misma señal. Segundo, la comprensión: una o dos frases sobre qué pregunta la regla y por qué diez segundos, y qué haría una persona de guardia cuando saltara. Para un trabajo más sólido, pide una segunda regla sobre otra señal, como la tasa de peticiones, y una explicación de por qué alertar sobre un síntoma que notaría un usuario es mejor que alertar sobre cada cifra.

**Dónde encaja en un curso.** Es adecuado para una primera mirada a la monitorización, las métricas, los paneles y las alertas en una unidad de DevOps, operaciones, nube o sistemas, y a la idea de exporter, que es cómo se vigila el software que no publica métricas. Comprueba la redacción exacta en la unidad de tu propio organismo certificador; aquí no se cita ninguna.

**Quién ve qué.** Una copia es privada para el alumno que la arrancó. Un miembro del personal que imparte el módulo puede abrirla para ver lo que ha hecho el alumno, y abrir el trabajo de un alumno queda registrado en el registro de accesos, que el alumno puede leer.

## Qué no funciona en un laboratorio

El laboratorio no tiene salida a internet, así que no se puede descargar nada en él, el catálogo de plugins de Grafana y las comprobaciones de actualizaciones están desactivados, y una alerta se puede observar pero no enviar a ningún sitio: no hay correo ni chat al que notificar. Las mediciones no se guardan cuando el laboratorio se detiene. `docker exec` en el servicio Prometheus es la forma de escribir una regla, y la terminal del laboratorio en la plataforma lo permite; en un equipo que no pueda ofrecer el comando `docker` del laboratorio, escribe la regla con tu propio Docker.

## Solución de problemas

- **La página de Grafana aparece en blanco justo después de Start.** Espera unos segundos y pulsa Open de nuevo: el laboratorio se declara listo solo cuando Prometheus responde, y Grafana lo sigue.
- **La alerta nunca aparece tras la recarga.** Un archivo de reglas con un error hace que la recarga falle: `curl -s -X POST http://prometheus:9090/-/reload` imprime «failed to reload config», y Prometheus conserva las reglas que tenía antes. El motivo está en el registro del servicio (`docker logs prometheus`). Las reglas se leen solo de `/etc/prometheus/rules/*.yml`.
- **En tu propio equipo, el puerto 9090, 3000 u 8080 ya está en uso.** Cambia los números de la izquierda en `local.yaml` y abre esos puertos en su lugar.

## Comprobación del laboratorio

`test/check.sh` arranca el laboratorio como el ejecutor de la plataforma arranca cada servicio (todas las capacidades eliminadas, `no-new-privileges`, un límite de procesos, límites de memoria y sin salida a internet) y después comprueba desde dentro de su red lo que promete esta página: cada servicio está sano, Prometheus recoge las métricas del exporter, una consulta PromQL responde, Grafana tiene la sesión iniciada y su origen de datos funciona, una regla escrita en el volumen pasa a pending, luego a firing y luego se apaga, y la configuración y la regla sobreviven a una parada y un arranque. Necesita Docker y se ejecuta en cada push, que es la insignia de arriba.

```bash
test/check.sh
```

## Versiones y licencias

[nginx](https://nginx.org) es BSD-2-Clause, el [exporter de NGINX para Prometheus](https://github.com/nginx/nginx-prometheus-exporter) y [Prometheus](https://github.com/prometheus/prometheus) son Apache-2.0, y [Grafana](https://github.com/grafana/grafana) es AGPL-3.0. Se ejecutan sin modificar a partir de sus propias imágenes y no se distribuyen aquí. Las imágenes son `nginx:1.27-alpine`, `nginx/nginx-prometheus-exporter:1.5.3`, `prom/prometheus:v3.13.4` y `grafana/grafana:13.2.4`.

El archivo compose, las pruebas y esta documentación son nuestros y los cubre la [Licencia](#licencia) de abajo. Las aplicaciones que contiene conservan la licencia de sus propios proyectos, enlazados arriba.

## Acerca de

Creado por [Mitsuru Technologies](https://mitsurutech.co.uk) para la [plataforma de aprendizaje MitsuruTech](https://mitsurutech.co.uk/es/learning): Python, Java, Go, Node, SQL y Linux en el navegador para colegios y centros, con laboratorios de contenedores, aplicaciones web desplegadas desde GitHub y cuestionarios que se califican solos. Prueba código sin cuenta en el [entorno de pruebas](https://mitsurutech.co.uk/es/playground). El [manual de ayuda](https://mitsurutech.co.uk/es/help/labs) enumera todos los laboratorios.

Más laboratorios del mismo autor: [lab-juice-shop](https://github.com/mitsurutech/lab-juice-shop), [lab-dvwa](https://github.com/mitsurutech/lab-dvwa), [lab-webgoat](https://github.com/mitsurutech/lab-webgoat), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) y [lab-sample](https://github.com/mitsurutech/lab-sample).

## Licencia

Esta obra está bajo licencia [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). Puedes compartirla y adaptarla para aprender y enseñar, si citas a Mitsuru Technologies Ltd, no la usas comercialmente y compartes lo que hagas con ella bajo la misma licencia. El texto completo está en el archivo `LICENSE`.
