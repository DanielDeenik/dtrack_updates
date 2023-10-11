#!/usr/bin/env bash

# Load environment variables from .env file
set -a
source .env
set +a

execute_files() {
  local dir="${1}"
  local base_dir="$(basename "${dir}")"

  # Extract user and db from filename
  local user_var="$(echo "${base_dir}" | cut -d. -f2 | tr '[:lower:]' '[:upper:]')"
  local db_var="$(echo "${base_dir}" | cut -d. -f3 | tr '[:lower:]' '[:upper:]')"
  local user="${!user_var}"
  local db="${!db_var}"

  while IFS= read -r -d '' file; do
    if [[ "${file}" == *.sql ]]; then
      echo "--> Executing "${file}" as "${user}" on "${db}""
      envsubst < "${file}" | docker compose exec -T postgres psql -o /dev/null --quiet -U "${user}" -d "${db}"
    elif [[ "${file}" == *.sh ]]; then
      echo "--> Executing "${file}" as bash script ("${user}" on "${db}")"
      envsubst < "${file}" | docker compose exec -T postgres bash -- /dev/stdin -U "${user}" -d "${db}"
    fi
  done < <(find "${dir}" -type f \( -name '*.sql' -o -name '*.sh' \) -print0 | sort -z)
}

# Wait for psql service to be ready
docker compose up postgres -d
while ! docker compose exec postgres pg_isready -U "${POSTGRES_USER}"; do
  echo "Waiting for psql service to be ready..."
  sleep 1
done
echo "psql service is ready!"

# Execute SQL commands from files via docker compose exec at the relevant authentication levels
for dir in dtrack/db/sql/*; do
  echo "Procesing "${dir}":"
  execute_files "${dir}"
done

# During development
docker compose exec -T postgres bash -c "echo \"log_statement = 'all'\" | tee -a /var/lib/postgresql/data/postgresql.conf"
docker compose exec -T postgres bash -c "echo \"log_min_messages = 'notice'\" | tee -a /var/lib/postgresql/data/postgresql.conf"
docker compose kill --signal=SIGTERM postgres
