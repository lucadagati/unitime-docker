# UniTime in Docker

Single-container deployment of **[UniTime](https://www.unitime.org/)** (university course/exam timetabling web application) on Apache Tomcat 9 with a local MySQL database. Useful for demos, teaching and evaluation — not a production setup.

*Versione italiana in fondo.*

## Contents

| Path | Purpose |
|---|---|
| `Dockerfile` | Ubuntu 22.04 + OpenJDK 11 + MySQL; initialises the database from the UniTime SQL scripts |
| `entrypoint.sh` | starts MySQL, then Tomcat as the unprivileged `tomcat` user |
| `apache-tomcat-9.0.82/` | Tomcat with the UniTime web application already deployed in `webapps/UniTime` (stock docs/examples/manager apps removed) |
| `unitime-4.8/doc/mysql/` | schema, blank data and demo ("woebegon") data loaded at build time |

## Build and run

```bash
docker build -t unitime:latest .
docker run -d --name unitime_container -p 8080:8080 unitime:latest
docker logs -f unitime_container      # wait until the database update has finished
```

Open <http://localhost:8080/UniTime>. Demo login: `admin` / `admin` (from the sample data) — **change it immediately** and do not expose the container to untrusted networks.

## Notes

- The MySQL root account has no password inside the container and the database is not exposed; do not publish port 3306.
- UniTime's database settings live in `apache-tomcat-9.0.82/webapps/UniTime/WEB-INF/classes/custom.properties`.
- Data is stored inside the container; mount a volume on `/var/lib/mysql` to persist it.

## Italiano

Questo repository contiene un `Dockerfile` e uno script di avvio per eseguire UniTime (gestione di orari e esami universitari) con Tomcat 9 e MySQL in un unico container.

```bash
docker build -t unitime:latest .
docker run -d --name unitime_container -p 8080:8080 unitime:latest
docker logs -f unitime_container   # attendere il termine dell'aggiornamento del database
```

L'applicazione è raggiungibile su `http://localhost:8080/UniTime`; credenziali demo `admin` / `admin` (da cambiare subito). Per rendere persistenti i dati montare un volume su `/var/lib/mysql`.
