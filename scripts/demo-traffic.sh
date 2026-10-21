#!/usr/bin/env bash
# Generuje ruch do demonstracji monitoringu i alertów.
#   ./scripts/demo-traffic.sh http://1.2.3.4            -> normalny ruch przez 3 minuty
#   ./scripts/demo-traffic.sh http://1.2.3.4 errors     -> ~30% błędów 500 (alert WysokiOdsetekBledow)
#   ./scripts/demo-traffic.sh http://1.2.3.4 slow       -> wolne odpowiedzi (alert WysokieOpoznienie)
set -euo pipefail

URL="${1:?Podaj adres, np. http://1.2.3.4}"
MODE="${2:-normal}"
DURATION="${DURATION:-180}"

end=$((SECONDS + DURATION))
count=0
echo "Ruch '$MODE' do $URL przez ${DURATION}s (Ctrl+C przerywa)..."
while [ $SECONDS -lt $end ]; do
  curl -s -o /dev/null "$URL/"
  curl -s -o /dev/null "$URL/api/info"
  case "$MODE" in
    errors) curl -s -o /dev/null "$URL/api/error" ;;
    slow) curl -s -o /dev/null "$URL/api/slow?seconds=2" & ;;
  esac
  count=$((count + 1))
  sleep 0.3
done
wait
echo "Gotowe: $count iteracji."
