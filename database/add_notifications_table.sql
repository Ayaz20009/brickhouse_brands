-- Notifications Table for Low Inventory Alerts
-- This table stores notifications for products that need reordering

CREATE TABLE IF NOT EXISTS notifications (
    notification_id SERIAL PRIMARY KEY,
    notification_type VARCHAR(50) NOT NULL CHECK (notification_type IN ('low_stock', 'out_of_stock', 'reorder_needed', 'critical')),
    product_id INTEGER NOT NULL REFERENCES products(product_id),
    store_id INTEGER NOT NULL REFERENCES stores(store_id),
    inventory_id INTEGER REFERENCES inventory(inventory_id),
    current_stock INTEGER NOT NULL,
    reorder_threshold INTEGER NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    UNIQUE(product_id, store_id, notification_type)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_unresolved ON notifications(is_resolved) WHERE is_resolved = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_severity ON notifications(severity);
CREATE INDEX IF NOT EXISTS idx_notifications_store ON notifications(store_id);
CREATE INDEX IF NOT EXISTS idx_notifications_product ON notifications(product_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- Insert notifications for low stock items
-- Critical: Stock is at 0 or very low (< 5 cases)
INSERT INTO notifications (notification_type, product_id, store_id, inventory_id, current_stock, reorder_threshold, severity, message)
SELECT 
    CASE 
        WHEN i.quantity_cases = 0 THEN 'out_of_stock'
        WHEN i.quantity_cases <= 5 THEN 'critical'
        ELSE 'low_stock'
    END as notification_type,
    i.product_id,
    i.store_id,
    i.inventory_id,
    i.quantity_cases as current_stock,
    CASE 
        WHEN p.category IN ('Cola', 'Water', 'Energy Drink') THEN 50  -- High turnover products
        WHEN p.category IN ('Juice', 'Sports Drink') THEN 30
        ELSE 20
    END as reorder_threshold,
    CASE 
        WHEN i.quantity_cases = 0 THEN 'critical'
        WHEN i.quantity_cases <= 5 THEN 'critical'
        WHEN i.quantity_cases <= 15 THEN 'high'
        WHEN i.quantity_cases <= 25 THEN 'medium'
        ELSE 'low'
    END as severity,
    CASE 
        WHEN i.quantity_cases = 0 THEN 
            'OUT OF STOCK: ' || p.product_name || ' at ' || s.store_name || ' - Immediate reorder required!'
        WHEN i.quantity_cases <= 5 THEN 
            'CRITICAL: Only ' || i.quantity_cases || ' cases of ' || p.product_name || ' remaining at ' || s.store_name
        WHEN i.quantity_cases <= 15 THEN 
            'LOW STOCK: ' || p.product_name || ' at ' || s.store_name || ' has only ' || i.quantity_cases || ' cases left'
        ELSE 
            'Reorder Alert: ' || p.product_name || ' at ' || s.store_name || ' is running low (' || i.quantity_cases || ' cases)'
    END as message
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN stores s ON i.store_id = s.store_id
WHERE 
    s.store_type != 'Warehouse'  -- Exclude warehouse
    AND i.quantity_cases <= 25   -- Only items with 25 or fewer cases
ORDER BY i.quantity_cases ASC, s.store_name
ON CONFLICT (product_id, store_id, notification_type) DO NOTHING;

-- Add some older notifications (already read but not resolved)
UPDATE notifications 
SET 
    is_read = TRUE,
    created_at = CURRENT_TIMESTAMP - INTERVAL '2 days'
WHERE notification_id IN (
    SELECT notification_id 
    FROM notifications 
    WHERE severity IN ('low', 'medium')
    ORDER BY RANDOM()
    LIMIT (SELECT COUNT(*) / 3 FROM notifications WHERE severity IN ('low', 'medium'))
);

-- Mark some low severity items as resolved
UPDATE notifications
SET 
    is_resolved = TRUE,
    resolved_at = CURRENT_TIMESTAMP - INTERVAL '1 day',
    updated_at = CURRENT_TIMESTAMP - INTERVAL '1 day'
WHERE notification_id IN (
    SELECT notification_id 
    FROM notifications 
    WHERE severity = 'low'
    ORDER BY RANDOM()
    LIMIT (SELECT COUNT(*) / 4 FROM notifications WHERE severity = 'low')
);

