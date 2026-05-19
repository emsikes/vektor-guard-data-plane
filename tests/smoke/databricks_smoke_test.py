"""
Smoke test for the Vektor-Guard data plane Databricks setup.

Writes a small JSON file to the landing volume, verifies it exists,
reads it back, and cleans up.  Proves the runtime write path is 
functional end to end.
"""

import json
import subprocess
import sys
from datetime import datetime, timezone
from io import BytesIO

from databricks.sdk import WorkspaceClient


def aws_cli(*args: str) -> str:
    """Run an AWS CLI command and return stdout (stripped)."""
    result = subprocess.run(
        ["aws"] + list(args),
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()

def main() -> int:
    # Fetch credentials and config from AWS
    workspace_url = aws_cli(
        "ssm", "get-parameter",
        "--name", "/vektor-guard-dp-dev/databricks/workspace-url",
        "--query", "Parameter.Value",
        "--output", "text",
    )
    pat = aws_cli(
        "secretsmanager", "get-secret-value",
        "--secret-id", "vektor-guard-dp-dev/databricks-pat",
        "--query", "SecretString",
        "--output", "text",
    )

    print(f"Workspace: {workspace_url}")
    print(f"PAT length: {len(pat)}")

    # Initialize the Databricks client
    client = WorkspaceClient(host=workspace_url, token=pat)

    # The target path
    volume_path = "/Volumes/vektor_guard_dp/bronze/landing"
    test_filename = f"smoke_test_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.json"
    target = f"{volume_path}/{test_filename}"

    # Construct a sample event payload (what the sync agent would write)
    payload = {
        "event_id": "smoke-test-001",
        "event_ts": datetime.now(timezone.utc).isoformat(),
        "event_source": "smoke-test",
        "model_version": "vektor-guard-v2",
        "predicted_class": "benign",
        "predicted_confidence": 0.99,
        "provenance": {
            "test_run": True,
            "purpose": "verify_runtime_write_path",
        },
    }
    body = json.dumps(payload, indent=2).encode("utf-8")

    print(f"\nWriting to: {target}")
    print(f"Payload size: {len(body)} bytes")

    # Write the file
    client.files.upload(
        file_path=target,
        contents=BytesIO(body),
        overwrite=True,
    )
    print(" Write succeeded")

    # Verify it exists by listing the volume
    print(f"\nListing volume contents...")
    files = list(client.files.list_directory_contents(directory_path=volume_path))
    print(f" Found {len(files)} file(s) in volume")
    for f in files:
        print(f" {f.path} ({f.file_size}) bytes")

    if not any(f.path.endswith(test_filename) for f in files):
        print(f"\n Error: Test file not found in listing!")
        return 1
    
    # Read it back
    print(f"\nReading {test_filename} back...")
    response = client.files.download(file_path=target)
    readback = json.loads(response.contents.read())
    print(f" Read successful; event_id = {readback['event_id']}")
    assert readback["event_id"] == "smoke-test-001"
    assert readback["event_source"] == "smoke-test"

    # Cleanup 
    print(f"\nCleaning up...")
    client.files.delete(file_path=target)
    print(f" Deleted {target}")

    print("\n ALL CHECKS PASSED")
    return 0

if __name__ == "__main__":
    sys.exit(main())