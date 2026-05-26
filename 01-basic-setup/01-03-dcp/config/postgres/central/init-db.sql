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

-- TODO: Mal schauen ob man die holder per REST hinzufügen kann, wenn ja das eventuell über ein zusätzlichen init-container machen
-- TODO: Oder hier einfach die holder datenbank vorher anlegen und befüllen, vermutlich der einfacherer Hack