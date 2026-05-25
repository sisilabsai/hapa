#!/usr/bin/env bash
# Run on a physical Android device.
# Gets the host machine's current LAN IP automatically.

HOST_IP=$(ip route get 1 | awk '{print $7; exit}')
echo "→ Backend: http://$HOST_IP:8080"
flutter run --dart-define=API_BASE_URL="http://$HOST_IP:8080" "$@"
