# Zadanie 1

## Opis aplikacie

Tato aplikacia je jednoducha webova aplikacia nasadena pomocou Docker Compose. Umoznuje zapisat meno cez webove rozhranie do databazy PostgreSQL a nasledne zobrazit zoznam ulozenych zaznamov. Aplikacia obsahuje frontend, backend, databazu a webove rozhranie Adminer na pracu s databazou.

## Potrebny software

- Linux
- Docker
- Docker Compose plugin (`docker compose`)

## Pouzite kontajnery

- `nginx:latest` - webovy server pre staticke subory frontendu
- `node:18` - backend aplikacie postaveny zo suboru `backend/Dockerfile`
- `postgres:15` - relacna databaza PostgreSQL
- `adminer` - webove rozhranie na pracu s databazou

## Siete a zvazky

Docker Compose vytvori predvolenu virtualnu siet, v ktorej spolu komunikujú sluzby:

- `web`
- `backend`
- `db`
- `adminer`

Pouzity pomenovany trvaly zvazok:

- `db_data` - uklada databazove data PostgreSQL, aby zostali zachovane aj po zastaveni aplikacie

## Konfiguracia kontajnerov

- `web` bezi v kontajneri s Nginx a spristupnuje frontend na porte `8080`
- `backend` bezi v Node.js kontajneri a je dostupny na porte `5000`
- `db` bezi ako PostgreSQL databaza s premennymi `POSTGRES_USER`, `POSTGRES_PASSWORD` a `POSTGRES_DB`
- `adminer` je dostupny na porte `8081`
- vsetky sluzby maju nastavene `restart: always`
- backend zavisi od databazy a Adminer zavisi od databazy

## Navod na pouzitie

Priecinok projektu:

```bash
cd z1
```

Spustenie aplikacie:

```bash
./start-app.sh
```

Zastavenie aplikacie:

```bash
./stop-app.sh
```

Alternativne je mozne aplikaciu spustit aj priamo cez Docker Compose:

```bash
docker compose up -d
```

## Pristup cez webovy prehliadac

- Hlavna aplikacia: `http://localhost:8080`
- Backend API: `http://localhost:5000`
- Adminer: `http://localhost:8081`

Prihlasovacie udaje do PostgreSQL:

- system: `PostgreSQL`
- server: `db`
- username: `user`
- password: `password`
- database: `mydb`

## Priklad prace s aplikaciou

1. Otvorte `http://localhost:8080`
2. Zadajte meno do formulara
3. Kliknite na tlacidlo `Save & Show`
4. Udaj sa ulozi do databazy a zobrazi v zozname

## Zdroje

- Docker dokumentacia
- Docker Compose dokumentacia
- Nginx oficialny image na Docker Hub
- Node.js oficialny image na Docker Hub
- PostgreSQL oficialny image na Docker Hub
- Adminer oficialny image na Docker Hub

## Pouzitie umelej inteligencie

Pri priprave dokumentacie a pomocnych skriptov bola pouzita umele inteligencia vo forme AI agenta Codex.
