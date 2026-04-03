# Playbook Marketplace

Community-contributed playbooks for selfmodel. Each playbook adapts the orchestration framework to a specific domain, tech stack, or workflow style.

## What is a Playbook?

A playbook is a set of configuration files that customize how selfmodel evaluates, dispatches, and reviews code for a specific context:

- **Dispatch rules** — which agent handles which task type
- **Quality gates** — scoring dimensions and thresholds
- **Evaluator prompts** — what the independent evaluator looks for
- **Sprint templates** — contract format for your domain

## Available Playbooks

| Playbook | Domain | Description |
|----------|--------|-------------|
| `default/` | General | The built-in selfmodel playbook (ships with the framework) |

> Want yours listed here? Submit a PR!

## Creating a Playbook

### Directory Structure

```
playbooks/
  your-playbook/
    README.md              # Description, use cases, installation
    dispatch-rules.md      # Agent routing matrix
    quality-gates.md       # Scoring dimensions and weights
    evaluator-prompt.md    # Evaluator instructions (optional)
    sprint-template.md     # Contract template (optional)
```

### Requirements

1. **README.md** is required — explain what domain this is for and why default rules don't fit
2. At least one of: `dispatch-rules.md`, `quality-gates.md`, `evaluator-prompt.md`
3. Must not break the default selfmodel workflow
4. All rules must follow the Iron Rules (Never Mock, Never Lazy, etc.)

### Example: ML Playbook

An ML-focused playbook might:
- Add a "Data Integrity" scoring dimension (detect train/test leakage)
- Route data pipeline tasks to Codex (structured, repetitive)
- Route model architecture tasks to Opus (complex, creative)
- Add evaluator checks for reproducibility (random seeds, deterministic ops)

### Installation

```bash
# Copy a community playbook into your project
cp -r playbooks/ml-ops/ .selfmodel/playbook/

# Or selectively override specific files
cp playbooks/ml-ops/quality-gates.md .selfmodel/playbook/quality-gates.md
```

## Contributing

1. Fork the repo
2. Create your playbook in `playbooks/your-name/`
3. Include a clear README explaining the use case
4. Submit a PR

See [CONTRIBUTING.md](../CONTRIBUTING.md) for general guidelines.
