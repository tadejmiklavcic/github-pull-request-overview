import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';

const page = await readFile(new URL('./index.html', import.meta.url));
const script = new URL('./viewPr.sh', import.meta.url);
let state = { running: false, logs: [], report: null, error: null };
let child;
const modes = { all: [], review: ['--needs-my-review'], mine: ['--my-prs-pending-approval'], ready: ['--only-ready'] };

const server = http.createServer(async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method === 'GET' && req.url === '/') {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.end(page);
  }
  res.setHeader('Content-Type', 'application/json');
  if (req.method === 'GET' && req.url === '/api/state') return res.end(JSON.stringify(state));
  if (req.method === 'POST' && req.url === '/api/scan') {
    if (req.headers.origin && req.headers.origin !== `http://${req.headers.host}`) {
      res.writeHead(403); return res.end(JSON.stringify({ error: 'Invalid origin' }));
    }
    if (state.running) { res.writeHead(409); return res.end(JSON.stringify({ error: 'A scan is already running' })); }
    let body = '';
    try {
      for await (const chunk of req) {
        body += chunk;
        if (body.length > 4096) throw new Error('Request too large');
      }
      const options = JSON.parse(body);
      if (!Object.hasOwn(modes, options.mode)) throw new Error('Invalid mode');
      const args = [script.pathname, '--format', 'json', ...modes[options.mode]];
      if (options.login?.trim()) {
        if (!/^[a-z\d-]+$/i.test(options.login.trim())) throw new Error('Invalid GitHub login');
        if (options.mode === 'review') args.push('--reviewer', options.login.trim());
        if (options.mode === 'mine') args.push('--author', options.login.trim());
      }
      state = { running: true, logs: [], report: null, error: null };
      let output = '';
      child = spawn('python3', args, { cwd: new URL('.', import.meta.url), env: process.env });
      child.stdout.on('data', chunk => { output += chunk; });
      child.stderr.on('data', chunk => { state.logs.push(chunk.toString()); if (state.logs.length > 1000) state.logs.shift(); });
      child.on('error', error => { state.error = error.message; state.running = false; });
      child.on('close', code => {
        state.running = false;
        if (code !== 0) { state.error ||= `Scan failed (exit ${code}). Check progress for details.`; return; }
        try { state.report = JSON.parse(output); } catch { state.error = 'The script returned invalid JSON.'; }
      });
      return res.end(JSON.stringify({ started: true }));
    } catch (error) { res.writeHead(400); return res.end(JSON.stringify({ error: error.message })); }
  }
  res.writeHead(404); res.end(JSON.stringify({ error: 'Not found' }));
});
server.listen(Number(process.env.PORT || 3080), '127.0.0.1', () => console.log(`PR Overview: http://127.0.0.1:${server.address().port}`));
process.on('SIGINT', () => { child?.kill(); server.close(() => process.exit()); });
