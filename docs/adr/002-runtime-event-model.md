# ADR-002: Runtime Event Model

## Status

Accepted.

## Context

Direct command-to-update recursion and unordered external completions made lifecycle and event order difficult to prove.

## Decision

Accepted runtime items receive a monotonic sequence and are processed FIFO through one ordered queue. Application updates run to completion and never recursively invoke another update. Presentation scheduling is separate from state-transition scheduling.

## Evidence

Step 1A established FIFO processing and `maxUpdateDepth == 1` across input, commands, timer, async, PTY, and external actions.

## Consequences

Command-generated and externally generated actions append to the queue. Runtime queue/envelope types remain implementation details even where language visibility is public.

## Rejected alternatives

Synchronous nested update and a new generic `Message<M>` runtime.

## Revisit conditions

Revisit only on a demonstrated ordering or lifecycle contradiction, or when two consumers require typed composable routing the existing Event/Command boundary cannot express.

## Fitness functions

Accepted event order/count is deterministic and `maxUpdateDepth == 1`.
