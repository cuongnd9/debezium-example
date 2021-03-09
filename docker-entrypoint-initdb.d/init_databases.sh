#!/bin/bash

set -e
set -u

function create_user_and_database() {
	local database=$1
	echo "Creating user and database $database"
	if psql --username "$POSTGRES_USER" -t -c '\du' | cut -d \| -f 1 | grep -qw $database; then
		echo "💅 user $database already exists"
		exit 1
	else
		psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
			CREATE USER $database;
		EOSQL
	fi

	if [ "$( psql --username "$POSTGRES_USER" -tAc "SELECT 1 FROM pg_database WHERE datname='$database'" )" = '1' ]
	then
		echo "💅 database $database already exists"
		exit 1
	else
		psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
			CREATE DATABASE $database;
			GRANT ALL PRIVILEGES ON DATABASE $database TO $database;
		EOSQL
	fi

	if [ -f ../mocking/$database.sql ]
	then
		echo "🐳 database $database: importing mocking data"
		psql --username "$POSTGRES_USER" -v ON_ERROR_STOP=1 -f ../mocking/$database.sql
	fi
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
	for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
		create_user_and_database $db
	done
	echo "Multiple databases created"
fi
