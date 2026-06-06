const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");

const app = express();
const port = Number(process.env.PORT || 3000);

app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || "postgres-service",
  user: process.env.DB_USER || "user",
  password: process.env.DB_PASSWORD || "password",
  database: process.env.DB_NAME || "mydb",
  port: Number(process.env.DB_PORT || 5432)
});

async function prepareDatabase() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL
    )
  `);
}

async function waitForDatabase(maxAttempts = 20, delayMs = 3000) {
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await prepareDatabase();
      console.log(`Database is ready after attempt ${attempt}.`);
      return;
    } catch (error) {
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
    await pool.query("SELECT 1");
    res.json({ status: "ok" });
  } catch (error) {
    console.error("Healthcheck failed:", error);
    res.status(500).json({ status: "error" });
  }
});

app.post("/save", async (req, res) => {
  const name = (req.body.name || "").trim();

  if (!name) {
    return res.status(400).send("Name is required");
  }

  try {
    await pool.query("INSERT INTO users(name) VALUES($1)", [name]);
    return res.send(`Saved to DB: ${name}`);
  } catch (error) {
    console.error("Insert failed:", error);
    return res.status(500).send("Error");
  }
});

app.get("/users", async (_req, res) => {
  try {
    const result = await pool.query("SELECT * FROM users ORDER BY id ASC");
    return res.json(result.rows);
  } catch (error) {
    console.error("Select failed:", error);
    return res.status(500).send("Error");
  }
});

waitForDatabase()
  .then(() => {
    app.listen(port, () => {
      console.log(`Backend running on port ${port}`);
    });
  })
  .catch((error) => {
    console.error("Database initialization failed:", error);
    process.exit(1);
  });
