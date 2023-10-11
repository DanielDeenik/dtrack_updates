import 'react-big-calendar/lib/css/react-big-calendar.css';

import { useTheme } from '@mui/material/styles';
import moment from 'moment';
import { FC, useCallback, useState } from 'react';
import { useGetList } from 'react-admin';
import { Calendar, Event, momentLocalizer } from 'react-big-calendar';
import { useNavigate } from 'react-router-dom';

interface CalendarViewProps {
  userId: number;
}

interface DurationData {
  day: string;
  duration: number;
}

interface DateRange {
  start: Date;
  end: Date;
}

const getISOWeekDateRange = (date: Date) => {
  const startOfWeek = moment(date).startOf('isoWeek').format('YYYY-MM-DD');
  const endOfWeek = moment(date).endOf('isoWeek').format('YYYY-MM-DD');
  return { startOfWeek, endOfWeek };
};

function fillMissing(data: Array<DurationData>, dateRange: DateRange) {
  let date = moment(dateRange.start);
  const dateEnd = moment(dateRange.end);
  while (date.isBefore(dateEnd)) {
    const dayOfWeek = date.day();
    const dateStr = date.format('YYYY-MM-DD');
    if (
      dayOfWeek >= 1 &&
      dayOfWeek <= 5 &&
      date.isBefore(moment().subtract(1, 'days')) &&
      !data.some((item) => item.day === dateStr)
    ) {
      data.push({ day: dateStr, duration: 0 });
    }
    date = date.add(1, 'days');
  }
  return data;
}

export const CalendarView: FC<CalendarViewProps> = ({ userId }) => {
  const theme = useTheme();
  const navigate = useNavigate();
  const defaultStart = moment().startOf('month');
  const defaultEnd = defaultStart.clone().add(1, 'months');
  const [dateRange, setdateRange] = useState<DateRange>({
    start: defaultStart.toDate(),
    end: defaultEnd.toDate(),
  });
  const [navigatedDate, setNavigatedDate] = useState<Date>(moment().toDate());
  const start = moment(dateRange?.start).format('YYYY-MM-DD');
  const end = moment(dateRange?.end).format('YYYY-MM-DD');
  const { data, isLoading } = useGetList(
    'duration_calendar',
    {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      filter: {
        ...(userId ? { user_id: userId } : {}),
        'daterange@cd': `[${start},${end})`,
      },
      sort: { field: 'day', order: 'asc' },
      meta: { columns: ['id', 'day', 'duration'] },
    },
    { enabled: dateRange ? true : false },
  );

  const handleDateRangeChange = (dateRange: DateRange | Date[]) => {
    const start = Array.isArray(dateRange) ? dateRange[0] : dateRange.start;
    const end = Array.isArray(dateRange) ? dateRange[1] : dateRange.end;
    setdateRange({ start, end: moment(end).add(1, 'days').toDate() });
  };

  const handleEventClick = (dateRange: DateRange) => {
    const { startOfWeek, endOfWeek } = getISOWeekDateRange(dateRange.start);
    navigate(
      `/time_trackings?displayedFilters={"date@gte":true,"date@lte":true,"user->>id":true}&filter={"date@gte":"${startOfWeek}","date@lte":"${endOfWeek}","user->>id":${userId}}`,
    );
  };

  const eventPropGetter = (event: Event) => {
    const date = event.start;
    const duration = Number(event.title?.toString().split(' ')[0]);
    if (
      moment(date).day() >= 1 &&
      moment(date).day() <= 5 &&
      (duration <= 6 || duration >= 10)
    ) {
      return { style: { backgroundColor: theme.palette.secondary.main } };
    } else {
      return { style: { backgroundColor: '#d3d3d3' } };
    }
  };

  const onNavigate = useCallback((date: Date) => {
    setNavigatedDate(date);
  }, []);

  if (isLoading) return null;
  moment.updateLocale('en', { week: { dow: 1 } });
  const events = fillMissing(data as Array<DurationData>, dateRange).map((item) => ({
    title: `${item.duration} hours`,
    start: new Date(item.day),
    end: new Date(item.day),
  }));

  return (
    <Calendar
      date={navigatedDate}
      onNavigate={onNavigate}
      localizer={momentLocalizer(moment)}
      views={['month']}
      events={events}
      eventPropGetter={eventPropGetter}
      startAccessor="start"
      endAccessor="end"
      onRangeChange={handleDateRangeChange}
      onSelectEvent={handleEventClick}
      style={{ height: '400px' }}
    />
  );
};
