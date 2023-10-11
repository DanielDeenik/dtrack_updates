import { SilentRequest } from '@azure/msal-browser';
import postgrestRestProvider from '@raphiniert/ra-data-postgrest';
import { MsalHttpClientParams, msalRefreshAuth } from 'ra-auth-msal';
import { addRefreshAuthToDataProvider, fetchUtils, Options } from 'react-admin';

import { msalInstance, tokenRequest } from './authConfig';

type MsalHttpClientParamsRequiredTokenRequest = MsalHttpClientParams & {
  tokenRequest: SilentRequest;
};

const postgrestHttpClient =
  ({ msalInstance, tokenRequest }: MsalHttpClientParamsRequiredTokenRequest) =>
  async (url: string, options: Options = {}) => {
    const account = msalInstance.getActiveAccount() || undefined;
    const authResult = await msalInstance.acquireTokenSilent({
      account,
      ...tokenRequest,
    });
    const token = authResult && authResult.idToken;
    const user = { authenticated: !!token, token: `Bearer ${token}` };
    return fetchUtils.fetchJson(url, { ...options, user });
  };

export const dataProvider = addRefreshAuthToDataProvider(
  postgrestRestProvider(
    import.meta.env.VITE_API_BASE_URI,
    postgrestHttpClient({ msalInstance, tokenRequest }),
  ),
  msalRefreshAuth({
    msalInstance,
    tokenRequest,
  }),
);
