# Simplified Technical English (ASD-STE100)

Write every response, doc, README, plan, and commit message in ASD-STE100
Simplified Technical English.

## The rules

- Use the active voice. Passive voice is for descriptive text only, and only
  when the actor is unknown or irrelevant.
- Keep sentences to 20 words or fewer. Descriptive text can use 25.
- Give one idea in each sentence. Give one instruction in each sentence.
- Use simple tenses only: present, past, and future. Do not use the present
  perfect or the past perfect. Write "we received", not "we have received".
- Use "-ing" forms only inside a technical noun. Never as a verb form.
- Use the same word for the same idea each time. Do not use synonyms.
- Use each word with one meaning and one part of speech. Write "apply oil",
  not "oil the valve".
- Prefer the shorter, plainer, more common word.
- Do not use idioms, slang, or jargon.
- Keep paragraphs to 6 sentences or fewer. Give one topic in each paragraph.
- Cap noun clusters at 3 words.
- Use numbered or bulleted lists for sequences, conditions, and enumerations.
- Start a safety warning with the command or the condition.
- Do not delete a verb, a subject, or an article to make a sentence shorter.
  A short ambiguous sentence is worse than a long clear one.

## Why

The reader cannot ask a follow-up question. A subagent parsing this output, a
translation layer, and a non-native reader all work with no back-channel. STE
was built for aircraft technicians for the same reason. Ambiguity costs more
than length.

## Examples

**Tool description**

Before: "This tool will attempt to synchronize state across the various
backends that have been configured, and if a conflict is detected it may
resolve it automatically depending on the strategy that has been set, or
otherwise it will surface the conflict for manual review."

After: "The tool synchronizes state across the configured backends. If it finds
a conflict, it checks the current strategy. If the strategy allows automatic
resolution, the tool resolves the conflict. If not, the tool reports the
conflict for manual review."

**Error message**

Before: "An error may have occurred while processing your request due to a
possible mismatch in the expected data format, which could be caused by an
outdated client version."

After: "The request failed. The data format did not match what the server
expected. Check your client version. An outdated client is the most common
cause."

**Instruction to a subagent**

Before: "Once the upstream job has completed and assuming no errors were
raised, the downstream agent should proceed to consume the output artifact,
though it is worth noting that partial artifacts are sometimes produced under
timeout conditions."

After: "Wait for the upstream job to finish with no errors. Then read the
output artifact. Warning: a timeout can produce a partial artifact. Check the
artifact is complete before you use it."

## Checking

Read each sentence you wrote. Then ask:

1. How many words? Cut to 20.
2. How many ideas? Split into one idea per sentence.
3. Is the verb active? Make it active.
4. Is there a hedge, an idiom, or a compound tense? Remove it.

## Scope

This rule applies to the writing style. Keep sentences direct, short, and
literal. Drop idioms and pop-culture references that break the rules above.
