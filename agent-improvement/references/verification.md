# Verify: hypotheses, eligibility, verdicts and companion floors

Read this when registering a hypothesis or applying a verdict in step 5 of the agent-improvement
loop. It is the complete Verify step; the skill keeps only its summary.

## 5. Verify — the step that makes this a loop rather than a diary

Two verifications, both required:

1. **Now: does the change work?** Exercise it. Re-read the loader you rewrote and confirm it still
   boots; confirm a permission change admits the intended call and still blocks the unintended one.
   Never assume a configuration edit does what it says.
2. **Next run: did the metric move?** Every change registers a **hypothesis** in memory — the change,
   the signature it targets, the baseline value, the window, and the expected direction.
   For a rate-based metric, record the normalized baseline rate and its **baseline observation volume**,
   a **UTC verification-window start** when the change became effective, a **UTC not-before timestamp**,
   and a **minimum post-change observation volume** in the unit that generates the evidence (for example
   sessions, dispatches, requests, or artifacts). Count only evidence generated at or after the
   verification-window start toward the post-change volume.
   A state metric whose outcome is decisive from one live inspection may omit the volume floor.
   **Before any adverse verdict, prove the intervention is deployed.** A metric that did not move
   has two causes taking opposite remedies: the diagnosis was wrong, or the change never reached the
   runtime that generated the evidence. Establish deployment by reading the intervention's content at
   the revision the consuming deployment loads; an upstream merge, a version string, or a green check
   on the authoring pull request is not delivery, because a synced or vendored artifact reaches the
   runtime only after every intermediate hop lands. An intervention that is not live is NOT-YET-DUE,
   blocked on rollout, never NOT-WORKING, and the stalled rollout is itself the finding to pursue
   rather than a reason to revert or reshape.

   The next run checks eligibility before applying a verdict:
   - if either floor is unmet, or the intervention is not live at the consuming deployment's loaded
     revision → record **NOT-YET-DUE**, keep the hypothesis open without applying a
     verdict, and continue with other authorised work;
   - metric moved in its expected direction and every declared companion floor held → close the
     hypothesis, keep the change;
   - metric unchanged **and the intervention proven live** → the diagnosis was wrong. **Say so**,
     then revert or reshape — never layer a second guess on an unverified first;
   - metric moved in the wrong direction, or a companion safety or quality floor regressed,
     **and the intervention proven live** → **revert first, diagnose after**.

   **A companion floor has three dispositions, not two.** Evidence showing
   no regression **within a stated coverage** is **HELD**; evidence showing a regression is
   **REGRESSED**; only the absence of admissible evidence is UNMEASURED. A fleet-wide safety or
   coordination floor is normally evidenced by a
   bounded sample, so "no regression across the sessions actually examined" is HELD within that
   stated coverage, never UNMEASURED — filing gathered evidence as unknown discards it, and is what
   makes such a hypothesis
   unscoreable in principle rather than merely unscored.
   State the coverage next to the disposition, exactly as the Gather step already requires of every
   measurement.

   **UNMEASURED is bounded, never a standing state.** A floor recorded UNMEASURED for the same
   hypothesis across
   three consecutive eligible dispatches is a measurement gap, and that gap
   becomes tracked work in its own right rather than a reason to park the hypothesis again. An
   unbounded NOT-YET-DUE is this step's own failure mode wearing the costume of rigour.

While the hypothesis remains pending, continue only with work that cannot affect its tracked signature
or metric; otherwise wait for evidence or choose a non-overlapping improvement.

A fix whose metric is never checked is indistinguishable from a fix that did not work. This step is what
stops a definition accreting well-intentioned text that never helped anything — the main failure mode of
a self-improving system.

---
