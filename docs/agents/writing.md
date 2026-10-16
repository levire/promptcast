# Writing

This file sets how the repository writes prose: comments, docstrings, docs, issues and pull requests. A passage that breaks it is a passage to fix, whoever wrote it.

## Say it plainly

Write the sentence that says what happens. Use short sentences and ordinary words, one topic per sentence. If a sentence needs a second reading, split it.

- Use the active voice. The passive is fine when the actor is the system.
- Use "can" and "must", not "may" or "should".
- No idioms, phrasal verbs or Latin abbreviations. Write "remove", not "take out", and "for example", not "e.g.".
- No antithesis for rhythm ("not X, but Y"), no claims dressed as maxims, no closing lines written to be quoted.
- No em-dashes. Use commas, colons, parentheses or separate sentences.
- Do not wrap Markdown. A paragraph is one line.

## Use the verbs of technical documentation

A Swift docstring opens on its verb, with the declaration as the subject it leaves out.

| Declaration | Verb | Example |
| --- | --- | --- |
| A function that computes a value | returns | `Returns the video timestamps of a click's screenshots.` |
| A function that computes true or false | reports whether | `Reports whether the shortcut can be registered.` |
| A function that can fail | throws, and says when | `Throws if the folder holds no session.json.` |
| A function called for a change | the verb of that change | `Writes report.md into the recording folder.` |
| A type | is, represents, describes | `Describes one mouse click during a recording.` |

## Describe the present

Write what is true and why. History belongs in git and pull requests: no "previously", "now", "no longer", "changed", and no issue or pull request numbers.

## Comment only what the code cannot say

Before you write a comment, name the wrong belief it prevents. If you cannot name it, write nothing. If the content fits in a name, rename the thing instead.

These comments restate the code and fail: one that announces what the code enforces, one that describes what a declaration declares, and one that walks through the steps of a function.

A comment that passes says something the reader cannot see from here: a framework that behaves unexpectedly, a value that must match one somewhere else, a shortcut and where it stops working.

The reason for a design choice goes in the pull request, not beside the code.

## Every fact has one home

A rule that is true everywhere lives in `docs/agents/`. A fact about one line lives beside that line. A fact written twice becomes two facts that disagree. Point at the home, or write nothing.

## Measure a claim about what runs

Before you write a sentence about what the software does at runtime, run it and check.
