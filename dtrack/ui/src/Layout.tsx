import { CssBaseline } from '@mui/material';
import { LayoutProps } from 'react-admin';
import { Layout } from 'react-admin';
import { ReactQueryDevtools } from 'react-query/devtools';

export const CustomLayout = (props: LayoutProps) => (
  <>
    <CssBaseline />
    <Layout {...props} />
    <ReactQueryDevtools
      initialIsOpen={false}
      toggleButtonProps={{ style: { width: 20, height: 30 } }}
    />
  </>
);
