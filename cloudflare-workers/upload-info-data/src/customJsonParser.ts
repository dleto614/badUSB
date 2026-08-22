// Our interface that is to build the proper thing on a successful parse to prepare for insert in db.
export interface ParsedLine {
  category: string;
  timestamp: string;
  payloadRaw: string;
}

function splitKeyValuePairs(line: string): Array<[string, string]> {
  // Grab the outer {...}
  // I think these are called, curly brackets?
  let obj = line.trim();
  if (!obj.startsWith("{") || !obj.endsWith("}")) return [];

  // Remove outer braces so we can split the "body"
  const body = obj.slice(1, -1).trim();

  // Split pairs on commas at "top level" by using a heuristic:
  // Iterate characters and only cut when not inside quotes and not inside nested braces/brackets
  const parts: string[] = [];
  let startIdx = 0;
  let depthObj = 0;
  let inStr = false;
  let esc = false;

  for (let i = 0; i < body.length; i++) {
    const ch = body[i];

      if (inStr) {
        if (esc) {
          esc = false;
          // If a quote is "escaped" but is immediately followed by JSON structure, 
          // it means the quote actually closed and the backslash was garbage.
          if (ch === '"' && i + 1 < body.length) {
            const nextCh = body[i + 1];
            if (nextCh === ',' || nextCh === ':' || nextCh === '}' || nextCh === ']' || nextCh === '[' || nextCh === '{') {
              inStr = false;
            }
          }
        } else if (ch === "\\") {
          esc = true;
        } else if (ch === '"') {
          inStr = false;
        }
        continue;
     }

    if (ch === '"') {
      inStr = true;
      continue;
    }

    if (ch === "{" || ch === "[") depthObj++;

    if (ch === "}" || ch === "]") {
      depthObj = Math.max(0, depthObj - 1);
    }

    if (ch === "," && depthObj === 0) {
      parts.push(body.substring(startIdx, i).trim());
      startIdx = i + 1;
      continue;
    }
  }
  
  if (startIdx < body.length) {
    parts.push(body.substring(startIdx).trim());
  }

  // Split each part on the first colon only
  return parts
    .filter(Boolean)
    .map(p => {
      const idx = p.indexOf(":");
      const k = p.slice(0, idx).trim().replace(/^"|"$/g, "");
      const v = p.slice(idx + 1).trim();
      return [k, v] as [string, string];
    });
}

// This is to handle our Payload thing...
function splitArrayElements(arrString: string): string[] {
  const inner = arrString.slice(1, -1).trim(); // strip outer [ ]... I think these are called square brackets.
  if (!inner) return [];

  const parts: string[] = [];
  let startIdx = 0;
  let depthObj = 0;
  let inStr = false;
  let esc = false;

  for (let i = 0; i < inner.length; i++) {
    const ch = inner[i];

    if (inStr) {
      if (esc) {
        esc = false;
        // If a quote is "escaped" but is immediately followed by JSON structure, 
        // it means the quote actually closed and the backslash was garbage.
        if (ch === '"' && i + 1 < inner.length) {
          const nextCh = inner[i + 1];
          if (nextCh === ',' || nextCh === ':' || nextCh === '}' || nextCh === ']' || nextCh === '[' || nextCh === '{') {
            inStr = false;
          }
        }
      } else if (ch === "\\") {
        esc = true;
      } else if (ch === '"') {
        inStr = false;
      }
      continue;
    }

    if (ch === '"') {
      inStr = true;
      continue;
    }

    if (ch === "{" || ch === "[") {
      depthObj++;
    }

    if (ch === "}" || ch === "]") {
      depthObj = Math.max(0, depthObj - 1);
    }

    if (ch === "," && depthObj === 0) {
      parts.push(inner.substring(startIdx, i).trim());
      startIdx = i + 1;
      continue;
    }
  }
  
  if (startIdx < inner.length) {
    parts.push(inner.substring(startIdx).trim());
  }

  return parts;
}

export function parseJSON(incomingJsonl: string[]): ParsedLine[] {
  const results: ParsedLine[] = [];

  for (const line of incomingJsonl) {
    // Skip blank lines from the file so we don't process empty objects
    if (!line.trim()) {
      continue;
    }

    // JSON.parse breaks due to Windows being a little bitch so this has to be done manually...
    const splitResult = splitKeyValuePairs(line);
    
    // Elegant key extraction using .find() instead of mutating let variables in a loop
    const categoryPair = splitResult.find(([key]) => key === "Category");
    const timestampPair = splitResult.find(([key]) => key === "Timestamp");
    const payloadPair = splitResult.find(([key]) => key === "Payload");

    // Clean up the strings safely with optional chaining
    const category = categoryPair?.[1]?.replace(/^"|"$/g, "") ?? "";
    const timestamp = timestampPair?.[1]?.replace(/^"|"$/g, "") ?? "";
    const payloadRaw = payloadPair?.[1] ?? "";

    // Only push if we actually got a category and payload
    if (category && payloadRaw) {
      results.push({ category, timestamp, payloadRaw });
    }
  }

  return results;
}