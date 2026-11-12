#!/bin/sh

echo "Image tag: $IMAGE_TAG"

# If DB_SECRET_ARN is set, fetch RDS credentials from Secrets Manager and build DATABASE_URL.
# The RDS-managed secret holds the username and password (RDS rotates the password automatically).
# DB_HOST and DB_PORT are taken from the environment when set, otherwise from the secret's host/port fields.
# Username and password are URL-encoded because RDS-generated passwords contain URL-reserved characters.
if [ -n "$DB_SECRET_ARN" ]; then
  echo "Fetching database credentials from Secrets Manager (secret: $DB_SECRET_ARN)..."
  SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "$DB_SECRET_ARN" \
    --query SecretString \
    --output text) || { echo "Failed to read database credentials from Secrets Manager" >&2; exit 1; }
  DB_USERNAME=$(echo "$SECRET" | jq -r '.username | @uri')
  DB_PASSWORD=$(echo "$SECRET" | jq -r '.password | @uri')
  DB_HOST=${DB_HOST:-$(echo "$SECRET" | jq -r '.host')}
  DB_PORT=${DB_PORT:-$(echo "$SECRET" | jq -r '.port // 5432')}
  export DATABASE_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME:-litellm}"
  echo "DATABASE_URL set (host: $DB_HOST, db: ${DB_NAME:-litellm})"
fi

# Execute the script in the same directory as this entrypoint
SCRIPT_DIR="$(dirname "$0")"
"$SCRIPT_DIR"/create_nginx_conf.sh

# Start litellm from /app directory as a background process
"$SCRIPT_DIR"/docker/prod_entrypoint.sh --port 4000 --config /etc/litellm/config.yaml &

# Start nginx as a background service
nginx -g 'daemon off;' &

# Optionally, wait for background processes or keep the container alive
wait
