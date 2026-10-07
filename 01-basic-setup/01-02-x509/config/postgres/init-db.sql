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

-- Create a user and database for alice
CREATE USER edc_alice WITH PASSWORD 'devpass';
CREATE DATABASE edc_alice;
GRANT ALL PRIVILEGES ON DATABASE edc_alice TO edc_alice;

-- Create a user and database for bob
CREATE USER edc_bob WITH PASSWORD 'devpass';
CREATE DATABASE edc_bob;
GRANT ALL PRIVILEGES ON DATABASE edc_bob TO edc_bob;

-- Grant access to public schemas
\c edc_alice postgres
GRANT ALL ON SCHEMA public TO edc_alice;
\c edc_bob postgres
GRANT ALL ON SCHEMA public TO edc_bob;