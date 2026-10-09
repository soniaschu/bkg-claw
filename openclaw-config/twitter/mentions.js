#!/usr/bin/env node
/**
 * Read mentions (tweets that @mention you) via X/Twitter API v2
 *
 * Usage:
 *   node mentions.js
 *   node mentions.js --count 20
 *
 * Environment:
 *   TWITTER_BEARER_TOKEN - OAuth 2.0 access token (required)
 */

const https = require('https');

const token = process.env.TWITTER_BEARER_TOKEN;
if (!token) {
  console.error('Error: Set TWITTER_BEARER_TOKEN environment variable');
  process.exit(1);
}

const args = process.argv.slice(2);
const countIdx = args.indexOf('--count');
const count = countIdx !== -1 ? args[countIdx + 1] : '10';

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, {
      headers: { 'Authorization': `Bearer ${token}` }
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    }).on('error', reject);
  });
}

async function main() {
  // Get authenticated user's ID
  const me = await get('https://api.twitter.com/2/users/me');
  if (me.status !== 200) {
    console.error(`❌ Failed to get user info (${me.status}):`, me.body);
    process.exit(1);
  }
  const user = JSON.parse(me.body);
  const userId = user.data.id;
  console.log(`📋 Mentions for @${user.data.username} (${userId}):\n`);

  // Get mentions
  const params = new URLSearchParams({
    max_results: count,
    'tweet.fields': 'created_at,author_id,conversation_id',
    expansions: 'author_id',
    'user.fields': 'username'
  });
  const mentions = await get(`https://api.twitter.com/2/users/${userId}/mentions?${params}`);
  if (mentions.status !== 200) {
    console.error(`❌ Failed to get mentions (${mentions.status}):`, mentions.body);
    process.exit(1);
  }

  const parsed = JSON.parse(mentions.body);
  if (!parsed.data || parsed.data.length === 0) {
    console.log('No mentions found.');
    return;
  }

  // Build author lookup
  const authors = {};
  if (parsed.includes && parsed.includes.users) {
    parsed.includes.users.forEach(u => { authors[u.id] = u.username; });
  }

  parsed.data.forEach(tweet => {
    const author = authors[tweet.author_id] || tweet.author_id;
    const time = tweet.created_at ? new Date(tweet.created_at).toLocaleString() : '';
    console.log(`@${author} (${time})`);
    console.log(`  ${tweet.text}`);
    console.log(`  ID: ${tweet.id}`);
    console.log();
  });

  console.log(`(${parsed.data.length} mentions shown)`);
}

main();
