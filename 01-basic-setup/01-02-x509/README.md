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

### 05. Offboard a participant technically (optional)

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