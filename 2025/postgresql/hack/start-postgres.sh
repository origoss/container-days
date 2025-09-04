#!/usr/bin/env bash

set -e

docker run \
	--name pseudo-postgres \
	-e POSTGRES_PASSWORD=Origoss123 \
	-e PGDATA=/var/lib/postgresql/data/pgdata \
	-v ./data:/var/lib/postgresql/data \
	pseudo-postgres:16
