# Dataspace Setup with OAuth2

This setup is only meant as a technology showcase. 
We do not recommend reusing the current architecture and steps as a production-ready solution. 

## Dataspace Architecture

![architecture](./doc/img/architecture.jpg)

In this setup, there are two needed central services `Keycloak` and the `Connector Registry`, often provided by a dataspace operator. 
`Keycloak` acts as an identity provider and issues a [JWT](https://datatracker.ietf.org/doc/html/rfc7519) that the `Connectors` use to authenticate 
each other via well-known `OAuth2` endpoints.
The `Connector Registry` is a phonebook that holds a list of all available participants and delivers it, including their identities and the `DSP URL`. 

## Step-by-Step Setup

For this step-by-step description, you need the following software installed on your computer:

- Container Engine, such as Docker
- Terminal 
- API Tool, such as cURL or Postman

### 01. Start central services

Open a Terminal and execute the following commands:
```sh
$ cd ./01-basic-setup/01-01-oauth
$ docker compose -f docker-compose-central.yaml up -d
```
With these commands you will start an instance of `Keycloak` and the `Connector Registry`.
Both are already pre-configured. 

### 02. Check everything is up and running

Check the status of the containers in Docker Desktop or with the `docker ps` command.
Check the logs for any Errors. If you are not able to resolve the issue, feel free to open an `Issue`!

### 03. Onboard a participant



### 04. Offboard a participant