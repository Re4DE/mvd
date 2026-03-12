# MVD

[![license](https://img.shields.io/github/license/eclipse-edc/Connector?style=flat-square&logo=apache)](https://www.apache.org/licenses/LICENSE-2.0)

---

With this `MVD`, we will present the different capabilities of the `Re4DE` ecosystem.
It is essential to understand that the setup described here is intended solely for development and demonstration purposes.
If you want to move this setup to a productive environment, check out the production-ready [checklist](#03-production-ready-checklist) below.

## 01. Basic Setup

The first question to answer during the building phase of a dataspace is: 
*How does each participant identify itself?*
`Re4DE` provides three answers to that question. 
- [OAuth2](01-basic-setup/01-01-oauth/README.md)
- [X.509](01-basic-setup/01-02-x509/README.md)
- [DCP (SSI) - Recommended](01-basic-setup/01-03-dcp/README.md)

While `OAuth2` and `X.509` create a strong coupling between the identity provider and the participants, the `DCP` allows loose coupling and is also our recommended choice.
You should use `OAuth2` and `X.509` only for demonstration or fast bootstrap.

## 02. Feature Showcases

After you have chosen and deployed one of our three basic setups, you can explore the following Feature Showcases of `Re4DE`:
- [Connector UI with decentralized catalog](02-features/02-01-catalog/README.md)
- [Integration Permission Administrator](02-features/02-01-pa/README.md)
- [Integration Smart-Meter PKI](02-features/02-01-sm-pki/README.md)

## 03. Production Ready Checklist

Will follow, stay tuned!