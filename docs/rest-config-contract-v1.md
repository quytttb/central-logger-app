# REST config contract v1 (Central ↔ data-logger)

Base URL: `http://<host>:<api_port>/api/v1` (or `api_base_url` override).

## Central DB (`logger_info`)

| Column | Role |
|--------|------|
| `name`, `host`, `port`, `unit_id`, `poll_interval_s`, `timeout_s` | Modbus TCP client (Central polls edge; interval in **seconds**, synced from edge `poll_interval`) |
| `api_port`, `api_token`, `api_base_url`, `last_revision` | REST client |
| `enabled`, `note` | Operations |

`port` is edited only in the **Central** column of Add/Edit. It is not mirrored as `modbus_tcp_port` on the Device column.

## Edge `GET/POST /config` root fields

| REST key | Device form (Edit, online) |
|----------|----------------------------|
| `station_code` | Station code |
| `station_name` | Station name |
| `poll_interval` | Device poll interval (**seconds**) |
| `modbus_tcp_bind` | Modbus TCP bind |
| `modbus_tcp_enabled` | Modbus TCP server enabled |
| `modbus_tcp_unit_id` | Modbus TCP unit ID (edge) |

Not in REST snapshot: `rest_api_token` (use [provision QR](provision-qr-v1.md)).

**Do not send:** `logger_serial`, `cloud_enabled`, `cloud_endpoint` — edge returns 422 (`extra=forbid`).

## Revision

`last_revision` in Central DB; used internally for `POST /config` `expected_revision`. Not shown in UI.

## Additional endpoints (data-logger REST v1)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/readings` | Bearer | Live sensor values (top-level only): analog + standalone DI/DO. Central merges with Modbus poll for analog. |
| GET | `/reports/latest` | Bearer | Download newest TXT report from edge `DATA_DIR/reports/` (`Content-Disposition: attachment`). |

### GET `/readings` response

```json
{
  "ok": true,
  "polling": true,
  "rtu_connected": true,
  "sensors": [
    {
      "sensor_id": 1,
      "sensor_type": "ANALOG",
      "value": 25.5,
      "status": "OK",
      "is_alarm": false,
      "alarm_type": "",
      "valid": true,
      "recorded_at": "2026-05-19T10:00:00"
    }
  ]
}
```

Central: `DashboardController.fetchReadings(loggerId)` — polled when catalog has DI/DO or on Logger Detail open.
