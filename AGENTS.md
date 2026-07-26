# AGENTS.md

## Bootstrap

Before substantial work, read these files in order:

1. `.agents/AGENTS.md`
2. `.agents/PROJECT.md`
3. `.agents/ARCHITECTURE.md`
4. `.agents/TODO.md`
5. `.agents/SESSION.md`

Also use global user context when available:

- `~/.agent/ME.md`

## Working Rules

- Update `.agents/` and `README.md` when substantial behavior or project
  decisions change.
- Keep the production package RTL8812AU USB-focused.
- Never add test-only fault injection to a production build.
- Do not claim secured, USB2, powered-path, or long-endurance validation without
  matching hardware evidence.
