// The runtime wraps this body in an async function, so top-level `await` and `return` are expected.

export const meta = {
  name: 'implement',
  description: 'Plan a change with the architect, build it with the coder, then review and fix it until nothing is left to change.',
  whenToUse: 'Implementing an issue or a described change in this repository.',
  phases: [
    { title: 'Plan', detail: 'architect turns the request into a plan', model: 'opus' },
    { title: 'Challenge', detail: "devil's advocate weighs the request's criteria against their cost", model: 'opus' },
    { title: 'Reconcile', detail: 'architect answers the challenges and settles one plan', model: 'opus' },
    { title: 'Build', detail: 'coder implements the settled plan' },
    { title: 'Review', detail: 'reviewer reads the diff' },
    { title: 'Fix', detail: 'coder applies the findings it accepts' },
    { title: 'Verify', detail: 'make check, with one repair pass if it fails' },
  ],
}

const MAX_ROUNDS = 2

const DIFF = 'The change under review is `git diff $(git merge-base HEAD origin/main)`, plus anything uncommitted.'

const STANDARDS = 'A rule in `docs/agents/` is yours to correct where it no longer matches the code. Name every file in `docs/agents/` you touched and what you changed, so that a person reads it before merging.'

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          summary: { type: 'string', description: 'One sentence naming the problem.' },
          change: { type: 'string', description: 'What to do about it.' },
          breaks: { type: 'string', description: 'The input or state that produces a wrong result, and that result. Exactly `nothing breaks` when the finding rests only on a rule.' },
          verdict: { type: 'string', enum: ['change-it', 'beyond-the-request'], description: 'beyond-the-request: a real problem outside this request, for a person to file.' },
        },
        required: ['file', 'summary', 'change', 'breaks', 'verdict'],
      },
    },
  },
  required: ['findings'],
}

const CHALLENGES = {
  type: 'object',
  properties: {
    challenges: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          criterion: { type: 'string', description: 'The line of the request being challenged, quoted.' },
          protects: { type: 'string' },
          cost: { type: 'string', description: 'What building it costs at this size.' },
          reversal: { type: 'string', description: 'What adding it later would take.' },
          cheaper: { type: 'string', description: 'The cheapest alternative that protects the same thing.' },
        },
        required: ['criterion', 'protects', 'cost', 'reversal', 'cheaper'],
      },
    },
  },
  required: ['challenges'],
}

const DEVIATIONS = {
  type: 'object',
  properties: {
    deviations: {
      type: 'array',
      description: 'Every point where the plan was not followed. Empty when it was.',
      items: {
        type: 'object',
        properties: { planned: { type: 'string' }, found: { type: 'string' }, did: { type: 'string' } },
        required: ['planned', 'found', 'did'],
      },
    },
    capture: { type: 'boolean', description: 'True when the change alters recording, capture, permissions or the overlay, so that a person must try a recording.' },
  },
  required: ['deviations', 'capture'],
}

const FIXES = {
  type: 'object',
  properties: {
    applied: { type: 'array', items: { type: 'string' } },
    disputed: {
      type: 'array',
      items: { type: 'object', properties: { summary: { type: 'string' }, reason: { type: 'string' } }, required: ['summary', 'reason'] },
    },
  },
  required: ['applied', 'disputed'],
}

const VERDICT = {
  type: 'object',
  properties: {
    ok: { type: 'boolean' },
    tail: { type: 'string', description: 'The last lines `make check` printed.' },
    failures: { type: 'array', items: { type: 'string' } },
  },
  required: ['ok', 'tail', 'failures'],
}

const WHAT_COUNTS = 'Report only what is wrong. An empty list is the right answer when you find nothing. Every finding says in `breaks` what goes in and what wrong result comes out, or exactly `nothing breaks`. Do not edit any file.'

const request = typeof args === 'string' ? args : (args?.request ?? '')
if (!request) throw new Error('implement needs an issue number or a description of the change')

const issue = /^\d+$/.test(request.trim())
  ? `GitHub issue ${request.trim()} in this repository. Read it with \`gh issue view ${request.trim()} --json title,body,comments\` and treat it as the request.`
  : request

phase('Plan')
const plan = await agent(
  `${issue}\n\nReport an implementation plan: the modules that change and the interface each ends up with, what moves into PromptCastCore as a pure function, what is deliberately not built, and where the tests go. Do not write code.`,
  { agentType: 'architect', label: 'plan', phase: 'Plan', model: 'opus' },
)

phase('Challenge')
const challenged = await agent(
  `${issue}\n\nThe architect's plan follows.\n\n${plan}\n\nWhich criteria of this request cost more than they protect, at the size this repository is now?`,
  { agentType: 'devils-advocate', label: 'challenge', phase: 'Challenge', schema: CHALLENGES, model: 'opus' },
)
const challenges = challenged?.challenges ?? []
log(challenges.length === 0 ? 'challenge: the request is proportionate' : `challenge: ${String(challenges.length)} criteria questioned`)

phase('Reconcile')
const settled = await agent(
  `${issue}\n\nYour plan follows.\n\n${plan}\n\n${
    challenges.length === 0
      ? 'Nothing was questioned.'
      : `These criteria were questioned:\n\n${challenges.map((c) => `- ${c.criterion}\n  protects: ${c.protects}\n  costs: ${c.cost}\n  cheaper: ${c.cheaper}`).join('\n')}`
  }\n\nReport the plan to build. Build everything the request asks for: take a cheaper alternative that protects the same thing, and leave a criterion the request states in the plan for a person to answer. The coder will not see this conversation, so leave nothing open.`,
  { agentType: 'architect', label: 'reconcile', phase: 'Reconcile', model: 'opus' },
)

phase('Build')
const built = await agent(
  `${issue}\n\nImplement this settled plan. Where it does not survive contact with the code, build what works and report the deviation.\n\n${settled}\n\n${STANDARDS}`,
  { agentType: 'coder', label: 'build', phase: 'Build', schema: DEVIATIONS },
)
const deviations = built?.deviations ?? []
for (const d of deviations) log(`off plan: ${d.planned}. found: ${d.found}. built: ${d.did}`)

const disputed = []
const beyond = []
let open = []
let unreviewed = []
let clean = false

for (let round = 1; round <= MAX_ROUNDS; round++) {
  phase('Review')
  const report = await agent(`${issue}\n\n${DIFF}\n\n${WHAT_COUNTS}`, {
    agentType: 'reviewer',
    label: `review r${String(round)}`,
    phase: 'Review',
    schema: FINDINGS,
  })
  const found = report?.findings ?? []
  for (const f of found) if (f.verdict === 'beyond-the-request' && !beyond.some((b) => b.summary === f.summary)) beyond.push(f)
  open = found.filter((f) => f.verdict === 'change-it' && !disputed.some((d) => d.summary === f.summary))
  if (open.length === 0) {
    clean = true
    unreviewed = []
    log(`round ${String(round)}: clean`)
    break
  }
  log(`round ${String(round)}: ${String(open.length)} findings`)

  // A round whose findings break nothing is fixed but does not earn another review.
  const settling = open.every((f) => /^nothing breaks/i.test((f.breaks ?? '').trim()))

  phase('Fix')
  const fixed = await agent(
    `Your change was reviewed:\n\n${open.map((f) => `- ${f.file}: ${f.summary}\n  change: ${f.change}`).join('\n')}\n\nMake the changes you agree with. For the rest, leave the code alone and give the reason.\n\n${STANDARDS}`,
    { agentType: 'coder', label: `fix r${String(round)}`, phase: 'Fix', schema: FIXES },
  )
  unreviewed = fixed?.applied ?? []
  for (const d of fixed?.disputed ?? []) {
    disputed.push(d)
    log(`disputed: ${d.summary}. ${d.reason}`)
  }
  open = open.filter((f) => !disputed.some((d) => d.summary === f.summary))
  if (settling) {
    clean = true
    log(`round ${String(round)}: no finding breaks anything, so the rounds stop here`)
    break
  }
}

phase('Verify')
const VERIFY = 'Run `make check` once at the repository root. Report whether it passed, its last lines, and each failure. Change nothing.'
let verdict = await agent(VERIFY, { agentType: 'reviewer', label: 'verify', phase: 'Verify', schema: VERDICT })
if (verdict && !verdict.ok) {
  log(`verify: ${String(verdict.failures.length)} failing`)
  await agent(
    `\`make check\` fails on your change:\n\n${verdict.failures.map((f) => `- ${f}`).join('\n')}\n\nRepair it. Change nothing the failures do not ask for.`,
    { agentType: 'coder', label: 'repair', phase: 'Verify' },
  )
  verdict = await agent(VERIFY, { agentType: 'reviewer', label: 'verify again', phase: 'Verify', schema: VERDICT })
}
const blocked = !verdict?.ok
if (blocked) log('verify: still failing, reported rather than repaired again')
if (built?.capture) log('capture: the change touches recording, so a person must try a recording before merging')

return { clean, blocked, capture: built?.capture ?? false, disputed, beyond, open, unreviewed, deviations, challenges, plan: settled, verification: verdict }
