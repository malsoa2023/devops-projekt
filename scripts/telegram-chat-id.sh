#!/usr/bin/env bash
# Wypisuje chat_id do powiadomień: z TELEGRAM_CHAT_ID, a gdy go brak - z ostatniej wiadomości wysłanej do bota.
# Telegram przechowuje nieodebrane wiadomości 24 h, dlatego docelowo chat_id warto zapisać jako sekret.
set -euo pipefail

if [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "$TELEGRAM_CHAT_ID"
  exit 0
fi
[ -n "${TELEGRAM_BOT_TOKEN:-}" ] || exit 0

ID=$(curl -sf "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates" |
  jq -r '[.result[] | (.message // .my_chat_member // .channel_post) | select(. != null) | .chat.id] | last // empty')

if [ -n "$ID" ] && [ -n "${GITHUB_ACTIONS:-}" ]; then
  echo "::notice::Wykryty chat_id Telegrama: $ID - zapisz go jako sekret TELEGRAM_CHAT_ID" >&2
fi
echo "$ID"
