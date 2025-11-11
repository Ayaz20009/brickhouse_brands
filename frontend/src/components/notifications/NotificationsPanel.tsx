import { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Bell, AlertTriangle, AlertCircle, Info, Check, X } from "lucide-react";
import { useDarkModeStore } from "@/store/useDarkModeStore";
import axios from "axios";

interface Notification {
  notification_id: number;
  notification_type: string;
  product_id: number;
  store_id: number;
  current_stock: number;
  reorder_threshold: number;
  severity: "low" | "medium" | "high" | "critical";
  message: string;
  is_read: boolean;
  is_resolved: boolean;
  created_at: string;
  product_name?: string;
  store_name?: string;
  category?: string;
  region?: string;
}

export const NotificationsPanel = () => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { isDarkMode } = useDarkModeStore();

  const fetchNotifications = async () => {
    try {
      setLoading(true);
      const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api';
      const response = await axios.get(`${API_BASE_URL}/notifications?limit=5&is_resolved=false`);
      setNotifications(response.data);
      setError(null);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch notifications');
      console.error('Error fetching notifications:', err);
    } finally {
      setLoading(false);
    }
  };

  const markAsRead = async (notificationId: number) => {
    try {
      const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api';
      await axios.patch(`${API_BASE_URL}/notifications/${notificationId}/read`);
      // Update local state
      setNotifications(prev => 
        prev.map(n => 
          n.notification_id === notificationId ? { ...n, is_read: true } : n
        )
      );
    } catch (err) {
      console.error('Error marking notification as read:', err);
    }
  };

  const resolveNotification = async (notificationId: number) => {
    try {
      const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api';
      await axios.patch(`${API_BASE_URL}/notifications/${notificationId}/resolve`);
      // Remove from local state
      setNotifications(prev => prev.filter(n => n.notification_id !== notificationId));
    } catch (err) {
      console.error('Error resolving notification:', err);
    }
  };

  useEffect(() => {
    fetchNotifications();
    // Refresh every 30 seconds
    const interval = setInterval(fetchNotifications, 30000);
    return () => clearInterval(interval);
  }, []);

  const getSeverityIcon = (severity: string) => {
    switch (severity) {
      case 'critical':
        return <AlertCircle className="h-5 w-5 text-red-500" />;
      case 'high':
        return <AlertTriangle className="h-5 w-5 text-orange-500" />;
      case 'medium':
        return <AlertTriangle className="h-5 w-5 text-yellow-500" />;
      default:
        return <Info className="h-5 w-5 text-blue-500" />;
    }
  };

  const getSeverityBadge = (severity: string) => {
    const variants: Record<string, string> = {
      critical: 'destructive',
      high: 'default',
      medium: 'secondary',
      low: 'outline',
    };

    const colors: Record<string, string> = {
      critical: 'bg-red-500 hover:bg-red-600 text-white',
      high: 'bg-orange-500 hover:bg-orange-600 text-white',
      medium: 'bg-yellow-500 hover:bg-yellow-600 text-white',
      low: 'bg-blue-500 hover:bg-blue-600 text-white',
    };

    return (
      <Badge className={colors[severity] || colors.low}>
        {severity.toUpperCase()}
      </Badge>
    );
  };

  const getStockIndicator = (currentStock: number, threshold: number) => {
    const percentage = (currentStock / threshold) * 100;
    let color = 'bg-green-500';
    
    if (percentage === 0) {
      color = 'bg-red-600';
    } else if (percentage < 20) {
      color = 'bg-red-500';
    } else if (percentage < 50) {
      color = 'bg-orange-500';
    } else if (percentage < 80) {
      color = 'bg-yellow-500';
    }

    return (
      <div className="flex items-center gap-2">
        <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
          <div 
            className={`${color} h-2 rounded-full transition-all`}
            style={{ width: `${Math.min(percentage, 100)}%` }}
          />
        </div>
        <span className="text-sm text-gray-600 dark:text-gray-400 whitespace-nowrap">
          {currentStock}/{threshold}
        </span>
      </div>
    );
  };

  if (loading) {
    return (
      <Card className={isDarkMode ? 'bg-gray-800 border-gray-700' : ''}>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Bell className="h-5 w-5" />
            Low Stock Alerts
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 dark:border-gray-100 mx-auto"></div>
            <p className="mt-2 text-gray-600 dark:text-gray-400">Loading notifications...</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card className={isDarkMode ? 'bg-gray-800 border-gray-700' : ''}>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Bell className="h-5 w-5" />
            Low Stock Alerts
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8">
            <AlertCircle className="h-8 w-8 text-red-500 mx-auto mb-2" />
            <p className="text-red-500">Error: {error}</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className={isDarkMode ? 'bg-gray-800 border-gray-700' : ''}>
      <CardHeader>
        <CardTitle className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Bell className="h-5 w-5" />
            Low Stock Alerts
            {notifications.length > 0 && (
              <Badge variant="destructive" className="ml-2">
                {notifications.length}
              </Badge>
            )}
          </div>
          <Button 
            variant="ghost" 
            size="sm"
            onClick={fetchNotifications}
            className="text-xs"
          >
            Refresh
          </Button>
        </CardTitle>
      </CardHeader>
      <CardContent>
        {notifications.length === 0 ? (
          <div className="text-center py-8">
            <Check className="h-12 w-12 text-green-500 mx-auto mb-2" />
            <p className="text-gray-600 dark:text-gray-400">All stock levels are healthy!</p>
          </div>
        ) : (
          <div className="space-y-4">
            {notifications.map((notification) => (
              <div
                key={notification.notification_id}
                className={`p-4 rounded-lg border transition-all ${
                  notification.is_read
                    ? isDarkMode ? 'bg-gray-700/50 border-gray-600' : 'bg-gray-50 border-gray-200'
                    : isDarkMode ? 'bg-gray-700 border-gray-600' : 'bg-white border-gray-300'
                }`}
              >
                <div className="flex items-start gap-3">
                  <div className="mt-1">
                    {getSeverityIcon(notification.severity)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      {getSeverityBadge(notification.severity)}
                      {!notification.is_read && (
                        <Badge variant="outline" className="text-xs">
                          NEW
                        </Badge>
                      )}
                    </div>
                    <p className={`text-sm font-medium mb-2 ${
                      isDarkMode ? 'text-gray-200' : 'text-gray-900'
                    }`}>
                      {notification.message}
                    </p>
                    
                    {/* Stock level indicator */}
                    <div className="mb-2">
                      {getStockIndicator(notification.current_stock, notification.reorder_threshold)}
                    </div>

                    {/* Metadata */}
                    <div className="flex items-center gap-4 text-xs text-gray-500 dark:text-gray-400 mb-2">
                      {notification.product_name && (
                        <span>📦 {notification.product_name}</span>
                      )}
                      {notification.store_name && (
                        <span>🏪 {notification.store_name}</span>
                      )}
                      {notification.region && (
                        <span>📍 {notification.region}</span>
                      )}
                    </div>

                    {/* Actions */}
                    <div className="flex gap-2">
                      {!notification.is_read && (
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => markAsRead(notification.notification_id)}
                          className="text-xs"
                        >
                          Mark as Read
                        </Button>
                      )}
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => resolveNotification(notification.notification_id)}
                        className="text-xs"
                      >
                        <Check className="h-3 w-3 mr-1" />
                        Resolve
                      </Button>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
};

