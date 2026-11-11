# Offensive Security Hiring Plan — Three Roles

**Prepared for:** Claire, Managing Director, Vanguard Security
**Purpose:** Careers-page descriptions for three hires next quarter
**Roles selected:** Web Application Security Consultant; Infrastructure Penetration Tester; Cloud Security Assessor

## 1. Web Application Security Consultant

### Role title and positioning

This consultant sits in the application-assessment practice. They lead or co-lead tests of customer-facing web applications and HTTP APIs for the firm's financial, healthcare, and technology clients. They work with the engagement lead on scope, with the infrastructure tester when the application exposes a network path, and with the client developers in the readout. They do not own proposals, and they do not run physical or social-engineering operations.

### Scope of intervention

They test web applications, authenticated and unauthenticated, and the APIs those applications call, where the scope names them. The work covers access control, injection, session handling, business-logic flaws, and the safe proof of each finding. They do not test mobile binaries, cloud control planes, corporate networks, or third-party platforms the client does not own. A hostname that merely answers from the application server is a lead, not an authorization.

### Key technical and soft skills

They need to read a modern application, not only run a scanner: HTTP, sessions, JWTs, object-level authorization, SQL and NoSQL injection, server-side request forgery, and file-handling bugs. They should be comfortable in Burp Suite and in a short Python or Ruby proof when the scanner cannot show the issue. They must write a finding a developer can reproduce, including request, impact, and a fix that fits the framework in front of them. In the room, they have to tell a CISO that a bug is serious without exaggerating it, and they have to stop when the data in the response is real customer data.

### Relevant certifications

OSWE matters because it tests whether the consultant can find and exploit flaws in source-level web applications, which is the work on a Rails or Java API, not a multiple-choice survey of tool names. BSCP (Burp Suite Certified Practitioner) matters because it is a timed practical on the tool this practice uses every day, and it filters candidates who only know automated scans. GWAPT matters as a broader web-testing credential that shows method, not a single product, and it is recognized by clients who ask for a SANS-track assessor.

### Distinction from adjacent roles

The infrastructure tester attacks hosts, identity, and network paths. This role attacks the application even when the host is fully patched. The cloud assessor looks at the account, the identity policies, and the managed services. This role looks at the application deployed on top of them. A red team operator chains access across people, buildings, and detection. This role stays on the named application and proves one flaw at a time.

### Typical engagement

A payments firm asks for a gray-box test of its customer API and admin panel before a funding round. The consultant joins the scoping call, refuses the third-party KYC provider as a target, and agrees test accounts and a rate limit. Over two weeks they map the API, demonstrate an object-level authorization flaw with a single test customer, and stop without exporting live records. The deliverable is a technical report and a developer readout, with each finding tied to a request and a recommended control.

## 2. Infrastructure Penetration Tester

### Role title and positioning

This consultant sits in the network and identity practice. They lead assessments of corporate networks, remote-access edges, Active Directory, and the servers clients actually operate. They work beside the web consultant when an application foothold should be tested for lateral movement, and beside the cloud assessor when the "internal" network is a VPC. They are not the firm's social-engineering lead and they do not perform physical intrusion.

### Scope of intervention

They test in-scope ranges, VPN concentrators, identity systems, and exposed management services. They validate segmentation: whether a guest or a user VLAN can reach a database. They do not test applications in depth, mobile clients, or SaaS platforms run by a vendor. They do not invent a red-team license out of a network scope. Exploitation stops at the proof the rules of engagement allow, which is usually a controlled credential or a single host, not a domain-wide ransomware simulation.

### Key technical and soft skills

They need TCP/IP, common network services, Windows and Linux privilege boundaries, and Active Directory attack paths well enough to explain which hop was in scope. Tooling is Nmap, a packet capture when a scan result is ambiguous, and the usual authenticated and unauthenticated identity checks. The soft skill that matters is restraint at a subnet boundary: they must be able to tell a client sponsor, in writing, that a live host next door is out of scope, and they must be able to brief an IT director who did not realize the guest Wi-Fi could route to the database.

### Relevant certifications

OSCP matters because it is a practical examination of enumeration and exploitation on hosts, which is the core of this job, and clients in Europe still ask for it by name. GPEN matters because it is built around a penetration-test method rather than a single lab style, and it covers the planning and reporting this practice has to defend. CREST CRT (or the equivalent CCT Infrastructure practical) matters when the client or their regulator requires a CREST-accredited tester on the team.

### Distinction from adjacent roles

The web consultant stays in HTTP. This role follows the network and the directory. The cloud assessor starts from the provider's API and identity policies. This role starts from packets and logons, and only enters the cloud account when that account is explicitly in scope. A red team operator is measured on detection and on objectives across domains. This role is measured on a defensible list of hosts and on not crossing it.

### Typical engagement

A logistics company wants to know whether the flat network that enabled a previous incident is actually closed. The tester receives a signed range, a VPN test account, and a ban on the payment processor's subnet. They map the in-scope segments, show that a user VLAN can still reach a database port, and prove it with a single authenticated connection using a test account. The report lists the path, the missing firewall rule, and the retest condition. Hosts outside the range are named only as "observed, not accessed."

## 3. Cloud Security Assessor

### Role title and positioning

This consultant sits between the application practice and the infrastructure practice, and owns assessments of the cloud accounts clients operate. For Vanguard that is mostly Amazon Web Services, with occasional Azure. They work with the client's DevOps or platform engineer, and they pull in the web consultant for the application running on the cluster. They are not a general network tester and they are not a compliance auditor producing a SOC 2 opinion.

### Scope of intervention

They assess the accounts, projects, and clusters named in the scope: identity and access, network policy, storage exposure, logging, and secrets handling. Read-only cloud credentials are the normal starting point. They do not attack the cloud provider's own control plane, other tenants, or a SaaS product the client only consumes. They do not load-test production, and they do not change infrastructure except where a rule explicitly allows a reversible proof.

### Key technical and soft skills

They need the shared-responsibility model in enough detail to say which misconfiguration is the client's. On AWS that means IAM, VPC and security groups, S3 and block storage, EKS or ECS, RDS exposure, CloudTrail, and the places API keys leak. They should be able to read a Terraform or console export and then confirm the live state. The soft skill is translation: a CFO hears "the bucket is public," a DevOps engineer hears the policy statement and the fix. They also have to refuse a scope that says "test AWS" without an account ID.

### Relevant certifications

AWS Certified Security – Specialty matters because the firm's current clients run on AWS, and the exam forces the candidate through IAM, logging, and data protection rather than generic cloud marketing. CCSP matters because it tests the shared-responsibility and legal side of cloud work, which is what keeps an assessor from treating the provider's platform as a target. CCSK matters as the vendor-neutral companion: it is shorter than a full audit credential and it checks that the consultant can explain the same boundary in a client workshop.

### Distinction from adjacent roles

The infrastructure tester pivots through hosts and directories. This role pivots through roles, policies, and managed services, and a finding is often a policy rather than a shell. The web consultant exploits the application. This role asks whether the cluster, the database, and the bucket around that application are exposed. An IoT or OT assessor works on devices and plant networks this role does not touch. A red team operator may abuse a cloud identity as one step in a scenario. This role assesses the account systematically and writes the control gap down whether or not it makes a good story.

### Typical engagement

A fintech hosts its payments API on EKS, RDS, and S3 in eu-west-1. The assessor is given a read-only role in the production and staging accounts after the account IDs are written into the scope. They review IAM and public exposure, confirm a finding by reading the live policy rather than by exfiltrating data, and hand the application-layer issues to the web consultant. The deliverable separates "your misconfiguration" from "the provider's responsibility," and it states that the third-party KYC vendor's account was not assessed.

## Why these three roles

Vanguard's clients are in healthcare, financial services, and technology, and the work they actually buy is a scoped test of an application, a network, or a cloud account. These three hires cover that book. The web consultant takes the APIs and admin panels. The infrastructure tester takes the corporate network, the VPN, and the segmentation questions that follow a breach. The cloud assessor takes the AWS accounts those same clients already run, which today get folded awkwardly into whichever of the other two is free.

I did not hire a red team operator, a social-engineering specialist, or an IoT assessor this quarter. The case file from this week is a firm that sold "red team" to a client who meant "test the website." Adding a red team operator before the scoped practices are staffed would push the firm toward the work that is easiest to mishandle. IoT and operational technology are a different legal and safety problem, and they are not the engagements on the current pipeline.

Taken together, the three roles say that Vanguard's next quarter is about defensible, scoped assessments for regulated clients, not about building an adversary-simulation brand. A red team practice can come later, and only after the firm is staffed to tell a client no.
