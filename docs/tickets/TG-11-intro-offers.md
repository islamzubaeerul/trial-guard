# TG-11: Treat intro offers as reminder-worthy
Owner role: Parser Engineer   Milestone: M1   Size: M
Spec: §4 of the Architecture & Design Spec · Contract Q1 (decided by owner 2026-10-25: yes)
Status: To do

## Why
"$0.99 for the first month, then $12.99/month" bills a higher price after a short period, exactly like a trial. Users want the same reminder before the jump.

## Acceptance criteria
- [ ] Contract v1.3 adds `kind: "trial" | "introOffer" | "none"` (isTrial stays true only for free trials, for compatibility)
- [ ] Given `qa-paramount-plus-checkout-09`, when parsed, then kind = introOffer, trialEnd = 2026-11-24, price = 12.99 (the post-intro price)
- [ ] Intro price is exposed separately (`introPrice`) and never chosen as `price`
- [ ] At least 5 new intro-offer fixtures and 2 near-miss negatives ("first month 50% off" with no later price change is still introOffer; "$5/month, first month included" is none)
- [ ] TS and Swift parity clean

## Gates
Design: yes (confirm card shows "Intro price ends") · Contract: yes · Privacy review: no
