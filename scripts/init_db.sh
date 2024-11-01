#!/bin/bash 
set -x
set -eo pipefail

# Check if a custom user has been set, otherwise default to 'postgres' 
DB_USER=${POSTGRES_USER:=postgres} 
# Check if a custom password has been set, otherwise default to 'password' 
DB_PASSWORD="${POSTGRES_PASSWORD:=password}" 
# Check if a custom database name has been set, otherwise default to 'newsletter' 
DB_NAME="${POSTGRES_DB:=newsletter}" 
# Check if a custom port has been set, otherwise default to '5432' 
DB_PORT="${POSTGRES_PORT:=5432}"

# Set the path to psql.exe
if ! [[ -z "${CI_CD_PIPELINE}" ]]; then
    PATH_PSQL="C:\Program Files\PostgreSQL\16\bin"
    # Add PATH_PSQL to PATH
    export PATH="$PATH:$PATH_PSQL"
fi

if ! command -v psql >/dev/null 2>&1; then
    echo >&2 "Error: psql is not installed"
    echo >&2 "Please install PostgreSQL client tools"
    exit 1
fi
if ! [ -x "$(command -v sqlx)" ]; then 
    echo >&2 "Error: sqlx is not installed."
    echo >&2 "Use:"
    echo >&2 " cargo install --version=0.5.7 sqlx-cli --no-default-features --features postgres"
    echo >&2 "to install it."
    exit 1 
fi

# Launch postgres using Docker 
if [[ -z "${SKIP_DOCKER}" ]] 
then
    docker run \
        -e POSTGRES_USER=${DB_USER} \
        -e POSTGRES_PASSWORD=${DB_PASSWORD} \
        -e POSTGRES_DB=${DB_NAME} \
        -p "${DB_PORT}":5432 \
        -d postgres \
        postgres -N 1000 # ^ Increased maximum number of connections for testing purposes
fi

# Keep pinging Postgres until it's ready to accept commands 
export PGPASSWORD="${DB_PASSWORD}" 
until psql -h "localhost" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q'; do 
>&2 echo "Postgres is still unavailable - sleeping" 
sleep 1 
done

>&2 echo "Postgres is up and running on port ${DB_PORT} - running migrations now!"

# Create database
export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}
sqlx database create
sqlx migrate run

>&2 echo "Postgres has been migrated, ready to go!"