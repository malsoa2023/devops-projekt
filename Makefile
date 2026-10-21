SHELL := /bin/bash

# Infrastruktura i wdrożenia działają w GitHub Actions - klucze AWS, tokeny i hasła są tylko w GitHub Secrets,
# nic wrażliwego nie jest przechowywane na komputerze. Makefile jedynie uruchamia workflowy przez GitHub CLI.

COMPOSE_LOCAL := docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.local.yml

.DEFAULT_GOAL := help
.PHONY: help github up down status local local-down test lint venv

help: ## Pokaż dostępne komendy
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# --- Produkcja (AWS przez GitHub Actions) ---

github: ## Przygotuj repozytorium: klucz SSH do wdrożeń, zmienne, kontrola sekretów
	./scripts/setup-github.sh

up: ## Postaw WSZYSTKO od zera: Terraform (AWS) + Ansible (serwer i aplikacja)
	gh workflow run infra.yml -f akcja=apply
	@sleep 5; gh run watch $$(gh run list --workflow infra.yml -L1 --json databaseId -q '.[0].databaseId') --exit-status
	gh variable set DEPLOY_ENABLED --body true

down: ## Usuń całą infrastrukturę AWS
	gh variable set DEPLOY_ENABLED --body false
	gh workflow run infra.yml -f akcja=destroy
	@sleep 5; gh run watch $$(gh run list --workflow infra.yml -L1 --json databaseId -q '.[0].databaseId') --exit-status

status: ## Ostatnie przebiegi pipeline'ów
	gh run list -L 10

# --- Lokalnie (bez chmury, bez sekretów) ---

local: ## Uruchom cały stos lokalnie w Dockerze (http://localhost:8080)
	GRAFANA_ADMIN_PASSWORD=admin PUBLIC_URL=http://localhost:8080 $(COMPOSE_LOCAL) up -d --build
	@echo "Aplikacja: http://localhost:8080   Grafana: http://localhost:8080/grafana/ (admin / admin)"

local-down: ## Zatrzymaj lokalny stos i usuń jego dane
	GRAFANA_ADMIN_PASSWORD=admin $(COMPOSE_LOCAL) down -v

venv:
	@test -d .venv || python3 -m venv .venv
	@.venv/bin/pip install -q -r app/requirements.txt -r app/requirements-dev.txt

test: venv ## Testy jednostkowe aplikacji
	cd app && ../.venv/bin/pytest -v

lint: venv ## Lint kodu i walidacja IaC
	cd app && ../.venv/bin/ruff check .
	terraform -chdir=terraform fmt -check -recursive
	terraform -chdir=terraform init -backend=false -input=false > /dev/null && terraform -chdir=terraform validate
	cd ansible && ansible-playbook -i localhost, site.yml --syntax-check
