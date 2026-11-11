# Manage the centralized todo list

The [specs index](../../architecture/README.md) tracks all future work and todo
items for the home lab in its "Specifications to write and TODOs" section, so
that specifications carry no future work sections or todo items of their own.
This guide describes the conventions that keep that list useful.

## Structure

- The section is organized in themed subsections (for example Security,
  Networking, Monitoring and alerting). Add new items to the matching themed
  subsection; create a new subsection only when no existing theme fits.
- The "Current focus" subsection lists the items being actively worked toward,
  in priority order: data-loss and reliability risks first, then security
  exposure, then automation. Keep it short (three to five items), each item a
  one-liner linking to its themed subsection, and never empty: when the last
  focus item closes, promote the next ones in the same change.
- The "Ideas" subsection, last, parks the undated ideas that have no decision
  and no first step (wishlists, links to read, questions), grouped by theme, so
  the themed subsections hold only work. An idea becomes an item when it gets a
  date and a first step; software alternatives go to the
  [software candidates](../../architecture/software-candidates.md) page instead,
  whose rows link to the idea or the item that evaluates them.

## Item shape

An item is work with a next step, and reads as one:

- A bold title with the date of the decision or of the last change of state,
  then the remaining steps in order and what the work waits on, with
  `Depends on:` and `Blocks:` annotations as the next section describes.
- Evidence and narrative (an incident chronology, measurements, the alternatives
  weighed, the design of a postponed attempt) live in the page that owns them, a
  guide, an archive note, or the specification, and the item links to them. An
  item that grows past ten lines or so is carrying narrative that belongs in
  such a page.
- The state of a rollout goes in the Details column of the specification's
  status table, not in the item.

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

An item leaves the list in one of three ways: it is implemented and reflected in
the relevant specification; it is explicitly discarded; or it was a decision to
take, and the decision is taken and recorded with its rationale in the page that
owns it (the specification, the references page, or an archive note). A decided
item that stays in the list has no exit and only grows, so record the decision
and remove the item in the same change, leaving at most a one-line pointer where
another item depends on it. In every case:

- Remove it from its themed subsection.
- Remove it from "Current focus" if it is listed there, and promote the next
  priority if needed.
- Update or remove the `Depends on:` and `Blocks:` annotations of other items
  that referenced it.
- A verified change sometimes completes items as a side effect (for example, a
  rollout that also deploys an integration an item was waiting on): close those
  items in the same pass and mention them in the commit message, so the list
  does not drift.
- Search the specifications and this list for the words that described the step
  as pending (`until the <event>`, `Depends on: the <event>`, the component's
  name) and update every hit in the same change: a landed step leaves stale text
  wherever it was awaited, status table rows included, not only in its own item.

## Deferring work

When part of an approved plan is put on hold, add the deferred work as an item
in the same pass, with the date and why it is on hold, and close it when the
work later lands.

Work that pauses between sessions because it waits on something (a host that is
off, a measurement window, an action of the user) is deferred work too: record
it as an item with the date, what remains in order, and what it waits on, and
update that item as the work advances, so that any session finds the current
state in one place. The progress of a rollout goes in the Details column of the
specification's status table. A private note, such as an agent's memory store,
is not that place: nothing versions it, and each session rewrites it.
