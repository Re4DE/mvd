# Decentralized Catalog

This documentation describes the individual steps involved in providing and retrieving data in a dataspace.
Starting with providing data as an `Asset`, restricting its access with a `Policy`, and making it available in the `Decentralized Catalog` with an `Offer`.
After that, we show how to fetch and further process this data.

## Preparation

Depending on the initially selected `basic setup`, the values used in the following commands may change. 
The following table collects all needed values grouped by each `basic setup`.

| Setup | ParticipantId                           | DSP URL                                     | Data Plane URL                    |
|-------|-----------------------------------------|---------------------------------------------|-----------------------------------|
| oauth | alice                                   | http://controlplane-alice:8282/api/protocol | http://localhost:18185/api/public |
| oauth | bob                                     | http://controlplane-bob:8282/api/protocol   | http://localhost:28185/api/public |
| x509  | ...                                     | ...                                         | ...                               |
| dsp   | did:web:identityhub-alice%3A10100:alice | http://controlplane-alice:8282/api/protocol | http://localhost:18185/api/public |
| dsp   | did:web:identityhub-bob%3A10100:bob     | http://controlplane-bob:8282/api/protocol   | http://localhost:28185/api/public |

## Create an Asset for your data

The `Control Plane's management API` is used for all interactions with the `Connector`.
This API can be used to manage `Assets`, `Policies`, `Offers`, `Contract Negotiations`, and `Data Transfers`.

To create an `Asset`, the following request must be made:

```bash
$ curl -X POST http://localhost:18181/api/management/v3/assets \
    -H "Content-Type: application/json"                        \
    -H "x-api-key: devpass"                                    \
    -d @my-asset.json
```

With the corresponding definition of `my-asset.json`.

```json
{
    "@context": [
        "https://w3id.org/edc/connector/management/v0.0.1"
    ],
    "@id": "my-asset",
    "@type": "Asset",
    "properties": {
        "name": "My Asset",
        "description": "This is a test asset that provides random cat images.",
        "contenttype": "application/json"
    },
    "dataAddress": {
        "@type": "DataAddress",
        "type": "HttpData",
        "baseUrl": "https://api.thecatapi.com/v1/images/search"
    }
}
```
- `@context`: Describes the vocabulary currently used for this request.
- `@id`: The unique ID of the `Asset`. A `UUID` is recommended here.
- `@type`: The schema type of this object, in this case `Asset`.
- `properties`: A collection of attributes that can be freely assigned.
    - `name`: Name of the asset.
    - `description`: Brief description of the data provided by this asset.
    - `contenttype`: Format in which the asset data is delivered.
- `dataAddress`: Configures the API that delivers the data.
    - `@type`: The schema type of this object, in this case `DataAddress`.
    - `type`: Describes the type of data source. We always use `HttpData` here.
    - `baseUrl`: The URL of the API that delivers the data. `This must be the endpoint of your API`.

The `dataAddress` field configures how to interact with your API. 
Various other configurations can be made. 
In the configuration shown here, all requests to the `Data Plane` for this `Asset` are interpreted as `GET` requests to the configured `baseUrl`. 
The `Data Plane` can be seen as a proxy for the actual data-providing APIs. 
We can configure whether incoming `Method`, `Query Parameter`, `Path`, or `Body` are also forwarded. 
This can be achieved with the following attributes in the `dataAddress` field.

```json
{
    ...
    "dataAddress": {
        "@type": "DataAddress",
        "type": "HttpData",
        "baseUrl": "https://api.thecatapi.com/v1/images/search",
        "proxyMethod": "true",
        "proxyPath": "true",
        "proxyQueryParams": "true",
        "proxyBody": "true"
    }
}
```

In this example, the `Method`, an additional `Path` (relative to the `baseUrl`), all `Query Parameters`, and the `Body` are forwarded to the API defined by the `baseUrl`.

If your API requires authentication, the following examples show `Basic Authentication`, an `API Key`, and `OAuth2`. Here, too, all configurations are carried out in the `dataAddress` field.

```json
    ...
    // Basic Authentication
    "dataAddress": {
        "@type": "DataAddress",
        "type": "HttpData",
        "baseUrl": "https://api.thecatapi.com/v1/images/search",
        "authKey": "Authorization",
        "authCode": "Basic ZGV2OmRldnBhc3M="
        // OR
        "secretName": "my-basic-secret"
    }
```

```json
    ...
    // API Key
    "dataAddress": {
        "@type": "DataAddress",
        "type": "HttpData",
        "baseUrl": "https://api.thecatapi.com/v1/images/search",
        "authKey": "api-key",
        "authCode": "devpass"
        // OR
        "secretName": "my-apikey-secret"
    }
```

```json
    ...
    // OAuth2
    "dataAddress": {
        "@type": "DataAddress",
        "type": "HttpData",
        "baseUrl": "https://api.thecatapi.com/v1/images/search",
        "oauth2:tokenUrl": "https://api.identity.example/tokens",
        "oauth2:clientId": "my-api-client",
        "oauth2:clientSecret": "devpass"
        // OR
        "oauth2:clientSecretKey": "my-client-secret"
    }
```

In the examples above, the credentials are set directly with `authCode` or `oauth2:clientSecret`.
The `dataAddress` definition is not accessible from outside the `Connector`; 
nevertheless, it is not recommended to store sensitive data there. 
Therefore, using a secret alias with `secretName` and `oauth2:clientSecretKey` is highly recommended.
The secrets must then be saved in the `Vault`. 

The newly created `Asset` can be checked again with the following request:

```bash
$ curl -X GET http://localhost:18181/api/management/v3/assets/my-asset \
    -H "x-api-key: devpass"
``` 

## Create a Policy for your Asset

After creating an `Asset`, a `Policy` must be generated.
`Policies` can be used to control who can view and use which `Assets` in the dataspace.

Currently, `Re4DE` supports the following `Policies`: 

| Setup | Name                      | Description                                                                                           |
|-------|---------------------------|-------------------------------------------------------------------------------------------------------|
| all   | In Force                  | An interoperable policy for specifying in-force periods for contract agreements                       |
| all   | Identity                  | Checks the identity of a `Connector` through its `participantId`                                      |
| oauth | Permission Administrator  | Integration of the `50Hertz Permission Administrator` to check for granted permissions of a household |
| dsp   | Membership Credential     | Checks whether a requesting `Connector` has an active membership in the dataspace                     |
| dsp   | Market Partner Credential | Checks which role a requesting `Connector` has in the regulated part of the market communication      |

Examples for the `In Force Policy` can be found in the general [EDC documentation](https://eclipse-edc.github.io/documentation/for-adopters/control-plane/policy-engine/#in-force-policy). 
The `Permission Administrator Policy` is shown in another [feature showcase](../02-02-pa/README.md).
The credentials-related and `Identity` `Policies` are documented in the [Re4DE Connector](https://github.com/Re4DE/connector/blob/main/extensions/control-plane/policy-functions/README.md).
A deeper look into the credential-related `Policies` is presented in the [SM-PKI showcase](../02-03-sm-pki/README.md).
In this showcase, we will create an `open-for-all Policy`.

To create a `Policy` that can be considered `open-for-all`, the following request must be made:

```bash
$ curl -X POST http://localhost:18181/api/management/v3/policydefinitions \
    -H "Content-Type: application/json"                                   \
    -H "x-api-key: devpass"                                               \
    -d @my-policy.json
```

With the corresponding definition of `my-policy.json`.

```json
{
    "@context": [
        "https://w3id.org/edc/connector/management/v0.0.1"
    ],
    "@id": "all",
    "@type": "PolicyDefinition",
    "policy": {
        "@type": "Set",
        "permission": [],
        "prohibition": [],
        "obligation": []
    }
}
```
- `@context`: Describes the vocabulary currently used for this request.
- `@id`: The unique ID of the `Policy`.
- `@type`: The schema type of this object, in this case `PolicyDefinition`.
- `policy`: The exact configuration of the `Policy`.
    - `@type`: The schema type of this object, in this case `Set`.
    - `permission`: A list of permissions. This corresponds to a list of "requirements" that a `Connector` must meet.
    - `prohibition`: A list of prohibitions that a requesting `Connector` must not fulfill. This can also be interpreted as a negated obligation.
    - `obligation`: A list of obligations that a requesting `Connector` must fulfill. E.g., a specific identity.

In the above example, neither `Permissions`, `Prohibitions` nor `Obligations` are defined. 
As a result, an `Asset` that is linked to this `Policy` via an `Offer` is not subject to any restrictions and can therefore be viewed and used by all dataspace participants.

The newly created `Policy` can be checked with the following request:

```bash
$ curl -X GET http://localhost:18181/api/management/v3/policydefinitions/all \
    -H "x-api-key: devpass"
``` 

## Create an Offer for the Asset and publish it

Next, an `Offer` must be created. This links `Assets` with `Policies` and ultimately represents an entry in the `Decentralized Catalog`.

To generate an `Offer`, the following request must be made:

```bash
$ curl -X POST http://localhost:18181/api/management/v3/contractdefinitions \
    -H "Content-Type: application/json"                                     \
    -H "x-api-key: devpass"                                                 \
    -d @my-offer.json
```

With the corresponding definition of `my-offer.json`.

```json
{
    "@context": [
        "https://w3id.org/edc/connector/management/v0.0.1"
    ],
    "@id": "my-offer",
    "@type": "ContractDefinition",
    "accessPolicyId": "all",
    "contractPolicyId": "all",
    "assetsSelector": [
        {
            "@type": "Criterion",
            "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
            "operator": "=",
            "operandRight": "my-asset"
        }
    ]
}
```
- `@context`: Describes the vocabulary currently used for this request.
- `@id`: The unique ID of the `Offer`.
- `@type`: The schema type of this object, in this case `ContractDefinition`.
- `accessPolicyId`: The ID of the `Policy` that controls the visibility of this `Offer`.
- `contractPolicyId`: The ID of the `Policy` that controls the usability of this `Offer`.
- `assetsSelector`: This is used to configure which `Asset` this `Offer` should apply to.
    - `@type`: The schema type of this object, in this case `Criterion`.
    - `operandLeft`: Which field of the `Asset` definition should be used for selection.
    - `operator`: How to compare, `=` should always be used here.
    - `operandRight`: What value should be in the field defined with `operandLeft`.

As shown in the example above, it is entirely possible to define multiple `Policies` to control visibility and access in the dataspace.
There may be cases where an `Asset` can be viewed by all participants, but access to this `Asset` is subject to certain rules.

To check whether everything has been configured correctly, we can query our own catalog with the following command:

```bash
$ curl -X POST http://localhost:18181/api/management/v3/catalog/request \
    -H "Content-Type: application/json"                                 \
    -H "x-api-key: devpass"                                             \
    -d @catalog-request.json
```

With the corresponding definition of `catalog-request.json`.

```json
{
    "@context": [
        "https://w3id.org/edc/connector/management/v0.0.1"
    ],
    "@type": "CatalogRequest",
    "counterPartyAddress": "http://controlplane-alice:8282/api/protocol",
    "counterPartyId": "did:web:identityhub-alice%3A10100:alice",
    "protocol": "dataspace-protocol-http"
}
```
- `@context`: Describes the vocabulary currently used for this request.
- `@type`: The schema type of this object, in this case `CatalogRequest`.
- `counterPartyAddress`: The `DSP URL` of the `Producer` from which the catalog is to be retrieved.
- `counterPartyId`: The participantId of the `Producer` from which the catalog is to be retrieved.
- `protocol`: The underlying protocol that the `Connectors` are to use for exchange; this must always be `dataspace-protocol-http`.

Since we do not want to view the catalog of another `Connector` in this example, but rather our own, it is important to ensure that the `counterPartyAddress` field is filled with `Alice's` `DSP URL` and the `counterPartyId` field is filled with her `ParticipantId` from the table from the beginning.

After the request, we should be able to see our created `Offer` in our own catalog.

## Negotiate a contract with another participant

At this point, we shift our perspective from `Alice` (the data producer) to Bob (the data consumer). 
Also, this is the moment where we will use the `Decentralized Catalog` to access the previously created `Asset` of `Alice`.  

There are two different catalogs in the dataspace. 
The first one we used in the last step to check our own `Offer`. 
That catalog is called the `Connector Catalog` because it represents all `Offers` from a single participant. 
On the other hand, the `Decentralized Catalog` is a full catalog containing all `Offers` from all participants. 
The `Decentralized Catalog` crawls all other `Connector Catalogs` every 5 minutes (as configured in the basic setup) and merges them into a single catalog that represents the dataspace. 

Now, we continue retrieving data from `Alice`. 
To do this, a contract must first be negotiated. 
In this process, both `Connectors` agree that the `Consumer` accepts the `Producer's` `Policies`. 

First, we need to retrieve the `Decentralized Catalog` to get an overview of all available `Assets` of all participants. 

To do this, use the following request:

```bash
$ curl -X POST http://localhost:27171/api/catalog/v1alpha/catalog/query \
    -H "Content-Type: application/json"                                 \
    -H "x-api-key: devpass"                                             \
    -d @full-catalog-request.json
```

With the corresponding definition of `full-catalog-request.json`.

```json
{
  "@context": [
    "https://w3id.org/edc/connector/management/v0.0.1"
  ],
  "@type": "QuerySpec"
}
```
- `@context`: Describes the vocabulary currently used for this query.
- `@type`: The schema type of this object, in this case `QuerySpec`.


```
It takes 5 minutes for the Decentralized Catalog to update its entries. If your Asset does not appear in Bob's Decentralized Catalog, you need to wait a bit.
```

Since the `QuerySpec` imposes no further restrictions, this query returns all `Assets` for all participants. 
A restriction of this list can be achieved as follows:

```json
{
  "@context": [
    "https://w3id.org/edc/connector/management/v0.0.1"
  ],
  "@type": "QuerySpec",
  "offset": 0,
  "limit": 20
}
```

In this example, the first 20 entries in the `Decentralized Catalog` are returned.
Entries can be skipped using `offset` and the maximum number can be limited using `limit`.
With an `offset` of 5 and a `limit` of 15, the first 5 `Assets` would be skipped and the following 15 would be returned.

Check that these four fields exist, as they must be taken from the catalog for further queries:

- `dspace:participantId`: The unique participantId of `Alice`. (Need to match with values from the table)
- `originator`: The `DSP URL` of `Alice`. (Need to match with values from the table)
- `dcat:dataset.@id`: The unique ID of the `Asset`.
- `dcat:dataset.odrl:hasPolicy.@id`: A unique ID used for contract negotiations.

For the following requests, we use the following example values for the fields described above:
- `dspace:participantId`: did:web:identityhub-alice%3A10100:alice
- `originator`: http://controlplane-alice:8282/api/protocol
- `dcat:dataset.@id`: my-asset
- `dcat:dataset.odrl:hasPolicy.@id`: dGVzdA==:bXktYXNzZXQ=:ZTM5OTAyM2MtZTMxNy00ZDUzLWEzNjUtZTIzZWZjNTVkNTY5

Now, we start the negotiation process:

```bash
$ curl -X POST http://localhost:28181/api/management/v3/contractnegotiations \
    -H "Content-Type: application/json"                                      \
    -H "x-api-key: devpass"                                                  \
    -d @contract-negotiation.json
```

With the corresponding definition of `contract-negotiation.json`.

```json
{
    "@context": [
        "https://w3id.org/edc/connector/management/v0.0.1"
    ],
    "@type": "ContractRequest",
    "counterPartyAddress": "http://controlplane-alice:8282/api/protocol",
    "counterPartyId": "did:web:identityhub-alice%3A10100:alice",
    "protocol": "dataspace-protocol-http",
    "policy": {
        "@id": "dGVzdA==:bXktYXNzZXQ=:ZTM5OTAyM2MtZTMxNy00ZDUzLWEzNjUtZTIzZWZjNTVkNTY5",
        "@type": "Offer",
        "assigner": "did:web:identityhub-alice%3A10100:alice",
        "target": "my-asset"
    }
}
```
- `@context`: Describes the vocabulary currently used for this request.
- `@type`: The schema type of this object, in this case `ContractRequest`.
- `counterPartyAddress`: The `DSP URL` of the `Producer` providing the data.
- `counterPartyId`: The participantId of the `Producer`.
- `protocol`: The underlying protocol that the `Connectors` should use for exchange; this must always be `dataspace-protocol-http`.
- `policy`: This describes that we (the `Consumer`) accept the `Policies` of the `Producer`. Since all `Assets` are generally shared without restrictions, no further specification is required here, except for the following values:
    - `@id`: The unique ID of the `Offer`.
    - `@type`: The schema type of this object, in this case `Offer`.
    - `assigner`: The participantId of the `Producer`.
    - `target`: The unique ID of the `Asset` provided by the `Producer`.

Based on the response to the last request, the field `@id` must be copied from the response to the following query. 
For this example, we assume the following value for the field `@id`: `cef31597-67f8-4d1c-aa91-55cbcfe50756`. 
We need the ID to see more details about the created negotiation. 
Check the negotiation status with:

```bash
curl -X GET http://localhost:28181/api/management/v3/contractnegotiations/cef31597-67f8-4d1c-aa91-55cbcfe50756 \
    -H "Content-Type: application/json"                                                                        \
    -H "x-api-key: devpass"                                                                                    
```

The response to this request includes the `state` field, which indicates whether the negotiation was successful. 
If the field value is `FINALIZED`, the contract was successfully negotiated. 
We need the `contractAgreementId` value in the next step.

```
If the 'state' has the value 'REQUESTED', even after repeated use of the above request,
this indicates that the value of the 'counterPartyAddress' field may contain a typo.
If the 'state' is set to 'TERMINATED', there is another field called 'errorDetails'.
```

## Get the data of another participant

Now we will reuse the contract generated in the previous step to start a data transfer. 
For this, we need the `contractAgreementId`. 
We can use this to retrieve data from the `Producer`. 
To do so, we start a `Data Transfer` via our `Connector` (`Consumer`). 
We can then retrieve the data via the `Producer's` `Data Plane`. 
For the example shown here, we will use the following value for the `contractAgreementId`: `e84dfae6-a083-47c7-9711-bfeefe993784`.

First, we start the data transfer with the following request:

```bash
$ curl -X POST http://localhost:28181/api/management/v3/transferprocesses \
    -H "Content-Type: application/json"                                   \
    -H "x-api-key: devpass"                                               \
    -d @transfer-request.json
```

With the corresponding definition of `transfer-request.json`.

```json
{
    "@context": [
        "https://w3id.org/edc/connector/management/v0.0.1"
    ],
    "@type": "TransferRequestDto",
    "connectorId": "did:web:identityhub-alice%3A10100:alice",
    "counterPartyAddress": "http://controlplane-alice:8282/api/protocol",
    "contractId": "e84dfae6-a083-47c7-9711-bfeefe993784",
    "protocol": "dataspace-protocol-http",
    "transferType": "HttpData-PULL"
}
```

- `@context`: Describes the vocabulary currently used for this request.
- `@type`: The schema type of this object, in this case `TransferRequestDto`.
- `connectorId`: The participantId of the `Producer`.
- `counterPartyAddress`: The `DSP URL` of the `Producer` providing the data.
- `contractId`: The `contractAgreementId` from the previous step.
- `protocol`: The underlying protocol that the `Connectors` should use for exchange; this must always be `dataspace-protocol-http`.
- `transferType`: The type of this data transfer. Since we want to retrieve the data, we use `HttpData-PULL`.

As with the contract negotiation from the previous step, the field `@id` must also be copied from the data transfer response to view the status of the transfer process. 
In this example, we assume the following value for `@id`: `d50c05cd-0ad8-482f-b547-57273be3c545`.

To view the status of the transfer process, we use the following request:

```bash
$ curl -X GET http://localhost:28181/api/management/v3/transferprocesses/d50c05cd-0ad8-482f-b547-57273be3c545 \ 
    -H "Content-Type: application/json"                                                                       \
    -H "x-api-key: devpass"                                                                                    
```

The response to this request includes the `state` field, which indicates whether the start of the transfer was successful. 
If the field value is `FINALIZED`, the data transfer process was successfully started. 

```
If the 'state' has the value 'REQUESTED', even after repeated use of the above request,
this indicates that the value of the 'counterPartyAddress' field may contain a typo.
If the 'state' is set to 'TERMINATED', there is another field called 'errorDetails'.
```

The next step is to obtain the information about the endpoint from which we can retrieve the data. 
This is referred to as the `Endpoint Data Reference (EDR)`. We again need the `@id` of the started data transfer.

The following request provides us with the information we need to retrieve the data:

```bash
$ curl -X GET http://localhost:28181/api/management/v3/edrs/d50c05cd-0ad8-482f-b547-57273be3c545/dataaddress \ 
    -H "Content-Type: application/json"                                                                      \
    -H "x-api-key: devpass"                                                                                  
```

We need the following fields from the response in order to retrieve data:

- `endpoint`: The address of the `Data Plane` of the `Producer` where we can retrieve the data.
- `authType`: The needed authorization type, this should always be `bearer`.
- `authorization`: The actual `bearer token` needed to authenticate against the `Data Plane`.

With this information, we can finally retrieve our data with the following request:

```bash
$ curl -X GET http://localhost:18185/api/public                          \
    -H "Content-Type: application/json"                                  \
    -H "Authorization: eyJraWQiOiJ2ZXJpZmllci1rZXkiLC...KP3tMbXWx7Q98wg"
```

You should receive a response with a link that follows to a random cat image.