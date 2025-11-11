import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Bell, AlertCircle, AlertTriangle, Info, Check, X } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useDarkModeStore } from "@/store/useDarkModeStore";
import { ScrollArea } from "@/components/ui/scroll-area";
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

interface NotificationSummary {
  total: number;
  critical: number;
  high: number;
  medium: number;
  low: number;
  unread: number;
  unresolved: number;
}

export const NotificationBell = () => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [summary, setSummary] = useState<NotificationSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [isOpen, setIsOpen] = useState(false);
  const { isDarkMode } = useDarkModeStore();

  const fetchNotifications = async () => {
    try {
      const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api';
      
      // Fetch both notifications and summary
      const [notificationsRes, summaryRes] = await Promise.all([
        axios.get(`${API_BASE_URL}/notifications?limit=10&is_resolved=false`),
        axios.get(`${API_BASE_URL}/notifications/summary`)
      ]);
      
      setNotifications(notificationsRes.data);
      setSummary(summaryRes.data);
      setLoading(false);
    } catch (err: any) {
      console.error('Error fetching notifications:', err);
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
      
      // Update summary
      if (summary) {
        setSummary({ ...summary, unread: Math.max(0, summary.unread - 1) });
      }
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
      
      // Update summary
      if (summary) {
        setSummary({
          ...summary,
          unresolved: Math.max(0, summary.unresolved - 1),
          unread: Math.max(0, summary.unread - 1)
        });
      }
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
        return <AlertCircle className="h-4 w-4 text-red-500" />;
      case 'high':
        return <AlertTriangle className="h-4 w-4 text-orange-500" />;
      case 'medium':
        return <AlertTriangle className="h-4 w-4 text-yellow-500" />;
      default:
        return <Info className="h-4 w-4 text-blue-500" />;
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'critical': return 'text-red-500';
      case 'high': return 'text-orange-500';
      case 'medium': return 'text-yellow-500';
      default: return 'text-blue-500';
    }
  };

  const unreadCount = summary?.unread || 0;
  const hasNotifications = notifications.length > 0;

  return (
    <DropdownMenu open={isOpen} onOpenChange={setIsOpen}>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          className={`relative h-10 w-10 rounded-full ${
            isDarkMode ? 'hover:bg-gray-700' : 'hover:bg-gray-100'
          }`}
        >
          <Bell className={`h-5 w-5 ${isDarkMode ? 'text-gray-300' : 'text-gray-600'}`} />
          {unreadCount > 0 && (
            <Badge
              variant="destructive"
              className="absolute -top-1 -right-1 h-5 w-5 rounded-full p-0 flex items-center justify-center text-xs"
            >
              {unreadCount > 9 ? '9+' : unreadCount}
            </Badge>
          )}
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        className={`w-96 ${isDarkMode ? 'bg-gray-800 border-gray-700' : 'bg-white'}`}
        align="end"
        sideOffset={8}
      >
        {/* Header */}
        <div className={`px-4 py-3 border-b ${isDarkMode ? 'border-gray-700' : 'border-gray-200'}`}>
          <div className="flex items-center justify-between">
            <h3 className={`font-semibold ${isDarkMode ? 'text-white' : 'text-gray-900'}`}>
              Low Stock Alerts
            </h3>
            {summary && (
              <div className="flex items-center gap-2 text-xs">
                <Badge variant="destructive" className="h-5">
                  {summary.critical} Critical
                </Badge>
                <Badge variant="secondary" className="h-5">
                  {summary.unresolved} Active
                </Badge>
              </div>
            )}
          </div>
        </div>

        {/* Notifications List */}
        <ScrollArea className="h-[400px]">
          {loading ? (
            <div className="flex items-center justify-center py-8">
              <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-gray-900 dark:border-gray-100"></div>
            </div>
          ) : !hasNotifications ? (
            <div className="flex flex-col items-center justify-center py-8 px-4">
              <Check className="h-12 w-12 text-green-500 mb-2" />
              <p className={`text-sm ${isDarkMode ? 'text-gray-400' : 'text-gray-600'}`}>
                All stock levels are healthy!
              </p>
            </div>
          ) : (
            <div className="py-2">
              {notifications.map((notification) => (
                <div
                  key={notification.notification_id}
                  className={`px-4 py-3 border-b ${
                    isDarkMode ? 'border-gray-700 hover:bg-gray-750' : 'border-gray-100 hover:bg-gray-50'
                  } transition-colors ${
                    !notification.is_read ? (isDarkMode ? 'bg-gray-700/50' : 'bg-blue-50/50') : ''
                  }`}
                >
                  <div className="flex items-start gap-3">
                    <div className="mt-0.5">
                      {getSeverityIcon(notification.severity)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1">
                        <Badge
                          variant="outline"
                          className={`text-xs ${getSeverityColor(notification.severity)}`}
                        >
                          {notification.severity.toUpperCase()}
                        </Badge>
                        {!notification.is_read && (
                          <div className="h-2 w-2 rounded-full bg-blue-500"></div>
                        )}
                      </div>
                      
                      <p className={`text-xs font-medium mb-1 ${
                        isDarkMode ? 'text-gray-200' : 'text-gray-900'
                      }`}>
                        {notification.product_name}
                      </p>
                      
                      <p className={`text-xs mb-2 ${
                        isDarkMode ? 'text-gray-400' : 'text-gray-600'
                      }`}>
                        {notification.store_name} • {notification.current_stock} cases left
                      </p>

                      <div className="flex gap-1">
                        {!notification.is_read && (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={(e) => {
                              e.stopPropagation();
                              markAsRead(notification.notification_id);
                            }}
                            className="h-6 text-xs px-2"
                          >
                            Mark Read
                          </Button>
                        )}
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={(e) => {
                            e.stopPropagation();
                            resolveNotification(notification.notification_id);
                          }}
                          className="h-6 text-xs px-2"
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
        </ScrollArea>

        {/* Footer */}
        {hasNotifications && (
          <div className={`px-4 py-2 border-t ${isDarkMode ? 'border-gray-700' : 'border-gray-200'}`}>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => {
                setIsOpen(false);
                fetchNotifications();
              }}
              className="w-full text-xs"
            >
              Refresh Notifications
            </Button>
          </div>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
};

