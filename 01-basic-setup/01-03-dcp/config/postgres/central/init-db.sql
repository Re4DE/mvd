--
--  Copyright (c) 2025 Fraunhofer Institute for Energy Economics and Energy System Technology (IEE)
--
--  This program and the accompanying materials are made available under the
--  terms of the Apache License, Version 2.0 which is available at
--  https://www.apache.org/licenses/LICENSE-2.0
--
--  SPDX-License-Identifier: Apache-2.0
--
--  Contributors:
--       Fraunhofer IEE - initial API and implementation
--

\c edc edc
-- Create membership attestations database
CREATE TABLE IF NOT EXISTS membership_attestations
(
    holder_id   varchar                                 not null,
    id          varchar     default gen_random_uuid()   not null
        constraint attestations_pk
            primary key
);

CREATE UNIQUE INDEX IF NOT EXISTS membership_attestation_holder_id_uindex
    ON membership_attestations (holder_id);

-- Create market partner attestations database
CREATE TABLE IF NOT EXISTS marketpartner_attestations
(
    company_name        varchar                                 not null,
    company_uid         varchar                                 not null,
    sector              varchar     default 'electricity'       not null,
    code_issuing_body   varchar     default 'BDEW'              not null,
    market_role         json                                    not null,
    holder_id           varchar                                 not null,
    id                  varchar     default gen_random_uuid()   not null
        constraint markt_attestations_pk
            primary key
);

CREATE UNIQUE INDEX IF NOT EXISTS marketpartner_attestation_holder_id_uindex
    ON marketpartner_attestations (holder_id);

-- Insert alice as a attested participant
INSERT INTO membership_attestations (holder_id)
VALUES ('did:web:identityhub-alice%3A10100:alice');

INSERT INTO marketpartner_attestations (company_name, company_uid, market_role, holder_id)
VALUES ('alice inc.', '123456', '{"mpId":"123456","roleAbbreviation":"MSB","roleName":"Messstellenbetreiber"}', 'did:web:identityhub-alice%3A10100:alice');

-- Insert bob as a attested participant
INSERT INTO membership_attestations (holder_id)
VALUES ('did:web:identityhub-bob%3A10100:bob');

INSERT INTO marketpartner_attestations (company_name, company_uid, market_role, holder_id)
VALUES ('bob corp.', '654321', '{"mpId":"123456","roleAbbreviation":"VNB","roleName":"Verteilnetzbetreiber"}', 'did:web:identityhub-bob%3A10100:bob');

-- Create the holder table. Normally, the issuer creates this database on its own, but we will use it to initialize with default participants
-- From holder-schema.sql - issuerservice-holder-store-sql - identity-hub
CREATE TABLE IF NOT EXISTS holders
(
    holder_id                    VARCHAR PRIMARY KEY NOT NULL, -- ID of the Holder
    participant_context_id       VARCHAR NOT NULL,             -- the DID with which this holder is identified
    did                          VARCHAR NOT NULL,             -- the DID with which this holder is identified
    holder_name                  VARCHAR,                      -- the display name of the holder
    created_date       BIGINT    NOT NULL,                     -- POSIX timestamp of the creation of the PC
    last_modified_date BIGINT                                  -- POSIX timestamp of the last modified date
);
CREATE UNIQUE INDEX IF NOT EXISTS holders_holder_id_uindex ON holders USING btree (holder_id);

-- Insert alice and bob as valid dataspace participants
INSERT INTO holders (holder_id, participant_context_id, did, holder_name, created_date)
VALUES ('did:web:identityhub-alice%3A10100:alice', 'ZGlkOndlYjppZGVudGl0eWh1Yi1hbGljZSUzQTEwMTAwOmFsaWNl', 'did:web:identityhub-alice%3A10100:alice', 'alice', 1779969883);

INSERT INTO holders (holder_id, participant_context_id, did, holder_name, created_date)
VALUES ('did:web:identityhub-bob%3A10100:bob', 'ZGlkOndlYjppZGVudGl0eWh1Yi1ib2IlM0ExMDEwMDpib2I=', 'did:web:identityhub-bob%3A10100:bob', 'bob', 1779969883);