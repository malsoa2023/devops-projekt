SHELL := /bin/bash

# Ustawienia z pliku .env (skopiuj .env.example -> .env)
-include .env
export

TF            := terraform -chdir=terraform
SSH_KEY       ?= $(HOME)/.ssh/devops_projekt
INVENTORY     := ansible/inventory.ini
COMPOSE_LOCAL := docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.local.yml
REGISTRY_USER ?= $(shell gh api user -q .login 2>/dev/null)
REGISTRY_TOKEN ?= $(shell gh auth token 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help up infra deploy down inventory ssh-key ssh tunnel output github telegram-chat-id \
        local local-down test lint venv

help: ## Pokaż dostępne komendy
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# --- Produkcja (AWS) ---

up: infra deploy ## Postaw WSZYSTKO od zera: infrastruktura AWS + konfiguracja serwera + aplikacja
	@$(TF) output

infra: ssh-key ## Utwórz / zaktualizuj infrastrukturę AWS (Terraform)
	$(TF) init -input=false
	$(TF) apply -input=false -auto-approve \
		-var ssh_public_key_path=$(SSH_KEY).pub \
		-var budget_email=$(BUDGET_EMAIL)

deploy: inventory ## Skonfiguruj serwer i wdróż aplikację (Ansible)
	cd ansible && ansible-playbook site.yml

down: ## Usuń całą infrastrukturę AWS (koniec kosztów)
	$(TF) destroy -input=false -auto-approve \
		-var ssh_public_key_path=$(SSH_KEY).pub \
		-var budget_email=$(BUDGET_EMAIL)
	rm -f $(INVENTORY)

ssh-key:
	@test -f $(SSH_KEY) || ssh-keygen -t ed25519 -N "" -C devops-projekt -f $(SSH_KEY)

inventory:
	@IP=$$($(TF) output -raw public_ip) && \
	printf "[app_servers]\nserver ansible_host=%s ansible_user=ubuntu ansible_ssh_private_key_file=%s\n" "$$IP" "$(SSH_KEY)" > $(INVENTORY) && \
	echo "Inwentarz Ansible: serwer $$IP"

output: ## Pokaż adresy aplikacji i Grafany
	@$(TF) output

ssh: ## Zaloguj się na serwer
	ssh -i $(SSH_KEY) ubuntu@$$($(TF) output -raw public_ip)

tunnel: ## Tunel SSH do Prometheusa (localhost:9090) i Alertmanagera (localhost:9093)
	@echo "Prometheus: http://localhost:9090  Alertmanager: http://localhost:9093  (Ctrl+C kończy)"
	ssh -i $(SSH_KEY) -N -L 9090:localhost:9090 -L 9093:localhost:9093 ubuntu@$$($(TF) output -raw public_ip)

# --- GitHub i Telegram ---

github: ## Utwórz repozytorium na GitHubie i ustaw sekrety dla CI/CD
	./scripts/setup-github.sh

telegram-chat-id: ## Odczytaj chat_id z Telegrama (najpierw napisz coś do swojego bota)
	@test -n "$(TELEGRAM_BOT_TOKEN)" || { echo "Ustaw TELEGRAM_BOT_TOKEN w .env"; exit 1; }
	@curl -s "https://api.telegram.org/bot$(TELEGRAM_BOT_TOKEN)/getUpdates" | \
		python3 -c "import json,sys; r=json.load(sys.stdin)['result']; ids={u['message']['chat']['id'] for u in r if 'message' in u}; print('\n'.join(map(str,ids)) or 'Brak wiadomości - napisz coś do bota i spróbuj ponownie')"

# --- Lokalnie ---

local: ## Uruchom cały stos lokalnie w Dockerze (http://localhost:8080)
	GRAFANA_ADMIN_PASSWORD=admin PUBLIC_URL=http://localhost:8080 $(COMPOSE_LOCAL) up -d --build
	@echo "Aplikacja: http://localhost:8080   Grafana: http://localhost:8080/grafana/ (admin / admin)"

local-down: ## Zatrzymaj lokalny stos
	GRAFANA_ADMIN_PASSWORD=admin $(COMPOSE_LOCAL) down

venv:
	@test -d .venv || python3 -m venv .venv
	@.venv/bin/pip install -q -r app/requirements.txt -r app/requirements-dev.txt

test: venv ## Testy jednostkowe aplikacji
	cd app && ../.venv/bin/pytest -v

lint: venv ## Lint kodu i walidacja IaC
	cd app && ../.venv/bin/ruff check .
	$(TF) fmt -check -recursive
	cd ansible && ansible-playbook -i localhost, site.yml --syntax-check
