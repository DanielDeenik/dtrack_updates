import { Autocomplete, Box, Tab, Tabs, TextField, Typography } from '@mui/material';
import { useEffect, useState } from 'react';
import { useDataProvider, useGetList } from 'react-admin';

import { SunburstZoomChart } from './charts/SunburstChart/SunburstZoomChart';
import {
  DateGranularitySelect,
  DateRangeSelect,
  defaultDaterange,
  Option,
} from './utils/Dropdowns';
import { handleSummaryExport } from './utils/utils';

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function CustomTabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`simple-tabpanel-${index}`}
      aria-labelledby={`simple-tab-${index}`}
      {...other}
    >
      {value === index && (
        <Box sx={{ p: 3 }}>
          <Typography>{children}</Typography>
        </Box>
      )}
    </div>
  );
}

function a11yProps(index: number) {
  return {
    id: `simple-tab-${index}`,
    'aria-controls': `simple-tabpanel-${index}`,
  };
}

export const Dashboard = () => {
  const [axes, setAxes] = useState<Option[]>([
    { label: 'Activity', value: 'activity' },
    { label: 'Project', value: 'project' },
    { label: 'AoW', value: 'aow' },
    { label: 'User', value: 'user' },
  ]);
  const [granularity, setGranularity] = useState<Option>({
    label: 'Month',
    value: 'month',
  });
  const [daterange, setDaterange] = useState<Option>(defaultDaterange(granularity));
  useEffect(() => {
    setDaterange(defaultDaterange(granularity));
  }, [granularity]);
  const axesValues = axes.map((option) => option.value);
  const { data, isLoading } = useGetList('rpc/timetracking_summary', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    filter: {
      'axes@': `{${['daterange', ...axesValues].join(',')}}`,
      'date_part@': granularity.value,
      'zoom_level@': '1',
      'daterange@cs': daterange.value,
    },
    meta: { columns: ['id', 'daterange', 'data'] },
  });
  const [value, setValue] = useState(0);
  const handleChange = (event: React.SyntheticEvent, newValue: number) => {
    setValue(newValue);
  };
  const dataProvider = useDataProvider();
  const handleDownload = async () => {
    // The reason for using the dataProvider directly is that the getList method can be defined
    // to trigger on condition of clicking the download button, which is not possible with the
    // useGetList hook.
    const { data } = await dataProvider.getList('rpc/timetracking_summary_export', {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      filter: {
        'axes@': `{${['daterange', ...axesValues].join(',')}}`,
        'date_part@': granularity.value,
        'daterange@cs': daterange.value,
      },
      sort: { field: 'id', order: 'ASC' },
      meta: {
        columns: ['id', 'daterange', ...axesValues, 'total_duration'],
      },
    });
    handleSummaryExport(data);
  };
  if (isLoading) return null;
  return (
    <>
      <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
        <Tabs value={value} onChange={handleChange} aria-label="basic tabs example">
          <Tab label="Chart" {...a11yProps(0)} />
        </Tabs>
      </Box>
      <CustomTabPanel value={value} index={0}>
        <Box display="flex" className="chart-container chart-container-dashboard">
          <Box className="chart-left">
            <Autocomplete
              size="small"
              multiple
              value={axes}
              options={[
                { label: 'User', value: 'user' },
                { label: 'Activity', value: 'activity' },
                { label: 'Project', value: 'project' },
                { label: 'AoW', value: 'aow' },
              ]}
              filterSelectedOptions
              isOptionEqualToValue={(option, value) => option.value === value.value}
              onChange={(_event, newValue: Option[]) => {
                if (newValue !== null) {
                  setAxes(newValue);
                }
              }}
              renderInput={(params) => <TextField {...params} label="Axes" />}
            />
            <DateGranularitySelect
              granularity={granularity}
              setGranularity={setGranularity}
            />
            <DateRangeSelect
              daterange={daterange}
              setDaterange={setDaterange}
              granularity={granularity}
            />
          </Box>
          {data?.length === 0 ? (
            <Box className="chart">
              <Typography variant="h6" align="center">
                No data available for the current filter combinations.
              </Typography>
            </Box>
          ) : data?.length === 1 ? (
            <SunburstZoomChart
              data={{ name: 'Timetracking Summary', children: data[0].data || [] }}
              handleDownload={handleDownload}
            />
          ) : (
            <Box className="chart" />
          )}
          <Box className="chart-right" />
        </Box>
      </CustomTabPanel>
    </>
  );
};
