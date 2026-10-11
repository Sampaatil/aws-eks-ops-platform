
"""Validate safe release evidence without running a scanner in the CD project."""

import datetime as dt
import hashlib
import json
import re
from pathlib import Path


def verify_security(record, root=Path(".")):
    security = record.get("security", {})

    if security.get("schemaVersion") != 1 or security.get("status") != "PASSED":
        raise RuntimeError("Phase 12 passing security evidence required")

    if security.get("commit") != record["commit"]:
        raise RuntimeError("Security evidence commit mismatch")

    expected = {"secrets", "lint", "tests", "dependencies", "iac", "images"}

    if set(security.get("stages", {})) != expected or any(
        value != "PASSED" for value in security["stages"].values()
    ):
        raise RuntimeError("All configured security stages must pass")

    # Missing frontend tests are disclosed separately.
    # Tests stage means declared tests passed.

    reports = security.get("reports", {})
    required = {
        "source-secrets",
        "source-dependencies",
        "iac",
        "image-backend",
        "image-frontend",
    }

    if set(reports) != required:
        raise RuntimeError("Expected all five sanitized scanner reports")

    loaded = {}

    for name, entry in reports.items():
        path = f"security/reports/{name}.json"

        if entry.get("path") != path:
            raise RuntimeError("Unexpected security report path")

        blob = (root / path).read_bytes()

        if (
            not re.fullmatch(r"[a-f0-9]{64}", entry.get("sha256", ""))
            or hashlib.sha256(blob).hexdigest() != entry["sha256"]
        ):
            raise RuntimeError("Security report checksum mismatch")

        report = json.loads(blob)

        if report.get("status") != "PASSED" or report.get("blockingCount") != 0:
            raise RuntimeError("Blocking findings or incomplete scanner report")

        for finding in report.get("findings", []):
            kind = finding.get("kind")
            severity = finding.get("severity")
            disposition = finding.get("disposition")

            if kind not in ("secret", "vulnerability", "misconfiguration"):
                raise RuntimeError("Unknown security finding type")

            if severity not in (
                "UNKNOWN",
                "LOW",
                "MEDIUM",
                "HIGH",
                "CRITICAL",
            ):
                raise RuntimeError("Unknown security finding severity")

            # Secrets always block deployment.
            if kind == "secret":
                raise RuntimeError("Detected secret in passing report")

            # Lab policy:
            # IaC misconfigurations are informational, not deployment blockers.
            if kind == "misconfiguration":
                if disposition != "INFORMATIONAL":
                    raise RuntimeError(
                        "Unexpected IaC finding disposition"
                    )
                continue

            # Vulnerability policy:
            # CRITICAL and UNKNOWN findings cannot be exempted.
            if severity in ("CRITICAL", "UNKNOWN"):
                raise RuntimeError(
                    "Non-exemptible vulnerability in passing report"
                )

            # HIGH vulnerabilities require a reviewed exception.
            if severity == "HIGH":
                exception = finding.get("exception", {})

                if disposition != "ACCEPTED":
                    raise RuntimeError(
                        "Unaccepted HIGH vulnerability in passing report"
                    )

                today = dt.datetime.now(dt.timezone.utc).date()

                expiration = dt.date.fromisoformat(
                    exception.get("expires", "")
                )

                if (
                    expiration < today
                    or expiration > today + dt.timedelta(days=30)
                ):
                    raise RuntimeError(
                        "HIGH exception expired before deployment "
                        "or exceeds policy"
                    )

            elif disposition != "INFORMATIONAL":
                raise RuntimeError(
                    "Unexpected vulnerability finding disposition"
                )

        loaded[name] = report

    # Verify that image scan evidence matches the deployed image digests.
    for app in ("backend", "frontend"):
        evidence = loaded["image-" + app]

        if evidence.get("image") != record[app + "Image"]:
            raise RuntimeError(
                "Image security evidence not bound to release digest"
            )

        if not re.fullmatch(
            r"sha256:[a-f0-9]{64}",
            evidence.get("localImageId", ""),
        ):
            raise RuntimeError("Image scan provenance missing")

    return security
