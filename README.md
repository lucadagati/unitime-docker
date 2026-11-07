# UniTime in Docker

Single-container deployment of **[UniTime](https://www.unitime.org/)** 4.8 (university course and exam timetabling web application) on Apache Tomcat 9.0.82 with a local MySQL database. Intended for demos, teaching and evaluation, **not for production**.

*Versione italiana in fondo.*

## Table of contents

1. [What it is and why it exists](#1-what-it-is-and-why-it-exists)
2. [Architecture](#2-architecture)
3. [Requirements](#3-requirements)
4. [Installation (build and run)](#4-installation-build-and-run)
5. [Configuration](#5-configuration)
6. [Usage and expected output](#6-usage-and-expected-output)
7. [Repository layout](#7-repository-layout)
8. [Testing and verification](#8-testing-and-verification)
9. [Troubleshooting](#9-troubleshooting)
10. [Known limitations and security notes](#10-known-limitations-and-security-notes)
11. [Extending](#11-extending)
12. [Italiano](#12-italiano)

## 1. What it is and why it exists

UniTime is an open-source (Apache 2.0) comprehensive timetabling system. Installing it by hand requires a JDK, Tomcat, MySQL, a schema, sample data and the right JDBC settings. This repository packages all of that so that a working instance, loaded with UniTime's demo "woebegon" data set, comes up with two commands. The UniTime web application is already unpacked inside `apache-tomcat-9.0.82/webapps/UniTime`, so the build needs no download of UniTime itself.

## 2. Architecture

```
 docker run -p 8080:8080
        |
 +------v---------------------------------------------------+
 | Container (ubuntu:22.04, OpenJDK 11)                       |
 |  /entrypoint.sh                                            |
 |    1. service mysql start     (mysqld as user mysql)       |
 |    2. su tomcat -> catalina.sh run (java as user tomcat)   |
 |                                                            |
 |  Tomcat 9.0.82 :8080  --JDBC--> MySQL :3306 (localhost)    |
 |  webapps/UniTime                 database "timetable"      |
 |  (UniTime 4.8)                   user timetable / unitime  |
 +------------------------------------------------------------+
```

At image build time MySQL is started once and `schema.sql`, `blank-data.sql` and `woebegon-data.sql` are loaded, so the data is baked into the image. `schema.sql` itself creates the database `timetable` and the MySQL user `timetable@localhost`.

## 3. Requirements

| Item | Version |
|---|---|
| Docker Engine | any recent version with BuildKit or the classic builder (verified here with the Docker available on the host) |
| Network at build time | needed for `apt-get` (ubuntu:22.04 base, `mysql-server`, `openjdk-11-jdk-headless`) |
| Disk | roughly 1.5 GB for the image |
| RAM | JVM max heap is 2 GB (`-Xmx2048m`) plus MySQL; give the container at least 3 GB |
| Free host port | 8080 (or choose another with `-p`) |

## 4. Installation (build and run)

```bash
git clone git@github.com:lucadagati/unitime-docker.git
cd unitime-docker
docker build -t unitime:latest .          # about 3 minutes on a fast connection
docker run -d --name unitime_container -p 8080:8080 unitime:latest
docker logs -f unitime_container          # wait for "Server startup in [...] milliseconds"
```

To keep the data across container re-creations, mount a volume on `/var/lib/mysql` (an empty named volume is seeded from the image content):

```bash
docker run -d --name unitime_container -p 8080:8080 -v unitime-mysql:/var/lib/mysql unitime:latest
```

Stop and remove: `docker stop unitime_container && docker rm unitime_container`.

## 5. Configuration

| Setting | Where | Value |
|---|---|---|
| Published port | `docker run -p HOST:8080` | 8080 in the container (`EXPOSE 8080`) |
| JVM options | `ENV JAVA_OPTS` in `Dockerfile` (override with `docker run -e JAVA_OPTS=...`) | `-Djava.awt.headless=true -Xmx2048m -XX:+UseG1GC` |
| `JAVA_HOME` | `Dockerfile` | `/usr/lib/jvm/java-11-openjdk-amd64/` |
| `CATALINA_HOME` | `Dockerfile` | `/usr/local/tomcat` |
| JDBC URL | `apache-tomcat-9.0.82/webapps/UniTime/WEB-INF/classes/custom.properties` | `jdbc:mysql://localhost:3306/timetable?serverTimezone=Europe/Prague` |
| DB user / password | same file; created by `schema.sql` | `timetable` / `unitime` (only reachable from `localhost` inside the container) |
| DB root account | MySQL inside container | no password, local socket only |
| Timezone | JDBC URL `serverTimezone` | `Europe/Prague`; edit `custom.properties` and rebuild if needed |
| Tomcat users | `conf/tomcat-users.xml` | all users commented out; the stock manager/examples/docs webapps are removed |

Changes to `custom.properties` require a rebuild (the Tomcat directory is copied into the image).

## 6. Usage and expected output

Open <http://localhost:8080/UniTime>. The page title is "UniTime 4.8 | University Timetabling Application". The demo data set ships an `admin` account with password `admin` (see `unitime-4.8/doc/mysql/blank-data.sql`); **change it immediately**. Interactive login was not exercised in this verification, only that the application starts and serves the page.

Tail of a healthy start log:

```
INFO  AbstractSolverServer> Solver server is up and running.
INFO  ContextLoader> Root WebApplicationContext initialized in 23906 ms
org.apache.catalina.startup.HostConfig.deployDirectory Deployment of web application directory [/usr/local/tomcat/webapps/UniTime] has finished in [26,446] ms
org.apache.catalina.startup.Catalina.start Server startup in [26506] milliseconds
```

Startup takes roughly 30 seconds; `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/UniTime/` then returns `200`.

Inspect the database from the host:

```bash
docker exec unitime_container mysql -uroot -e "show databases; select count(*) from timetable.timetable_manager;"
```

Expected: databases `information_schema, mysql, performance_schema, sys, timetable, unitime` and 7 timetable managers.

## 7. Repository layout

| Path | Purpose |
|---|---|
| `Dockerfile` | Ubuntu 22.04, OpenJDK 11, MySQL; loads the SQL scripts; copies Tomcat; creates the non-root `tomcat` user |
| `entrypoint.sh` | starts MySQL (aborts if it fails), then runs Tomcat in the foreground as user `tomcat` |
| `apache-tomcat-9.0.82/` | Tomcat with the UniTime webapp in `webapps/UniTime` (UniTime configuration in `WEB-INF/classes/custom.properties`); `logs/`, `work/`, `temp/` are git-ignored |
| `unitime-4.8/doc/mysql/` | `schema.sql`, `blank-data.sql`, `woebegon-data.sql` loaded at build time |
| `unitime-4.8/doc/` | UniTime license, notice and readme |
| `.gitignore` | ignores `.env`, logs and Tomcat runtime directories |

Note: the Dockerfile also runs `CREATE DATABASE unitime;`, which is an empty leftover database; the application uses `timetable`.

## 8. Testing and verification

Verified in this environment: `docker build` succeeded; a container started from the image brought MySQL and Tomcat up (processes `mysqld` as `mysql`, `java` as `tomcat`), UniTime logged "Solver server is up and running", `GET /UniTime/` and `/UniTime/login.action` returned HTTP 200, and the page title was `UniTime 4.8`. The test image and container were removed afterwards.

Not verified: logging in, running a solver, and the volume persistence procedure.

## 9. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Connection refused for the first ~30 s | Tomcat is still deploying UniTime; follow `docker logs -f`. |
| `Failed to start MySQL: <code>` in the log and the container exits | MySQL could not start (corrupted or wrongly-owned mounted `/var/lib/mysql`). Use a fresh named volume. |
| Port already allocated | Another service uses 8080: use `-p 8081:8080`. |
| Out of memory / container killed | The JVM is allowed 2 GB: increase the container memory or lower `-Xmx` via `-e JAVA_OPTS=...`. |
| Wrong dates/time offsets | JDBC `serverTimezone=Europe/Prague`; change in `custom.properties` and rebuild. |
| Log warning "includeJars pattern ... did not match any jars" | Harmless Struts scanning warning seen in a normal start. |

## 10. Known limitations and security notes

- Not production grade: everything runs as one container with a bundled MySQL, no TLS, no backups.
- Default credentials: UniTime `admin`/`admin`, MySQL `timetable`/`unitime`, MySQL root without password. Do not expose the container to untrusted networks and do not publish port 3306.
- Data lives in the container layer unless a volume is mounted on `/var/lib/mysql`.
- The image bundles UniTime 4.8 and Tomcat 9.0.82 as committed; there is no automated update of either.
- Base image `ubuntu:22.04` is pinned by tag, not by digest.

## 11. Extending

- **Different UniTime version or your own data**: replace `webapps/UniTime` and the SQL files in `unitime-4.8/doc/mysql/` (the Dockerfile loads `schema.sql`, `blank-data.sql`, `woebegon-data.sql` in this order; drop the last for an empty installation).
- **External MySQL**: change `connection.url`, `connection.username`, `connection.password` in `custom.properties` and remove the MySQL startup from `entrypoint.sh`.
- **Different Tomcat JVM options**: `docker run -e JAVA_OPTS="..."`.

## 12. Italiano

Questo repository contiene un `Dockerfile` e uno script di avvio per eseguire UniTime 4.8 (gestione di orari e esami universitari) con Tomcat 9.0.82 e MySQL in un unico container, con i dati demo "woebegon" già caricati. Non è pensato per la produzione.

```bash
docker build -t unitime:latest .
docker run -d --name unitime_container -p 8080:8080 unitime:latest
docker logs -f unitime_container   # attendere "Server startup in [...] milliseconds" (circa 30 secondi)
```

- L'applicazione è su `http://localhost:8080/UniTime`; credenziali demo `admin` / `admin` (da cambiare subito).
- Il database si chiama `timetable` (utente `timetable`, password `unitime`, raggiungibile solo da localhost nel container); la configurazione JDBC è in `apache-tomcat-9.0.82/webapps/UniTime/WEB-INF/classes/custom.properties` e richiede un rebuild se modificata.
- Persistenza: `-v unitime-mysql:/var/lib/mysql`. Senza volume i dati restano nel container.
- Verificato: build, avvio di MySQL e Tomcat, risposta HTTP 200 su `/UniTime/`. Non verificati: login e solver.
- Sicurezza: nessuna password per root MySQL, nessun TLS: non esporre il container su reti non fidate e non pubblicare la porta 3306.
