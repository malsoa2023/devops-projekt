#!/usr/bin/env bash
# Tworzy repozytorium na GitHubie i ustawia sekrety potrzebne w CI/CD.
# Można uruchamiać wielokrotnie - zmienia tylko to, czego brakuje albo co się zmieniło.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO_NAME="${REPO_NAME:-devops-projekt}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/devops_projekt}"

if [ -f .env ]; then set -a; source .env; set +a; fi

gh api user >/dev/null 2>&1 || { echo "Najpierw zaloguj się: gh auth login"; exit 1; }
OWNER=$(gh api user -q .login)
REPO="$OWNER/$REPO_NAME"

# 1. Repozytorium
if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "Repozytorium $REPO już istnieje"
else
  echo "Tworzę publiczne repozytorium $REPO"
  gh repo create "$REPO" --public --description "Projekt dyplomowy DevOps: IaC, CI/CD, monitoring"
fi
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$REPO.git"

# 2. Sekrety niezależne od serwera
set_secret() { # nazwa wartość
  if [ -n "$2" ]; then
    printf '%s' "$2" | gh secret set "$1" --repo "$REPO"
  else
    echo "  pomijam $1 (brak wartości w .env)"
  fi
}
echo "Ustawiam sekrety..."
set_secret GRAFANA_ADMIN_PASSWORD "${GRAFANA_ADMIN_PASSWORD:-}"
set_secret TELEGRAM_BOT_TOKEN "${TELEGRAM_BOT_TOKEN:-}"
set_secret TELEGRAM_CHAT_ID "${TELEGRAM_CHAT_ID:-}"
if [ -n "${SITE_ADDRESS:-}" ]; then
  gh variable set SITE_ADDRESS --repo "$REPO" --body "$SITE_ADDRESS"
fi

# 3. Dane serwera - dopiero gdy infrastruktura istnieje (po "make infra")
if IP=$(terraform -chdir=terraform output -raw public_ip 2>/dev/null) && [ -n "$IP" ]; then
  echo "Serwer: $IP - ustawiam SERVER_HOST, SSH_PRIVATE_KEY i włączam automatyczne wdrożenia"
  set_secret SERVER_HOST "$IP"
  gh secret set SSH_PRIVATE_KEY --repo "$REPO" < "$SSH_KEY"
  gh variable set DEPLOY_ENABLED --repo "$REPO" --body true
else
  echo "Infrastruktura jeszcze nie istnieje - wdrożenia z CI pozostają wyłączone (uruchom 'make up', potem ponownie 'make github')"
fi

echo "Gotowe: https://github.com/$REPO"
