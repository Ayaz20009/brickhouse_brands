# Notifications Schema V2 - Enhancement Summary

## Overview
This migration demonstrates advanced schema evolution capabilities, adding enterprise-grade features to the notification system for improved tracking, assignment, and analytics.

## 🆕 New Columns Added to `notifications` Table

| Column Name | Type | Purpose |
|------------|------|---------|
| `priority` | VARCHAR(20) | Priority level: low, medium, high, urgent |
| `assigned_to_user_id` | INT | User assigned to handle the notification |
| `resolved_by_user_id` | INT | User who resolved the notification |
| `estimated_impact_cost` | DECIMAL(12,2) | Estimated financial impact of the stock issue |
| `notes` | TEXT | Additional comments and notes |
| `tags` | TEXT[] | Array of tags for categorization |
| `due_date` | TIMESTAMP | Target resolution date |
| `auto_resolved` | BOOLEAN | Flag for system-resolved notifications |
| `viewed_count` | INT | Number of times viewed |
| `last_viewed_at` | TIMESTAMP | Last view timestamp |

## 🗃️ New Tables Created

### 1. `notification_history`
Comprehensive audit trail tracking all notification changes:
- Action type (created, updated, assigned, resolved, reopened, viewed, commented)
- Changed by user ID
- Timestamp
- Old and new values (JSONB)
- Comments

### 2. `notification_sla`
Service Level Agreement configuration for notification response and resolution times:
- Target response hours
- Target resolution hours
- Configurable by notification type, severity, and priority
- Default SLA values for 10 common scenarios

### 3. `notification_analytics` (Materialized View)
Pre-aggregated analytics for performance:
- Daily notification counts by type, severity, priority
- Resolution metrics
- Average resolution time
- Total and average estimated impact costs
- Unique assignee counts

## 📊 New Views

### `overdue_notifications`
Real-time view of notifications exceeding their SLA targets:
- Shows hours open vs. target resolution hours
- Includes assignee details
- Filters for unresolved notifications only

## ⚡ Automated Triggers

### 1. Priority Auto-Assignment
- Automatically sets priority based on severity if not explicitly set
- Critical → Urgent, High → High, Medium → Medium, Low → Low
- Calculates estimated impact cost based on stock deficit

### 2. Change Logging
- Automatically logs all notification changes to history table
- Tracks creation, updates, assignments, and resolutions
- Preserves old and new values in JSONB format

## 🔍 New Indexes for Performance

- Composite index on (is_resolved, severity, priority, created_at)
- Store-severity composite index
- Priority index
- Assignment tracking indexes
- GIN index on tags array
- History table indexes for fast lookups

## 💡 Business Benefits

1. **Better Assignment Tracking**: Know who's responsible for each notification
2. **SLA Management**: Track and report on resolution times
3. **Cost Impact Analysis**: Quantify the financial impact of stock issues
4. **Audit Trail**: Complete history of all notification changes
5. **Advanced Filtering**: Tag-based categorization for better organization
6. **Performance Analytics**: Pre-aggregated data for dashboards
7. **Overdue Monitoring**: Identify notifications requiring immediate attention

## 📋 To Apply This Migration

```bash
# Option 1: Using psql (requires admin privileges)
psql -h <DB_HOST> -p <DB_PORT> -d <DB_NAME> -U <ADMIN_USER> -f notifications_schema_v2.sql

# Option 2: Through Databricks SQL Warehouse
# - Copy the contents of notifications_schema_v2.sql
# - Execute in a SQL Warehouse with appropriate permissions

# Option 3: Using Python (from database directory)
source venv/bin/activate
python -c "
import os
import psycopg2
from dotenv import load_dotenv

load_dotenv('../.env')

conn = psycopg2.connect(
    host=os.getenv('DB_HOST'),
    port=os.getenv('DB_PORT'),
    database=os.getenv('DB_NAME'),
    user=os.getenv('ADMIN_USER'),  # Use admin user
    password=os.getenv('ADMIN_PASSWORD'),
    sslmode='require'
)

cursor = conn.cursor()
with open('notifications_schema_v2.sql', 'r') as f:
    cursor.execute(f.read())
conn.commit()
conn.close()
"
```

## 🎯 Demo Talking Points

1. **Schema Evolution Without Downtime**: All changes use `IF NOT EXISTS` and `ADD COLUMN IF NOT EXISTS`
2. **Backward Compatibility**: Existing queries continue to work
3. **Automatic Data Population**: Existing notifications automatically get priority and tags
4. **Advanced Analytics**: Materialized views for fast dashboard queries
5. **Audit Compliance**: Complete change history with JSONB snapshots
6. **SLA Tracking**: Built-in service level agreement monitoring
7. **Cost Quantification**: Financial impact analysis for business decisions

## 📈 Example Queries

### Get high-priority unresolved notifications
```sql
SELECT * FROM notifications
WHERE is_resolved = FALSE
  AND priority IN ('high', 'urgent')
ORDER BY created_at DESC;
```

### Check SLA compliance
```sql
SELECT * FROM overdue_notifications
WHERE is_overdue = TRUE;
```

### View notification change history
```sql
SELECT
    nh.*,
    u.first_name || ' ' || u.last_name as changed_by_name
FROM notification_history nh
LEFT JOIN users u ON nh.changed_by_user_id = u.user_id
WHERE notification_id = 1
ORDER BY changed_at DESC;
```

### Get analytics summary
```sql
SELECT
    notification_date,
    region,
    severity,
    total_notifications,
    resolved_count,
    avg_resolution_hours,
    total_estimated_impact
FROM notification_analytics
WHERE notification_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY notification_date DESC, total_estimated_impact DESC;
```

## 🔐 Security Considerations

- All new foreign keys have appropriate ON DELETE actions
- Sensitive fields (notes, history) should have appropriate access controls
- SLA configuration should be restricted to admin users only
- Consider row-level security policies for multi-tenant scenarios

## 📝 Version Information

- **Version**: 2.0
- **Date**: 2025-11-13
- **Author**: Brickhouse Brands Development Team
- **Compatibility**: PostgreSQL 12+, Databricks SQL Warehouse

