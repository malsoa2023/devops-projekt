# Projekt dyplomowy DevOps

Kompletny, zautomatyzowany cykl życia aplikacji webowej: od commita, przez testy, budowanie i publikację obrazu,
po automatyczne wdrożenie na AWS, z monitoringiem, centralnymi logami i powiadomieniami na Telegram.

| Obszar | Narzędzia |
|---|---|
| Aplikacja | Python 3.13, Flask, Gunicorn, metryki Prometheus |
| Konteneryzacja | Docker (obraz wieloetapowy), Docker Compose |
| Infrastruktura jako kod | Terraform (AWS: VPC, EC2, Elastic IP, Security Group, Budżet) + Ansible |
| CI/CD | GitHub Actions, GitHub Container Registry (GHCR) |
| Load balancing i TLS | Caddy (round robin na 2 repliki, opcjonalnie automatyczny certyfikat Let's Encrypt) |
| Monitoring | Prometheus, Alertmanager, Grafana, node-exporter, cAdvisor |
| Logi | Grafana Loki + Grafana Alloy |
| Powiadomienia | Telegram (wynik pipeline'u i alerty z monitoringu) |

## Architektura

```mermaid
graph LR
    dev[Programista] -- git push --> gh[GitHub]
    gh --> ci[GitHub Actions]
    ci -- testy, build --> ghcr[(GHCR<br/>obrazy Docker)]
    ci -- "main: ansible-playbook" --> ec2
    ci -- wynik --> tg[Telegram]

    subgraph aws[AWS - eu-central-1, tworzone przez Terraform]
      subgraph ec2[EC2 Ubuntu 24.04 - konfiguracja Ansible]
        caddy[Caddy<br/>load balancer :80/:443] --> app1[app #1]
        caddy --> app2[app #2]
        caddy --> grafana[Grafana]
        prom[Prometheus] -- scrape --> app1 & app2
        prom -- scrape --> ne[node-exporter] & cad[cAdvisor]
        prom --> am[Alertmanager]
        alloy[Alloy] -- logi kontenerów --> loki[Loki]
        grafana --> prom & loki
      end
    end
    ghcr -- docker pull --> ec2
    am -- alerty --> tg
    user[Użytkownik] -- HTTP/HTTPS --> caddy
```

## Struktura repozytorium

```
app/                     aplikacja + testy + Dockerfile
deploy/                  stos uruchamiany na serwerze (docker-compose.yml) i konfiguracja monitoringu
  caddy/                 load balancer / reverse proxy
  prometheus/            scrape config + reguły alertów
  alertmanager/          (alertmanager.yml generuje Ansible - zawiera token Telegrama)
  grafana/               źródła danych i dashboardy (provisioning - zero klikania)
  loki/, alloy/          centralne logi
terraform/               infrastruktura AWS
ansible/                 konfiguracja serwera: role common (swap, pakiety), docker, stack (wdrożenie)
.github/workflows/       pipeline CI/CD
scripts/                 setup-github.sh (repo + sekrety), demo-traffic.sh (ruch do demo)
docs/                    instrukcja zakładania kont, scenariusz obrony
Makefile                 wszystkie komendy w jednym miejscu (make help)
```

## Pipeline CI/CD

```mermaid
graph LR
    push[push na dowolną gałąź] --> test[Testy + lint] & iac[Walidacja Terraform/Ansible]
    test & iac --> build[Build obrazu]
    build --> publish[Publikacja w GHCR<br/>tagi: SHA, gałąź, latest]
    publish --> smoke[Test integracyjny obrazu]
    smoke -- tylko main --> deploy[Ansible: wdrożenie na EC2]
    deploy --> verify[Weryfikacja wersji na produkcji]
    smoke & verify --> notify[Telegram]
```

* **Każda gałąź:** testy jednostkowe (pytest), lint (ruff), `terraform fmt/validate`, `ansible --syntax-check`,
  build obrazu, publikacja w GHCR, uruchomienie opublikowanego obrazu i sprawdzenie `/health`, `/api/info`, `/metrics`.
* **Gałąź `main`:** dodatkowo `ansible-playbook` wdraża obraz o tagu równym SHA commita i sprawdza,
  czy produkcja zwraca właśnie tę wersję.
* **Zawsze:** wiadomość na Telegram ze statusem każdego etapu i linkiem do przebiegu.

## Wdrożenie od zera

Wymagane narzędzia: `git`, `docker`, `terraform`, `ansible`, `aws` (AWS CLI), `gh` (GitHub CLI).
Zakładanie kont i kluczy opisuje [docs/KONFIGURACJA-KONT.md](docs/KONFIGURACJA-KONT.md).

```bash
cp .env.example .env      # uzupełnij wartości
make github               # repozytorium na GitHubie + sekrety; pierwszy push buduje obraz
git push -u origin main
make up                   # Terraform (AWS) + Ansible (serwer + aplikacja) - jedna komenda
make github               # dopisuje adres serwera i klucz SSH - od teraz każdy push na main wdraża
```

`make up` jest **idempotentne**: ponowne uruchomienie bez zmian w kodzie daje
`No changes` w Terraformie i `changed=0` w Ansible.

Najważniejsze komendy (`make help` pokazuje wszystkie):

| Komenda | Co robi |
|---|---|
| `make up` | Tworzy infrastrukturę i wdraża wszystko od zera |
| `make deploy` | Tylko konfiguracja serwera i wdrożenie (Ansible) |
| `make output` | Adresy aplikacji, Grafany i polecenie SSH |
| `make tunnel` | Prometheus i Alertmanager przez tunel SSH (localhost:9090 / 9093) |
| `make down` | Usuwa całą infrastrukturę AWS |
| `make local` | Cały stos lokalnie w Dockerze: http://localhost:8080 |
| `make test` / `make lint` | Testy i walidacja |

## Monitoring i logi

* **Grafana:** `http://<IP>/grafana/` (login `admin`, hasło z `GRAFANA_ADMIN_PASSWORD`)
  * *Aplikacja:* liczba replik, wdrożona wersja, żądania/s na replikę (widać load balancing), kody odpowiedzi,
    opóźnienia p50/p95/p99, pamięć replik, logi aplikacji.
  * *Infrastruktura:* CPU, RAM, swap, dysk, sieć, load average, zasoby każdego kontenera, logi wszystkich kontenerów.
* **Alerty** (Prometheus, wysyłane przez Alertmanager na Telegram): niedziałająca replika, brak replik,
  ponad 5% błędów 5xx, p95 powyżej 1 s, niedziałająca usługa monitoringu, CPU powyżej 85%, RAM poniżej 10%, dysk poniżej 15%.
* **Demo alertu:** `./scripts/demo-traffic.sh http://<IP> errors` - po ok. 2 minutach przychodzi alert na Telegram,
  a po zakończeniu skryptu wiadomość o rozwiązaniu.

## Endpointy aplikacji

| Ścieżka | Opis |
|---|---|
| `/` | Strona z wersją, nazwą repliki i licznikiem odwiedzin |
| `/health` | Health check |
| `/api/info` | Wersja i replika w JSON |
| `/metrics` | Metryki Prometheusa |
| `/api/slow?seconds=N` | Celowo wolna odpowiedź (demo opóźnień) |
| `/api/error` | Celowy błąd 500 (demo alertów) |

## Bezpieczeństwo i koszty

* Sekrety tylko w `.env` (poza repozytorium) i w GitHub Secrets; Ansible nie loguje tokenów.
* SSH wyłącznie kluczem; Prometheus i Alertmanager słuchają tylko na `127.0.0.1` (dostęp tunelem SSH).
* Dysk szyfrowany, IMDSv2, kontener aplikacji działa jako użytkownik bez uprawnień roota.
* HTTPS: ustaw `SITE_ADDRESS` na domenę z `make output` (np. `3-120-45-67.sslip.io`); Caddy sam pobierze certyfikat.
* **Koszt:** t3.micro, 20 GB gp3 i publiczny adres IP mieszczą się w darmowym pakiecie AWS (Free Plan: kredyty
  dla nowych kont). `cpu_credits = "standard"` wyklucza dopłaty za CPU, a budżet AWS wysyła e-mail po przekroczeniu
  1 USD. GitHub Actions i GHCR są darmowe dla publicznych repozytoriów. Po obronie: `make down`.

## Ograniczenia i możliwe rozszerzenia

* Stan Terraformu trzymany lokalnie; w zespole należałoby przenieść go do S3 z blokadą (DynamoDB / S3 lockfile).
* Jeden serwer: repliki chronią przed awarią procesu, nie całej maszyny. Kolejny krok to Auto Scaling Group + ALB
  albo Kubernetes (EKS / k3s), co kosztuje więcej niż darmowy pakiet.
