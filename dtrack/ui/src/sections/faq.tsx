import { RichTextInput } from 'ra-input-rich-text';
import {
  BooleanField,
  BooleanInput,
  BulkDeleteButton,
  CloneButton,
  Create,
  CreateButton,
  Datagrid,
  DeleteButton,
  Edit,
  EditButton,
  List,
  NumberInput,
  RichTextField,
  Show,
  SimpleForm,
  SimpleShowLayout,
  TextField,
  TextInput,
  TopToolbar,
  usePermissions,
} from 'react-admin';

export const FaqList = () => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
  return (
    <List
      sort={{ field: 'priority', order: 'asc' }}
      actions={
        <TopToolbar>{permissions.roles.includes('power') && <CreateButton />}</TopToolbar>
      }
      empty={false}
      perPage={50}
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
        <TextField label="Frequently asked Question" source="question" sortable={false} />
        {permissions.roles.includes('power') && <BooleanField source="is_published" />}
      </Datagrid>
    </List>
  );
};

export const FaqCreate = () => (
  <Create>
    <SimpleForm>
      <NumberInput source="priority" step={1} />
      <TextInput source="question" />
      <RichTextInput source="answer" />
      <BooleanInput source="is_published" />
    </SimpleForm>
  </Create>
);

export const FaqEdit = () => (
  <Edit>
    <SimpleForm>
      <NumberInput source="priority" step={1} />
      <TextInput source="question" />
      <RichTextInput source="answer" />
      <BooleanInput source="is_published" />
    </SimpleForm>
  </Edit>
);

export const FaqShow = () => {
  const { permissions, isLoading: permissionsLoading } = usePermissions();
  if (permissionsLoading) return null;
  return (
    <Show
      actions={
        <TopToolbar>
          {permissions.roles.includes('power') && (
            <>
              <EditButton />
              <CloneButton />
              <DeleteButton mutationMode="pessimistic" />
            </>
          )}
        </TopToolbar>
      }
    >
      <SimpleShowLayout>
        <TextField source="question" />
        <RichTextField source="answer" fullWidth />
        {permissions.roles.includes('power') && <BooleanField source="is_published" />}
      </SimpleShowLayout>
    </Show>
  );
};
