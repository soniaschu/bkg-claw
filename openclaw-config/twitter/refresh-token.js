#!/usr/bin/env node
/**
 * Refresh an expired Twitter/X OAuth 2.0 access token
 *
 * Usage:
 *   node refresh-token.js <refresh_token>
 *
 * Environment:
 *   TWITTER_CLIENT_ID     - OAuth 2.0 Client ID (required)
 *   TWITTER_CLIENT_SECRET - OAuth 2.0 Client Secret (required)
 */

const https = require('https');

const CLIENT_ID = process.env.TWITTER_CLIENT_ID;
const CLIENT_SECRET = process.env.TWITTER_CLIENT_SECRET;
const refreshToken = process.argv[2];

if (!CLIENT_ID || !CLIENT_SECRET) {
  console.error('Error: Set TWITTER_CLIENT_ID and TWITTER_CLIENT_SECRET environment variables');
  process.exit(1);
}
if (!refreshToken) {
  console.error('Usage: node refresh-token.js <refresh_token>');
  process.exit(1);
}

const body = new URLSearchParams({
  grant_type: 'refresh_token',
  refresh_token: refreshToken,
  client_id: CLIENT_ID
}).toString();

const basicAuth = Buffer.from(`${CLIENT_ID}:${CLIENT_SECRET}`).toString('base64');

const req = https.request('https://api.twitter.com/2/oauth2/token', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Authorization': `Basic ${basicAuth}`,
    'Content-Length': Buffer.byteLength(body)
  }
}, (res) => {
  let data = '';
  res.on('data', c => data += c);
  res.on('end', () => {
    const parsed = JSON.parse(data);
    if (parsed.access_token) {
      console.log('\n✅ Token refreshed!\n');
      console.log('ACCESS TOKEN:', parsed.access_token);
      console.log('REFRESH TOKEN:', parsed.refresh_token || '(same)');
      console.log('EXPIRES IN:', parsed.expires_in, 'seconds');
      console.log('\nexport TWITTER_BEARER_TOKEN="' + parsed.access_token + '"');
    } else {
      console.error('❌ Error:', data);
      process.exit(1);
    }
  });
});
req.write(body);
req.end();
