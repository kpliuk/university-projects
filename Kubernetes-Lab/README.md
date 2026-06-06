# Zadanie 2 - webova aplikacia v Kubernetes

Tento projekt nasadzuje jednoduchu webovu aplikaciu do Kubernetes. Pouzivatel zada meno v prehliadaci, frontend ho odosle backend API a backend ulozi hodnotu do PostgreSQL. Ulozene mena sa potom znova zobrazia v prehliadaci.

## Pouzite kontajnery

- `z2-frontend:latest` - vlastny obraz Nginx, ktory obsluhuje staticky frontend a proxyuje API poziadavky na backendovu sluzbu.
- `z2-backend:latest` - vlastny obraz Node.js a Express API, ktory uklada a cita pouzivatelske udaje z PostgreSQL.
- `postgres:15-alpine` - databazovy kontajner bezici v StatefulSete s trvalym uloziskom.

## Objekty Kubernetes

- `Namespace zkt26-z2` - oddeluje vsetky prostriedky aplikacie do jedneho namespace.
- `Deployment backend-deployment` - spusta backend API kontajner.
- `Deployment frontend-deployment` - spusta frontendovy Nginx kontajner.
- `Service backend-service` - spristupnuje backend vo vnutri klastra.
- `Service frontend-service` - spristupnuje frontend cez NodePort `30080`.
- `Service postgres-service` - stabilny sietovy endpoint pre PostgreSQL.
- `PersistentVolume postgres-pv` - hostitelske ulozisko pre data PostgreSQL.
- `PersistentVolumeClaim postgres-pvc` - pripaja ulozisko pre databazovy pod.
- `StatefulSet postgres-statefulset` - spusta PostgreSQL s trvalymi datami.

## Siete a zvazky

Aplikacia pouziva predvolene sietovanie klastra Kubernetes. Pody medzi sebou komunikuju cez Kubernetes sluzby:

- `frontend-service` pre pristup z prehliadaca
- `backend-service` pre komunikaciu frontendu s backendom
- `postgres-service` pre komunikaciu backendu s databazou

Trvale data sa ukladaju pomocou:

- `PersistentVolume postgres-pv`
- `PersistentVolumeClaim postgres-pvc`

Zvazok pouziva `hostPath` na adrese `/tmp/zkt26-postgres-data`, takze data databazy ostanu dostupne aj po restarte podu.

## Konfiguracia kontajnerov

Frontendovy kontajner je zalozeny na Nginx a obsahuje vlastny `nginx.conf`, ktory proxyuje poziadavky `/api/*` na backendovu sluzbu.

Backendovy kontajner pouziva pre pripojenie k databaze tieto premenne prostredia:

- `DB_HOST=postgres-service`
- `DB_PORT=5432`
- `DB_USER=user`
- `DB_PASSWORD=password`
- `DB_NAME=mydb`

PostgreSQL kontajner je nakonfigurovany takto:

- `POSTGRES_USER=user`
- `POSTGRES_PASSWORD=password`
- `POSTGRES_DB=mydb`

## Ako aplikaciu pripravit, spustit, zastavit a odstranit

Prikazy spustite z adresara `z2`:

```bash
chmod +x prepare-app.sh start-app.sh stop-app.sh remove-app.sh
./prepare-app.sh
./start-app.sh
```

Na zastavenie aplikacie pouzite:

```bash
./stop-app.sh
```

Na uplne odstranenie aplikacie pouzite:

```bash
./remove-app.sh
```

## Ako aplikaciu pozastavit

Aplikaciu je mozne pozastavit zmenou poctu replik deploymentov a statefulsetu na nulu:

```bash
kubectl scale deployment frontend-deployment --replicas=0 -n zkt26-z2
kubectl scale deployment backend-deployment --replicas=0 -n zkt26-z2
kubectl scale statefulset postgres-statefulset --replicas=0 -n zkt26-z2
```

Na jej opatovne spustenie:

```bash
kubectl scale deployment frontend-deployment --replicas=1 -n zkt26-z2
kubectl scale deployment backend-deployment --replicas=1 -n zkt26-z2
kubectl scale statefulset postgres-statefulset --replicas=1 -n zkt26-z2
```

## Ako otvorit webovu aplikaciu

Po spusteni aplikacie v standardnom Kubernetes prostredi otvorte prehliadac na adrese:

- `http://localhost:30080`

Ak pouzivate Minikube vo WSL s Docker driverom, skutocnu URL pre prehliadac ziskate pomocou:

```bash
minikube service frontend-service -n zkt26-z2 --url
```

Nechajte tento terminal otvoreny a otvorte vypisanu URL v prehliadaci.

Ak vase Kubernetes prostredie nespristupnuje NodePort priamo na localhoste alebo chcete pevny lokalny port, pouzite:

```bash
kubectl port-forward service/frontend-service 8080:80 -n zkt26-z2
```

Potom otvorte:

- `http://localhost:8080`
