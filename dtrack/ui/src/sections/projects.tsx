import {
  Autocomplete as MuiAutocomplete,
  Box,
  TextField as MuiTextField,
  Typography,
} from '@mui/material';
import { useEffect, useState } from 'react';
import {
  AutocompleteArrayInput,
  AutocompleteArrayInputProps,
  AutocompleteInput,
  AutocompleteInputProps,
  BulkDeleteButton,
  ChipField,
  CloneButton,
  Create,
  CreateButton,
  Datagrid,
  DateField,
  DateInput,
  DeleteButton,
  Edit,
  EditButton,
  FilterButton,
  List,
  ListProps,
  ReferenceArrayField,
  Show,
  SimpleForm,
  SingleFieldList,
  TabbedShowLayout,
  TextField,
  TextInput,
  TopToolbar,
  useDataProvider,
  useGetIdentity,
  useGetList,
  usePermissions,
  useShowController,
} from 'react-admin';
import { useWatch } from 'react-hook-form';

import { SunburstZoomChart } from '../charts/SunburstChart/SunburstZoomChart';
import { ArrayCountField } from '../utils/ArrayCountField';
import {
  DateGranularitySelect,
  DateRangeSelect,
  defaultDaterange,
  Option,
} from '../utils/Dropdowns';
import { handleSummaryExport } from '../utils/utils';

const EmployeeSelectInput = (props: AutocompleteArrayInputProps) => {
  const { data, isLoading } = useGetList('all_employees', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    sort: { field: 'username', order: 'asc' },
    meta: { columns: ['id', 'name:username'] },
  });
  const lead_ids = useWatch({ name: 'lead_ids' }) || [];
  const member_ids = useWatch({ name: 'member_ids' }) || [];
  let filteredData = data || [];
  if (props.source === 'lead_ids') {
    filteredData = (data || []).filter((employee) => !member_ids.includes(employee.id));
  } else if (props.source === 'member_ids') {
    filteredData = (data || []).filter((employee) => !lead_ids.includes(employee.id));
  }
  if (isLoading) return null;
  return <AutocompleteArrayInput choices={filteredData} {...props} />;
};

// TODO: Make Dry
const EmployeeSelectInputFilter = (props: AutocompleteInputProps) => {
  const { data, isLoading } = useGetList('employees', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    sort: { field: 'username', order: 'asc' },
    meta: { columns: ['id', 'name:username'] },
  });
  if (isLoading) return null;
  return (
    <AutocompleteInput choices={data} optionValue="id" optionText="name" {...props} />
  );
};

const ActivitySelectInput = (props: AutocompleteArrayInputProps) => {
  const { data, isLoading } = useGetList('activities', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    sort: { field: 'name', order: 'asc' },
    meta: { columns: ['id', 'name'] },
  });
  if (isLoading) return null;
  return (
    <AutocompleteArrayInput choices={data} source="activity_ids" fullWidth {...props} />
  );
};

// TODO: Make Dry
const ActivitySelectInputFilter = (props: AutocompleteInputProps) => {
  const { data, isLoading } = useGetList('activities', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    sort: { field: 'name', order: 'asc' },
    meta: { columns: ['id', 'name'] },
  });
  if (isLoading) return null;
  return (
    <AutocompleteInput choices={data} optionValue="id" optionText="name" {...props} />
  );
};

// TODO: Make Dry
const ProjectSelectInputFilter = (props: AutocompleteInputProps) => {
  const { data, isLoading } = useGetList('projects', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    sort: { field: 'name', order: 'asc' },
    meta: { columns: ['id', 'name'] },
  });
  if (isLoading) return null;
  return (
    <AutocompleteInput choices={data} optionValue="id" optionText="name" {...props} />
  );
};

const AowSelectInput = (props: AutocompleteArrayInputProps) => {
  const { data, isLoading } = useGetList('areas_of_work', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    sort: { field: 'name', order: 'asc' },
    meta: { columns: ['id', 'name'] },
  });
  if (isLoading) return null;
  return <AutocompleteArrayInput choices={data} source="aow_ids" {...props} />;
};

// TODO: Make Dry
const AowSelectInputFilter = (props: AutocompleteInputProps) => {
  const { data, isLoading } = useGetList('areas_of_work', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    sort: { field: 'name', order: 'asc' },
    meta: { columns: ['id', 'name'] },
  });
  if (isLoading) return null;
  return (
    <AutocompleteInput choices={data} optionValue="id" optionText="name" {...props} />
  );
};

const ProjectFilters = [
  <ProjectSelectInputFilter key="name" label="Project" source="id" />,
  <TextInput key="description" label="Description" source="description@ilike" />,
  <AowSelectInputFilter key="aow" label="AoW" source="aow_ids@cs" />,
  <ActivitySelectInputFilter key="activity" label="Activity" source="activity_ids@cs" />,
  <EmployeeSelectInputFilter key="lead" label="Manager" source="lead_ids@cs" />,
  <EmployeeSelectInputFilter key="member" label="Member" source="member_ids@cs" />,
];

const ProjectListActions = () => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
  return (
    <TopToolbar>
      <FilterButton filters={ProjectFilters} />
      {permissions.roles.includes('power') && <CreateButton />}
    </TopToolbar>
  );
};

export const ProjectList = (props: ListProps) => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
  return (
    <List
      {...props}
      actions={<ProjectListActions />}
      filters={ProjectFilters}
      exporter={false}
      sort={{ field: 'name', order: 'asc' }}
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
        <TextField source="description" />
        <DateField source="start_date" />
        <DateField source="end_date" />
        <ArrayCountField label="# of AoWs" source="areas_of_work" />
        <ArrayCountField label="# of Activities" source="activities" />
        <ArrayCountField label="# of Managers" source="leads" />
        <ArrayCountField label="# of Members" source="members" />
      </Datagrid>
    </List>
  );
};

export const ProjectCreate = () => (
  <Create>
    <SimpleForm>
      <TextInput source="name" fullWidth />
      <TextInput source="description" fullWidth />
      <DateInput source="start_date" />
      <DateInput source="end_date" />
      <AowSelectInput label="AoWs" fullWidth />
      <ActivitySelectInput label="Activities" fullWidth />
      <EmployeeSelectInput label="Managers" source="lead_ids" fullWidth />
      <EmployeeSelectInput label="Members" source="member_ids" fullWidth />
    </SimpleForm>
  </Create>
);

export const ProjectEdit = () => (
  <Edit>
    <SimpleForm>
      <TextInput source="name" fullWidth />
      <TextInput source="description" fullWidth />
      <DateInput source="start_date" />
      <DateInput source="end_date" />
      <AowSelectInput label="AoWs" fullWidth />
      <ActivitySelectInput label="Activities" fullWidth />
      <EmployeeSelectInput label="Managers" source="lead_ids" fullWidth />
      <EmployeeSelectInput label="Members" source="member_ids" fullWidth />
    </SimpleForm>
  </Edit>
);

export const ProjectShow = () => {
  const { record } = useShowController({ resource: 'projects' });
  const [axes, setAxes] = useState<Option[]>([
    { label: 'Activity', value: 'activity' },
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
  const { data, isLoading: timetrackingLoading } = useGetList(
    'rpc/timetracking_summary',
    {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      filter: {
        'axes@': `{${['project', 'daterange', ...axesValues].join(',')}}`,
        'date_part@': granularity.value,
        'zoom_level@': '2',
        project_id: record?.id,
        'daterange@cs': daterange.value,
      },
      meta: { columns: ['id', 'project_id', 'daterange', 'data'] },
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
        'project->id': record?.id,
        'axes@': `{${['project', 'daterange', ...axesValues].join(',')}}`,
        'date_part@': granularity.value,
        'daterange@cs': daterange.value,
      },
      sort: { field: 'id', order: 'ASC' },
      meta: {
        columns: ['id', 'project', 'daterange', ...axesValues, 'total_duration'],
      },
    });
    handleSummaryExport(data);
  };
  const { data: identity, isLoading: identityLoading } = useGetIdentity();
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (identityLoading || permissionsLoading || timetrackingLoading) return null;
  return (
    <Show
      actions={
        <TopToolbar>
          {(permissions.roles.includes('power') ||
            record.lead_ids.includes(identity?.id)) && <EditButton />}
          {permissions.roles.includes('power') && (
            <>
              <CloneButton />
              <DeleteButton mutationMode="pessimistic" />
            </>
          )}
        </TopToolbar>
      }
    >
      <TabbedShowLayout>
        <TabbedShowLayout.Tab label="Summary">
          <TextField source="name" />
          <TextField source="description" />
          <DateField source="start_date" />
          <DateField source="end_date" />
          <ReferenceArrayField label="AoWs" source="aow_ids" reference="areas_of_work">
            <SingleFieldList linkType="show">
              <ChipField source="name" size="small" clickable />
            </SingleFieldList>
          </ReferenceArrayField>
          <ReferenceArrayField
            label="Activities"
            source="activity_ids"
            reference="activities"
          >
            <SingleFieldList linkType="show">
              <ChipField source="name" size="small" clickable />
            </SingleFieldList>
          </ReferenceArrayField>
          <ReferenceArrayField label="Managers" source="lead_ids" reference="employees">
            <SingleFieldList linkType="show">
              <ChipField source="username" size="small" clickable />
            </SingleFieldList>
          </ReferenceArrayField>
          <ReferenceArrayField label="Members" source="member_ids" reference="employees">
            <SingleFieldList linkType="show">
              <ChipField source="username" size="small" clickable />
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
                  { label: 'AoW', value: 'aow' },
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
                  'dims@': '{project_id}',
                  'dimensions->>project_id': record?.id,
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
