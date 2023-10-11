import {
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
  ListProps,
  ReferenceArrayField,
  Show,
  SimpleForm,
  SimpleShowLayout,
  SingleFieldList,
  TextField,
  TextInput,
  TopToolbar,
  useGetList,
  usePermissions,
} from 'react-admin';

const EmployeeSelectInput = (props: AutocompleteInputProps) => {
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

const AoEFilters = [
  <TextInput key="name" label="Name" source="name@ilike" />,
  <TextInput key="description" label="Description" source="description@ilike" />,
  <EmployeeSelectInput key="supervisor" label="Lead" source="supervisor_ids@cs" />,
];

const AoEListActions = () => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
  return (
    <TopToolbar>
      <FilterButton filters={AoEFilters} />
      {permissions.roles.includes('power') && <CreateButton />}
    </TopToolbar>
  );
};

export const AoEList = (props: ListProps) => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
  return (
    <List
      {...props}
      actions={<AoEListActions />}
      sort={{ field: 'name', order: 'asc' }}
      filters={AoEFilters}
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
        <ReferenceArrayField
          label="Leads"
          source="supervisor_ids"
          reference="employees"
          sortable={false}
        >
          <SingleFieldList linkType={false}>
            <ChipField source="username" size="small" />
          </SingleFieldList>
        </ReferenceArrayField>
      </Datagrid>
    </List>
  );
};

export const AoECreate = () => (
  <Create>
    <SimpleForm>
      <TextInput source="name" fullWidth />
      <TextInput source="description" fullWidth />
    </SimpleForm>
  </Create>
);

export const AoEEdit = () => (
  <Edit>
    <SimpleForm>
      <TextInput source="name" fullWidth />
      <TextInput source="description" fullWidth />
    </SimpleForm>
  </Edit>
);

export const AoEShow = () => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
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
      <SimpleShowLayout>
        <TextField source="name" />
        <TextField source="description" />
        <ReferenceArrayField label="Leads" source="supervisor_ids" reference="employees">
          <SingleFieldList linkType="show">
            <ChipField source="username" size="small" clickable />
          </SingleFieldList>
        </ReferenceArrayField>
      </SimpleShowLayout>
    </Show>
  );
};
