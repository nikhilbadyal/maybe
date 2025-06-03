#!/bin/sh

mkdir -p /tmp/ngrok
# Generate v3 config file
cat > /tmp/ngrok/ngrok.yml <<EOF
version: "3"
agent:
  authtoken: ${NGROK_TOKEN}
endpoints:
  - name: maybe
    url: https://${NGROK_URL}
    upstream:
      url: web:80
EOF
# Start ngrok with v3 config
exec ngrok start --all --config /tmp/ngrok/ngrok.yml