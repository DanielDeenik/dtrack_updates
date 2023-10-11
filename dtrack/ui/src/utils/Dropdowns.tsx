import { Autocomplete, TextField } from '@mui/material';
import { Button } from '@mui/material';
import { styled } from '@mui/material/styles';
import { Dispatch, SetStateAction } from 'react';
import { useGetList } from 'react-admin';

const CustomButton = styled(Button)({
  minWidth: 'auto',
  padding: 0,
  margin: 0,
  lineHeight: 1,
  transform: 'scale(0.75)',
});

const ButtonContainer = styled('div')({
  display: 'flex',
  flexDirection: 'column',
  marginLeft: '0px',
});

export interface Option {
  value: string;
  label: string;
}

export const monthOption = (date: Date) => {
  const month: number = date.getMonth() + 1;
  const year: number = date.getFullYear();
  const monthLabel: string = date.toLocaleString('default', {
    month: 'long',
  });
  return {
    label: `${monthLabel} ${year}`,
    value: `[${year}-${month.toString().padStart(2, '0')}-01,${year}-${(month + 1)
      .toString()
      .padStart(2, '0')}-01)`,
  };
};

export const yearOption = (date: Date) => {
  const year: number = date.getFullYear();
  return {
    label: year.toString(),
    value: `[${year}-01-01,${year + 1}-01-01)`,
  };
};

export const weekOption = (date: Date) => {
  const weekNumber = getISOWeek(date);
  const weekStart = getISOWeekStart(date);
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 6);
  const weekStartLabel = weekStart.toLocaleString('default', {
    day: 'numeric',
    month: 'short',
    year: '2-digit',
  });
  const weekEndLabel = weekEnd.toLocaleString('default', {
    day: 'numeric',
    month: 'short',
    year: '2-digit',
  });
  return {
    label: `${weekNumber} (${weekStartLabel} - ${weekEndLabel})`,
    value: `[${weekStart.toISOString().slice(0, 10)},${new Date(
      weekEnd.getTime() + 24 * 60 * 60 * 1000,
    )
      .toISOString()
      .slice(0, 10)})`,
  };
};

export const dayOption = (date: Date) => {
  const label = date.toLocaleString('default', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
  const day = date
    .toLocaleString('default', {
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
    })
    .replace(/\//g, '-');
  const nextDay = new Date(date.getTime() + 24 * 60 * 60 * 1000)
    .toLocaleString('default', {
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
    })
    .replace(/\//g, '-');
  return {
    label: label,
    value: `[${day},${nextDay})`,
  };
};

function getISOWeek(date: Date) {
  const target = new Date(date.valueOf());
  const dayNr = (date.getDay() + 6) % 7;
  target.setDate(target.getDate() - dayNr + 3);
  const firstThursday = target.valueOf();
  target.setMonth(0, 1);
  if (target.getDay() !== 4) {
    target.setMonth(0, 1 + ((4 - target.getDay() + 7) % 7));
  }
  return Math.ceil((firstThursday - target.valueOf()) / (7 * 24 * 3600 * 1000)) + 1;
}

function getISOWeekStart(date: Date) {
  const target = new Date(date.valueOf());
  const dayNr = (date.getDay() + 6) % 7;
  target.setDate(target.getDate() - dayNr);
  return target;
}

const getDateRange = (date: Date, granularity: string) => {
  return {
    month: monthOption(date),
    year: yearOption(date),
    week: weekOption(date),
    day: dayOption(date),
  }[granularity]! as Option;
};

export const defaultDaterange = (granularity: Option) => {
  // TODO: Ensure that by default, at least one full day has passed.
  // Therefore if month is selected, on first day of month, previous month is selected.
  // Only on second day of month, current month is selected.
  // Similarly if day is selected, yesterday is the default.
  return getDateRange(new Date(), granularity.value);
};

const getDatefromDaterange = (value: string, granularity: string) => {
  return getDateRange(new Date(value.slice(1, 11)), granularity);
};

const getDaterangeOptions = (values: string[], granularity: string) => {
  return values.map((value: string) => getDatefromDaterange(value, granularity));
};

interface DateGranularitySelectProps {
  granularity: Option;
  setGranularity: Dispatch<SetStateAction<Option>>;
}

export const DateGranularitySelect = (props: DateGranularitySelectProps) => (
  <Autocomplete
    size="small"
    value={props.granularity}
    options={[
      { label: 'Year', value: 'year' },
      { label: 'Month', value: 'month' },
      { label: 'Week', value: 'week' },
      { label: 'Day', value: 'day' },
    ]}
    filterSelectedOptions
    isOptionEqualToValue={(option, value) => option.value === value.value}
    onChange={(_event, newValue: Option | null) => {
      if (newValue !== null) {
        props.setGranularity(newValue);
      }
    }}
    renderInput={(params) => <TextField {...params} label="Granularity" />}
  />
);

interface DateRangeSelectProps {
  daterange: Option;
  setDaterange: Dispatch<SetStateAction<Option>>;
  filter?: {
    'dims@'?: string;
    'dimensions->>user_id'?: number;
    'dimensions->>user_id@in'?: string;
    'dimensions->>aow_id'?: number;
    'dimensions->>project_id'?: number;
    'dimensions->>activity_id'?: number;
  };
  granularity: Option;
}

export const DateRangeSelect = (props: DateRangeSelectProps) => {
  const { data, isLoading } = useGetList('rpc/daterange_active', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    filter: props.filter || {},
    meta: { columns: ['id', `values:${props.granularity.value}s`, 'dimensions'] },
  });

  const options =
    data?.length === 1
      ? getDaterangeOptions(data[0].values || [], props.granularity.value)
      : getDaterangeOptions(
          [...new Set(data?.flatMap((item) => item.values) || [])].sort((a, b) =>
            b.localeCompare(a),
          ),
          props.granularity.value,
        );

  const handleToggle = (direction: 'up' | 'down') => {
    const currentIndex = options.findIndex(
      (option) => option.value === props.daterange.value,
    );
    if (direction === 'up' && currentIndex > 0) {
      props.setDaterange(options[currentIndex - 1]);
    } else if (direction === 'down' && currentIndex < options.length - 1) {
      props.setDaterange(options[currentIndex + 1]);
    }
  };
  if (isLoading) return null;
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      <Autocomplete
        size="small"
        options={options}
        value={props.daterange}
        isOptionEqualToValue={(option, value) => option.value === value.value}
        onChange={(_event, newValue: Option | null) => {
          if (newValue !== null) {
            props.setDaterange(newValue);
          }
        }}
        renderInput={(params) => (
          <TextField {...params} label={props.granularity.label} />
        )}
        sx={{ flexGrow: 1 }}
      />
      <ButtonContainer>
        <CustomButton onClick={() => handleToggle('up')}>&#9650;</CustomButton>
        <CustomButton onClick={() => handleToggle('down')}>&#9660;</CustomButton>
      </ButtonContainer>
    </div>
  );
};
