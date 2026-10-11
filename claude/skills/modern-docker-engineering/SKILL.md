---
name: modern-docker-engineering
description: "Automatically enforces modern Docker engineering standards, BuildKit multi-stage Dockerfiles, non-root/rootless containers, modern Compose Spec orchestration (compose.yaml / docker-compose.yaml), healthcheck choreography, network segmentation, and lean build context filtering with .dockerignore."
---

# Modern Docker Engineering Guardrails & Skill Router

Entry point for this plugin's guardrails in Claude Code. Before acting, read the full standard:

`${CLAUDE_PLUGIN_ROOT}/rules/modern-docker-engineering.md`

It routes each kind of task to the specialized skill of this plugin and lists the non-negotiable rules.
In Claude Code those skills are namespaced: invoke `modern-docker-best-practices:<skill-name>`.

> Generated from `rules/modern-docker-engineering.md`, which is also the Antigravity rule. Edit the rule, not this file.
