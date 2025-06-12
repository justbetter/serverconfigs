#!/bin/bash
cd "$(dirname "$0")"

# Create root certificate
[ ! -f ./ssl/root-ca-key.pem ] && openssl genrsa -out ./ssl/root-ca-key.pem 2048
openssl req -new -x509 -sha256 -key ./ssl/root-ca-key.pem -subj "/C=CA/ST=NOORD-HOLLAND/L=ALKMAAR/O=ORG/OU=UNIT/CN=ROOT" -out ./ssl/root-ca.pem -days 358000

# Generate transport certificate
[ ! -f ./ssl/esnode-key-temp.pem ] && openssl genrsa -out ./ssl/esnode-key-temp.pem 2048
[ ! -f ./ssl/esnode-key.pem ] && openssl pkcs8 -inform PEM -outform PEM -in ./ssl/esnode-key-temp.pem -topk8 -nocrypt -v1 PBE-SHA1-3DES -out ./ssl/esnode-key.pem
[ ! -f ./ssl/esnode.csr ] && openssl req -new -key ./ssl/esnode-key.pem -subj "/C=CA/ST=NOORD-HOLLAND/L=ALKMAAR/O=ORG/OU=UNIT/CN=A" -out ./ssl/esnode.csr
openssl x509 -req -in ./ssl/esnode.csr -CA ./ssl/root-ca.pem -CAkey ./ssl/root-ca-key.pem -CAcreateserial -sha256 -out ./ssl/esnode.pem -days 358000

mkdir data
chown -R 1000:1000 ssl opensearch-security data
chown 1000:1000 opensearch.yml

sed -i "s/plugins.security.ssl.http.enabled: false/plugins.security.ssl.http.enabled: true/" opensearch.yml

if netstat -tulpn | grep 9200 > /dev/null 2>&1;
then
    echo "Elasticsearch is also installed! Moving opensearch to port 9201";
    sed -i 's/9200:9200/9201:9200/' docker-compose.yml;
fi

docker compose up -d --wait

if [ -f .env ]; then
    echo "env is already generated"
    sed -i "s/plugins.security.ssl.http.enabled: true/plugins.security.ssl.http.enabled: false/" opensearch.yml
    docker compose restart opensearch
    exit 1
fi

OPENSEARCH_ADMIN_PASSWORD=$(openssl rand -base64 20 | tr -dc '[:alnum:]')
OPENSEARCH_WEB_PASSWORD=$(openssl rand -base64 20 | tr -dc '[:alnum:]')
OPENSEARCH_ADMIN_PASSWORD_HASH=$(docker compose exec opensearch /usr/share/opensearch/plugins/opensearch-security/tools/hash.sh -p ${OPENSEARCH_ADMIN_PASSWORD} | grep -v "WARNING")
OPENSEARCH_WEB_PASSWORD_HASH=$(docker compose exec opensearch /usr/share/opensearch/plugins/opensearch-security/tools/hash.sh -p ${OPENSEARCH_WEB_PASSWORD} | grep -v "WARNING")

echo "OPENSEARCH_ADMIN_PASSWORD=${OPENSEARCH_ADMIN_PASSWORD}" >> .env
echo "OPENSEARCH_WEB_PASSWORD=${OPENSEARCH_WEB_PASSWORD}" >> .env

sed -i "s#ADMIN_PASSWORD_REPLACEME#${OPENSEARCH_ADMIN_PASSWORD_HASH}#" opensearch-security/internal_users.yml
sed -i "s#WEB_PASSWORD_REPLACEME#${OPENSEARCH_WEB_PASSWORD_HASH}#" opensearch-security/internal_users.yml

docker compose up -d --wait --force-recreate
docker compose exec opensearch /usr/share/opensearch/plugins/opensearch-security/tools/securityadmin.sh \
    -icl \
    -nhnv \
    -cert /usr/share/opensearch/config/esnode.pem \
    -cacert /usr/share/opensearch/config/root-ca.pem \
    -key /usr/share/opensearch/config/esnode-key.pem

sed -i "s/plugins.security.ssl.http.enabled: true/plugins.security.ssl.http.enabled: false/" opensearch.yml
docker compose restart opensearch
