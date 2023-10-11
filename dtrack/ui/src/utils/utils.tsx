import jsonExport from 'jsonexport/dist';
import { downloadCSV } from 'react-admin';

export const generateId = (length: number) => {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return result;
};

export const handleSummaryExport = (data: any) => {
  jsonExport(
    data.map((record: any) => {
      const mappedRecord: any = {};
      if (record.user?.name) mappedRecord.Employee = record.user.name;
      if (record.aow?.name) mappedRecord.AoW = record.aow.name;
      if (record.project?.name) mappedRecord.Project = record.project.name;
      if (record.activity?.name) mappedRecord.Activity = record.activity.name;
      if (record.daterange) {
        mappedRecord['Daterange - Start'] = record.daterange.substring(1, 11);
        mappedRecord['Daterange - End'] = record.daterange.substring(12, 22);
      }
      if (record.total_duration)
        mappedRecord['Total Duration (hrs)'] = record.total_duration;
      return mappedRecord;
    }),
    {
      headers: [
        'Employee',
        'AoW',
        'Project',
        'Activity',
        'Daterange - Start',
        'Daterange - End',
        'Total Duration (hrs)',
      ],
    },
    (err: any, csv: any) => {
      if (err) {
        console.error(err);
      } else {
        downloadCSV(csv, `timetracking-summary-${generateId(6)}`);
      }
    },
  );
};
