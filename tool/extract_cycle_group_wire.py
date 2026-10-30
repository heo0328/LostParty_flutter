"""Project the approved cycle-group OpenAPI onto the app's existing operations.

Usage: python tool/extract_cycle_group_wire.py path/to/two-cycle.openapi.yaml
The original snapshot remains immutable and is used only for saved requests.
"""
import hashlib
import json
import sys
from pathlib import Path

SOURCE = "b212ad0f45e36e1bd5c6c860bb1e118f590bbc79"
BLOB = "c8f611615453403bec337a073c32d965e697488f"
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "lib/features/recruitment_list/data/beta"


def refs(value):
    if isinstance(value, dict):
        if "$ref" in value:
            yield value["$ref"].split("/")[-1]
        for item in value.values():
            yield from refs(item)
    elif isinstance(value, list):
        for item in value:
            yield from refs(item)


def rewrite(value):
    if isinstance(value, dict):
        return {k: "#/$defs/" + v.split("/")[-1] if k == "$ref" else rewrite(v)
                for k, v in value.items()}
    if isinstance(value, list):
        return [rewrite(v) for v in value]
    return value


def main():
    raw = Path(sys.argv[1]).read_bytes()
    assert hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest() == BLOB
    api = json.loads(raw)
    original = json.loads((DEST / "beta_original_wire_schema.g.dart").read_text(encoding="utf-8")
                          .split("r'''", 1)[1].rsplit("'''", 1)[0])
    operations, needed = [], set()
    definitions = dict(original["definitions"])
    for old in original["operations"]:
        operation = api["paths"][old["path"]][old["method"].lower()]
        previous = {p["name"]: p for p in old["query"]}
        query = []
        for parameter in operation.get("parameters", []):
            if parameter["in"] != "query":
                continue
            name = parameter["name"]
            if "schema" not in parameter:
                query.append(previous[name])  # Existing JSON-encoded query contract.
                continue
            item = {k: parameter[k] for k in ("name", "required", "schema")}
            # The app always consumes beta; preserve its stricter required inputs.
            item["required"] |= previous.get(name, {}).get("required", False)
            if name == "contract_profile":
                item.update(required=True, schema={"type": "string", "const": "beta-recruitment-1"})
            query.append(item)
        request = operation.get("requestBody", {}).get("content", {}).get("application/json", {}).get("schema")
        if request and "anyOf" in request:
            if old["path"].endswith("/common-settings"):
                request = {"$ref": "#/components/schemas/TitleCommand"}
            else:
                request, = [branch for branch in request["anyOf"]
                            if branch.get("$ref", "").split("/")[-1].startswith("Beta")]
        responses = {status: response["content"]["application/json"]["schema"]
                     for status, response in operation["responses"].items()
                     if status.startswith("2") and "content" in response}
        projected = {"id": old["id"], "method": old["method"], "path": old["path"],
                     "query": query, "request": request, "responses": responses}
        operations.append(rewrite(projected))
        needed.update(refs(projected))
    seen = set()
    while needed:
        name = min(needed)
        needed.remove(name)
        if name in seen:
            continue
        seen.add(name)
        if name not in api["components"]["schemas"]:
            assert name in definitions
            continue
        definition = api["components"]["schemas"][name]
        definitions[name] = rewrite(definition)
        needed.update(set(refs(definition)) - seen)
    result = {"operations": operations, "definitions": definitions}
    (DEST / "beta_wire_schema.g.dart").write_text(
        f"// Generated validation projection from Backend {SOURCE}.\n"
        "// Regenerate with tool/extract_cycle_group_wire.py; original requests use the original snapshot.\n"
        "const betaWireSchemaJson = r'''\n" + json.dumps(result, ensure_ascii=False, indent=2) + "\n''';\n",
        encoding="utf-8")
    print(f"Pinned {len(operations)} operations, {len(definitions)} definitions")


if __name__ == "__main__":
    main()
