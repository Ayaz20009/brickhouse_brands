from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from app.models.schemas import Notification, NotificationSummary
from app.database.connection import get_db_cursor
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("", response_model=List[Notification])
async def get_notifications(
    limit: int = Query(default=10, ge=1, le=100, description="Number of notifications to return"),
    severity: Optional[str] = Query(default=None, description="Filter by severity: low, medium, high, critical"),
    is_read: Optional[bool] = Query(default=None, description="Filter by read status"),
    is_resolved: Optional[bool] = Query(default=False, description="Filter by resolved status"),
):
    """
    Get notifications with optional filtering.
    Default: Returns top 10 unresolved notifications ordered by severity and date.
    """
    try:
        with get_db_cursor() as cursor:
            # Build query with filters
            query = """
                SELECT 
                    n.notification_id,
                    n.notification_type,
                    n.product_id,
                    n.store_id,
                    n.inventory_id,
                    n.current_stock,
                    n.reorder_threshold,
                    n.severity,
                    n.message,
                    n.is_read,
                    n.is_resolved,
                    n.created_at,
                    n.updated_at,
                    n.resolved_at,
                    p.product_name,
                    s.store_name,
                    p.category,
                    s.region
                FROM notifications n
                JOIN products p ON n.product_id = p.product_id
                JOIN stores s ON n.store_id = s.store_id
                WHERE 1=1
            """
            
            params = []
            
            # Add filters
            if severity:
                query += " AND n.severity = %s"
                params.append(severity)
            
            if is_read is not None:
                query += " AND n.is_read = %s"
                params.append(is_read)
            
            if is_resolved is not None:
                query += " AND n.is_resolved = %s"
                params.append(is_resolved)
            
            # Order by severity and date
            query += """
                ORDER BY 
                    CASE n.severity 
                        WHEN 'critical' THEN 1 
                        WHEN 'high' THEN 2 
                        WHEN 'medium' THEN 3 
                        ELSE 4 
                    END,
                    n.created_at DESC
                LIMIT %s
            """
            params.append(limit)
            
            cursor.execute(query, params)
            rows = cursor.fetchall()
            
            # RealDictCursor returns rows as dictionaries
            return list(rows)
            
    except Exception as e:
        logger.error(f"Error fetching notifications: {e}")
        raise HTTPException(status_code=500, detail=f"Error fetching notifications: {str(e)}")


@router.get("/summary", response_model=NotificationSummary)
async def get_notifications_summary():
    """
    Get a summary of notification counts by severity and status.
    """
    try:
        with get_db_cursor() as cursor:
            cursor.execute("""
                SELECT 
                    COUNT(*) as total,
                    COUNT(*) FILTER (WHERE severity = 'critical') as critical,
                    COUNT(*) FILTER (WHERE severity = 'high') as high,
                    COUNT(*) FILTER (WHERE severity = 'medium') as medium,
                    COUNT(*) FILTER (WHERE severity = 'low') as low,
                    COUNT(*) FILTER (WHERE is_read = FALSE) as unread,
                    COUNT(*) FILTER (WHERE is_resolved = FALSE) as unresolved
                FROM notifications
            """)
            
            row = cursor.fetchone()
            
            # RealDictCursor returns rows as dictionaries
            return {
                "total": row['total'] or 0,
                "critical": row['critical'] or 0,
                "high": row['high'] or 0,
                "medium": row['medium'] or 0,
                "low": row['low'] or 0,
                "unread": row['unread'] or 0,
                "unresolved": row['unresolved'] or 0,
            }
            
    except Exception as e:
        logger.error(f"Error fetching notification summary: {e}")
        raise HTTPException(status_code=500, detail=f"Error fetching notification summary: {str(e)}")


@router.patch("/{notification_id}/read")
async def mark_notification_read(notification_id: int):
    """
    Mark a notification as read.
    """
    try:
        with get_db_cursor() as cursor:
            cursor.execute("""
                UPDATE notifications 
                SET is_read = TRUE, updated_at = CURRENT_TIMESTAMP 
                WHERE notification_id = %s
                RETURNING notification_id
            """, (notification_id,))
            
            result = cursor.fetchone()
            
            if not result:
                raise HTTPException(status_code=404, detail="Notification not found")
            
            return {"message": "Notification marked as read", "notification_id": notification_id}
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error marking notification as read: {e}")
        raise HTTPException(status_code=500, detail=f"Error updating notification: {str(e)}")


@router.patch("/{notification_id}/resolve")
async def resolve_notification(notification_id: int):
    """
    Resolve a notification (mark as completed/handled).
    """
    try:
        with get_db_cursor() as cursor:
            cursor.execute("""
                UPDATE notifications 
                SET 
                    is_resolved = TRUE, 
                    is_read = TRUE,
                    resolved_at = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP 
                WHERE notification_id = %s
                RETURNING notification_id
            """, (notification_id,))
            
            result = cursor.fetchone()
            
            if not result:
                raise HTTPException(status_code=404, detail="Notification not found")
            
            return {"message": "Notification resolved", "notification_id": notification_id}
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error resolving notification: {e}")
        raise HTTPException(status_code=500, detail=f"Error updating notification: {str(e)}")

