-- Schema Enhancements for Brickhouse Brands
-- Date: 2025-11-11
-- Purpose: Add audit logging and user activity tracking

-- Create audit_logs table for tracking all database changes
CREATE TABLE IF NOT EXISTS audit_logs (
    audit_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    user_id INTEGER REFERENCES users(user_id),
    changed_data JSONB,
    change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT,
    description TEXT
);

-- Create indexes for faster audit log queries
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(change_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);

-- Create user_activity table for tracking user sessions and actions
CREATE TABLE IF NOT EXISTS user_activity (
    activity_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    activity_type VARCHAR(50) NOT NULL,
    activity_description TEXT,
    page_url VARCHAR(500),
    session_id VARCHAR(255),
    duration_seconds INTEGER,
    device_type VARCHAR(50),
    browser VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for user activity tracking
CREATE INDEX IF NOT EXISTS idx_user_activity_user_id ON user_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_type ON user_activity(activity_type);
CREATE INDEX IF NOT EXISTS idx_user_activity_timestamp ON user_activity(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_activity_session ON user_activity(session_id);

-- Create inventory_history table for tracking stock level changes over time
CREATE TABLE IF NOT EXISTS inventory_history (
    history_id SERIAL PRIMARY KEY,
    inventory_id INTEGER NOT NULL REFERENCES inventory(inventory_id),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    store_id INTEGER NOT NULL REFERENCES stores(store_id),
    previous_quantity INTEGER NOT NULL,
    new_quantity INTEGER NOT NULL,
    quantity_change INTEGER NOT NULL,
    change_type VARCHAR(50) NOT NULL CHECK (change_type IN ('SALE', 'RESTOCK', 'ADJUSTMENT', 'RETURN', 'DAMAGE', 'EXPIRED')),
    changed_by INTEGER REFERENCES users(user_id),
    notes TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for inventory history
CREATE INDEX IF NOT EXISTS idx_inventory_history_inventory_id ON inventory_history(inventory_id);
CREATE INDEX IF NOT EXISTS idx_inventory_history_product_id ON inventory_history(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_history_store_id ON inventory_history(store_id);
CREATE INDEX IF NOT EXISTS idx_inventory_history_timestamp ON inventory_history(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_inventory_history_change_type ON inventory_history(change_type);

-- Create order_status_history table for tracking order lifecycle
CREATE TABLE IF NOT EXISTS order_status_history (
    status_history_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(order_id),
    previous_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    changed_by INTEGER REFERENCES users(user_id),
    notes TEXT,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for order status history
CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_timestamp ON order_status_history(changed_at DESC);

-- Create notification_preferences table for user notification settings
CREATE TABLE IF NOT EXISTS notification_preferences (
    preference_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users(user_id),
    email_notifications BOOLEAN DEFAULT TRUE,
    sms_notifications BOOLEAN DEFAULT FALSE,
    push_notifications BOOLEAN DEFAULT TRUE,
    low_stock_alerts BOOLEAN DEFAULT TRUE,
    order_updates BOOLEAN DEFAULT TRUE,
    weekly_summary BOOLEAN DEFAULT TRUE,
    critical_alerts_only BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for notification preferences
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_id ON notification_preferences(user_id);

-- Add comments for documentation
COMMENT ON TABLE audit_logs IS 'Tracks all database changes for compliance and debugging';
COMMENT ON TABLE user_activity IS 'Tracks user actions and sessions for analytics';
COMMENT ON TABLE inventory_history IS 'Historical record of all inventory quantity changes';
COMMENT ON TABLE order_status_history IS 'Tracks the complete lifecycle of order status changes';
COMMENT ON TABLE notification_preferences IS 'User preferences for notification delivery methods';

-- Create view for recent audit activity (last 7 days)
CREATE OR REPLACE VIEW recent_audit_activity AS
SELECT 
    a.audit_id,
    a.table_name,
    a.action,
    u.username,
    u.email,
    a.change_timestamp,
    a.description
FROM audit_logs a
LEFT JOIN users u ON a.user_id = u.user_id
WHERE a.change_timestamp >= CURRENT_TIMESTAMP - INTERVAL '7 days'
ORDER BY a.change_timestamp DESC;

-- Create view for inventory movement summary
CREATE OR REPLACE VIEW inventory_movement_summary AS
SELECT 
    p.product_name,
    p.category,
    s.store_name,
    s.region,
    COUNT(*) as total_movements,
    SUM(CASE WHEN ih.quantity_change > 0 THEN ih.quantity_change ELSE 0 END) as total_additions,
    SUM(CASE WHEN ih.quantity_change < 0 THEN ABS(ih.quantity_change) ELSE 0 END) as total_reductions,
    MAX(ih.changed_at) as last_movement_date
FROM inventory_history ih
JOIN products p ON ih.product_id = p.product_id
JOIN stores s ON ih.store_id = s.store_id
WHERE ih.changed_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY p.product_name, p.category, s.store_name, s.region;

-- Create function to automatically update audit logs
CREATE OR REPLACE FUNCTION log_order_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
        INSERT INTO order_status_history (order_id, previous_status, new_status)
        VALUES (NEW.order_id, OLD.status, NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic order status tracking
DROP TRIGGER IF EXISTS order_status_change_trigger ON orders;
CREATE TRIGGER order_status_change_trigger
    AFTER UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION log_order_changes();

-- Grant permissions (adjust based on your user roles)
-- GRANT SELECT, INSERT ON audit_logs TO app_user;
-- GRANT SELECT, INSERT ON user_activity TO app_user;
-- GRANT SELECT, INSERT ON inventory_history TO app_user;
-- GRANT SELECT ON recent_audit_activity TO app_user;
-- GRANT SELECT ON inventory_movement_summary TO app_user;

