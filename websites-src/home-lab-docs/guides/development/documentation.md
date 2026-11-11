# Documentation conventions

This guide describes how the specifications, the todo list, the guides, and the
agent memory store divide the knowledge of this repository, and the rules each
kind of page follows. The [site development guide](./website-development.md) has
the build and lint pipeline, and the [todo list guide](./todo-list.md) the todo
list's structure.

## Specifications and their status tables

The architecture section of the site,
[`websites-src/home-lab-docs/architecture/`](../../architecture/README.md),
holds the living design specifications that guide architectural, testing, and
deployment choices before code is modified. Its entry page is the global index:
a table outlining the scope and the overall **Current Implementation Status** of
each specification. Whenever a specification's status table changes, update that
column for the specification.

Every specification carries an **Implementation Status** table right beneath its
title (create it when a specification lacks one), with one row per component the
specification defines and a status of `Fully Implemented`,
`Partially Implemented`, or `Missing`. A component is `Fully Implemented` only
when it passes its tests or builds cleanly in CI. The **Status** column tracks
implementation alone: when code is implemented but not yet applied to the real
environment, record the pending deployment as a caveat in the **Details** column
(for example "not yet applied", "applied on node A; node B not yet run") and
remove it once the deployment is verified, instead of adding deployment values
to the Status column.

As soon as a change is tested and complete, or a logical sub-task is finished,
update the `Status` and `Details` fields of the modified components with
precise, objective details (for example "MAC declared in Terraform; awaiting
test verification"), then update the global index, so the specifications and the
code do not drift apart. A landed step also closes or updates the todo items and
rows that awaited it, as the todo list guide describes under "Completing items".

## The todo list

Future work and todo items are tracked centrally in the "Specifications to write
and TODOs" section of the specs index, so they are never scattered across
specifications: a specification carries no "Future Work" section and no todo
items of its own. The list is organized in themed subsections with a "Current
focus" priority list and `Depends on:` and `Blocks:` dependency annotations; the
todo list guide describes adding, completing, and discarding items.

State that outlives a session lives in the repository as well: the progress of a
rollout in the status tables, and work paused between sessions as a todo item,
as the "Deferring work" section of the todo list guide describes. The agent
memory store is unversioned and every session rewrites it, so it holds only what
this repository cannot: facts about the workstation and private identifiers,
each behind a one-line index entry.

## Where a page belongs

The architecture section holds the design and the as-built description of each
subsystem: a page with a status table is a specification, and its status table,
not a separate section, tells design from reality. Reference pages (software
candidates, references) sit beside the specifications with no status table and
no row in the specifications index table, and the index lists them.
Forward-looking material, intentions included, goes in the todo list of the
index, not in a page that reads as a description of the lab; procedures go in
the guides.

Reusable operational and development knowledge (commands, invocation patterns,
troubleshooting workflows, verification recipes) belongs in the guides, the
pages under `websites-src/home-lab-docs/guides/`, not in the agent instructions
file, which carries rules and pointers only. When a task produces such
knowledge, record the substance in the relevant guide, creating one if needed.
Each fact has one home: a new page links to where a fact already lives (the
backups specification holds the verification matrix, the operations guide the
recipes) instead of restating it, and overlap between pages is removed rather
than reworded. The one summary a specification may keep of a guide's procedure
is its workflow list (the step order, no commands): when the guide's steps or
their order change, update that list in the same edit.

## Style

The global agent instructions carry the Markdown rules that apply everywhere
(prose wrapped at 80 columns, no horizontal rules, no trailing punctuation in
headings, no numbered headings). Two rules are specific to this site:

- Format file references as Markdown links with relative paths (for example
  `[README.md](./README.md)`), so that they are navigable from the site.
- Do not put private or personal identifiers (people's names, personal directory
  or share names) in committed documentation; describe them neutrally (for
  example "a personal data directory").
