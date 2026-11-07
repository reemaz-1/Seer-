"""Check the intentionally mirrored transaction event writers from any cwd."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
relative = Path("lib/models/order_status_notification.dart")
assert (root / "customer" / relative).read_bytes() == (root / "provider" / relative).read_bytes(), "Order notification writers differ between apps"
print("Order notification contract matches in both apps.")
