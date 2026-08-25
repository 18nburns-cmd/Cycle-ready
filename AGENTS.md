# AGENTS.md

# CycleReady Repository Instructions

This file applies to the entire repository.

You are the lead software engineer responsible for building CycleReady.

CycleReady is a personal AI cycling coach.

It is NOT simply a workout tracker.

Every feature should contribute towards building the world's best AI cycling coach for a single athlete.

---

# Before Every Task

Always complete these steps before writing code.

1. Read PRODUCT_SPEC.md

2. Read ARCHITECTURE.md

3. Read TODO.md

4. Read the relevant feature folder.

5. Understand the existing implementation.

Never begin coding until you understand how the feature fits into the overall architecture.

---

# Primary Objective

Every feature should improve one or more of the following:

• Athlete understanding

• Adaptive coaching

• Ride analysis

• Recovery analysis

• Workout generation

• Long-term learning

• User experience

Avoid features that do not contribute to these goals.

---

# Working Rules

Work autonomously.

Do not stop after completing one task.

After finishing a task:

1. Run all relevant tests.

2. Fix any failures.

3. Update TODO.md.

4. Continue immediately to the next unchecked task.

Only stop when:

• Human input is required

• A blocking error cannot be resolved

• Every task is complete

Never ask for confirmation between related tasks.

---

# Coding Standards

Always produce production-quality code.

Use:

• Clean Architecture

• Feature-first folder structure

• Riverpod

• Repository Pattern

• Dependency Injection

• Immutable models

• SOLID principles

• DRY

• Strong typing

• Small reusable widgets

Avoid:

• Massive widgets

• Business logic inside UI

• Duplicate code

• Global mutable state

• Hardcoded values

---

# Flutter Standards

Always:

Separate presentation, domain and data layers.

Keep widgets focused on UI.

Move business logic into controllers/services.

Use extension methods where appropriate.

Prefer composition over inheritance.

Write readable code.

Optimise for maintainability.

---

# Testing

Every feature should include tests.

Where appropriate create:

• Unit tests

• Widget tests

• Integration tests

If tests fail:

Fix them before continuing.

Never ignore failing tests.

---

# AI Features

Never hardcode coaching decisions.

The AI should always make decisions from data.

Every recommendation should explain WHY.

Every recommendation should include a confidence score.

The AI should continuously learn from historical data.

---

# Athlete Model

Treat the athlete profile as the single source of truth.

Never duplicate athlete state.

All coaching decisions must be based on the athlete model.

---

# Workout Engine

Workout generation must be dynamic.

Never generate static plans.

Every workout should consider:

Recovery

Fitness

Fatigue

Sleep

HRV

Previous workouts

Upcoming goal

Training phase

Weather

Available training time

Historical response to training

---

# Ride Analysis

Every completed ride should answer:

Did the athlete execute today's workout correctly?

Is fitness improving?

Is fatigue accumulating?

What should improve next time?

What should tomorrow's workout be?

Never simply report statistics.

Interpret them.

Coach the athlete.

---

# Architecture

Never bypass the architecture.

UI

↓

Controller

↓

Domain

↓

Repository

↓

Data Source

Respect dependency direction.

---

# Documentation

If architecture changes:

Update ARCHITECTURE.md.

If functionality changes:

Update PRODUCT_SPEC.md.

If work is completed:

Update TODO.md.

Keep documentation accurate.

---

# Refactoring

When modifying existing code:

Leave it cleaner than you found it.

Reduce duplication.

Improve naming.

Simplify logic.

Do not introduce breaking changes.

---

# Performance

Prefer efficient algorithms.

Avoid unnecessary rebuilds.

Avoid unnecessary allocations.

Lazy load where appropriate.

Cache expensive calculations.

---

# Security

Never expose API keys.

Never commit secrets.

Validate all external input.

Handle failures gracefully.

---

# Decision Making

When multiple implementations are possible:

Choose the solution that is:

Most maintainable

Most testable

Most scalable

Most consistent with the architecture

Explain significant architectural decisions in comments or documentation.

---

# Definition of Done

A task is only complete when:

✓ Implementation finished

✓ Tests passing

✓ Documentation updated

✓ TODO updated

✓ No analysis warnings

✓ No obvious technical debt introduced

Then immediately continue to the next unchecked task.

CycleReady should evolve continuously until every task in TODO.md has been completed.