# Dataspace Setup with X.509

This setup is only meant as a technology showcase. 
We do not recommend reusing the architecture and steps as a production-ready solution. 

## Dataspace Architecture

![architecture](./doc/img/architecture.jpg)

In this setup, there are two needed central services `Keycloak` and the `Connector Registry`, often provided by a dataspace operator. 
`Keycloak` acts as an identity provider and issues a [JWT](https://datatracker.ietf.org/doc/html/rfc7519) that the `Connectors` use to authenticate 
each other via well-known `OAuth2` endpoints.
Additionally, an `Nginx` reverse proxy in front of `Keycloak` performs `TLS` termination, 
extracts an incoming `client certificate` into a proxy header, and forwards it to `Keycloak`.
The `Connector Registry` is a phonebook that holds a list of all available participants and delivers it, including their identities and the `DSP URL`. 

> [!Important]
> The architecture is the same as for the `OAuth2` setup, but in this setup we will use `X.509` certificates instead of `client-id` and `client-secret` to authenticate a connector. This allows PKI-based authentication to be incorporated into the dataspace. 

> [!Caution]
> Nevertheless, this setup also leads to strong coupling among participants, which runs counter to the paradigms of a dataspace.

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
With these commands you will start an instance of `Keycloak`, `Nginx` and the `Connector Registry`.
All of them are already pre-configured. 

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
- Generate the needed `X.509` certificates.
- Add a new pair of `Control Plane` and `Data Plane` to the `docker-compose-participants.yaml` file.

> [!IMPORTANT]
> Be aware that the following description only applies to this MVD setup!

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
In this setup, we will use `X509 Certificates`. 
Follow these steps.

1. Choose created client from list by clicking the `Client ID`, e.g. `my-con`
2. Switch the tab to `Credentials`
3. Choose `X509 Certificates` in the `Client Authenticator` dropdown
4. Toggle `Alow regex pattern comparison`, if is not checked
5. Set `SubjectDN` to what you will use later in your certificate, like `(.*?)CN=MY-CON.EMT.API(.*?)(?:$)`
6. Click `Save` and confirm the popup

#### Generate the needed X.509 certificates

Use the following commands from the section [06](#regenrate-alices-client-certificate-and-key)
to generate you new client certificates.

```bash
# Generate certificate signing request and key for my-con
$ openssl req -sha384 -newkey ec -pkeyopt ec_paramgen_curve:brainpoolP256r1 -keyout my-con.key -nodes -out my-con.csr -subj "/CN=MY-CON.EMT.API/O=SM-PKI-DE/OU=Fraunhofer IEE/C=DE/serialNumber=10/L=Kassel/ST=Hessen"

# Create certificate for Alice from the Sub-CA using the certificate signing request
$ openssl x509 -req -CA sub-ca.crt -CAkey sub-ca.key -in my-con.csr -out my-con.crt -days 36500 -sha384 -CAcreateserial -extfile my-con.v3.ext
```

> [!IMPORTANT]
> Copy the `alice.v3.ext` and use your values. Also be aware to use a `serialNumber` that is not taken.

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

We will now go to the `vault-init.sh` script in the folder `./config/vault`. Add the following lines to the end of the file:

```bash
put_if_missing secret/my-con-client-cert "@/opt/certs/my-con.crt"
put_if_missing secret/my-con-client-key "@/opt/certs/my-con.key"
put_if_missing secret/signer-key-my-con "@/opt/secrets/my_con/signer-key-my-con.pem"
put_if_missing secret/verifier-key-my-con "@/opt/secrets/my_con/verifier-key-my-con.pem"
```

As you may have noticed, some files need to be created.
For that, create a new folder in the `./config/vault/secrets` folder with the `participantId` of your connector as the name, e.g., `my-con`.
The `my-con.crt` and `my-con.key` were generated by the last step and need to be copied in the `vault/secrets` folder. 

For the other two variables (e.g. `signer-key-my-con.pem` and `verifier-key-my-con.pem`), use the following commands in your secret folder to generate them:

```bash
$ openssl genrsa -out signer-key-my-con.pem 2048
$ openssl rsa -in signer-key-my-con.pem -outform PEM -pubout -out verifier-key-my-con.pem
```

In the next step, we need to adjust the `docker-compose-participant.yaml` file. 
Add the following configuration after the definition of participant `bob`.
You can interpret the following as a template to add further participants.

```bash
  controlplane-my-con:
    image: ghcr.io/re4de/connector-controlplane-x509:1.2.2-edc0.14.0                    # Do not change
    ports:
      - "38181:8181"                                                                    # Increment first port for any further participant
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
      EDC_X509_CLIENT_ID: my-con                                                        # Need to be equal with the client name in Keycloak
      EDC_X509_CERTIFICATE_ALIAS: my-con-client-cert                                    # Same name as imported certificate from the vault
      EDC_X509_KEY_ALIAS: my-con-client-key                                             # Same name as imported certificate from the vault
      EDC_X509_TOKEN_URL: https://nginx/realms/demo-dataspace/protocol/openid-connect/token           # Do not change
      EDC_X509_JWKS_URL: http://keycloak:8080/realms/demo-dataspace/protocol/openid-connect/certs     # Do not change
      EDC_VAULT_HASHICORP_URL: http://vault:8200                                        # Do not change
      EDC_VAULT_HASHICORP_TOKEN: devpass                                                # Do not change
      EDC_POLICY_MONITOR_STATE-MACHINE_ITERATION-WAIT-MILLIS: 30000                     # Do not change
      WEB_HTTP_PORT: 8180                                                               # Do not change
      WEB_HTTP_MANAGEMENT_AUTH_TYPE: tokenbased                                         # Do not change
      WEB_HTTP_MANAGEMENT_AUTH_KEY: devpass                                             # Do not change
      EDC_SQL_SCHEMA_AUTOCREATE: true                                                   # Do not change
      EDC_DATASOURCE_DEFAULT_USER: edc_my_con                                           # Need to equal to the user name you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_PASSWORD: devpass                                          # Need to equal to the user password you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_URL: jdbc:postgresql://postgresql:5432/edc_my_con          # Depends on the two env vars you used above this
      EDC_CATALOG_REGISTRY_URL: http://connector-registry:3000/api/registry             # Do not change
      EDC_CATALOG_REGISTRY_API_KEY: devpass                                             # Do not change
      EDC_CATALOG_CACHE_EXECUTION_PERIOD_SECONDS: 300                                   # Do not change
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
    image: ghcr.io/re4de/connector-dataplane:1.2.2-edc0.14.0                            # Do not change
    ports:
      - "38185:8185"                                                                    # Increment first port for any further participant
    networks:
      - default                                                                         # Do not change
      - dataspace-net                                                                   # Do not change
    depends_on:
      controlplane-my-con:
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
      EDC_DATASOURCE_DEFAULT_USER: edc_my_con                                           # Need to equal to the user name you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_PASSWORD: devpass                                          # Need to equal to the user password you used in the init-db.sql script
      EDC_DATASOURCE_DEFAULT_URL: jdbc:postgresql://postgresql:5432/edc_my_con          # Depends on the two env vars you used above this
      EDC_DPF_SELECTOR_URL: http://controlplane-my-con:9191/api/control/v1/dataplanes   # Hostname need to be equal with the service name of the control plane service, do not change port 
      EDC_DATAPLANE_API_PUBLIC_BASEURL: http://localhost:8185/api/public                # Do not change
      EDC_TRANSFER_PROXY_TOKEN_SIGNER_PRIVATEKEY_ALIAS: signer-key-my-con               # Same name as defined in vault-init.sh
      EDC_TRANSFER_PROXY_TOKEN_VERIFIER_PUBLICKEY_ALIAS: verifier-key-my-con            # Same name as defined in vault-init.sh
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8180/api/check/health"]         # Do not change
      interval: 10s                                                                     # Do not change
      timeout: 10s                                                                      # Do not change
      retries: 5                                                                        # Do not change
      start_period: 30s                                                                 # Do not change
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

And, finally, delete the generated certificate and key.

### 06. Regenrate certificates and keys (optional)

To regenrate the key material, follow these steps.

#### Regenerate CA

```bash
$ cd /config/certs

# Generates Root-CA certificate and key
$ openssl req -x509 -sha512 -days 36500 -newkey ec -pkeyopt ec_paramgen_curve:brainpoolP512r1 -keyout ca.key -nodes -out ca.crt -subj "/CN=SM-Root.CA/O=SM-PKI-DE/OU=Fraunhofer IEE/C=DE/serialNumber=1" -extensions v3_req -config ca.v3.ext
```

#### Regenerate Sub-CA

```bash
# Generate certificate signing request and key for the Sub-CA
$ openssl req -sha512 -newkey ec -pkeyopt ec_paramgen_curve:brainpoolP384r1 -keyout sub-ca.key -nodes -out sub-ca.csr -subj "/CN=Fraunhofer-SM-Sub.CA/O=SM-PKI-DE/OU=Fraunhofer IEE/C=DE/serialNumber=2"

# Create certificate for the Sub-CA from the Root-CA using the certificate signing request
$ openssl x509 -req -CA ca.crt -CAkey ca.key -in sub-ca.csr -out sub-ca.crt -days 36500 -sha512 -CAcreateserial -extfile sub-ca.v3.ext
```

#### Regenerate Keycloak server certificate and key

```bash
# Generate certificate signing request and key for Keycloak
$ openssl req -sha384 -newkey ec -pkeyopt ec_paramgen_curve:brainpoolP256r1 -keyout keycloak.key -nodes -out keycloak.csr -subj "/CN=nginx/O=SM-PKI-DE/OU=Fraunhofer IEE/C=DE/serialNumber=3/L=Kassel/ST=Hessen"

# Create certificate for Keycloak from the Sub-CA using the certificate signing request
$ openssl x509 -req -CA sub-ca.crt -CAkey sub-ca.key -in keycloak.csr -out keycloak.crt -days 36500 -sha384 -CAcreateserial -extfile keycloak.v3.ext
```

#### Regenrate Alices client certificate and key

```bash
# Generate certificate signing request and key for Alice
$ openssl req -sha384 -newkey ec -pkeyopt ec_paramgen_curve:brainpoolP256r1 -keyout alice.key -nodes -out alice.csr -subj "/CN=Alice.EMT.API/O=SM-PKI-DE/OU=Fraunhofer IEE/C=DE/serialNumber=4/L=Kassel/ST=Hessen"

# Create certificate for Alice from the Sub-CA using the certificate signing request
$ openssl x509 -req -CA sub-ca.crt -CAkey sub-ca.key -in alice.csr -out alice.crt -days 36500 -sha384 -CAcreateserial -extfile alice.v3.ext
```

#### Regenrate Bobs client certificate and key

```bash
# Generate certificate signing request and key for Bob
$ openssl req -sha384 -newkey ec -pkeyopt ec_paramgen_curve:brainpoolP256r1 -keyout bob.key -nodes -out bob.csr -subj "/CN=Bob.EMT.API/O=SM-PKI-DE/OU=Fraunhofer IEE/C=DE/serialNumber=5/L=Kassel/ST=Hessen"

# Create certificate for Bob from the Sub-CA using the certificate signing request
$ openssl x509 -req -CA sub-ca.crt -CAkey sub-ca.key -in bob.csr -out bob.crt -days 36500 -sha384 -CAcreateserial -extfile bob.v3.ext
```