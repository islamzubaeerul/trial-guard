# TG-8: Services database (first 40) and validator
Owner role: Parser Engineer   Milestone: M0   Size: M
Spec: §9 of the Architecture & Design Spec
Status: Done

## Acceptance criteria
- [ ] services-db/services.json has 40 entries matching the schema
- [ ] npm run validate:services passes; --check-urls reports each cancel URL status
- [ ] Entries never verified have lastVerified null and are listed by the validator

## Gates
Design: no · Contract: no · Privacy review: no
