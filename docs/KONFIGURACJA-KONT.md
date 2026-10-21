# Konfiguracja kont (jednorazowo)

Wszystkie konta są darmowe. Hasła i klucze wpisujesz tylko u siebie: w terminalu albo w pliku `.env`.

## 1. GitHub

1. Załóż konto na https://github.com.
2. W terminalu zaloguj GitHub CLI i nadaj uprawnienia do pakietów (potrzebne do pobierania obrazu z GHCR):
   ```bash
   gh auth login --web --scopes "repo,workflow,read:packages,write:packages"
   ```

## 2. AWS

1. Załóż konto na https://aws.amazon.com/free (wybierz **Free plan**). AWS wymaga karty i weryfikacji telefonu,
   ale w darmowym planie nie pobiera opłat.
2. Zaloguj się do konsoli jako root, wybierz region **Europe (Frankfurt) eu-central-1**.
3. Utwórz użytkownika do Terraforma: **IAM → Users → Create user**
   * nazwa: `terraform`
   * *Attach policies directly* → `AdministratorAccess` (dla projektu uczelnianego; w firmie użyłoby się węższych uprawnień)
4. Wejdź w użytkownika → **Security credentials → Create access key → Command Line Interface (CLI)**.
5. W terminalu:
   ```bash
   aws configure
   ```
   Wklej *Access key ID* i *Secret access key*, region `eu-central-1`, format `json`.
6. Sprawdzenie: `aws sts get-caller-identity` powinno pokazać użytkownika `terraform`.

## 3. Telegram

1. W Telegramie napisz do **@BotFather** → `/newbot` → podaj nazwę i login bota (musi kończyć się na `bot`).
2. Skopiuj token do `.env` jako `TELEGRAM_BOT_TOKEN`.
3. Znajdź swojego nowego bota i wyślij mu dowolną wiadomość (np. `/start`).
4. Odczytaj swój `chat_id`:
   ```bash
   make telegram-chat-id
   ```
   Wpisz wynik do `.env` jako `TELEGRAM_CHAT_ID`.
   Chcesz powiadomienia na grupie? Dodaj bota do grupy, napisz tam wiadomość i uruchom komendę jeszcze raz
   (id grupy jest ujemne).

## 4. Plik .env

```bash
cp .env.example .env
```

Uzupełnij: `IMAGE` (`ghcr.io/<twój-login-małymi-literami>/devops-projekt`), `GRAFANA_ADMIN_PASSWORD`,
`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `BUDGET_EMAIL`.

## Sekrety w GitHubie (ustawia je `make github`)

| Nazwa | Typ | Skąd |
|---|---|---|
| `GRAFANA_ADMIN_PASSWORD` | secret | `.env` |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | secret | `.env` |
| `SERVER_HOST` | secret | `terraform output public_ip` |
| `SSH_PRIVATE_KEY` | secret | `~/.ssh/devops_projekt` (tworzy go `make up`) |
| `DEPLOY_ENABLED` | variable | `true`, gdy serwer istnieje |
| `SITE_ADDRESS` | variable | opcjonalnie, domena do HTTPS |
