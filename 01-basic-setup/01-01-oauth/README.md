# Dataspace Setup with OAuth2

This setup is only meant as a technology showcase. 
We do not recommend reusing the architecture and steps as a production-ready solution. 

## Dataspace Architecture

![architecture](./doc/img/architecture.jpg)

In this setup, there are two needed central services `Keycloak` and the `Connector Registry`, often provided by a dataspace operator. 
`Keycloak` acts as an identity provider and issues a [JWT](https://datatracker.ietf.org/doc/html/rfc7519) that the `Connectors` use to authenticate 
each other via well-known `OAuth2` endpoints.
The `Connector Registry` is a phonebook that holds a list of all available participants and delivers it, including their identities and the `DSP URL`. 

## Step-by-Step Setup

For this step-by-step description, you need the following software installed on your computer:

- Container Engine, such as `Docker` or `Podman`
- Terminal 
- API Tool, such as `cURL` or `Postman`

### 01. Start central services

Open a Terminal and execute the following commands:
```sh
$ cd ./01-basic-setup/01-01-oauth
$ docker network create dataspace-net
$ docker compose -f docker-compose-central.yaml up -d
```
With these commands you will start an instance of `Keycloak` and the `Connector Registry`.
Both are already pre-configured. 

### 02. Check everything is up and running

Check the status of the containers in `Docker Desktop` or with the `docker ps` command.
Check the logs for any errors.

### 03. Start the participants

Back to your terminal, run the following commands:
```sh
$ docker compose -f docker-compose-participants.yaml up -d
```
With this command, you start two participants with dedicated `Control` and `Data Planes` but a shared `PostgreSQL` and `HashiCorp Vault` instance.
You are now ready to go through our [Feature Showcase](../../02-features/README.md).

### 04. Onboard a participant technically (optional)

The technical onboarding expects that all organizational contracts or requirements are completed, and that a new participant needs to be created on the technical side. 
In this setup, with `Keycloak` as the central identity provider, the following steps for the onboarding are:
- Create a new technical user within `Keycloak`.
- Add a new pair of `Control Plane` and `Data Plane` to the `docker-compose-participants.yaml` file .

```
Be aware that the following description only applies to this MVD setup!
```

#### Create a technical user within Keycloak

Follow these steps to create a new client in `Keycloak`.
The description expecting that the `docker-compose-central.yaml` is up and running.

1. Login to `Keyloak` using `admin:devpass` under `http://localhost:8080`
2. Switch Realm to `demo-dataspace`
3. Goto `Clients`
4. Click `Create client`
5. Set `ClientID` and `Name` to a unique id, e.g. `my-con`. This ID need to be used as the `participantId` later!
6. Click `Next`
7. Toggle `Client authentication` to `On`
8. Uncheck `Standard flow` and if checked `Direct access grants`
8. Check `Service accounts roles`
9. Click `Next` and then click `Save`

After the client has been created, you need to configure the authentication method.
In this setup, we will use `Signed JWT`. 
Follow these steps.

1. Choose created client from list by clicking the `Client ID`, e.g. `my-con`
2. Switch the tab to `Credentials`
3. Choose `Signed JWT` in the `Client Authenticator` dropdown
4. Click `Save` and confirm the popup
5. Switch the tab to `Keys`
6. Click `Generate new keys`
7. Fill in the fields `Key password` and `Store password`, e.g. devpass
8. Click `Generate` in the popup and `Save` afterwards

A download of `keystore.jks` will run in the background. From this file, we will later extract configuration parameters. 
Rename the keystore file to the connector name, e.g., `my-con.jks`.

#### Configure the connector through Docker Compose

Before we configure the connector, we need to add configuration to the `PostgreSQL` and `HashiCorp Vault` deployments.
Open the `init-db.sql` from the `./config/postgres` folder. Adjust the file as follows.

```sql
-- Create a user and database for bob
CREATE USER edc_bob WITH PASSWORD 'devpass';
CREATE DATABASE edc_bob;
GRANT ALL PRIVILEGES ON DATABASE edc_bob TO edc_bob;

-- Your new participant
CREATE USER edc_my_con WITH PASSWORD 'devpass';
CREATE DATABASE edc_my_con;
GRANT ALL PRIVILEGES ON DATABASE edc_my_con TO edc_my_con;

-- Grant access to public schemas
\c edc_alice postgres
GRANT ALL ON SCHEMA public TO edc_alice;
\c edc_bob postgres
GRANT ALL ON SCHEMA public TO edc_bob;
-- Your new participant
\c edc_my_con postgres
GRANT ALL ON SCHEMA public TO edc_my_con;
```

We will now go to the `vault-init.sh` script in the folder `./config/postgres`. Add the following lines to the end of the file:

```bash
put_if_missing secret/auth-cert-my_con "@/opt/secrets/my_con/auth-cert-my_con.pem"
put_if_missing secret/auth-key-my_con "@/opt/secrets/my_con/auth-key-my_con.pem"
put_if_missing secret/signer-key-my_con "@/opt/secrets/my_con/signer-key-my_con.pem"
put_if_missing secret/verifier-key-my_con "@/opt/secrets/my_con/verifier-key-my_con.pem"
```

As you may have noticed, some files need to be created.
For that, create a new folder in the `./config/secrets` folder with the `participantId` of your connector as the name, e.g., `my-con`.
Now, create a file `auth-key-my_con.pem` and put the `private key` from the previously saved `my-con.jks` keystore. 
Repeat the same for the `auth-cert-my_con.pem`, but this time with the `certificate`.

For the other two variables (e.g. `signer-key-my_con.pem` and `verifier-key-my_con.pem`), use the following commands in your secret folder to generate them:

```bash
$ openssl genrsa -out signer-key-my_con.pem 2048
$ openssl rsa -in signer-key-my_con.pem -outform PEM -pubout -out verifier-key-my_con.pem
```

In the next step, we need to adjust the `docker-compose-participant.yaml` file. 
Add the following configuration after the definition of participant `bob`.
You can interpret the following as a template to add further participants.

```bash
  controlplane-my-con:
    image: ghcr.io/re4de/connector-controlplane-oauth2:1.1.3-edc0.14.0                  # Do not change
    ports:
      - "38181:8181"                                                                    # Increment first port for any further participant
      - "38282:8282"                                                                    # Increment first port for any further participant
      - "37171:17171"                                                                   # Increment first port for any further participant
    networks:
      - default                                                                         # Do not change
      - dataspace-net                                                                   # Do not change
    depends_on:
      postgresql:
        condition: service_healthy                                                      # Do not change
        restart: true                                                                   # Do not change
      vault:
        condition: service_healthy                                                      # Do not change
        restart: true                                                                   # Do not change
    environment:
      EDC_PARTICIPANT_ID: my-con                                                        # Need to be equal with the client name in Keycloak
      EDC_COMPONENT_ID: my-con-controlplane                                             # Use participantId for unique name
      EDC_HOSTNAME: controlplane-my-con                                                 # Use participantId for unique name
      EDC_OAUTH_CLIENT_ID: my-con                                                       # Need to be equal with the client name in Keycloak
      EDC_OAUTH_TOKEN_URL: http://keycloak:8080/realms/demo-dataspace/protocol/openid-connect/token             # Do not change
      EDC_OAUTH_PROVIDER_JWKS_URL: http://keycloak:8080/realms/demo-dataspace/protocol/openid-connect/certs     # Do not change
      EDC_OAUTH_PROVIDER_AUDIENCE: http://keycloak:8080/realms/demo-dataspace/protocol/openid-connect/token     # Do not change
      EDC_OAUTH_CERTIFICATE_ALIAS: auth-cert-my-co                                      # Use participantId for unique name
      EDC_OAUTH_PRIVATE_KEY_ALIAS: auth-key-my-con                                      # Use participantId for unique name
      EDC_VAULT_HASHICORP_URL: http://vault:8200                                        # Do not change
      EDC_VAULT_HASHICORP_TOKEN: devpass                                                # Do not change
      EDC_POLICY_MONITOR_STATE-MACHINE_ITERATION-WAIT-MILLIS: 30000                     # Do not change
      WEB_HTTP_PORT: 8180                                                               # Do not change
      WEB_HTTP_MANAGEMENT_AUTH_TYPE: tokenbased                                         # Do not change
      WEB_HTTP_MANAGEMENT_AUTH_KEY: devpass                                             # Do not change
      EDC_SQL_SCHEMA_AUTOCREATE: true                                                   # Do not change
      EDC_DATASOURCE_DEFAULT_USER: edc_my-con                                           # Need to equal to the user name you used in the init-db.sql script
    EDC_DATASOURCE_DEFAULT_PASSWORD: devpass                                            # Need to equal to the user password you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_URL: jdbc:postgresql://postgresql:5432/edc_my-con          # Depends on the two env vars you used above this
      EDC_CATALOG_REGISTRY_URL: http://connector-registry:3000/api/registry             # Do not change
      EDC_CATALOG_REGISTRY_API_KEY: devpass                                             # Do not change
      EDC_CATALOG_CACHE_EXECUTION_PERIOD_SECONDS: 30000                                 # Do not change
      EDC_CATALOG_CACHE_EXECUTION_DELAY_SECONDS: 5                                      # Do not change
      EDC_CATALOG_CACHE_PARTITION_NUM_CRAWLERS: 5                                       # Do not change
      EDC_REGISTRATION_PARTICIPANT_CONTEXT_ENABLED: false                               # Do not change
      EDC_REGISTRATION_MEMBERSHIP_ISSUANCE_ENABLED: false                               # Do not change
      EDC_REGISTRATION_REGISTRY_URL: http://connector-registry:3000/api/registry        # Do not change
      EDC_REGISTRATION_REGISTRY_API_KEY: devpass                                        # Do not change
      EDC_REGISTRATION_IH_IDENTITY_URL: not-used                                        # Do not change
      EDC_REGISTRATION_IH_CREDENTIALS_URL: not-used                                     # Do not change
      EDC_REGISTRATION_ISSUER_DID: not-used                                             # Do not change
      EDC_POLICY_PM_URL: https://api-nprd.traxes.io/prprd/forwatt/v2                    # Do not change
      EDC_POLICY_PM_TOKEN_URL: https://acc.signin.energy/am/oauth2/realms/root/realms/difesp/access_token # Do not change
      EDC_POLICY_PM_TOKEN_CLIENT-ID: change-me                                          # Do not change
      EDC_POLICY_PM_TOKEN_CLIENT-SECRET-ALIAS: pm-secret                                # Do not change
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8180/api/check/health"]         # Do not change
      interval: 10s                                                                     # Do not change
      timeout: 10s                                                                      # Do not change
      retries: 5                                                                        # Do not change
      start_period: 30s                                                                 # Do not change

  dataplane-my-con:
    image: ghcr.io/re4de/connector-dataplane:1.1.3-edc0.14.0                            # Do not change
    ports:
      - "38185:8185"                                                                    # Increment first port for any further participant
    networks:
      - default                                                                         # Do not change
      - dataspace-net                                                                   # Do not change
    depends_on:
      controlplane-bob:
        condition: service_healthy                                                      # Do not change
        restart: true                                                                   # Do not change
    environment:
      EDC_PARTICIPANT_ID: my-con                                                        # Need to be equal with the client name in Keycloak
      EDC_COMPONENT_ID: my-con-dataplane                                                # Use participantId for unique name
      EDC_HOSTNAME: dataplane-my-con                                                    # Use participantId for unique name
      EDC_VAULT_HASHICORP_URL: http://vault:8200                                        # Do not change
      EDC_VAULT_HASHICORP_TOKEN: devpass                                                # Do not change
      WEB_HTTP_PORT: 8180                                                               # Do not change
      EDC_SQL_SCHEMA_AUTOCREATE: true                                                   # Do not change
      EDC_DATASOURCE_DEFAULT_USER: edc_my-con                                           # Need to equal to the user name you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_PASSWORD: devpass                                          # Need to equal to the user password you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_URL: jdbc:postgresql://postgresql:5432/edc_my-con          # Depends on the two env vars you used above this
      EDC_DPF_SELECTOR_URL: http://controlplane-my-con:9191/api/control/v1/dataplanes   # Hostname need to be equal with the service name of the control plane service, do not change port 
      EDC_DATAPLANE_API_PUBLIC_BASEURL: http://localhost:8185/api/public                # Do not change
      EDC_TRANSFER_PROXY_TOKEN_SIGNER_PRIVATEKEY_ALIAS: signer-key-bob                  # Same name as defined in vault-init.sh
      EDC_TRANSFER_PROXY_TOKEN_VERIFIER_PUBLICKEY_ALIAS: verifier-key-bob               # Same name as defined in vault-init.sh
```

Run the following command to apply the changes:

```bash
$ docker compose -f docker-compose-participants.yaml up -d
```

### 05. Offboard a participant technically (optional)

To offboard a participant, revert your changes to the `init-db.sql`, `vault-init.sh`, and `docker-compose-participant.yaml` files. 
After that, remove the client from `Keycloak` and run the following command:

```bash
$ docker compose -f docker-compose-participants.yaml up -d
```