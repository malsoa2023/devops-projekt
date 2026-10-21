# Konfiguracja kont (jednorazowo)

Wszystkie konta są darmowe. **Klucze, tokeny i hasła wpisujesz tylko w przeglądarce, w GitHub Secrets.**
Nie trafiają na dysk komputera ani do repozytorium, a w logach GitHub Actions są automatycznie zamaskowane.

## 1. GitHub

1. Załóż konto na https://github.com.
2. Zaloguj GitHub CLI (`gh auth login`) i uruchom `make github`. Skrypt tworzy repozytorium, generuje klucz SSH
   do wdrożeń i zapisuje go od razu w GitHubie, bez kopii lokalnej. Na koniec wypisuje sekrety, których brakuje.

## 2. AWS

1. Załóż konto na https://aws.amazon.com/free (wybierz **Free plan**). AWS wymaga karty i weryfikacji telefonu,
   ale w darmowym planie nie pobiera opłat.
2. W konsoli AWS: **IAM → Users → Create user**
   * nazwa: `terraform`
   * *Attach policies directly* → `AdministratorAccess` (dla projektu uczelnianego; w firmie użyłoby się węższych uprawnień)
3. Wejdź w użytkownika → **Security credentials → Create access key → Third-party service**.
   Zostaw tę stronę otwartą: sekretny klucz jest widoczny tylko raz.

## 3. Telegram

1. W Telegramie napisz do **@BotFather** → `/newbot` → podaj nazwę i login bota (musi kończyć się na `bot`).
   Zapisz token.
2. Znajdź swojego nowego bota i wyślij mu dowolną wiadomość (np. `/start`). Dzięki temu pipeline sam
   odczyta Twój `chat_id`.

## 4. Sekrety w GitHubie

Otwórz **repozytorium → Settings → Secrets and variables → Actions → New repository secret** i dodaj:

| Nazwa | Wartość |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key z kroku 2.3 (zaczyna się od `AKIA`) |
| `AWS_SECRET_ACCESS_KEY` | Secret access key z kroku 2.3 |
| `TELEGRAM_BOT_TOKEN` | token od @BotFather |
| `GRAFANA_ADMIN_PASSWORD` | hasło do Grafany, które wymyślasz (min. 8 znaków) |

Ustawiane automatycznie przez `make github` / `make up`:

| Nazwa | Typ | Opis |
|---|---|---|
| `SSH_PRIVATE_KEY` | secret | klucz, którym Ansible loguje się na serwer |
| `SSH_PUBLIC_KEY` | variable | jego część publiczna, wgrywana przez Terraform na serwer |
| `BUDGET_EMAIL` | variable | e-mail na alert budżetowy AWS |
| `DEPLOY_ENABLED` | variable | `true`, gdy infrastruktura istnieje: push na `main` wdraża |
| `TELEGRAM_CHAT_ID` | secret (opcjonalny) | gdy brak, odczytywany z ostatniej wiadomości do bota |
| `SITE_ADDRESS` | variable (opcjonalna) | domena do HTTPS |

## 5. Start

```bash
make up
```

Albo w przeglądarce: **Actions → Infrastruktura → Run workflow → apply**.
