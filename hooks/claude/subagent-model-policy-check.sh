#!/usr/bin/env bash
# PreToolUse — blocks Agent/Workflow calls that don't set an explicit
# low-cost model (Agent) or explicit model+effort per agent() call
# (Workflow), per CLAUDE.md's subagent-model-policy.
#
# Fails CLOSED: anything it can't statically verify (model/effort passed
# via a variable instead of a literal) is treated as missing and blocked,
# not silently passed through.

INPUT=$(cat)

python3 - "$INPUT" <<'PY'
import json, re, sys

ALLOWED_MODELS = {"sonnet", "haiku"}
ALLOWED_EFFORTS = {"low", "medium"}

try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    sys.exit(0)

tool = data.get("tool_name")
tool_input = data.get("tool_input") or {}

def block(reason):
    print(json.dumps({"decision": "block", "reason": reason}))
    sys.exit(0)

if tool == "Agent":
    model = tool_input.get("model")
    if model not in ALLOWED_MODELS:
        block(
            "Agent call is missing an explicit low-cost `model` "
            f"(must be one of: {', '.join(sorted(ALLOWED_MODELS))}). "
            "Per CLAUDE.md's subagent-model-policy, every Agent call must "
            "set model explicitly — the default inherits the session "
            "model, which may exceed the policy."
        )
    sys.exit(0)

if tool == "Workflow":
    script = tool_input.get("script") or ""
    if not script:
        sys.exit(0)  # named/scriptPath workflows — nothing to statically check here

    violations = []
    for m in re.finditer(r"\bagent\s*\(", script):
        depth, i = 1, m.end()
        while i < len(script) and depth:
            depth += (script[i] == "(") - (script[i] == ")")
            i += 1
        call_src = script[m.end():i]
        line_no = script.count("\n", 0, m.start()) + 1

        model_m = re.search(r"model\s*:\s*['\"](\w+)['\"]", call_src)
        effort_m = re.search(r"effort\s*:\s*['\"](\w+)['\"]", call_src)
        if not model_m or model_m.group(1) not in ALLOWED_MODELS:
            violations.append(f"line ~{line_no}: agent() missing a literal model in {sorted(ALLOWED_MODELS)}")
        if not effort_m or effort_m.group(1) not in ALLOWED_EFFORTS:
            violations.append(f"line ~{line_no}: agent() missing a literal effort in {sorted(ALLOWED_EFFORTS)}")

    if violations:
        block(
            "Workflow script has agent() call(s) that don't verify as "
            "low-cost per CLAUDE.md's subagent-model-policy:\n"
            + "\n".join(f"  - {v}" for v in violations)
            + "\nSet model and effort as literal strings on every agent() "
              "call, e.g. {model: 'sonnet', effort: 'low'}. If they're "
              "already set via a variable, inline them as literals so "
              "this check can verify them."
        )
    sys.exit(0)
PY
