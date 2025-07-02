#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

sed -i "s/plugins.security.ssl.http.enabled: false/plugins.security.ssl.http.enabled: true/" opensearch.yml

docker compose up -d --force-recreate
for i in {1..15}; do docker compose exec opensearch curl https://localhost:9200 -k && break || sleep 5; done
docker compose exec opensearch /usr/share/opensearch/plugins/opensearch-security/tools/securityadmin.sh \
    -icl \
    -nhnv \
    -cert /usr/share/opensearch/config/esnode.pem \
    -cacert /usr/share/opensearch/config/root-ca.pem \
    -key /usr/share/opensearch/config/esnode-key.pem

sed -i "s/plugins.security.ssl.http.enabled: true/plugins.security.ssl.http.enabled: false/" opensearch.yml
docker compose restart opensearch
