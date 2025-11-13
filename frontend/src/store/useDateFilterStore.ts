import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import { getLastDaysRange } from '@/utils/dateUtils';

interface DateFilterState {
  // Current date filter values
  dateFrom: string | undefined;
  dateTo: string | undefined;

  // Actions
  setDateFilter: (dateFrom: string | undefined, dateTo: string | undefined) => void;
  clearDateFilter: () => void;
  setPresetFilter: (days: number | null) => void;

  // Getters
  getCurrentRange: () => { dateFrom: string | undefined; dateTo: string | undefined };
  hasDateFilter: () => boolean;
}

// Start with no date filter (All Time) by default
// const defaultDateRange = getLastDaysRange(30);

export const useDateFilterStore = create<DateFilterState>()(
  devtools(
    (set, get) => ({
      // Initial state - no date filter (All Time)
      dateFrom: undefined,
      dateTo: undefined,

      // Actions
      setDateFilter: (dateFrom: string | undefined, dateTo: string | undefined) => {
        set({ dateFrom, dateTo });
      },

      clearDateFilter: () => {
        set({ dateFrom: undefined, dateTo: undefined });
      },

      setPresetFilter: (days: number | null) => {
        console.log('DateFilterStore: setPresetFilter called with days:', days);
        if (days === null) {
          console.log('DateFilterStore: Clearing date filter');
          get().clearDateFilter();
        } else {
          const dateRange = getLastDaysRange(days);
          console.log('DateFilterStore: Setting date range:', dateRange);
          set({
            dateFrom: dateRange.from,
            dateTo: dateRange.to
          });
        }
      },

      // Getters
      getCurrentRange: () => {
        const { dateFrom, dateTo } = get();
        return { dateFrom, dateTo };
      },

      hasDateFilter: () => {
        const { dateFrom, dateTo } = get();
        return !!(dateFrom && dateTo);
      }
    }),
    {
      name: 'date-filter-store',
    }
  )
); 