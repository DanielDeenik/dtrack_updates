import Tooltip from '@mui/material/Tooltip';
import { FunctionField, useRecordContext } from 'react-admin';

type ArrayCountFieldProps = {
  source: string;
  label: string;
};

type ElementType = {
  [key: string]: number | string;
};

type RecordType = {
  [key: string]: ElementType[];
};

export const ArrayCountField = ({ source, label }: ArrayCountFieldProps) => {
  const record = useRecordContext<RecordType>();
  const array = record[source];
  const count = array ? array.length : 0;
  const items = array ? array.map((item) => item.name).join(', ') : '';

  return (
    <FunctionField
      label={label}
      render={() => (
        <Tooltip title={items}>
          <span>{count > 0 ? count : null}</span>
        </Tooltip>
      )}
    />
  );
};
