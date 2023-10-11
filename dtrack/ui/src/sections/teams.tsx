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
  Create,
  CreateButton,
  Datagrid,
  DeleteButton,
  Edit,
  EditButton,
  FilterButton,
  List,
  ReferenceArrayField,
  ReferenceField,
  Show,
  SimpleForm,
  SingleFieldList,
  TabbedShowLayout,
  TextField,
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

const AoESelectInput = (props: AutocompleteInputProps) => {
  const { data, isLoading } = useGetList('areas_of_expertise', {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    sort: { field: 'name', order: 'asc' },
    meta: { columns: ['id', 'name'] },
  });
  if (isLoading) return null;
  return (
    <AutocompleteInput choices={data} optionValue="id" optionText="name" {...props} />
  );
};

interface EmployeeSelectInputProps extends AutocompleteInputProps {
  getListResource: string;
}

interface EmployeeSelectArrayInputProps extends AutocompleteArrayInputProps {
  getListResource: string;
}

const EmployeeSelectInput = (
  props: EmployeeSelectInputProps | EmployeeSelectArrayInputProps,
) => {
  const { data, isLoading } = useGetList(props.getListResource, {
    pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
    sort: { field: 'username', order: 'asc' },
    meta: { columns: ['id', 'name:username'] },
  });
  const lead_id = useWatch({ name: 'lead.id' }) || null;
  const member_ids = useWatch({ name: 'member_ids' }) || [];
  let filteredData = data || [];
  if (props.source === 'lead.id') {
    filteredData = (data || []).filter((employee) => !member_ids.includes(employee.id));
  } else if (props.source === 'member_ids') {
    filteredData = (data || []).filter((employee) => employee.id !== lead_id);
  }
  if (isLoading) return null;
  return props.source === 'member_ids' ? (
    <AutocompleteArrayInput
      choices={filteredData}
      {...(props as AutocompleteArrayInputProps)}
    />
  ) : (
    <AutocompleteInput
      choices={filteredData}
      optionValue="id"
      optionText="name"
      {...(props as AutocompleteInputProps)}
    />
  );
};

const TeamFilters = [
  <AoESelectInput key="aoe" label="AoE" source="aoe->>id" />,
  <EmployeeSelectInput
    key="supervisor"
    label="Lead"
    source="supervisor->>id"
    getListResource="employees"
  />,
  <EmployeeSelectInput
    key="lead"
    label="Line Manager"
    source="lead->>id"
    getListResource="employees"
  />,
  <EmployeeSelectInput
    key="member"
    label="Member"
    source="member_ids@cs"
    getListResource="employees"
  />,
];

const TeamListActions = () => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
  return (
    <TopToolbar>
      <FilterButton filters={TeamFilters} />
      {permissions.roles.includes('power') && <CreateButton />}
    </TopToolbar>
  );
};

export const TeamList = () => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
  return (
    <List
      actions={<TeamListActions />}
      sort={{ field: 'id', order: 'asc' }}
      filters={TeamFilters}
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
        <ReferenceField
          label="AoE"
          source="aoe.id"
          reference="areas_of_expertise"
          sortBy="aoe->name"
          link={false}
        >
          <ChipField source="name" size="small" />
        </ReferenceField>
        <ReferenceField
          label="Lead"
          source="supervisor.id"
          reference="employees"
          sortBy="supervisor->name"
          link={false}
        >
          <ChipField source="username" size="small" />
        </ReferenceField>
        <ReferenceField
          label="Line Manager"
          source="lead.id"
          reference="employees"
          sortBy="lead->name"
          link={false}
        >
          <ChipField source="username" size="small" />
        </ReferenceField>
        <ArrayCountField label="# of Members" source="members" />
      </Datagrid>
    </List>
  );
};

export const TeamCreate = () => (
  <Create>
    <SimpleForm>
      <AoESelectInput label="AoE" source="aoe.id" fullWidth />
      <EmployeeSelectInput
        label="Line Manager"
        source="lead.id"
        getListResource="all_employees"
        fullWidth
      />
      <EmployeeSelectInput
        label="Members"
        source="member_ids"
        getListResource="all_employees"
        fullWidth
      />
    </SimpleForm>
  </Create>
);

export const TeamEdit = () => (
  <Edit>
    <SimpleForm>
      <AoESelectInput label="AoE" source="aoe.id" fullWidth />
      <EmployeeSelectInput
        label="Line Manager"
        source="lead.id"
        getListResource="all_employees"
        fullWidth
      />
      <EmployeeSelectInput
        label="Members"
        source="member_ids"
        getListResource="all_employees"
        fullWidth
      />
    </SimpleForm>
  </Edit>
);

export const TeamShow = () => {
  const { record } = useShowController({ resource: 'aoe_teams' });
  const [axes, setAxes] = useState<Option[]>([
    { label: 'User', value: 'user' },
    { label: 'Activity', value: 'activity' },
    { label: 'Project', value: 'project' },
    { label: 'AoW', value: 'aow' },
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
        'axes@': `{${['daterange', ...axesValues].join(',')}}`,
        'date_part@': granularity.value,
        'zoom_level@': '1',
        'filter_by@': 'user',
        'filter_ids@': record
          ? `{${[record.lead.id, ...record.member_ids].join(',')}}`
          : '{}',
        'daterange@cs': daterange.value,
      },
      meta: { columns: ['id', 'daterange', 'data'] },
    },
    { enabled: Number.isInteger(record?.lead.id) },
  );
  const dataProvider = useDataProvider();
  const handleDownload = async () => {
    // The reason for using the dataProvider directly is that the getList method can be defined
    // to trigger on condition of clicking the download button, which is not possible with the
    // useGetList hook.
    const axesValuesRelevant = axesValues.filter((value) => value !== 'user');
    // TODO: For now we force a group by users for teams download, to relax this constraint would take more work
    const { data } = await dataProvider.getList('rpc/timetracking_summary_export', {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      filter: {
        'user->id@in': `(${[record.lead.id, ...record.member_ids].join(',')})`,
        'axes@': `{${['user', 'daterange', ...axesValuesRelevant].join(',')}}`,
        'date_part@': granularity.value,
        'daterange@cs': daterange.value,
      },
      sort: { field: 'id', order: 'ASC' },
      meta: {
        columns: ['id', 'user', 'daterange', ...axesValuesRelevant, 'total_duration'],
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
            record.supervisor.id === identity?.id) && <EditButton />}
          {permissions.roles.includes('power') && (
            <DeleteButton mutationMode="pessimistic" />
          )}
        </TopToolbar>
      }
    >
      <TabbedShowLayout>
        <TabbedShowLayout.Tab label="Summary">
          <ReferenceField
            label="AoE"
            source="aoe.id"
            reference="areas_of_expertise"
            sortBy="aoe->name"
            link="show"
          >
            <ChipField source="name" size="small" clickable />
          </ReferenceField>
          <ReferenceField
            label="Lead"
            source="supervisor.id"
            reference="employees"
            sortBy="supervisor->name"
            link="show"
          >
            <ChipField source="username" size="small" clickable />
          </ReferenceField>
          <ReferenceField
            label="Line Manager"
            source="lead.id"
            reference="employees"
            sortBy="lead->name"
            link="show"
          >
            <ChipField source="username" size="small" clickable />
          </ReferenceField>
          <ReferenceArrayField label="Members" source="member_ids" reference="employees">
            <SingleFieldList linkType="show">
              <ChipField source="username" size="small" clickable />
            </SingleFieldList>
          </ReferenceArrayField>
        </TabbedShowLayout.Tab>
        <TabbedShowLayout.Tab label="Chart">
          <Box display="flex" className="chart-container">
            <Box className="chart-left">
              <>
                <ReferenceField
                  record={record}
                  source="aoe.id"
                  reference="areas_of_expertise"
                  link={false}
                >
                  <TextField source="name" />
                </ReferenceField>
                {' ('}
                <ReferenceField
                  record={record}
                  source="lead.id"
                  reference="employees"
                  link={false}
                >
                  <TextField source="username" />
                </ReferenceField>
                {')'}
              </>
              <MuiAutocomplete
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
                renderInput={(params) => <MuiTextField {...params} label="Axes" />}
              />
              <DateGranularitySelect
                granularity={granularity}
                setGranularity={setGranularity}
              />
              <DateRangeSelect
                daterange={daterange}
                setDaterange={setDaterange}
                filter={
                  record
                    ? {
                        'dims@': '{user_id}',
                        'dimensions->>user_id@in': `(${[
                          record.lead.id,
                          ...record.member_ids,
                        ].join(',')})`,
                      }
                    : {}
                }
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
