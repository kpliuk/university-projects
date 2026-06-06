const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");
const fs = require("fs/promises");
const path = require("path");

const app = express();
const port = Number(process.env.PORT || 3000);
const dataFile = process.env.DATA_FILE;
let databaseReady = false;
let databaseInitError = null;

app.use(cors());
app.use(express.json());

const pool = dataFile
  ? null
  : new Pool({
      host: process.env.DB_HOST || "postgres-service",
      user: process.env.DB_USER || "user",
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME || "mydb",
      port: Number(process.env.DB_PORT || 5432),
      ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false
    });

async function ensureDataFile() {
  await fs.mkdir(path.dirname(dataFile), { recursive: true });

  try {
    await fs.access(dataFile);
  } catch (_error) {
    await fs.writeFile(dataFile, "[]\n", "utf8");
  }
}

async function readUsersFromFile() {
  await ensureDataFile();
  const content = await fs.readFile(dataFile, "utf8");
  return JSON.parse(content || "[]");
}

async function saveUserToFile(name) {
  const users = await readUsersFromFile();
  const nextId = users.length > 0 ? Math.max(...users.map((user) => user.id || 0)) + 1 : 1;
  users.push({ id: nextId, name });
  await fs.writeFile(dataFile, `${JSON.stringify(users, null, 2)}\n`, "utf8");
}

async function prepareDatabase() {
  if (dataFile) {
    await ensureDataFile();
    return;
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS guestbook_entries (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      message TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function waitForDatabase(maxAttempts = 120, delayMs = 5000) {
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await prepareDatabase();
      console.log(`Database is ready after attempt ${attempt}.`);
      databaseReady = true;
      databaseInitError = null;
      return;
    } catch (error) {
      databaseReady = false;
      databaseInitError = error;
      console.error(`Database is not ready yet (attempt ${attempt}/${maxAttempts}):`, error.message);

      if (attempt === maxAttempts) {
        throw error;
      }

      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
}

app.get("/health", async (_req, res) => {
  try {
    if (dataFile) {
      await ensureDataFile();
    } else {
      await pool.query("SELECT 1");
    }

    res.json({ status: "ok" });
  } catch (error) {
    console.error("Healthcheck failed:", error);
    res.status(500).json({ status: "error" });
  }
});

app.get("/ready", (_req, res) => {
  if (databaseReady) {
    return res.json({ status: "ready" });
  }

  return res.status(503).json({
    status: "starting",
    error: databaseInitError ? databaseInitError.message : "Database is not ready yet"
  });
});

app.get("/status", (_req, res) => {
  res.json({
    backend: "online",
    database: databaseReady ? "ready" : "starting"
  });
});

app.post("/save", async (req, res) => {
  if (!databaseReady) {
    return res.status(503).send("Database is still starting");
  }

  const name = (req.body.name || "").trim();
  const message = (req.body.message || "").trim();

  if (!name) {
    return res.status(400).send("Name is required");
  }

  if (!message) {
    return res.status(400).send("Message is required");
  }

  try {
    if (dataFile) {
      await saveUserToFile(name);
    } else {
      await pool.query("INSERT INTO guestbook_entries(name, message) VALUES($1, $2)", [name, message]);
    }

    return res.send(`Saved: ${name}`);
  } catch (error) {
    console.error("Insert failed:", error);
    return res.status(500).send("Error");
  }
});

app.get("/users", async (_req, res) => {
  if (!databaseReady) {
    return res.status(503).json([]);
  }

  try {
    if (dataFile) {
      const users = await readUsersFromFile();
      return res.json(users);
    }

    const result = await pool.query(`
      SELECT id, name, message, created_at
      FROM guestbook_entries
      ORDER BY created_at DESC, id DESC
    `);
    return res.json(result.rows);
  } catch (error) {
    console.error("Select failed:", error);
    return res.status(500).send("Error");
  }
});

app.get("/entries", async (_req, res) => {
  if (!databaseReady) {
    return res.status(503).json([]);
  }

  try {
    const result = await pool.query(`
      SELECT id, name, message, created_at
      FROM guestbook_entries
      ORDER BY created_at DESC, id DESC
    `);

    return res.json(result.rows);
  } catch (error) {
    console.error("Select entries failed:", error);
    return res.status(500).send("Error");
  }
});

app.delete("/entries/:id", async (req, res) => {
  if (!databaseReady) {
    return res.status(503).send("Database is still starting");
  }

  const id = Number(req.params.id);

  if (!Number.isInteger(id) || id < 1) {
    return res.status(400).send("Invalid entry id");
  }

  try {
    await pool.query("DELETE FROM guestbook_entries WHERE id = $1", [id]);
    return res.send("Deleted");
  } catch (error) {
    console.error("Delete entry failed:", error);
    return res.status(500).send("Error");
  }
});

app.delete("/entries", async (_req, res) => {
  if (!databaseReady) {
    return res.status(503).send("Database is still starting");
  }

  try {
    await pool.query("DELETE FROM guestbook_entries");
    return res.send("Cleared");
  } catch (error) {
    console.error("Clear entries failed:", error);
    return res.status(500).send("Error");
  }
});

app.listen(port, () => {
  console.log(`Backend running on port ${port}`);
});

waitForDatabase()
  .catch((error) => {
    console.error("Database initialization failed:", error);
  });
