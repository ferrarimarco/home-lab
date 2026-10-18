# Manage the centralized todo list

The [specs index](../../specs/README.md) tracks all future work and todo items
for the home lab in its "Specifications to write and TODOs" section, so that
specifications carry no future work sections or todo items of their own. This
guide describes the conventions that keep that list useful.

## Structure

- The section is organized in themed subsections (for example Security,
  Networking, Monitoring and alerting). Add new items to the matching themed
  subsection; create a new subsection only when no existing theme fits.
- The "Current focus" subsection lists the items being actively worked toward,
  in priority order: data-loss and reliability risks first, then security
  exposure, then automation. Keep it short (three to five items), each item a
  one-liner linking to its themed subsection.

## Dependencies

- Record dependencies between items as trailing sentences with consistent
  phrasing, so they stay greppable: `Depends on: ...` and `Blocks: ...`.
- `Depends on:` and its inverse `Blocks:` record hard prerequisites only, items
  without which the work cannot be done. An ordering preference (doing one item
  first because it shrinks another) is a plain sentence, not a dependency: a
  preference recorded as a dependency later has to be untangled.
- Link cross-subsection references to the themed subsection anchors (for example
  `[Networking](#networking)`).

## Completing items

When an item is implemented (and reflected in the relevant specification) or
explicitly discarded:

- Remove it from its themed subsection.
- Remove it from "Current focus" if it is listed there, and promote the next
  priority if needed.
- Update or remove the `Depends on:` and `Blocks:` annotations of other items
  that referenced it.
- A verified change sometimes completes items as a side effect (for example, a
  rollout that also deploys an integration an item was waiting on): close those
  items in the same pass and mention them in the commit message, so the list
  does not drift.

## Deferring work

When part of an approved plan is put on hold, add the deferred work as an item
in the same pass, with the date and why it is on hold, and close it when the
work later lands.
