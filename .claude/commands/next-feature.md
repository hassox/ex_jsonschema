---
description: "Intelligently implement the next feature in the ExJsonschema upgrade roadmap"
args:
  - name: "context"
    description: "Optional: milestone ID (M1.1), focus area (testing/performance), or 'status'"
    required: false
---

# ExJsonschema Next Feature Implementation

## Algorithm

1. **Determine Target**
   - Read `docs/upgrade/PROGRESS.md` for current status
   - If {{context}} is milestone ID (M1.x): target that specific task
   - If {{context}} is focus area: apply that lens to next task
   - If {{context}} is "status": show progress and recommend next action
   - Default: implement next incomplete task in dependency order

2. **Get Constraints**
   - `docs/upgrade/ROADMAP.md` - dependencies and acceptance criteria
   - `docs/upgrade/TESTING_STRATEGY.md` - testing requirements (>95% coverage, all test types)
   - Current codebase - follow existing patterns and conventions

3. **Execution Process**
   - **TodoWrite first** - track all subtasks immediately
   - **Test-first always** - comprehensive test suite before implementation
   - **Progressive implementation** - research → design → test → implement → document → validate
   - **Update progress** - mark todos complete as you go

4. **Success Validation**
   - All acceptance criteria from roadmap met
   - Test coverage >95% with all test types passing
   - Documentation updated with tested examples
   - Ready for next milestone dependency

## Implementation Focus

Start working immediately - no planning phase needed. The roadmap is the plan.

Break changes are acceptable. Design the ideal API that exposes the Rust crate capabilities through idiomatic Elixir patterns.