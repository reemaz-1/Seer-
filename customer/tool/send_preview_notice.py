#!/usr/bin/env python3
"""Seed only the local demo Firestore emulator; never accepts a production URL."""
import argparse
import datetime
import json
from pathlib import Path
import urllib.request

BASE = 'http://127.0.0.1:8186/v1/projects/demo-seer-alert-preview/databases/(default)/documents/'
HEADERS = {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'}

def request(path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data=data, headers=HEADERS,
                                 method='GET' if body is None else 'PATCH')
    with urllib.request.urlopen(req) as response:
        return json.load(response)

def value(v):
    if isinstance(v, bool): return {'booleanValue': v}
    return {'stringValue': str(v)}

parser = argparse.ArgumentParser()
parser.add_argument('phase', choices=['foreground', 'home', 'lock', 'resume', 'recents'])
parser.add_argument('--evidence-dir', type=Path)
args = parser.parse_args()
customers = request('customers').get('documents', [])
if len(customers) != 1:
    raise SystemExit('Expected exactly one local preview customer; restart the demo emulators.')
uid = customers[0]['name'].split('/')[-1]
now = datetime.datetime.now(datetime.timezone.utc)
notice_id = 'host-' + args.phase + '-' + now.strftime('%H%M%S')
fields = {k: value(v) for k, v in {
    'recipientId': uid, 'type': 'orderStatusChanged', 'orderId': 'preview-order',
    'title': 'SEER TEST ' + args.phase.upper(),
    'body': 'LOCAL EMULATOR ONLY - no production data', 'read': False,
}.items()}
fields['createdAt'] = {'timestampValue': now.isoformat()}
result = request('notifications/' + notice_id, {'fields': fields})
record = {'phase': args.phase, 'notificationId': notice_id,
          'recipientId': uid, 'createdAt': now.isoformat(),
          'project': 'demo-seer-alert-preview', 'saved': result['name']}
print(json.dumps(record))
if args.evidence_dir:
    args.evidence_dir.mkdir(parents=True, exist_ok=True)
    (args.evidence_dir / (args.phase + '-fixture-event.json')).write_text(json.dumps(record, indent=2)+'\n')
