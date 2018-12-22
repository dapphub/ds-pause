# Governance Security Module

## Problem Statement

Governance has almost unlimited power. It is not clear that it can actually be constrained in any meaningful way. The security of the system therefore rests upon giving those affected by an attack time to respond to a malicious governance action, either by canceling the malicious action, triggering global settlement, or exiting from DAI / closing their CDP.

We therefore wish to introduce a time delay between the approval of a governance proposal, and it's execution.

## Requirements

Governance can:

- Queue any number of function calls
- Cancel any queued call
- Freeze the queue for a period of time (to allow for safe chief upgrades)

Each queued call can be:

- Executed only once some predetermined delay has passed
- Executed by anyone
- Executed once only
