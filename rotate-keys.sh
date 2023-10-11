#!/usr/bin/env bash

# Load environment variables from .env file
set -a
source .env
set +a

# Download keys
URL="https://login.microsoftonline.com/$AZURE_TENANT_ID/discovery/v2.0/keys"
curl -s $URL > keys/jwt-secret.new

# If difference, print to terminal and overwrite
touch keys/jwt-secret
diff_output=$(diff -u keys/jwt-secret keys/jwt-secret.new)
if [ -n "$diff_output" ]; then
    echo "$diff_output"
    mv keys/jwt-secret.new keys/jwt-secret
    docker compose kill -s SIGUSR2 postgrest
else
    rm keys/jwt-secret.new
fi
