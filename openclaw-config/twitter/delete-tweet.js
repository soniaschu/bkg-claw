#!/usr/bin/env node
/**
 * Delete a tweet via X/Twitter API v2
 *
 * Usage:
 *   node delete-tweet.js <tweet_id> [tweet_id2] [...]
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

const ids = process.argv.slice(2);
if (!ids.length) {
  console.error('Usage: node delete-tweet.js <tweet_id> [tweet_id2] [...]');
  process.exit(1);
}

ids.forEach(id => {
  const req = https.request(`https://api.twitter.com/2/tweets/${id}`, {
    method: 'DELETE',
    headers: { 'Authorization': `Bearer ${token}` }
  }, (res) => {
    let data = '';
    res.on('data', c => data += c);
    res.on('end', () => {
      if (res.statusCode === 200) {
        console.log(`✅ Deleted: ${id}`);
      } else {
        console.error(`❌ Failed to delete ${id} (${res.statusCode}):`, data);
      }
    });
  });
  req.end();
});
