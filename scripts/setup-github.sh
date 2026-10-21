#!/usr/bin/env bash
# Przygotowuje repozytorium GitHub do CI/CD. Można uruchamiać wielokrotnie.
#  - tworzy repozytorium (jeśli go nie ma)
#  - generuje klucz SSH do wdrożeń i zapisuje go WYŁĄCZNIE w GitHubie (lokalna kopia jest od razu usuwana)
#  - ustawia zmienne repozytorium
#  - sprawdza, czy są sekrety, które wpisuje się ręcznie w przeglądarce
# Żadne klucze ani hasła nie zostają na dysku komputera.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO_NAME="${REPO_NAME:-devops-projekt}"

gh api user >/dev/null 2>&1 || { echo "Najpierw zaloguj się: gh auth login"; exit 1; }
OWNER=$(gh api user -q .login)
REPO="$OWNER/$REPO_NAME"

# 1. Repozytorium
if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "✓ Repozytorium $REPO istnieje"
else
  gh repo create "$REPO" --public --description "Projekt dyplomowy DevOps: IaC, CI/CD, monitoring"
  echo "✓ Utworzono repozytorium $REPO"
fi
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$REPO.git"

# 2. Klucz SSH do wdrożeń - tylko raz; plik tymczasowy usuwany zaraz po wysłaniu
if gh variable get SSH_PUBLIC_KEY --repo "$REPO" >/dev/null 2>&1; then
  echo "✓ Klucz SSH do wdrożeń już jest w GitHubie"
else
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  ssh-keygen -q -t ed25519 -N "" -C "devops-projekt-deploy" -f "$TMP/key"
  gh secret set SSH_PRIVATE_KEY --repo "$REPO" < "$TMP/key"
  gh variable set SSH_PUBLIC_KEY --repo "$REPO" --body "$(cat "$TMP/key.pub")"
  rm -rf "$TMP"
  echo "✓ Wygenerowano klucz SSH i zapisano go w GitHubie (bez kopii lokalnej)"
fi

# 3. Zmienne (nie są tajne)
if [ -n "${BUDGET_EMAIL:-}" ]; then
  gh variable set BUDGET_EMAIL --repo "$REPO" --body "$BUDGET_EMAIL"
  echo "✓ BUDGET_EMAIL ustawiony"
fi

# 4. Sekrety wpisywane ręcznie w przeglądarce
EXISTING=$(gh secret list --repo "$REPO" --json name -q '.[].name')
MISSING=()
for s in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY GRAFANA_ADMIN_PASSWORD TELEGRAM_BOT_TOKEN; do
  grep -qx "$s" <<< "$EXISTING" || MISSING+=("$s")
done
if [ ${#MISSING[@]} -gt 0 ]; then
  echo
  echo "Brakuje sekretów: ${MISSING[*]}"
  echo "Dodaj je w przeglądarce: https://github.com/$REPO/settings/secrets/actions/new"
  exit 1
fi
echo "✓ Wszystkie wymagane sekrety są ustawione"
