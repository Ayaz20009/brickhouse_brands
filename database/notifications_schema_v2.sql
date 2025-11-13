-- ============================================================================
-- NOTIFICATIONS SCHEMA V2 - Enhanced Schema for Demo
-- ============================================================================
-- This migration adds new columns and features to the notifications system
-- to demonstrate schema evolution and advanced notification capabilities.
-- ============================================================================

-- Add new columns to the notifications table
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    ADD COLUMN IF NOT EXISTS assigned_to_user_id INT REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS resolved_by_user_id INT REFERENCES users(user_id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS estimated_impact_cost DECIMAL(12, 2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS tags TEXT[], -- Array of tags for categorization
    ADD COLUMN IF NOT EXISTS due_date TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS auto_resolved BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS viewed_count INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_viewed_at TIMESTAMP WITH TIME ZONE;

-- Add comments to new columns
COMMENT ON COLUMN notifications.priority IS 'Priority level of the notification (low, medium, high, urgent)';
COMMENT ON COLUMN notifications.assigned_to_user_id IS 'User ID of the person assigned to handle this notification';
COMMENT ON COLUMN notifications.resolved_by_user_id IS 'User ID of the person who resolved the notification';
COMMENT ON COLUMN notifications.estimated_impact_cost IS 'Estimated cost impact of the low stock situation';
COMMENT ON COLUMN notifications.notes IS 'Additional notes or comments about the notification';
COMMENT ON COLUMN notifications.tags IS 'Array of tags for categorization and filtering';
COMMENT ON COLUMN notifications.due_date IS 'Target date for resolution';
COMMENT ON COLUMN notifications.auto_resolved IS 'Flag indicating if notification was auto-resolved by system';
COMMENT ON COLUMN notifications.viewed_count IS 'Number of times this notification has been viewed';
COMMENT ON COLUMN notifications.last_viewed_at IS 'Last time the notification was viewed';

-- Create indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_notifications_priority ON notifications (priority);
CREATE INDEX IF NOT EXISTS idx_notifications_assigned_to ON notifications (assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_resolved_by ON notifications (resolved_by_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_due_date ON notifications (due_date);
CREATE INDEX IF NOT EXISTS idx_notifications_tags ON notifications USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_notifications_priority_severity ON notifications (priority, severity);

-- Create a notification history table to track all changes
CREATE TABLE IF NOT EXISTS notification_history (
    history_id BIGSERIAL PRIMARY KEY,
    notification_id INT NOT NULL,
    action VARCHAR(50) NOT NULL CHECK (action IN ('created', 'updated', 'assigned', 'resolved', 'reopened', 'viewed', 'commented')),
    changed_by_user_id INT REFERENCES users(user_id) ON DELETE SET NULL,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    old_values JSONB,
    new_values JSONB,
    comment TEXT,
    CONSTRAINT fk_notification FOREIGN KEY (notification_id) REFERENCES notifications(notification_id) ON DELETE CASCADE
);

COMMENT ON TABLE notification_history IS 'Tracks all changes and actions performed on notifications';
COMMENT ON COLUMN notification_history.action IS 'Type of action performed (created, updated, assigned, resolved, etc.)';
COMMENT ON COLUMN notification_history.old_values IS 'JSONB snapshot of values before the change';
COMMENT ON COLUMN notification_history.new_values IS 'JSONB snapshot of values after the change';

-- Create indexes for notification_history
CREATE INDEX IF NOT EXISTS idx_notification_history_notification_id ON notification_history (notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_history_user_id ON notification_history (changed_by_user_id);
CREATE INDEX IF NOT EXISTS idx_notification_history_action ON notification_history (action);
CREATE INDEX IF NOT EXISTS idx_notification_history_changed_at ON notification_history (changed_at DESC);

-- Create a notification SLA tracking table
CREATE TABLE IF NOT EXISTS notification_sla (
    sla_id SERIAL PRIMARY KEY,
    notification_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    target_response_hours INT NOT NULL,
    target_resolution_hours INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(notification_type, severity, priority)
);

COMMENT ON TABLE notification_sla IS 'Service Level Agreement targets for notifications';
COMMENT ON COLUMN notification_sla.target_response_hours IS 'Expected hours to first response';
COMMENT ON COLUMN notification_sla.target_resolution_hours IS 'Expected hours to resolution';

-- Insert default SLA values
INSERT INTO notification_sla (notification_type, severity, priority, target_response_hours, target_resolution_hours)
VALUES
    ('low_stock', 'critical', 'urgent', 1, 4),
    ('low_stock', 'critical', 'high', 2, 8),
    ('low_stock', 'high', 'urgent', 2, 8),
    ('low_stock', 'high', 'high', 4, 24),
    ('low_stock', 'medium', 'medium', 8, 48),
    ('low_stock', 'low', 'low', 24, 72),
    ('out_of_stock', 'critical', 'urgent', 1, 2),
    ('out_of_stock', 'high', 'urgent', 1, 4),
    ('reorder_needed', 'high', 'high', 4, 24),
    ('reorder_needed', 'medium', 'medium', 12, 48)
ON CONFLICT (notification_type, severity, priority) DO NOTHING;

-- Create a materialized view for notification analytics
CREATE MATERIALIZED VIEW IF NOT EXISTS notification_analytics AS
SELECT
    DATE_TRUNC('day', n.created_at) AS notification_date,
    n.notification_type,
    n.severity,
    n.priority,
    s.store_name,
    s.region,
    COUNT(*) AS total_notifications,
    COUNT(*) FILTER (WHERE n.is_resolved) AS resolved_count,
    COUNT(*) FILTER (WHERE NOT n.is_resolved) AS open_count,
    AVG(EXTRACT(EPOCH FROM (n.resolved_at - n.created_at)) / 3600) FILTER (WHERE n.is_resolved) AS avg_resolution_hours,
    SUM(n.estimated_impact_cost) AS total_estimated_impact,
    AVG(n.estimated_impact_cost) AS avg_estimated_impact,
    COUNT(DISTINCT n.assigned_to_user_id) AS unique_assignees
FROM notifications n
JOIN stores s ON n.store_id = s.store_id
GROUP BY
    DATE_TRUNC('day', n.created_at),
    n.notification_type,
    n.severity,
    n.priority,
    s.store_name,
    s.region;

COMMENT ON MATERIALIZED VIEW notification_analytics IS 'Aggregated analytics for notification performance and trends';

-- Create an index on the materialized view
CREATE INDEX IF NOT EXISTS idx_notification_analytics_date ON notification_analytics (notification_date DESC);
CREATE INDEX IF NOT EXISTS idx_notification_analytics_region ON notification_analytics (region);
CREATE INDEX IF NOT EXISTS idx_notification_analytics_severity ON notification_analytics (severity);

-- Create a function to automatically update notification priority based on severity
CREATE OR REPLACE FUNCTION update_notification_priority()
RETURNS TRIGGER AS $$
BEGIN
    -- Automatically set priority based on severity if not explicitly set
    IF NEW.priority IS NULL OR NEW.priority = 'medium' THEN
        NEW.priority := CASE
            WHEN NEW.severity = 'critical' THEN 'urgent'
            WHEN NEW.severity = 'high' THEN 'high'
            WHEN NEW.severity = 'medium' THEN 'medium'
            ELSE 'low'
        END;
    END IF;
    
    -- Calculate estimated impact cost
    IF NEW.estimated_impact_cost = 0 THEN
        -- Estimate based on current stock deficit
        NEW.estimated_impact_cost := (NEW.reorder_threshold - NEW.current_stock) * 50.00; -- Assume $50 per unit
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update priority automatically
DROP TRIGGER IF EXISTS trg_update_notification_priority ON notifications;
CREATE TRIGGER trg_update_notification_priority
    BEFORE INSERT OR UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_priority();

-- Create a function to log notification changes to history
CREATE OR REPLACE FUNCTION log_notification_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO notification_history (notification_id, action, changed_by_user_id, new_values)
        VALUES (NEW.notification_id, 'created', NEW.assigned_to_user_id, row_to_json(NEW)::jsonb);
    ELSIF TG_OP = 'UPDATE' THEN
        -- Log the update with old and new values
        INSERT INTO notification_history (notification_id, action, changed_by_user_id, old_values, new_values)
        VALUES (
            NEW.notification_id,
            CASE
                WHEN OLD.is_resolved = FALSE AND NEW.is_resolved = TRUE THEN 'resolved'
                WHEN OLD.assigned_to_user_id IS NULL AND NEW.assigned_to_user_id IS NOT NULL THEN 'assigned'
                WHEN OLD.assigned_to_user_id != NEW.assigned_to_user_id THEN 'reassigned'
                ELSE 'updated'
            END,
            NEW.resolved_by_user_id,
            row_to_json(OLD)::jsonb,
            row_to_json(NEW)::jsonb
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to log all notification changes
DROP TRIGGER IF EXISTS trg_log_notification_change ON notifications;
CREATE TRIGGER trg_log_notification_change
    AFTER INSERT OR UPDATE ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION log_notification_change();

-- Update existing notifications with sample priority and tags
UPDATE notifications
SET
    priority = CASE
        WHEN severity = 'critical' THEN 'urgent'
        WHEN severity = 'high' THEN 'high'
        WHEN severity = 'medium' THEN 'medium'
        ELSE 'low'
    END,
    tags = ARRAY['inventory', 'stock-alert', 'auto-generated'],
    estimated_impact_cost = (reorder_threshold - current_stock) * 50.00
WHERE priority IS NULL;

-- Create a view for overdue notifications
CREATE OR REPLACE VIEW overdue_notifications AS
SELECT
    n.*,
    u_assigned.first_name || ' ' || u_assigned.last_name AS assigned_to_name,
    s.store_name,
    s.region,
    p.product_name,
    EXTRACT(EPOCH FROM (NOW() - n.created_at)) / 3600 AS hours_open,
    sla.target_resolution_hours,
    CASE
        WHEN EXTRACT(EPOCH FROM (NOW() - n.created_at)) / 3600 > sla.target_resolution_hours THEN TRUE
        ELSE FALSE
    END AS is_overdue
FROM notifications n
LEFT JOIN users u_assigned ON n.assigned_to_user_id = u_assigned.user_id
JOIN stores s ON n.store_id = s.store_id
JOIN products p ON n.product_id = p.product_id
LEFT JOIN notification_sla sla ON
    n.notification_type = sla.notification_type AND
    n.severity = sla.severity AND
    n.priority = sla.priority
WHERE n.is_resolved = FALSE
    AND EXTRACT(EPOCH FROM (NOW() - n.created_at)) / 3600 > COALESCE(sla.target_resolution_hours, 24);

COMMENT ON VIEW overdue_notifications IS 'Notifications that have exceeded their SLA target resolution time';

-- Create indexes for better query performance on combined conditions
CREATE INDEX IF NOT EXISTS idx_notifications_composite_status ON notifications (is_resolved, severity, priority, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_store_severity ON notifications (store_id, severity, is_resolved);

-- Grant permissions (adjust as needed)
-- GRANT SELECT, INSERT, UPDATE ON notifications TO your_app_user;
-- GRANT SELECT, INSERT ON notification_history TO your_app_user;
-- GRANT SELECT ON notification_sla TO your_app_user;
-- GRANT SELECT ON notification_analytics TO your_app_user;

-- ============================================================================
-- END OF NOTIFICATIONS SCHEMA V2
-- ============================================================================

-- Print summary
DO $$
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Notifications Schema V2 Applied Successfully!';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE 'New Features Added:';
    RAISE NOTICE '  • Priority levels (low, medium, high, urgent)';
    RAISE NOTICE '  • Assignment tracking (assigned_to, resolved_by)';
    RAISE NOTICE '  • Cost impact estimation';
    RAISE NOTICE '  • Tags for categorization';
    RAISE NOTICE '  • Due dates and SLA tracking';
    RAISE NOTICE '  • View count tracking';
    RAISE NOTICE '  • Notification history audit trail';
    RAISE NOTICE '  • SLA configuration table';
    RAISE NOTICE '  • Analytics materialized view';
    RAISE NOTICE '  • Overdue notifications view';
    RAISE NOTICE '  • Automatic priority assignment triggers';
    RAISE NOTICE '============================================================================';
END $$;

