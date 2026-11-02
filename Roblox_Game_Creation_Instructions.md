# Roblox Game Creation Instructions

Recommended session setup: Select **GPT-6.1 Sol / Extra High (`xhigh`)** as the main model in your Codex client before submitting this prompt. Use this setting for initial market-research synthesis, concept selection, game design, release scoping, progression and economy design, architecture, and vertical-slice planning. Once the concept, architecture, and vertical-slice plan are established, manually switch the main session to **GPT-6.1 Sol / High (`high`)** for routine development. The task-based delegation policy below requests suitable models and effort levels for subagent tasks where supported. It does not change the main conversation's selected model or reasoning effort or unlock unavailable settings.

Act as the lead Roblox game designer and engineer for this project. Help me take an original game from market research through implementation, testing, and preparation for release.

Work proactively, make reasonable implementation decisions, and maintain enough documentation for another Codex session to continue without losing context.

## 1. Project objective

Create a polished, fully playable Roblox game that:

- Has a compelling core gameplay loop, clear onboarding, and meaningful progression.
- Targets a substantial audience based on current market evidence.
- Offers a distinctive reason to play and return.
- Works in Roblox Studio and can be built reproducibly from the repository.
- Performs well on mobile and desktop, with appropriate controls and responsive UI.
- Includes reliable multiplayer behavior where required by the chosen design.
- Saves player progress safely.
- Supports optional purchases using Roblox's supported monetization systems.
- Is prepared for deployment to Roblox.

Deliver a focused, complete initial release, with additional features organized into a later expansion roadmap. Set measurable acceptance criteria for "fully playable" before implementation begins.

Do not promise popularity or revenue. Optimize for evidence-supported potential, enjoyable gameplay, technical quality, and practical development scope.

## 2. Repository and Git workflow

Use the GitHub repository named `rollboxgame`. Preserve this exact spelling.

Before making changes:

- Inspect the existing repository, branches, files, instructions, and Git status.
- Verify the correct repository owner and remote. Ask only if the repository cannot be identified unambiguously.
- Preserve existing work and repository visibility.
- Check available tools, authentication, and Roblox Studio access.

Use `develop` for active development and keep `main` stable.

Define each roadmap task as a meaningful, independently verifiable milestone. Smaller implementation actions can be subtasks within a milestone.

For every completed milestone:

1. Implement the work on `develop`.
2. Run its required checks and fix failures.
3. Update the roadmap and handoff documentation.
4. Commit with a descriptive message and push `develop`.
5. Merge the validated milestone into `main`.
6. Push `main` and confirm the remote state.

These routine commits, pushes, and merges are authorized by this prompt. Follow branch protection requirements and use pull requests when required. Do not force-push, bypass protections, or overwrite unrelated work.

If authentication, required checks, or branch protections prevent completion, record the exact blocker and preserve the work. Never claim a push or merge succeeded without verifying it.

## 3. Durable instructions and resumable progress

Create and maintain these files:

**`AGENTS.md`**

Store the enduring project requirements, engineering conventions, validation rules, Git workflow, task-based model delegation policy, and session startup procedure. Keep this concise and actionable.

**`game_creation_steps.md`**

Maintain the authoritative roadmap. For each milestone include:

- Stable task ID and title.
- Objective and scope.
- Dependencies.
- Status.
- Deliverables.
- Observable acceptance criteria.
- Required automated checks and Studio playtests.
- Relevant commits and merge information.

Use explicit statuses such as `TODO`, `IN_PROGRESS`, `BLOCKED`, `AWAITING_VALIDATION`, and `DONE`.

**`PROJECT_STATE.md`**

Maintain a concise handoff containing:

- Current milestone and working branch.
- Last verified local and remote commits.
- Completed work and unfinished changes.
- Checks run and their results.
- Known issues and external blockers.
- Important decisions and assumptions.
- The next specific actions to take.

Never store credentials or secrets in these files.

**`docs/market_research.md`**

Record research sources, observations, concept comparisons, and the reasoning behind the selected concept.

**`docs/game_design.md`**

Document the chosen game's mechanics, progression, economy, monetization, visual direction, architecture, and initial release scope.

**`README.md`**

Provide reproducible setup, build, Studio synchronization, testing, configuration, and publishing instructions.

At the start of every resumed session:

1. Read `AGENTS.md`, `PROJECT_STATE.md`, and the roadmap.
2. Inspect the actual repository and Git state.
3. Reconcile documentation with the files, commits, and available test evidence.
4. Resume the next unfinished task without repeating completed work.

Before stopping or handing off, update the state files and save progress. Incomplete work may be committed to `develop` with a clear description, but must not be marked complete or merged as a finished milestone.

## 4. First substantive phase: current market research

Before choosing the game or implementing gameplay, investigate what has a credible chance of attracting and retaining Roblox players.

Use current, accessible evidence from Roblox discovery and charts, official Roblox resources, and relevant public signals from other gaming and creator platforms.

Record source URLs, observation dates, and the period each metric covers. Distinguish verified observations, estimates, and hypotheses.

Research:

- Popular genres and emerging gameplay patterns.
- Sustained demand versus short-lived spikes.
- Audience size and competition.
- Mobile accessibility and performance expectations.
- Social play, replayability, and reasons to return.
- Discoverability and opportunities for distinctive positioning.
- Monetization approaches that fit the gameplay.
- Development effort, content requirements, and operational complexity.

Do not treat visits, concurrent players, likes, retention, and revenue as interchangeable metrics. Do not invent unavailable data.

Compare three to five feasible, original game concepts using a transparent weighted decision matrix. Explain the weights and uncertainty.

For each concept describe:

- Target audience and evidence of demand.
- One-sentence hook.
- Core gameplay loop.
- First-session experience.
- Progression and replayability.
- Competitive differentiation.
- Monetization potential.
- Technical and content-production difficulty.
- Main risks.

Recommend one concept and explain why it is a practical choice for this project. Combine market evidence with a clear creative identity; do not simply copy the current largest game.

If browsing or important data is unavailable, state that limitation and label the recommendation provisional.

## 5. Design the game before expanding implementation

For the recommended concept, define:

- The player fantasy and distinctive hook.
- What the player does in the first minute and first ten minutes.
- The repeatable action-reward-progression loop.
- Short-term and long-term goals.
- Challenge, failure, recovery, and replay mechanics.
- Appropriate server size and multiplayer interactions.
- Controls and UI for mobile and desktop.
- Visual style, audio direction, and feedback.
- Initial content scope and expansion opportunities.
- Persistence requirements and economy rules.
- Measurable playtest criteria.

State assumptions about budget, team size, asset availability, and development capacity. Use a modest, achievable scope unless I provide different constraints.

Build a playable vertical slice early: one representative environment, the central mechanic, essential UI, and one complete progression cycle.

Evaluate whether that slice is understandable, enjoyable, and technically sound before adding substantial content. Document revisions when playtesting reveals problems.

## 6. Technical implementation

Use Luau and a source-controlled workflow suitable for Roblox Studio. Prefer Rojo unless the existing repository has a justified alternative.

Provide:

- A clear project structure and Rojo configuration.
- Pinned, compatible tool versions.
- Documented commands for setup, validation, and building.
- A reproducible `.rbxl` or `.rbxlx` output that opens in Studio.
- A reliable way to reproduce maps, UI, configuration, and required assets.
- A clear source-of-truth policy for any assets edited in Studio.
- Appropriate automated checks in CI.

Choose dependencies deliberately and keep the architecture understandable.

Implement relevant production foundations:

- Server-authoritative progression, inventory, rewards, and purchases.
- Validation and rate limiting for client requests.
- Safe handling of disconnects, respawns, and player lifecycle events.
- Persistent data with versioning, sensible retries, and protection against accidental overwrites or duplication.
- Separation of development/test data from production data.
- Centralized configuration for economy values and product IDs.
- Useful diagnostics and graceful handling of service failures.

Keep secrets out of source control. Use original assets or assets with verified usage rights, and record third-party asset sources and permissions.

Verify current APIs and platform requirements against official documentation when needed.

## 7. Monetization

Design optional Robux purchases that fit the game and support its long-term appeal.

Consider suitable combinations of:

- Cosmetics and customization.
- Permanent benefits through passes.
- Repeatable consumables through developer products.
- Optional convenience features.
- Resource refills, boosts, or extra capacity where appropriate.

If resources can run out, explain both how players can obtain more through gameplay and what an optional purchase provides. Design a satisfying free-player experience.

For every proposed product, document its benefit, purchase type, balance implications, and configurable product ID.

For repeatable purchases:

- Use Roblox's currently supported server-side receipt-processing mechanism.
- Verify the product and player.
- Persist purchase fulfillment and purchase-ID deduplication.
- Handle retries, disconnects, and persistence failures without duplicate grants or lost purchases.
- Never grant rewards solely from a client request or a purchase-prompt completion event.

Test successful purchases, cancellation, duplicate receipts, unavailable player data, and failed saves using supported testing methods.

Do not invent product IDs or enable broken purchase buttons. If Creator Dashboard configuration is required, document exactly what I must create and where the resulting IDs belong.

Verify applicable Roblox monetization and content requirements before implementation.

## 8. Validation and improvement loop

Use this loop for every milestone:

1. Define observable acceptance criteria.
2. Implement the smallest complete solution.
3. Run the relevant automated checks.
4. Run the required Studio tests when access is available.
5. Inspect results and fix failures.
6. Review gameplay, usability, security, and performance as relevant.
7. Re-run checks affected by fixes.
8. Record evidence and complete the Git workflow.

Stop polishing once the acceptance criteria are satisfied and material problems are resolved. Put additional ideas into the backlog.

Choose meaningful tests, particularly for:

- Progression and economy calculations.
- Inventory and reward handling.
- Save/load behavior and failure recovery.
- Purchase fulfillment and duplicate receipts.
- Invalid or abusive client requests.
- Multiplayer synchronization.
- First-time onboarding and the complete gameplay loop.

Include Studio playtests for a new player, returning player, multiple clients, touch controls, respawn/reconnect behavior, and appropriate performance targets.

Distinguish automated test results from manual playtest results. Static checks and a successful build do not prove that gameplay works.

If Roblox Studio or account access is unavailable, complete independent work, provide an exact manual test procedure, and mark the required runtime checks as pending. Do not fabricate playtest results or declare the game release-ready while mandatory checks remain unverified.

## 9. Deployment readiness and project completion

Prepare a reproducible release build and clear instructions covering:

- Opening or synchronizing the project in Roblox Studio.
- Creating or configuring the Roblox experience.
- Required assets, permissions, IDs, and settings.
- Persistence and monetization configuration.
- Private testing.
- Current publishing eligibility and content requirements.
- Release verification and rollback.

Keep any test experience private. Prepare everything possible before requesting actions that require my account access. Public release and paid expenditure require my explicit approval.

The project is complete only when the agreed initial release scope works, required validation has passed, necessary account configuration is verified, documentation is accurate, and the final validated code is pushed and merged into `main`.

If external requirements remain unresolved, clearly distinguish implementation completion from release readiness.

## 10. Task-based model delegation

Use the main agent to coordinate the project, maintain project state, integrate changes, validate milestones, and perform the agreed Git workflow.

Apply reasoning effort according to the task:

- **Extra High (`xhigh`):** Initial research synthesis, game concept comparison and selection, game design, release scope, progression and economy design, architecture, and vertical-slice planning. Also use it for difficult multiplayer bugs, persistence, purchase processing, and security reviews.
- **High (`high`):** Routine gameplay implementation, Luau code, tests, and ordinary debugging.
- **Medium (`medium`):** Small documentation changes and simple repository housekeeping when effort can be configured separately without unnecessary overhead.

Keep planning bounded by the required decisions and acceptance criteria. Build the playable vertical slice early and use Studio playtests to validate the design. Higher reasoning effort does not guarantee better results or replace current research, automated checks, or runtime testing.

Where supported, explicitly delegate substantial tasks to subagents with these model settings:

- **Market-research synthesis, game concept evaluation, game design, release scoping, progression and economy design, architecture, and vertical-slice planning:** `gpt-6-astra`, reasoning effort `xhigh`.
- **Gameplay implementation, Luau code, tests, and ordinary debugging:** `gpt-6.1-sol`, reasoning effort `high`. The main agent may handle these directly when it already uses this configuration.
- **Screenshot analysis, UI review, and player-facing text:** `gpt-6.1-terra`, reasoning effort `medium`.
- **Difficult bugs, multiplayer synchronization failures, persistence, purchase processing, and security reviews:** `gpt-6-astra`, reasoning effort `xhigh`.

Use only models and effort levels available to my account and client. If Astra is unavailable, prefer `gpt-6.1-sol` at the requested effort for its assigned tasks. If Extra High is unavailable, use High. Report any unavailable setting and the actual fallback used.

Once the initial concept, architecture, and vertical-slice plan are established, identify the transition to routine development and recommend that I switch the main session to High through the client. Recommend temporarily returning to Extra High for the difficult tasks listed above. Configure subagent effort explicitly where supported; do not claim that a prompt or recommendation changed the main session's settings.

Give each subagent a bounded task, relevant project context, acceptance criteria, and validation requirements. Parallelize independent work; process dependent tasks in order. Avoid simultaneous edits to the same files.

Keep small tasks in the main agent when delegation would add unnecessary overhead. The main agent must inspect and validate subagent results before accepting them.

Persist these instructions in `AGENTS.md`. Record the assigned model and effort when exposed by the runtime. Never claim a model or effort change occurred unless it actually did.

## 11. Communication and starting instructions

Give concise progress updates explaining:

- What was completed.
- What was tested.
- What remains uncertain or blocked.
- The current repository and milestone status.
- What happens next.

Ask questions only when a missing answer materially affects the concept, access, cost, or implementation. Continue useful independent work while a blocker is unresolved.

Start by inspecting the repository and environment. Establish the persistent project instructions, task-based model delegation policy, and initial roadmap, perform the market research, and present the recommended concept with its supporting evidence. Then carry out the roadmap, updating it as validated findings require.
