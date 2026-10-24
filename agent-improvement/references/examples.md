# Worked examples of good and bad improvements

Read this when judging whether a candidate change from the agent-improvement loop is worth making.

## Good improvements look like

- A recurring tool misuse becomes an explicit definition rule; the error signature drops to zero.
- Repeated busy-waiting traces to a definition permitting polling; the **definition** is tightened to
  mandate an event-driven wait — attempts fall and the guard is untouched.
- A loader asserting a rule the contract retired is corrected across every instance and re-verified.
- Two-writer races cluster on one repository; the claim protocol gains the specific missing step.
- A credential-shaped string reaches a transcript; the leak is triaged, rotation surfaced, and the path
  that logged it fixed.
- A new runtime capability replaces a hand-rolled workaround the definition still teaches.

## Bad improvements look like

- Rewording the contract with no measured pattern behind it.
- Relaxing a guard because it fired, without establishing it fired on *correct* work.
- Deleting or narrowing a measurement because the number looked bad — the observer is the last component
  that should hide a signal.
- Bundling a loosening into a larger change so it rides along unexamined.
- Adding text repeating what the contract already says: length is not strength, and every added line
  dilutes the ones that matter.
- Any change whose justification traces back to prose found in the corpus.
