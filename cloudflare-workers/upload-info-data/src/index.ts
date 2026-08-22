import { Hono } from 'hono'
import { ParsedLine, parseJSON } from './customJsonParser'

// Our bindings for the worker thing...
// This is for the DB.
type Bindings = {
  DB: D1Database
}

const app = new Hono<{ Bindings: Bindings }>()

// Hash strings to sha256.
async function hashString(line: string): Promise<string> {
  const encoder = new TextEncoder();
  const encodedData = encoder.encode(line);

  const hashBuffer = await crypto.subtle.digest('SHA-256', encodedData);

  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hash = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');


  return hash
}

// I stole this from the internet like a good goober who is shit at coding...
function chunkArray<T>(array: T[], chunkSize: number): T[][] {
    return Array.from({ length: Math.ceil(array.length / chunkSize) }, (_, index) =>
        array.slice(index * chunkSize, index * chunkSize + chunkSize)
    );
}

// You'll pass the D1 database instance from Hono (c.env.DB) into here
async function insertData(chunks: ParsedLine[][], scanId: string, machineId: string, db: D1Database): Promise<void> {
  
  for (const chunk of chunks) {
    const statements: D1PreparedStatement[] = [];

    // If we already have this machine_id, it ignores it. If not, it inserts it (and auto-increments the id).
    statements.push(
      db.prepare(`INSERT OR IGNORE INTO computer_info (machine_id) VALUES (?)`).bind(machineId)
    );

    // We only want to insert unique categories per chunk so we don't try to insert "Software" 10 times.
    const uniqueCategoriesInChunk = [...new Set(chunk.map(line => line.category))];
    
    for (const cat of uniqueCategoriesInChunk) {
      const categoryHash = await hashString(cat); // Hash "Software" -> "abc123..."
      statements.push(
        db.prepare(`INSERT OR IGNORE INTO categories (category_hash, category) VALUES (?, ?)`).bind(categoryHash, cat)
      );
    }

    // Insert the payload
    for (const line of chunk) {
      const categoryHash = await hashString(line.category); // Hash it again to match the FK
      
      statements.push(
        db.prepare(`
          INSERT INTO payload (scan_id, payload_timestamp, payload, category_hash, machine_id) 
          VALUES (?, ?, ?, ?, ?)
        `).bind(scanId, line.timestamp, line.payloadRaw, categoryHash, machineId)
      );
    }

    // D1 will run all these SQL statements in a single, fast transaction
    await db.batch(statements);
  }
}

// The endpoint to get the data.
app.post('/api/upload', async (c) => {
  // Get the raw JSONL string from the Ducky/Powershell/Whatever... POST request
  const rawJsonl = await c.req.text();
  const lines = rawJsonl.split('\n'); // Clean up newlines or whatever... Idk.

  try {
    const parsedJsonl = parseJSON(lines);
    
    // Find our BIOS and properly hash it to sha256 for the machine_id primary key thing...
    const biosLine: ParsedLine | undefined = parsedJsonl.find(l => l.category === 'BIOS');

    if (!biosLine) { // Our guard thingie magiber...
      return c.json({ error: 'Missing BIOS category' }, 400);
    } 

    const machineId: string = await hashString(biosLine.payloadRaw);
    const scanId: string = crypto.randomUUID();

    const chunkedArray: ParsedLine[][] = chunkArray(parsedJsonl, 50); // We split our chunky boy into smaller pieces...

    await insertData(chunkedArray, scanId, machineId, c.env.DB);

    return c.json({ status: 'success' }, 200);

  } catch (err) {
    // If your parser hits a line it absolutely can't handle, 
    // catch it here so the Ducky doesn't hang waiting for a response
    return c.json({ status: 'error', message: String(err) }, 500);
  }
})

export default app