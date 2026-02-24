<!--
SYNC IMPACT REPORT
==================
Version change  : [unversioned template] → 1.0.0
Bump rationale  : Initial ratification — all principles and sections are new (MINOR baseline → 1.0.0).

Modified principles : None (first-time authoring)
Added sections      :
  - I.  Code Quality
  - II. Testing Standards
  - III. User Experience Consistency
  - IV. Performance Requirements
  - Quality Gates
  - Development Workflow
  - Governance
Removed sections    : None (template placeholders replaced)

Templates reviewed  :
  ✅ .specify/templates/plan-template.md   — "Constitution Check" gate aligns; no structural edits needed.
  ✅ .specify/templates/spec-template.md   — Performance goals + success criteria fields align with principles III & IV.
  ✅ .specify/templates/tasks-template.md  — Test phases, performance polish, and quality tasks already present.
  ✅ .github/agents/*.agent.md             — No agent-specific name conflicts found; guidance is generic.

Deferred TODOs : None — all fields resolved.
-->

# SheetShow Constitution

## Core Principles

### I. Code Quality

Every unit of code shipped to the main branch MUST meet the following bar — no exceptions
without a documented, time-bounded exception tracked in the relevant PR:

- **Single Responsibility**: Each module, class, and function MUST have exactly one clearly
  stated purpose. Mixed concerns MUST be refactored before merging.
- **Readable by Default**: Functions MUST NOT exceed 50 lines. Deeply nested logic (> 3 levels)
  MUST be extracted into named helpers.
- **No Magic Values**: All literals used more than once MUST be extracted to named constants in
  a dedicated constants/config file. Inline magic numbers and unnamed strings are prohibited.
- **Dead-Code Free**: Commented-out code and unused imports MUST be removed before merging.
  Planned work MUST live in issues, not in source comments.
- **Documented Public API**: Every exported function, component, and type MUST carry a doc
  comment describing its purpose, parameters, and return value or side-effects.
- **Linting & Formatting**: Code MUST pass all configured linter and formatter checks (zero
  warnings policy) in CI before a PR can be merged.
- **Complexity Cap**: Cyclomatic complexity MUST NOT exceed 10 per function. Violations block
  merge until refactored or explicitly waived with justification.

### II. Testing Standards

Testing is not optional. Every feature increment MUST ship with tests that prove correctness
before the implementation is considered done:

- **Test-First by Default**: Tests MUST be written (and confirmed failing) before implementation
  begins on any new unit of behaviour. The Red → Green → Refactor cycle is mandatory.
- **Coverage Floor**: Unit-test coverage for all new and modified code MUST be ≥ 80%.
  Falling below this floor blocks merge.
- **Independence**: Tests MUST NOT share mutable state. Each test MUST be runnable in isolation
  and in any order, producing identical results.
- **Determinism**: Tests MUST NOT rely on wall-clock time, random seeds without fixed values,
  network calls, or file-system state not set up within the test itself.
- **Integration Coverage**: Any interaction crossing a module boundary or calling an external
  service MUST have at least one integration test covering the happy path and one covering a
  representative failure mode.
- **Test Naming**: Test names MUST describe the scenario in plain language:
  `given_<state>_when_<action>_then_<outcome>` or an equivalent readable convention.

### III. User Experience Consistency

Every user-facing surface MUST feel like it belongs to the same product. Inconsistency erodes
trust and increases cognitive load:

- **Design System First**: All UI elements MUST use the project's shared design tokens (colours,
  spacing, typography, border radii). Ad-hoc inline style values that duplicate or override
  tokens are prohibited without a design-system PR.
- **Human-Readable Errors**: Error messages presented to users MUST be written in plain language,
  explain what went wrong, and suggest a corrective action. Stack traces, raw codes, and
  technical identifiers MUST NOT appear in user-facing surfaces.
- **Always Communicate State**: Any operation taking > 200 ms MUST display a loading indicator
  (spinner, skeleton, or progress bar). Empty states MUST include instructional copy, not a
  blank screen.
- **Consistent Patterns**: Navigation, form validation feedback, modal behaviour, and button
  affordances MUST follow the patterns established in the design system. New patterns MUST be
  approved by the team before implementation.
- **Accessibility (WCAG 2.1 AA)**: All interactive elements MUST be keyboard-navigable. Colour
  contrast ratios MUST meet AA minimums (4.5:1 for normal text, 3:1 for large text). ARIA
  roles and labels MUST be present on all non-semantic interactive components.

### IV. Performance Requirements

Performance is a feature. Regressions are bugs and MUST be treated with the same priority as
functional defects:

- **Initial Load**: The application MUST reach First Contentful Paint (FCP) within 2 seconds
  and Time to Interactive (TTI) within 3 seconds on a mid-range device over a simulated 4G
  connection (Chrome DevTools "Fast 4G" profile).
- **Interaction Responsiveness**: All user interactions (button press, input, navigation) MUST
  produce visible feedback within 100 ms. Operations that cannot complete in 100 ms MUST show
  an immediate loading indicator.
- **Bundle Discipline**: No runtime dependency MUST be added without a documented size-impact
  review. The total initial JS bundle MUST NOT grow by more than 10 kB (gzipped) per PR
  without explicit approval.
- **No Memory Leaks**: Every component and service MUST clean up event listeners, subscriptions,
  timers, and observers on teardown. Memory profiles MUST be reviewed for long-running sessions
  before each major release.
- **Regression Gate**: Any performance metric regression exceeding 10% of the established
  baseline (measured in CI) MUST be investigated and resolved or explicitly accepted before
  the PR is merged.

## Quality Gates

The following automated and manual checks MUST pass before any PR is merged to the main branch:

| Gate | Tool / Check | Blocks Merge? |
|------|-------------|--------------|
| Linting & formatting | Configured linter (zero warnings) | Yes |
| Unit test coverage ≥ 80% | Coverage reporter in CI | Yes |
| All tests pass | CI test suite | Yes |
| Bundle size delta | Bundle analyser diff | Yes (> 10 kB gzip) |
| Performance baseline | Lighthouse / perf CI job | Yes (> 10% regression) |
| Accessibility scan | axe / pa11y automated scan | Yes (new violations) |
| Peer code review | ≥ 1 approval from a team member | Yes |

## Development Workflow

- **Branch Strategy**: All work MUST occur on short-lived feature branches (`###-short-description`)
  branched from `main`. Direct commits to `main` are prohibited.
- **PR Size**: PRs MUST be kept small and focused (≤ 400 lines of production code changed where
  possible). Large changes MUST be decomposed into stacked PRs.
- **Commit Discipline**: Commits MUST use Conventional Commits format
  (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`, `chore:`). Each commit MUST represent a
  single logical change that leaves the codebase in a working state.
- **Feature Flags**: Incomplete or experimental features MUST be gated behind a feature flag and
  MUST NOT affect users until explicitly enabled.
- **Dependency Updates**: Dependency updates MUST be reviewed for breaking changes, licence
  compatibility, and security advisories before merging.

## Governance

This constitution is the supreme governing document for SheetShow development. It supersedes
all other guidelines, style guides, or team norms where conflicts exist.

**Amendment Procedure**:

1. Open a PR that modifies `.specify/memory/constitution.md` with a clear rationale.
2. Obtain approval from at least one other active contributor.
3. If the change is MAJOR (removes or redefines a principle), include a migration plan describing
   how existing code and processes will be updated.
4. Bump the version number following the semantic rules below.
5. Update the `Last Amended` date to the merge date.

**Versioning Policy**:

- **MAJOR** (X.0.0): Backward-incompatible governance change — principle removed, fundamentally
  redefined, or a quality gate removed.
- **MINOR** (X.Y.0): New principle added, existing principle materially expanded, or a new
  mandatory section introduced.
- **PATCH** (X.Y.Z): Clarifications, wording improvements, typo fixes, or non-semantic
  refinements that do not change intent.

**Compliance Review**: All PR reviewers MUST verify constitution compliance as part of their
review checklist. Non-compliance MUST be called out and resolved before approval is granted.

**Version**: 1.0.0 | **Ratified**: 2025-07-18 | **Last Amended**: 2025-07-18
