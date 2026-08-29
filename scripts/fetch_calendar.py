#!/usr/bin/env python3
"""Fetch iCalendar feeds and emit the next few weeks of events as JSON.

Read by services/Calendar.qml in the grootshell repo, which draws the day
markers and the agenda from it.

A secret .ics URL rather than the Google Calendar API. The API means OAuth: a
consent flow completed in a browser, a refresh token to store and rotate, and a
client registration to keep alive — all to read events that the "secret address
in iCal format" link in Calendar's own settings hands over with a GET. Read-only
is the whole requirement here, so the cheap door is the right one.

Recurrence is expanded with recurring-ical-events rather than by hand. RRULE is
not a format to reimplement over a weekend: it has BYSETPOS, EXDATE, RDATE, and
per-instance overrides via RECURRENCE-ID, and the failure mode of getting it
subtly wrong is a standup that silently stops appearing.

Times are emitted as epoch milliseconds in UTC, so the QML side does no timezone
arithmetic — it formats what it is given in local time and that is correct by
construction.

The secret is one feed per line, `name|url`, so several calendars can be merged.
The name is a label only — colours are assigned shell-side from it, because a
colour is not a secret and changing one should not mean decrypting a file.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import sys
import urllib.request

import icalendar
import recurring_ical_events

# How far forward to expand. Long enough that paging a month or two ahead still
# shows markers, short enough that a calendar with a decade of weekly recurrences
# does not turn into a megabyte of JSON on every poll.
WEEKS_AHEAD = 10
WEEKS_BEHIND = 2

# Meeting links, in the order they are offered. Zoom and Teams bury the real
# link in the description; Meet usually sets it as the conference URL but not
# always, so every field gets scanned regardless of which one "should" have it.
JOIN_PATTERNS = [
    ("zoom", re.compile(r"https://[\w.-]*zoom\.(?:us|com)/j/[^\s<>\"']+")),
    ("meet", re.compile(r"https://meet\.google\.com/[a-z0-9-]+")),
    ("teams", re.compile(r"https://teams\.(?:microsoft|live)\.com/l/meetup-join/[^\s<>\"']+")),
    ("webex", re.compile(r"https://[\w.-]*webex\.com/[^\s<>\"']+")),
    ("jitsi", re.compile(r"https://meet\.jit\.si/[^\s<>\"']+")),
]

# A last resort, so a call on something we have no pattern for is still
# reachable rather than invisible.
ANY_URL = re.compile(r"https?://[^\s<>\"']+")


def to_epoch_ms(value) -> tuple[int, bool]:
    """Return (epoch_ms, all_day). Dates become local midnight, not UTC midnight.

    An all-day event is a date with no time and no zone. Treating it as UTC
    midnight puts it on the previous day for anyone east of Greenwich, which on
    this host means every all-day event lands a day early.
    """
    if isinstance(value, dt.datetime):
        if value.tzinfo is None:
            value = value.astimezone()
        return int(value.timestamp() * 1000), False
    # datetime.date
    local_midnight = dt.datetime(value.year, value.month, value.day).astimezone()
    return int(local_midnight.timestamp() * 1000), True


def find_links(*fields: str) -> list[dict[str, str]]:
    text = "\n".join(f for f in fields if f)
    if not text:
        return []

    out: list[dict[str, str]] = []
    seen: set[str] = set()

    for kind, pattern in JOIN_PATTERNS:
        for match in pattern.findall(text):
            url = match.rstrip(".,)>")
            if url not in seen:
                seen.add(url)
                out.append({"kind": kind, "url": url})

    if not out:
        for match in ANY_URL.findall(text):
            url = match.rstrip(".,)>")
            if url not in seen:
                seen.add(url)
                out.append({"kind": "link", "url": url})

    return out


def clean(value) -> str:
    if value is None:
        return ""
    text = str(value)
    # Google escapes these in DESCRIPTION per RFC 5545; icalendar hands back the
    # raw text with the escapes still in it for some producers.
    return text.replace("\\n", "\n").replace("\\,", ",").replace("\\;", ";").strip()


def read_feeds(path: str) -> list[tuple[str, str]]:
    """Parse the secret into (name, url) pairs.

    One feed per line as `name|url`, or a bare url. Blank lines and # comments
    are skipped so the file can be annotated.
    """
    if not path or not os.path.exists(path):
        return []

    feeds: list[tuple[str, str]] = []
    with open(path, encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "|" in line:
                name, _, url = line.partition("|")
                name, url = name.strip(), url.strip()
            else:
                name, url = "", line
            if url:
                feeds.append((name, url))
    return feeds


def fetch_one(name: str, url: str) -> tuple[list[dict], str, str]:
    """Return (events, resolved_name, error). One bad feed must not lose the rest."""
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "grootshell"})
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = response.read()
    except Exception as exc:  # noqa: BLE001 - any failure is "not right now"
        return [], name or "Calendar", str(exc)

    try:
        cal = icalendar.Calendar.from_ical(raw)
        # The feed names itself unless the secret gave it a name. Saves typing a
        # label for the common case of one personal calendar.
        resolved = name or clean(cal.get("X-WR-CALNAME")) or "Calendar"
        now = dt.datetime.now().astimezone()
        start = now - dt.timedelta(weeks=WEEKS_BEHIND)
        end = now + dt.timedelta(weeks=WEEKS_AHEAD)
        occurrences = recurring_ical_events.of(cal).between(start, end)
    except Exception as exc:  # noqa: BLE001
        return [], name or "Calendar", str(exc)

    return list(occurrences), resolved, ""


def feed_file() -> str:
    """Where the `name|url` list lives.

    The environment variable wins, because on NixOS the list is a sops secret
    decrypted to a path under /run that nothing else can guess. Everyone else
    gets a plain file in the config directory, so setting a calendar up is
    creating one file rather than also arranging for an environment variable to
    reach a systemd service.
    """
    explicit = os.environ.get("GROOTSHELL_CALENDAR_URL_FILE", "")
    if explicit:
        return explicit

    config = os.environ.get("XDG_CONFIG_HOME") or os.path.join(
        os.path.expanduser("~"), ".config"
    )
    return os.path.join(config, "grootshell", "calendars")


def main() -> int:
    feeds = read_feeds(feed_file())

    if not feeds:
        # Not an error. No calendar configured is a normal state, and the shell
        # should show an empty agenda rather than a failure.
        json.dump({"events": [], "calendars": [], "configured": False}, sys.stdout)
        return 0

    events = []
    calendars: list[str] = []
    errors: list[str] = []

    occurrences: list = []
    for name, url in feeds:
        found, resolved, error = fetch_one(name, url)
        if resolved not in calendars:
            calendars.append(resolved)
        if error:
            errors.append(f"{resolved}: {error}")
        for item in found:
            occurrences.append((resolved, item))

    for calendar_name, event in occurrences:
        try:
            start_ms, all_day = to_epoch_ms(event.get("DTSTART").dt)
            end_prop = event.get("DTEND")
            end_ms = to_epoch_ms(end_prop.dt)[0] if end_prop else start_ms
        except Exception:  # noqa: BLE001 - a malformed event should not lose the rest
            continue

        summary = clean(event.get("SUMMARY")) or "(no title)"
        location = clean(event.get("LOCATION"))
        description = clean(event.get("DESCRIPTION"))
        conference = clean(event.get("X-GOOGLE-CONFERENCE")) or clean(event.get("URL"))

        events.append(
            {
                "calendar": calendar_name,
                "summary": summary,
                "start": start_ms,
                "end": end_ms,
                "allDay": all_day,
                "location": location,
                "description": description,
                "links": find_links(conference, location, description),
            }
        )

    events.sort(key=lambda e: e["start"])
    json.dump(
        {
            "events": events,
            # Order matters: the shell assigns a default colour by position, so
            # this has to be stable across polls. It follows the order of the
            # secret rather than of whichever feed answered first.
            "calendars": calendars,
            "configured": True,
            "error": "; ".join(errors),
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
