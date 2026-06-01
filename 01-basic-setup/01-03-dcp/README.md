# Dataspace Setup with DCP

This setup is only meant as a technology showcase. 
We do not recommend reusing the architecture and steps as a production-ready solution. 

## Dataspace Architecture

![architecture](./doc/img/architecture.jpg)

In this setup, there are two needed central service the `Dataspace Issuer` and the `Connector Registry`, often provided by a dataspace operator.
The `Dataspace Issuer` acts as the identity anchor and issues `Verifiable Credentials` to the allowed participants.
The `Connector Registry` is a phonebook that holds a list of all available participants and delivers it, including their identities and the `DSP URL`. 

## Step-by-Step Setup

For this step-by-step description, you need the following software installed on your computer:

- Container Engine, such as `Docker` or `Podman`
- Terminal 
- API Tool, such as `cURL` or `Postman`

### 01. Start central services

Open a Terminal and execute the following commands:
```sh
$ cd ./01-basic-setup/01-03-dcp
$ docker network create dataspace-net
$ docker compose -f docker-compose-central.yaml up -d
```
With these commands you will start an instance of the `Dataspace Issuer` and the `Connector Registry`.
Both are already pre-configured. 

### 02. Check everything is up and running

Check the status of the containers in `Docker Desktop` or with the `docker ps` command.
Check the logs for any errors.

### 03. Start the participants

Back to your terminal, run the following commands:
```sh
$ docker compose -f docker-compose-participants.yaml up -d
```
With this command, you start two participants with dedicated `Control`, `Data Planes` and `Identity Hub` but a shared `PostgreSQL` and `HashiCorp Vault` instance.
You are now ready to go through our [Feature Showcase](../../02-features/README.md).

### 04. Onboard a participant technically (optional)

The technical onboarding expects that all organizational contracts or requirements are completed, and that a new participant needs to be created on the technical side.
In this setup, with the `Dataspace Issuer` as the trust anchor, the following steps for the onboarding are:
- Add the participant as a valid member to the `Dataspace Issuer` and prepare the company information to issues `Verifiable Credentials`.
- Add a new triple of `Control Plane`, `Data Plane` and `Identity Hub` to the `docker-compose-participants.yaml` file.

```
Be aware that the following description only applies to this MVD setup!
```

### Preparations

In the context of `DCP`, a participant's identifier is a `Decentralized Identifier (DID)`. 
In the real world, a company that wants to be onboarded in a dataspace already possesses a `DID`. 
In the `MVD` setup, we need to define this `DID` as the first step. 
The `DID` is built up as follows `did:web:<hostname>:<company-name>`. 
The `hostname` needs to reference the `Wallet` that will later hold the `Verifiable Credentials`. 
In the context of `Re4DE`, this `Wallet` is the `Identity Hub`. 
Assuming we want to onboard the fictional company, `spacer`, in the `MVD`, the following table shows the properties we need later.

| Name   | DID                                       | DID (base64)                                             |
|--------|-------------------------------------------|----------------------------------------------------------|
| spacer | did:web:identityhub-spacer%3A10100:spacer | ZGlkOndlYjppZGVudGl0eWh1Yi1zcGFjZXIlM0ExMDEwMDpzcGFjZXI= |

The `base64` encoded string of the `DID` can be achieved with the command `echo -n <DID> | base64`. 
For the following setup, we will reuse the values from the table.

### Prepare Dataspace Issuer to issue Verifiable Credentials

Before we configure the connector, we need to add configuration to the central `PostgresSQL`and `HashiCorp Vault` deployments.
Open the `init-db.sql` from  the `./config/postgres/central` folder.
Add the following changes at the end of the file.

```sql
-- Insert spacer as a valid participant and add attestations
INSERT INTO holders (holder_id, participant_context_id, did, holder_name, created_date)
VALUES ('did:web:identityhub-spacer%3A10100:spacer', 'ZGlkOndlYjppZGVudGl0eWh1Yi1zcGFjZXIlM0ExMDEwMDpzcGFjZXI=', 'did:web:identityhub-spacer%3A10100:spacer', 'spacer', 1779969883);

INSERT INTO membership_attestations (holder_id)
VALUES ('did:web:identityhub-spacer%3A10100:spacer');

INSERT INTO marketpartner_attestations (company_name, company_uid, market_role, holder_id)
VALUES ('spacer AG', '987654', '{"mpId":"456789","roleAbbreviation":"MSB","roleName":"Messstellenbetreiber"}', 'did:web:identityhub-spacer%3A10100:spacer');
```

In a real-world scenario, the values for `company_uid` and `market_role` in the third insert command are derived by a regulatory body of the German energy market that is authorized to assign them. 
Therefore, it is up to you which fictional values you choose. 

#### Configure the connector through Docker Compose

Before we configure the connector, we need to add configuration to the `PostgreSQL` and `HashiCorp Vault` deployments.
Open the `init-db.sql` from the `./config/postgres/participant` folder. Adjust the file as follows.

```sql
-- Create a user and database for bob
CREATE USER edc_bob WITH PASSWORD 'devpass';
CREATE DATABASE edc_bob;
GRANT ALL PRIVILEGES ON DATABASE edc_bob TO edc_bob;

-- Your new participant
CREATE USER edc_spacer WITH PASSWORD 'devpass';
CREATE DATABASE edc_spacer;
GRANT ALL PRIVILEGES ON DATABASE edc_spacer TO edc_spacer;

-- Grant access to public schemas
\c edc_alice postgres
GRANT ALL ON SCHEMA public TO edc_alice;
\c edc_bob postgres
GRANT ALL ON SCHEMA public TO edc_bob;
-- Your new participant
\c edc_spacer postgres
GRANT ALL ON SCHEMA public TO edc_spacer;
```

We will now go to the `vault-init.sh` script in the folder `./config/vault/participants`. Add the following lines to the end of the file:

```bash
put_if_missing secret/signer-key-spacer "@/opt/secrets/my_con/signer-key-spacer.pem"
put_if_missing secret/verifier-key-spacer "@/opt/secrets/my_con/verifier-key-spacer.pem"
```

As you may have noticed, some files need to be created.
For that, create a new folder in the `./config/vault/participants/secrets` folder with the `name` of your connector, in this case `spacer`.

For two variables (e.g. `signer-key-spacer.pem` and `verifier-key-spacer.pem`), use the following commands in your secret folder to generate them:

```bash
$ openssl genrsa -out signer-key-spacer.pem 2048
$ openssl rsa -in signer-key-spacer.pem -outform PEM -pubout -out verifier-key-spacer.pem
```

In the next step, we need to adjust the `docker-compose-participant.yaml` file. 
Add the following configuration after the definition of participant `bob`.
You can interpret the following as a template to add further participants.

```bash
controlplane-spacer:
    image: ghcr.io/re4de/connector-controlplane-dcp:1.1.3-edc0.14.0                         # Do not change
    ports:
      - "38181:8181"                                                                        # Increment first port for any further participant
      - "37171:17171"                                                                       # Increment first port for any further participant
    networks:
      - default                                                                             # Do not change
      - dataspace-net                                                                       # Do not change
    depends_on:
      postgresql:
        condition: service_healthy                                                          # Do not change
        restart: true                                                                       # Do not change
      vault:
        condition: service_healthy                                                          # Do not change
        restart: true                                                                       # Do not change
    environment:
      EDC_PARTICIPANT_ID: did:web:identityhub-spacer%3A10100:spacer                         # Your DID
      EDC_COMPONENT_ID: spacer-controlplane                                                 # Use company name for unique name
      EDC_HOSTNAME: controlplane-spacer                                                     # Use company name for unique name
      EDC_IAM_ISSUER_ID: did:web:identityhub-spacer%3A10100:spacer                          # Your DID
      EDC_IAM_DID_WEB_USE_HTTPS: false                                                      # Do not change
      EDC_IAM_STS_OAUTH_TOKEN_URL: http://identityhub-spacer:9292/api/sts/token             # Use hostname of the identity hub
      EDC_IAM_STS_OAUTH_CLIENT_ID: did:web:identityhub-spacer%3A10100:spacer                # Your DID
      EDC_IAM_STS_OAUTH_CLIENT_SECRET_ALIAS: spacer-sts-client-secret                       # Use company name for unique name
      EDC_IAM_CREDENTIAL_REVOCATION_MIMETYPE: application/json                              # Do not change
      EDC_IAM_TRUSTED-ISSUER_0_ID: did:web:issuer%3A10100:issuer                            # Do not change
      EDC_VAULT_HASHICORP_URL: http://vault:8200                                            # Do not change
      EDC_VAULT_HASHICORP_TOKEN: devpass                                                    # Do not change
      EDC_POLICY_MONITOR_STATE-MACHINE_ITERATION-WAIT-MILLIS: 30000                         # Do not change
      WEB_HTTP_PORT: 8180                                                                   # Do not change
      WEB_HTTP_MANAGEMENT_AUTH_TYPE: tokenbased                                             # Do not change
      WEB_HTTP_MANAGEMENT_AUTH_KEY: devpass                                                 # Do not change
      EDC_SQL_SCHEMA_AUTOCREATE: true                                                       # Do not change
      EDC_DATASOURCE_DEFAULT_USER: edc_spacer                                               # Need to equal to the user name you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_PASSWORD: devpass                                              # Need to equal to the user password you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_URL: jdbc:postgresql://postgresql:5432/edc_spacer              # Depends on the two env vars you used above this
      EDC_CATALOG_REGISTRY_URL: http://connector-registry:3000/api/registry                 # Do not change
      EDC_CATALOG_REGISTRY_API_KEY: devpass                                                 # Do not change
      EDC_CATALOG_CACHE_EXECUTION_PERIOD_SECONDS: 30000                                     # Do not change
      EDC_CATALOG_CACHE_EXECUTION_DELAY_SECONDS: 5                                          # Do not change
      EDC_CATALOG_CACHE_PARTITION_NUM_CRAWLERS: 5                                           # Do not change
      EDC_REGISTRATION_KEYS_NAME_OVERWRITE: spacer                                          # Use company name
      EDC_REGISTRATION_MARKETPARTNER_ISSUANCE_ENABLED: true                                 # Do not change
      EDC_REGISTRATION_REGISTRY_URL: http://connector-registry:3000/api/registry            # Do not change
      EDC_REGISTRATION_REGISTRY_API_KEY: devpass                                            # Do not change
      EDC_REGISTRATION_IH_IDENTITY_URL: http://identityhub-spacer:15151/api/identity        # Use hostname of the identity hub
      EDC_REGISTRATION_IH_CREDENTIALS_URL: http://identityhub-spacer:13131/api/credentials  # Use hostname of the identity hub
      EDC_REGISTRATION_ISSUER_DID: did:web:issuer%3A10100:issuer                            # Do not change
      EDC_POLICY_PM_URL: https://api-nprd.traxes.io/prprd/forwatt/v2                        # Do not change
      EDC_POLICY_PM_TOKEN_URL: https://acc.signin.energy/am/oauth2/realms/root/realms/difesp/access_token # Do not change
      EDC_POLICY_PM_TOKEN_CLIENT-ID: change-me                                              # Do not change
      EDC_POLICY_PM_TOKEN_CLIENT-SECRET-ALIAS: pm-secret                                    # Do not change
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8180/api/check/health"]             # Do not change
      interval: 10s                                                                         # Do not change
      timeout: 10s                                                                          # Do not change
      retries: 5                                                                            # Do not change
      start_period: 30s                                                                     # Do not change

  identityhub-spacer:
    image: ghcr.io/re4de/identity-hub:1.0.0-edc0.14.0                                       # Do not change
    networks:
      - default                                                                             # Do not change
      - dataspace-net                                                                       # Do not change
    depends_on:
      postgresql:
        condition: service_healthy                                                          # Do not change
        restart: true                                                                       # Do not change
      vault:
        condition: service_healthy                                                          # Do not change
        restart: true                                                                       # Do not change
    environment:
      EDC_PARTICIPANT_ID: did:web:identityhub-spacer%3A10100:spacer                         # Your DID
      EDC_COMPONENT_ID: spacer-identityhub                                                  # Use company name for unique name
      EDC_HOSTNAME: identityhub-spacer                                                      # Use company name for unique name
      EDC_IAM_DID_WEB_USE_HTTPS: false                                                      # Do not change
      EDC_ISSUER_API_SUPERUSER_KEY: c3VwZXItdXNlcg==.devpass                                # Do not change
      WEB_HTTP_PORT: 8180                                                                   # Do not change
      EDC_VAULT_HASHICORP_URL: http://vault:8200                                            # Do not change
      EDC_VAULT_HASHICORP_TOKEN: devpass                                                    # Do not change
      EDC_SQL_SCHEMA_AUTOCREATE: true                                                       # Do not change
      EDC_DATASOURCE_DEFAULT_USER: edc_spacer                                               # Need to equal to the user name you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_PASSWORD: devpass                                              # Need to equal to the user password you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_URL: jdbc:postgresql://postgresql:5432/edc_spacer              # Depends on the two env vars you used above this
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8180/api/check/health"]             # Do not change
      interval: 10s                                                                         # Do not change
      timeout: 10s                                                                          # Do not change
      retries: 5                                                                            # Do not change
      start_period: 30s                                                                     # Do not change

  dataplane-spacer:
    image: ghcr.io/re4de/connector-dataplane:1.1.3-edc0.14.0                                # Do not change
    ports:
      - "38185:8185"                                                                        # Increment first port for any further participant
    networks:
      - default                                                                             # Do not change
      - dataspace-net                                                                       # Do not change
    depends_on:
      controlplane-spacer:
        condition: service_healthy                                                          # Do not change
        restart: true                                                                       # Do not change
    environment:
      EDC_PARTICIPANT_ID: did:web:identityhub-spacer%3A10100:spacer                         # Your DID
      EDC_COMPONENT_ID: spacer-dataplane                                                    # Use company name for unique name
      EDC_HOSTNAME: dataplane-spacer                                                        # Use company name for unique name
      EDC_VAULT_HASHICORP_URL: http://vault:8200                                            # Do not change
      EDC_VAULT_HASHICORP_TOKEN: devpass                                                    # Do not change
      WEB_HTTP_PORT: 8180                                                                   # Do not change
      EDC_SQL_SCHEMA_AUTOCREATE: true                                                       # Do not change
      EDC_DATASOURCE_DEFAULT_USER: edc_spacer                                               # Need to equal to the user name you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_PASSWORD: devpass                                              # Need to equal to the user password you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_URL: jdbc:postgresql://postgresql:5432/edc_spacer              # Depends on the two env vars you used above this
      EDC_DPF_SELECTOR_URL: http://controlplane-spacer:9191/api/control/v1/dataplanes       # Hostname need to be equal with the service name of the control plane service, do not change port 
      EDC_DATAPLANE_API_PUBLIC_BASEURL: http://localhost:8185/api/public                    # Do not change
      EDC_TRANSFER_PROXY_TOKEN_SIGNER_PRIVATEKEY_ALIAS: signer-key-spacer                   # Same name as defined in vault-init.sh
      EDC_TRANSFER_PROXY_TOKEN_VERIFIER_PUBLICKEY_ALIAS: verifier-key-spacer                # Same name as defined in vault-init.sh
```

Run the following command to apply the changes:

```bash
$ docker compose -f docker-compose-participants.yaml up -d
```

### 05. Offboard a participant technically (optional)

To offboard a participant, revert your changes to the `init-db.sql`, `vault-init.sh`, and `docker-compose-participant.yaml` files.
After that, run the following command:

```bash
$ docker compose -f docker-compose-participants.yaml up -d
```