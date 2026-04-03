# Sprint <N>: <Title>

## Status
DRAFT → ACTIVE → DELIVERED → REVIEWED → MERGED | REJECTED

## Agent
<gemini | codex | opus>

## Objective
<One sentence: what this Sprint delivers>

## Acceptance Criteria
- [ ] <Specific, testable criterion 1>
- [ ] <Specific, testable criterion 2>
- [ ] <Specific, testable criterion 3>

## Context
<Background info the agent needs. Reference files, APIs, design decisions.>

## Constraints
- Timeout: <60 | 120 | 180>s
- Files in scope: <list specific files or directories>
- Files out of scope: <do not touch>

## Deliverables
- [ ] <File or feature 1>
- [ ] <File or feature 2>

## Chaos Gate (optional — for Sprints with user-facing surfaces)
- Surfaces: web | cli | api | lib | auto
- Intensity: gentle | standard | berserk
- Budget: 5m
- Threshold: resilience >= 70
(Leader dispatches `/rampage --selfmodel` after E2E PASS, see quality-gates.md Step 4.7)
