import { ApolloServer, ContextFunction } from "@apollo/server";
import { expressMiddleware } from '@apollo/server/express4';
import express from 'express';
import http from 'http';
import {
  StandaloneServerContextFunctionArgument,
  startStandaloneServer,
} from "@apollo/server/standalone";
import * as jose from 'jose'
import cors from 'cors'
import crypto from 'crypto'
import { readFileSync } from "fs";
import { readFile } from "fs/promises";
import { createPrivateKey } from "crypto";
import gql from "graphql-tag";
import { buildSubgraphSchema } from "@apollo/subgraph";
import { resolvers } from "./resolvers";
import { users } from "./resolvers/data.js";
import { DataSourceContext } from "./types/DataSourceContext";

const app = express();
const port = process.env.PORT ?? "4001";
const subgraphName = require("../package.json").name;

const jwks = readFileSync("./keys/jwks.json", "utf-8");
const joseJWKS = jose.createLocalJWKSet(JSON.parse(jwks));

// In-memory stores for OAuth (demo purposes)
const registeredClients = new Map<string, { client_id: string; client_secret: string; redirect_uris: string[] }>();
const authorizationCodes = new Map<string, { client_id: string; redirect_uri: string; scope: string; user_id: string; username: string; expires_at: number }>();

function getIssuer(req: express.Request): string {
  const host = req.headers['x-forwarded-host'] || req.headers.host || `localhost:${port}`;
  const protocol = req.headers['x-forwarded-proto'] || 'http';
  return `${protocol}://${host}`;
}

const context: ContextFunction<
  [StandaloneServerContextFunctionArgument],
  DataSourceContext
> = async ({ req }) => {
  let context: DataSourceContext = { headers: req.headers }
  if (req.headers.authorization && req.headers.authorization.split(' ')[0] === 'Bearer') {
    const token = req.headers.authorization.split(' ')[1];
    try {
      const { payload } = await jose.jwtVerify(token.trim(), joseJWKS)
      context.user = payload
    } catch (e) {
      if (e.name === 'JOSEError' || e.name === "JWTExpired") {
        return context;
      } else {
        console.error(e)
      }
    }
  }
  return context
};

type OAuthParams = { client_id: string; redirect_uri: string; state: string; scope: string; code_challenge: string; code_challenge_method: string };

function renderLoginPage(res: express.Response, params: OAuthParams, error?: string) {
  const errorHtml = error ? `<div class="error">${error}</div>` : '';
  res.type('html').send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sign In — Apollo Reference Architecture</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f6f8; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
    .card { background: #fff; border-radius: 12px; box-shadow: 0 2px 16px rgba(0,0,0,0.08); padding: 40px; width: 100%; max-width: 400px; }
    .logo { text-align: center; margin-bottom: 24px; }
    .logo svg { width: 40px; height: 40px; }
    .logo h1 { font-size: 20px; font-weight: 600; color: #1a1a2e; margin-top: 8px; }
    .logo p { font-size: 13px; color: #6b7280; margin-top: 4px; }
    .scope-badge { display: inline-block; background: #ede9fe; color: #5b21b6; font-size: 12px; font-weight: 500; padding: 2px 8px; border-radius: 4px; margin-top: 8px; }
    label { display: block; font-size: 14px; font-weight: 500; color: #374151; margin-bottom: 6px; margin-top: 16px; }
    input[type="text"], input[type="password"] { width: 100%; padding: 10px 12px; border: 1px solid #d1d5db; border-radius: 8px; font-size: 15px; outline: none; transition: border-color 0.15s; }
    input[type="text"]:focus, input[type="password"]:focus { border-color: #6d28d9; box-shadow: 0 0 0 3px rgba(109,40,217,0.1); }
    button { width: 100%; margin-top: 24px; padding: 12px; background: #311b92; color: #fff; font-size: 15px; font-weight: 600; border: none; border-radius: 8px; cursor: pointer; transition: background 0.15s; }
    button:hover { background: #4527a0; }
    .error { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; padding: 10px 14px; border-radius: 8px; font-size: 14px; margin-bottom: 8px; }
    .hint { font-size: 12px; color: #9ca3af; margin-top: 16px; text-align: center; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">
      <svg viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M128 0C57.308 0 0 57.308 0 128s57.308 128 128 128 128-57.308 128-128S198.692 0 128 0z" fill="#311B92"/><path d="M176.5 198.5h-22.4l-10.6-29.8H112l-10.6 29.8H79.5L122 68h13.5l41 130.5zm-40.2-50.3l-15.5-46.8h-.6l-15.5 46.8h31.6z" fill="#fff"/></svg>
      <h1>Apollo Reference Architecture</h1>
      <p>Sign in to authorize MCP access</p>
      ${params.scope ? `<span class="scope-badge">${params.scope}</span>` : ''}
    </div>
    ${errorHtml}
    <form method="POST" action="/authorize">
      <input type="hidden" name="client_id" value="${params.client_id || ''}">
      <input type="hidden" name="redirect_uri" value="${params.redirect_uri || ''}">
      <input type="hidden" name="state" value="${params.state || ''}">
      <input type="hidden" name="scope" value="${params.scope || ''}">
      <input type="hidden" name="code_challenge" value="${params.code_challenge || ''}">
      <input type="hidden" name="code_challenge_method" value="${params.code_challenge_method || ''}">
      <label for="username">Username</label>
      <input type="text" id="username" name="username" placeholder="e.g. user1" autocomplete="username" autofocus required>
      <label for="password">Password</label>
      <input type="password" id="password" name="password" placeholder="Any non-empty password" autocomplete="current-password" required>
      <button type="submit">Sign In</button>
    </form>
    <p class="hint">Test users: user1, user2, user3, inventoryManager</p>
  </div>
</body>
</html>`);
}

async function main() {
  const httpServer = http.createServer(app);
  let typeDefs = gql(
    readFileSync("schema.graphql", {
      encoding: "utf-8",
    })
  );
  const server = new ApolloServer({
    schema: buildSubgraphSchema({ typeDefs, resolvers }),
  });
  await server.start();

  app.get('/.well-known/jwks.json', (req, res) => {
    res.json(JSON.parse(jwks));
  })

  // OAuth 2.0 Authorization Server Metadata (RFC 8414)
  app.get('/.well-known/oauth-authorization-server', (req, res) => {
    const issuer = getIssuer(req);
    res.json({
      issuer,
      jwks_uri: `${issuer}/.well-known/jwks.json`,
      response_types_supported: ['code'],
      grant_types_supported: ['authorization_code'],
      code_challenge_methods_supported: ['S256'],
      token_endpoint: `${issuer}/token`,
      authorization_endpoint: `${issuer}/authorize`,
      registration_endpoint: `${issuer}/register`,
    });
  })

  // RFC 7591 Dynamic Client Registration
  app.post('/register', express.json(), (req, res) => {
    const client_id = `client_${crypto.randomUUID()}`;
    const client_secret = crypto.randomUUID();
    const redirect_uris = req.body.redirect_uris || [];

    registeredClients.set(client_id, { client_id, client_secret, redirect_uris });

    res.status(201).json({
      client_id,
      client_secret,
      redirect_uris,
      client_id_issued_at: Math.floor(Date.now() / 1000),
      client_secret_expires_at: 0,
    });
  });

  // OAuth Authorization Endpoint — renders a login form
  app.get('/authorize', (req, res) => {
    const { client_id, redirect_uri, state, scope, code_challenge, code_challenge_method } = req.query;
    renderLoginPage(res, {
      client_id: client_id as string,
      redirect_uri: redirect_uri as string,
      state: state as string,
      scope: scope as string,
      code_challenge: code_challenge as string,
      code_challenge_method: code_challenge_method as string,
    });
  });

  // OAuth Authorization Endpoint — processes the login form submission
  app.post('/authorize', express.urlencoded({ extended: true }), (req, res) => {
    const { username, password, client_id, redirect_uri, state, scope, code_challenge, code_challenge_method } = req.body;
    const oauthParams = { client_id, redirect_uri, state, scope, code_challenge, code_challenge_method };

    if (!username || !password) {
      renderLoginPage(res, oauthParams, 'Username and password are required.');
      return;
    }

    const user = users.find((u) => u.username === username);
    if (!user) {
      renderLoginPage(res, oauthParams, 'Invalid username or password.');
      return;
    }

    const userScopes = user.scopes || [];
    const grantedScope = (scope as string) || userScopes.join(' ') || 'user:read:email';

    const code = crypto.randomUUID();
    console.log('[OAuth /authorize] login success for', username, '- created code:', code);
    authorizationCodes.set(code, {
      client_id,
      redirect_uri,
      scope: grantedScope,
      user_id: user.id,
      username: user.username,
      expires_at: Date.now() + 5 * 60 * 1000,
    });

    const redirectUrl = new URL(redirect_uri as string);
    redirectUrl.searchParams.set('code', code);
    if (state) redirectUrl.searchParams.set('state', state as string);

    res.redirect(302, redirectUrl.toString());
  });

  // OAuth Token Endpoint
  app.post('/token', express.urlencoded({ extended: true }), express.json(), async (req, res): Promise<void> => {
    const { grant_type, code, redirect_uri, client_id } = req.body;
    console.log('[OAuth /token] body:', JSON.stringify(req.body));
    console.log('[OAuth /token] stored codes:', [...authorizationCodes.keys()]);

    if (grant_type !== 'authorization_code') {
      console.log('[OAuth /token] rejected: unsupported_grant_type', grant_type);
      res.status(400).json({ error: 'unsupported_grant_type' });
      return;
    }

    const authCode = authorizationCodes.get(code);
    if (!authCode || authCode.expires_at < Date.now()) {
      console.log('[OAuth /token] rejected: invalid_grant, code found:', !!authCode, 'expired:', authCode ? authCode.expires_at < Date.now() : 'N/A');
      res.status(400).json({ error: 'invalid_grant' });
      return;
    }

    authorizationCodes.delete(code);

    try {
      const privateKeyText = await readFile("./keys/private_key.pem", { encoding: "utf8" });
      const privateKey = createPrivateKey(privateKeyText);

      const issuer = getIssuer(req);

      const access_token = await new jose.SignJWT({
        sub: authCode.user_id,
        scope: authCode.scope,
        username: authCode.username,
      })
        .setProtectedHeader({ alg: 'ES256', kid: 'main-key-2024' })
        .setIssuer(issuer)
        .setAudience('apollo-mcp')
        .setIssuedAt()
        .setExpirationTime('2h')
        .sign(privateKey);

      const tokenResponse = {
        access_token,
        token_type: 'Bearer',
        expires_in: 7200,
        scope: authCode.scope,
      };
      console.log('[OAuth /token] SUCCESS - issuer:', issuer, 'scope:', authCode.scope);
      res.json(tokenResponse);
    } catch (err) {
      console.error('[OAuth /token] ERROR generating token:', err);
      res.status(500).json({ error: 'server_error', error_description: String(err) });
    }
  });

  // Log warning if trace context is missing
  app.use((req, res, next) => {
    if (!req.headers['traceparent']) {
      console.warn(`[${subgraphName}] Incoming request missing traceparent header - will create new root trace`);
    }
    next();
  });

  app.use(
    '/',
    cors(),
    express.json(),
    expressMiddleware(server, { context }),
  );

  await new Promise<void>((resolve) => httpServer.listen({ port }, () => resolve()));

  console.log(`🚀  Subgraph ${subgraphName} ready at http://localhost:${port}/`);
}

main();
