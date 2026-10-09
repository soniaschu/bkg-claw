#!/usr/bin/env node
/**
 * Post a tweet via X/Twitter API v2 (OAuth 2.0 Bearer token)
 *
 * Usage:
 *   node tweet.js "Your tweet text here"
 *   node tweet.js "Reply text" --reply-to 1234567890
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
const replyIdx = args.indexOf('--reply-to');
let replyTo = null;
if (replyIdx !== -1) {
  replyTo = args[replyIdx + 1];
  args.splice(replyIdx, 2);
}

const text = args[0];
if (!text) {
  console.error('Usage: node tweet.js "text" [--reply-to tweet_id]');
  process.exit(1);
}

const payload = { text };
if (replyTo) payload.reply = { in_reply_to_tweet_id: replyTo };

const body = JSON.stringify(payload);

const req = https.request('https://api.twitter.com/2/tweets', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body)
  }
}, (res) => {
  let data = '';
  res.on('data', c => data += c);
  res.on('end', () => {
    if (res.statusCode === 201) {
      const parsed = JSON.parse(data);
      console.log(`✅ Tweet posted: https://x.com/i/status/${parsed.data.id}`);
      console.log(`   ID: ${parsed.data.id}`);
      console.log(`   Text: ${parsed.data.text}`);
    } else {
      console.error(`❌ Failed (${res.statusCode}):`, data);
      process.exit(1);
    }
  });
});
req.write(body);
req.end();
