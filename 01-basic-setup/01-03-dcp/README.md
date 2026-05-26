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

### 05. Offboard a participant technically (optional)