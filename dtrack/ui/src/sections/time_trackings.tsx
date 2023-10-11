import jsonExport from 'jsonexport/dist';
import {
  AutocompleteInput,
  AutocompleteInputProps,
  BulkDeleteButton,
  ChipField,
  CloneButton,
  Create,
  Datagrid,
  DateField,
  DateFieldProps,
  DateInput,
  DeleteButton,
  downloadCSV,
  Edit,
  EditButton,
  List,
  ReferenceField,
  Show,
  SimpleForm,
  SimpleShowLayout,
  TextField,
  TextInput,
  TopToolbar,
  useGetIdentity,
  useGetList,
  usePermissions,
  useRecordContext,
  UserIdentity,
} from 'react-admin';
import { useWatch } from 'react-hook-form';

import { generateId } from '../utils/utils';

const EmployeeSelectInput = (props: AutocompleteInputProps) => {
  const { data: identity, isLoading: identityLoading } = useGetIdentity();
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  const { data, isLoading } = useGetList(
    'employees',
    {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      sort: { field: 'username', order: 'asc' },
      meta: { columns: ['id', 'name:username'] },
      ...(!permissions.roles.some((role: string) => ['power', 'lead'].includes(role))
        ? { filter: { id: identity?.id } }
        : {}),
    },
    { enabled: !(identityLoading || permissionsLoading) ? true : false },
  );
  if (isLoading) return null;
  return (
    <AutocompleteInput choices={data} optionValue="id" optionText="name" {...props} />
  );
};

const DurationInput = (props: AutocompleteInputProps) => {
  const durations: { id: string; name: string }[] = [];
  // Custom handling of 'In lieu of overtime'
  const activityId = useWatch({ name: 'activity.id' });
  if (activityId === 104) {
    durations.push({ id: '0.00 hrs', name: '0 hrs' });
  } else {
    for (let i = 15; i <= 15 * 60; i += 15) {
      const hours = i / 60;
      const duration = `${hours.toFixed(2)} hrs`;
      durations.push({ id: duration, name: duration });
    }
  }
  return (
    <AutocompleteInput
      choices={durations}
      optionValue="id"
      optionText="name"
      {...props}
    />
  );
};

const AowSelectInput = (props: AutocompleteInputProps) => {
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

const ProjectSelectInput = (props: AutocompleteInputProps) => {
  const aowId = useWatch({ name: 'aow.id' });
  const { data, isLoading } = useGetList(
    'projects',
    {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      sort: { field: 'name', order: 'asc' },
      filter: { 'areas_of_work@cs': `[{"id": ${aowId}}]` },
      meta: { columns: ['id', 'name'] },
    },
    { enabled: aowId ? true : false },
  );
  if (isLoading) return null;
  return (
    <AutocompleteInput
      choices={data}
      optionValue="id"
      optionText="name"
      disabled={!aowId}
      {...props}
    />
  );
};

// Todo: Make DRY
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

const ActivitySelectInput = (props: AutocompleteInputProps) => {
  const projectId = useWatch({ name: 'project.id' });
  const { data, isLoading } = useGetList(
    'activities',
    {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      sort: { field: 'name', order: 'asc' },
      filter: { 'projects@cs': `[{"id": ${projectId}}]` },
      meta: { columns: ['id', 'name'] },
    },
    { enabled: projectId ? true : false },
  );
  if (isLoading) return null;
  return (
    <AutocompleteInput
      choices={data}
      optionValue="id"
      optionText="name"
      disabled={!projectId}
      {...props}
    />
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

const TeamInput = (props: AutocompleteInputProps) => {
  const { data: identity, isLoading: identityLoading } = useGetIdentity();
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  const { data, isLoading } = useGetList(
    'aoe_teams',
    {
      pagination: { page: 1, perPage: Number.MAX_SAFE_INTEGER },
      sort: { field: 'id', order: 'asc' },
      meta: { columns: ['id', 'name'] },
      filter: permissions.roles.includes('power') ? {} : { 'lead->>id': identity?.id },
    },
    { enabled: !(identityLoading || permissionsLoading) ? true : false },
  );
  const parseValue = (value: string) => `"${value}"`;
  if (isLoading) return null;
  return (
    <AutocompleteInput
      choices={data}
      optionValue="id"
      optionText="name"
      parse={parseValue}
      {...props}
    />
  );
};

const TimeTrackingFilters = (
  identity: UserIdentity | undefined,
  permissions: { roles: string[] },
) => [
  <EmployeeSelectInput
    key="user"
    label="Employee"
    source="user->>id"
    defaultValue={identity?.id}
  />,
  ...(permissions.roles.some((role: string) => ['power', 'lead'].includes(role))
    ? [<TeamInput key="aoe_team" label="AoE Team" source="aoe_team_ids@cs" />]
    : []),
  <AowSelectInput key="aow" label="AoW" source="aow->>id" />,
  <ProjectSelectInputFilter key="project" label="Project" source="project->>id" />,
  <ActivitySelectInputFilter key="activity" label="Activity" source="activity->>id" />,
  <TextInput key="description" label="Task" source="description@ilike" />,
  <DateInput key="date@gte" label="Start Date" source="date@gte" />,
  <DateInput key="date@lte" label="End Date" source="date@lte" />,
];

interface FormattedDateFieldProps extends DateFieldProps {
  source: string;
}

const FormattedDateField = (props: FormattedDateFieldProps) => {
  const record = useRecordContext();
  const tooltipDate = new Date(record[props.source]).toLocaleString('en-GB', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
  return <DateField title={tooltipDate} {...props} />;
};

const exporter = (records: any[]) => {
  const data = records.map((record: any) => ({
    Employee: record.user.name,
    AoW: record.aow.name,
    Project: record.project.name,
    Activity: record.activity.name,
    Task: record.description,
    Date: record.date,
    'Duration (hrs)': record.duration.replace(' hrs', ''),
  }));
  jsonExport(
    data,
    {
      headers: [
        'Employee',
        'AoW',
        'Project',
        'Activity',
        'Task',
        'Date',
        'Duration (hrs)',
      ],
    },
    (err: any, csv: any) => {
      if (err) {
        console.error(err);
      } else {
        downloadCSV(csv, `timetracking-${generateId(6)}`);
      }
    },
  );
};

export const TimeTrackingList = () => {
  const { data: identity, isLoading: identityLoading } = useGetIdentity();
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (identityLoading || permissionsLoading) return null;
  return (
    <List
      sort={{ field: 'date', order: 'desc' }}
      filters={TimeTrackingFilters(identity, permissions)}
      filterDefaultValues={{ 'user->>id': identity?.id }}
      exporter={exporter}
    >
      <Datagrid
        rowClick="show"
        bulkActionButtons={<BulkDeleteButton mutationMode="pessimistic" />}
      >
        {permissions.roles.some((role: string) => ['power', 'lead'].includes(role)) && (
          <ReferenceField
            label="Employee"
            source="user.id"
            reference="employees"
            sortBy="user->name"
            link={false}
          >
            <ChipField source="username" size="small" />
          </ReferenceField>
        )}
        <ReferenceField
          label="AoW"
          source="aow.id"
          reference="areas_of_work"
          sortBy="aow->name"
          link={false}
        >
          <ChipField source="name" size="small" />
        </ReferenceField>
        <ReferenceField
          label="Project"
          source="project.id"
          reference="projects"
          sortBy="project->name"
          link={false}
        >
          <ChipField source="name" size="small" />
        </ReferenceField>
        <ReferenceField
          label="Activity"
          source="activity.id"
          reference="activities"
          sortBy="activity->name"
          link={false}
        >
          <ChipField source="name" size="small" />
        </ReferenceField>
        <TextField label="Task" source="description" />
        <FormattedDateField
          source="date"
          showTime={false}
          options={{ day: '2-digit', month: '2-digit', year: '2-digit' }}
        />
        <TextField source="duration" />
        <CloneButton />
      </Datagrid>
    </List>
  );
};

export const TimeTrackingEdit = () => (
  <Edit>
    <SimpleForm>
      <EmployeeSelectInput label="Employee Name" source="user.id" fullWidth />
      <AowSelectInput label="Area of Work" source="aow.id" fullWidth />
      <ProjectSelectInput label="Project" source="project.id" fullWidth />
      <ActivitySelectInput label="Activity" source="activity.id" fullWidth />
      <TextInput label="Task Description" source="description" multiline fullWidth />
      <DateInput source="date" />
      <DurationInput source="duration" />
    </SimpleForm>
  </Edit>
);

export const TimeTrackingCreate = () => {
  const { data: identity, isLoading: identityLoading } = useGetIdentity();
  if (identityLoading) return null;
  return (
    <Create>
      <SimpleForm>
        <EmployeeSelectInput
          fullWidth
          label="Employee Name"
          source="user.id"
          defaultValue={identity?.id}
        />
        <AowSelectInput label="Area of Work" source="aow.id" fullWidth />
        <ProjectSelectInput label="Project" source="project.id" fullWidth />
        <ActivitySelectInput label="Activity" source="activity.id" fullWidth />
        <TextInput label="Task Description" source="description" multiline fullWidth />
        <DateInput source="date" defaultValue={new Date().toISOString()} />
        <DurationInput source="duration" />
      </SimpleForm>
    </Create>
  );
};

export const TimeTrackingShow = () => {
  return (
    <Show
      actions={
        <TopToolbar>
          <EditButton />
          <CloneButton />
          <DeleteButton mutationMode="pessimistic" />
        </TopToolbar>
      }
    >
      <SimpleShowLayout>
        <ReferenceField
          label="Employee"
          source="user.id"
          reference="employees"
          sortBy="user->name"
          link="show"
        >
          <ChipField source="username" size="small" clickable />
        </ReferenceField>
        <ReferenceField
          label="AoW"
          source="aow.id"
          reference="areas_of_work"
          sortBy="aow->name"
          link="show"
        >
          <ChipField source="name" size="small" clickable />
        </ReferenceField>
        <ReferenceField
          label="Project"
          source="project.id"
          reference="projects"
          sortBy="project->name"
          link="show"
        >
          <ChipField source="name" size="small" clickable />
        </ReferenceField>
        <ReferenceField
          label="Activity"
          source="activity.id"
          reference="activities"
          sortBy="activity->name"
          link="show"
        >
          <ChipField source="name" size="small" clickable />
        </ReferenceField>
        <TextField label="Task" source="description" />
        <DateField
          source="date"
          showTime={false}
          options={{ weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }}
        />
        <TextField source="duration" />
      </SimpleShowLayout>
    </Show>
  );
};
