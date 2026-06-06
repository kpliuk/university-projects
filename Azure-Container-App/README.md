# Skuska - webova aplikacia v Azure

Projekt nasadzuje jednoduchu aplikaciu `Skuska Guestbook` do verejneho klaudu Microsoft Azure. Pouzivatel zada meno a kratku spravu, frontend ju odosle na backend API a backend ju ulozi do PostgreSQL databazy. Ulozene zaznamy sa zobrazia naspat v prehliadaci spolu s poctom zaznamov a stavom backendu/databazy.

## Pouzite cloudove sluzby

- Azure Container Apps - spustenie aplikacie s verejnym HTTPS endpointom.
- Azure Container Registry - ulozenie Docker obrazov frontendu a backendu.
- Azure Storage Account a Azure Files - trvaly zvazok pripojeny do `postgres` kontajnera na `/backup` pre SQL zalohy PostgreSQL.
- Azure Resource Group - spolocna skupina vsetkych zdrojov, aby sa aplikacia dala jednoducho odstranit.

Nasadenie pouziva jeden Container Apps Environment a jednu Container App s tromi kontajnermi. Azure Container Apps zabezpecuje HTTPS ingress, automaticke restartovanie kontajnerov a zobrazenie logov cez Azure CLI.

## Komponenty aplikacie

- `frontend` - Nginx kontajner so statickym HTML/CSS/JavaScript rozhranim a proxy `/api/*` na backend.
- `backend` - Node.js/Express API, ktore poskytuje endpointy `/save`, `/entries`, `/status`, `/ready` a `/health`.
- `postgres` - PostgreSQL kontajner s automatickym SQL backupom do Azure Files volume `/backup`.

Vsetky tri kontajnery bezia v jednej Container App, preto medzi sebou komunikuju cez `localhost` a interne porty. Verejne dostupny je iba frontend na HTTPS. Frontend posiela API poziadavky na `/api/*`, Nginx ich presmeruje na backend a backend zapisuje guestbook zaznamy do PostgreSQL.

PostgreSQL data directory nie je priamo ulozeny na Azure Files, pretoze PostgreSQL vyzaduje Unix permissions, ktore Azure Files cez SMB nepodporuje spolahlivo. Azure Files sa preto pouziva ako trvaly backup volume `/backup`. Postgres kontajner automaticky vytvara `pg_dump` backup do suboru `/backup/latest.sql` a pri novom starte ho pouzije na obnovu databazy. Takto data preziju restart alebo znovuvytvorenie kontajnera.

## Odovzdane subory

- `prepare-app.sh` - vytvori Azure resource group, ACR, Storage Account, Azure Files share, Container Apps Environment a jednu Container App s tromi kontajnermi.
- `remove-app.sh` - odstrani celu Azure resource group so vsetkymi zdrojmi aplikacie.
- `backup-db.sh` - stiahne aktualny SQL backup PostgreSQL databazy z Azure Files.
- `logs-app.sh` - zobrazi posledne logy kontajnerov `frontend`, `backend` a `postgres`.
- `start-app.sh` - zapne verejny ingress a nastavi minimalny pocet replik aplikacie na 1.
- `stop-app.sh` - vytvori finalny backup, vypne verejny ingress a nastavi minimalny pocet replik na 0.
- `backend/server.js` - zdrojovy kod backend API.
- `backend/Dockerfile` - Docker obraz backendu.
- `frontend/index.html` - zdrojovy kod frontend rozhrania.
- `frontend/nginx.conf` - Nginx konfiguracia, ktora proxyuje `/api/*` na backend kontajner.
- `frontend/Dockerfile` - Docker obraz frontendu.
- `.gitignore` - ignoruje lokalne secrets a backupy.

## Konfiguracia

Cloud konfiguracia je nastavitelna cez premenne prostredia:

- `APP_PREFIX` - prefix nazvov zdrojov, predvolene `skuska`.
- `LOCATION` - Azure region, predvolene `norwayeast`.
- `RESOURCE_GROUP` - nazov resource group, predvolene `skuska-rg`.
- `CONTAINER_ENV` - nazov Container Apps Environment, predvolene `skuska-env`.
- `CONTAINER_ENV_RESOURCE_GROUP` - resource group existujuceho environmentu, ak sa pouziva uz vytvoreny environment.
- `APP_NAME` - nazov Container App, predvolene `skuska-app`.
- `ALLOWED_LOCATIONS` - zoznam regionov povolenych politikou subscription, predvolene `norwayeast`.
- `DB_NAME` - nazov databazy, predvolene `appdb`.
- `DB_USER` - PostgreSQL pouzivatel, predvolene `appuser`.
- `DB_PASSWORD` - heslo databazy. Ak nie je nastavene, skript ho vygeneruje.

Skript ulozi lokalne nasadzovacie hodnoty do `.skuska.env`. Tento subor obsahuje citlive udaje a nesmie byt odovzdany do GITu.

## Spustenie v Azure

Podmienky spustenia:

- aktivne Azure konto a subscription;
- nainstalovany Azure CLI;
- nainstalovany Docker;
- prihlasenie cez `az login`;
- shell prostredie Bash.

Prikazy:

```bash
chmod +x prepare-app.sh remove-app.sh backup-db.sh logs-app.sh
az login
./prepare-app.sh
```

Ak uz v subscription existuje Container Apps Environment a dalsi sa neda vytvorit, pouzite existujuci:

```bash
az containerapp env list -o table
CONTAINER_ENV=nazov-env CONTAINER_ENV_RESOURCE_GROUP=resource-group-env ./prepare-app.sh
```

Na konci skript vypise verejnu HTTPS adresu aplikacie, napriklad:

```text
URL: https://skuska-app.example.azurecontainerapps.io
```

Tuto URL treba otvorit vo webovom prehliadaci.

## Funkcie aplikacie

- pridanie guestbook zaznamu s menom a spravou;
- zobrazenie zoznamu ulozenych zaznamov;
- pocitadlo ulozenych zaznamov;
- indikacia stavu backendu a databazy;
- manualne obnovenie zoznamu;
- vymazanie jedneho zaznamu;
- vymazanie vsetkych zaznamov.

## Odstranenie aplikacie

Po skuske je potrebne odstranit zdroje, aby nevznikali dalsie naklady:

```bash
./remove-app.sh
```

Skript sa najprv pokusi vytvorit finalny backup databazy cez `backup-db.sh` a potom odstrani celu Azure resource group, ktora bola vytvorena pre aplikaciu.

## Spustenie a pozastavenie

Aplikaciu je mozne pozastavit bez odstranenia zdrojov:

```bash
./stop-app.sh
```

Skript pred pozastavenim vytvori finalny backup databazy, vypne verejny ingress a nastavi minimalny pocet replik na 0. Aplikaciu je mozne znova zapnut:

```bash
./start-app.sh
```

## Zaloha dat

Manualny SQL backup databazy:

```bash
./backup-db.sh
```

PostgreSQL kontajner automaticky aktualizuje subor `latest.sql` na Azure Files. Skript `backup-db.sh` tento subor stiahne lokalne ako `backup-appdb-DATUM.sql`. Tento subor sa neodosiela do GITu.

## Logy a pristupy z internetu

Logy kontajnerov:

```bash
./logs-app.sh
```

Pristupy z internetu su v logoch kontajnera `frontend`, pretoze Nginx prijima verejne HTTPS poziadavky cez Azure Container Apps ingress.


- Generativny model (GPT 5-5) bol pouzity na upravu skriptov, kontrolu poziadaviek a pripravu dokumentacie.
