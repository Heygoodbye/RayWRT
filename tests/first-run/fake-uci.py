#!/usr/bin/env python3
"""Small UCI fixture used to execute RayWRT first-run shell helpers."""
import json
import os
import sys
from pathlib import Path


args = sys.argv[1:]
config_dir = Path(os.environ.get("RAYWRT_CONFIG_DIR", "/etc/config"))
while args and args[0] in ("-c", "-p"):
    option = args.pop(0)
    value = args.pop(0)
    if option == "-c":
        config_dir = Path(value)
while args and args[0] == "-q":
    args.pop(0)
if not args:
    raise SystemExit(2)

config_dir.mkdir(parents=True, exist_ok=True)
state_file = config_dir / ".fixture-uci.json"
committed_file = config_dir / ".fixture-uci-committed.json"
state = json.loads(state_file.read_text()) if state_file.exists() else {}
committed = json.loads(committed_file.read_text()) if committed_file.exists() else state.copy()


def save():
    state_file.write_text(json.dumps(state, sort_keys=True))


def key_parts(key):
    return key.split(".")


def get_value(key):
    value = state.get(key)
    if isinstance(value, list):
        return value[0] if value else None
    return value


operation = args.pop(0)
if operation == "get":
    value = get_value(args[0])
    if value is None:
        raise SystemExit(1)
    print(value)
elif operation == "set":
    key, value = args[0].split("=", 1)
    state[key] = value
    save()
elif operation == "add_list":
    key, value = args[0].split("=", 1)
    current = state.setdefault(key, [])
    if not isinstance(current, list):
        current = [current]
    current.append(value)
    state[key] = current
    save()
elif operation == "add":
    config, section_type = args
    existing = [key.split(".")[1] for key in state if key.startswith(config + ".")]
    index = 0
    while f"cfg{index:04d}" in existing:
        index += 1
    section = f"cfg{index:04d}"
    state[f"{config}.{section}"] = section_type
    save()
    print(section)
elif operation == "delete":
    state.pop(args[0], None)
    save()
elif operation == "show":
    prefix = args[0] if args else ""
    if prefix == "wireless":
        for key, value in sorted(state.items()):
            if key.startswith("wireless."):
                section = key.split(".")[1]
                if key.count(".") == 1:
                    print(f"wireless.{section}={value}")
                elif isinstance(value, list):
                    for item in value:
                        print(f"{key}='{item}'")
                else:
                    print(f"{key}='{value}'")
    else:
        for key, value in sorted(state.items()):
            if key == prefix or key.startswith(prefix + ".") or not prefix:
                values = value if isinstance(value, list) else [value]
                for item in values:
                    if item is not None:
                        print(f"{key}='{item}'")
elif operation == "commit":
    committed = state.copy()
    committed_file.write_text(json.dumps(committed, sort_keys=True))
    if args and args[0] == "wireless":
        (config_dir / "wireless").write_text("# fixture committed wireless state\n")
elif operation == "revert":
    name = args[0]
    state = {k: v for k, v in state.items() if not k.startswith(name + ".")}
    state.update({k: v for k, v in committed.items() if k.startswith(name + ".")})
    save()
else:
    raise SystemExit(f"unsupported fixture uci operation: {operation}")
