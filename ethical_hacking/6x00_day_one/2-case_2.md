# Post-Incident Analysis — Case 2: "The Scope Creep"

**Firm:** RedLine Security
**Client:** ClientCorp (e-commerce platform)
**Third party affected:** FinServe Inc.
**Prepared for:** Vanguard Security, internal case review

## 1. What happened

RedLine Security was hired for a web-application penetration test. The scope document limited testing to the application at shop.clientcorp.com and the API at api.clientcorp.com.

A senior consultant found that the API talked to an internal service at billing-internal.clientcorp.com:8443. That host was not in scope. It was reachable because of a misconfigured firewall rule. The consultant saw what looked like a default admin password, decided that access to billing would make a stronger report, logged in, and browsed screens that showed billing records for more than 10,000 customers, including names, addresses, and partial card numbers. He wrote it up as a bonus discovery.

The billing system was not ClientCorp's. FinServe Inc. operated it under a SaaS contract. ClientCorp did not own that infrastructure and could not authorize anyone to enter it. FinServe alleged unauthorized access and a PCI-DSS violation for viewing cardholder data without authorization. ClientCorp's counsel relied on the scope document, which excluded internal systems. The consultant was suspended and the firm's liability insurance was invoked.

## 2. What rule, law, or standard was violated

The scope was the contract. Crossing it was unauthorized access to a system the client did not have the right to open. ClientCorp could authorize tests of shop.clientcorp.com and api.clientcorp.com. It could not authorize access to FinServe's billing platform. The Computer Fraud and Abuse Act, the Computer Misuse Act, and Article 2 of the Budapest Convention attach to the system that was accessed, not to the hostname that happened to resolve inside the client's DNS.

Viewing cardholder data also sat outside PCI-DSS. Payment-card data may be accessed only by parties authorized under the cardholder-data environment's own rules. A penetration-test scope for an e-commerce site is not that authorization. PTES and CREST both require testers to stay inside the written scope and to obtain a fresh written authorization before any expansion. "It was reachable" and "the client will be grateful" are not exceptions.

## 3. What the correct professional behavior would have been

The consultant should have stopped at the boundary. The legitimate finding was already in scope: the API server could reach a host that the firewall should not have exposed, and that host presented what appeared to be a default administrative login. That is a reportable misconfiguration. It is demonstrated by showing the connection attempt and the login prompt, not by authenticating.

Any further step required a written scope amendment signed by ClientCorp and a separate written authorization from FinServe, naming the host, the accounts that could be used, and a prohibition on opening live cardholder screens. Until both signatures existed, the billing service was out of scope.

## 4. Clauses that would have prevented this outcome

- **Asset-owner boundary.** "Authorization covers only systems owned or operated by ClientCorp and listed in Annex A. Reachability from an in-scope host does not extend authorization. Third-party and SaaS platforms, including payment processors, are out of scope unless that third party has signed its own authorization."
- **No use of found credentials off-scope.** "Credentials discovered during the test, including default passwords, shall not be used against any host that is not named in Annex A."
- **Cardholder data.** "Testers shall not open, query, or screenshot primary account numbers or cardholder records. If such data is displayed unintentionally, the tester closes the view, does not copy it, and reports the exposure by field type only."
- **Scope-change procedure.** "A suspected adjacent system is documented as a lead. Testing it requires a written change request signed by the asset owner before any authentication or data access. Verbal encouragement from the client sponsor is not a change request."
- **Bonus findings.** "Findings outside the signed scope are not 'bonus' results. They are scope violations."
