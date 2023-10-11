import {
  Autocomplete as MuiAutocomplete,
  Box,
  TextField as MuiTextField,
  Typography,
} from '@mui/material';
import { useEffect, useState } from 'react';
import {
  BulkDeleteButton,
  ChipField,
  Create,
  CreateButton,
  Datagrid,
  DeleteButton,
  Edit,
  EditButton,
  List,
  ReferenceArrayField,
  Show,
  SimpleForm,
  SingleFieldList,
  TabbedShowLayout,
  TextField,
  TextInput,
  TopToolbar,
  useDataProvider,
  useGetList,
  usePermissions,
  useShowController,
} from 'react-admin';

import { SunburstZoomChart } from '../charts/SunburstChart/SunburstZoomChart';
import { ArrayCountField } from '../utils/ArrayCountField';
import {
  DateGranularitySelect,
  DateRangeSelect,
  defaultDaterange,
  Option,
} from '../utils/Dropdowns';
import { handleSummaryExport } from '../utils/utils';

export const AoWList = () => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
  return (
    <List
      actions={
        <TopToolbar>{permissions.roles.includes('power') && <CreateButton />}</TopToolbar>
      }
      empty={false}
    >
      <Datagrid
        rowClick="show"
        bulkActionButtons={
          permissions.roles.includes('power') ? (
            <BulkDeleteButton mutationMode="pessimistic" />
          ) : (
            false
          )
        }
      >
        <TextField source="name" />
        <ArrayCountField label="# of Projects in use by" source="projects" />
      </Datagrid>
    </List>
  );
};

export const AoWCreate = () => (
  <Create>
    <SimpleForm>
      <TextInput source="name" fullWidth />
    </SimpleForm>
  </Create>
);

export const AoWEdit = () => (
  <Edit>
    <SimpleForm>
      <TextInput source="name" fullWidth />
    </SimpleForm>
  </Edit>
);

export const AoWShow = () => {
  const { record } = useShowController({ resource: 'areas_of_work' });
  const [axes, setAxes] = useState<Option[]>([
    { label: 'Activity', value: 'activity' },
    { label: 'Project', value: 'project' },
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
  const { data, isLoading: timetrackingLoading } = useGetList(
    'rpc/timetracking_summary',
    {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      filter: {
        'axes@': `{${['aow', 'daterange', ...axesValues].join(',')}}`,
        'date_part@': granularity.value,
        'zoom_level@': '2',
        aow_id: record?.id,
        'daterange@cs': daterange.value,
      },
      meta: { columns: ['id', 'aow_id', 'daterange', 'data'] },
    },
    { enabled: Number.isInteger(record?.id) },
  );
  const dataProvider = useDataProvider();
  const handleDownload = async () => {
    // The reason for using the dataProvider directly is that the getList method can be defined
    // to trigger on condition of clicking the download button, which is not possible with the
    // useGetList hook.
    const { data } = await dataProvider.getList('rpc/timetracking_summary_export', {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      filter: {
        'aow->id': record?.id,
        'axes@': `{${['aow', 'daterange', ...axesValues].join(',')}}`,
        'date_part@': granularity.value,
        'daterange@cs': daterange.value,
      },
      sort: { field: 'id', order: 'ASC' },
      meta: {
        columns: ['id', 'aow', 'daterange', ...axesValues, 'total_duration'],
      },
    });
    handleSummaryExport(data);
  };
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading || timetrackingLoading) return null;
  return (
    <Show
      actions={
        <TopToolbar>
          {permissions.roles.includes('power') && (
            <>
              <EditButton />
              <DeleteButton mutationMode="pessimistic" />
            </>
          )}
        </TopToolbar>
      }
    >
      <TabbedShowLayout>
        <TabbedShowLayout.Tab label="Summary">
          <TextField source="name" />
          <ReferenceArrayField
            label="In Use By Projects"
            source="project_ids"
            reference="projects"
          >
            <SingleFieldList linkType="show">
              <ChipField source="name" size="small" clickable />
            </SingleFieldList>
          </ReferenceArrayField>
        </TabbedShowLayout.Tab>
        <TabbedShowLayout.Tab label="Chart">
          <Box display="flex" className="chart-container">
            <Box className="chart-left">
              <TextField source="name" />
              <MuiAutocomplete
                size="small"
                multiple
                value={axes}
                options={[
                  { label: 'Activity', value: 'activity' },
                  { label: 'Project', value: 'project' },
                  { label: 'User', value: 'user' },
                ]}
                filterSelectedOptions
                isOptionEqualToValue={(option, value) => option.value === value.value}
                onChange={(_event, newValue: Option[]) => {
                  if (newValue !== null) {
                    setAxes(newValue);
                  }
                }}
                renderInput={(params) => <MuiTextField {...params} label="Axes" />}
              />
              <DateGranularitySelect
                granularity={granularity}
                setGranularity={setGranularity}
              />
              <DateRangeSelect
                daterange={daterange}
                setDaterange={setDaterange}
                filter={{
                  'dims@': '{aow_id}',
                  'dimensions->>aow_id': record?.id,
                }}
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
        </TabbedShowLayout.Tab>
      </TabbedShowLayout>
    </Show>
  );
};
