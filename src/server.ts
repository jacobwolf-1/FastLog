import { createApp } from './app.ts';

const port = Number(process.env.PORT ?? 8787);

const server = createApp();
server.listen(port, () => {
  console.log(`FastLog API listening on http://localhost:${port}`);
});
