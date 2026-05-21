import { getDb, initDb } from './schema.js';

console.log('Initializing database...');
initDb();
console.log('Database initialized successfully.');
console.log('Run "npm run db:seed" to populate mock data.');
