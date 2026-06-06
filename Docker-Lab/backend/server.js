const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();

app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: 'db',
  user: 'user',
  password: 'password',
  database: 'mydb',
  port: 5432
});

pool.query(`
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name TEXT
  )
`);

app.post('/save', async (req, res) => {
  const name = req.body.name;

  try {
    await pool.query('INSERT INTO users(name) VALUES($1)', [name]);
    res.send("Saved to DB: " + name);
  } catch (err) {
    console.error(err);
    res.status(500).send("Error");
  }
});

app.get('/users', async (req, res) => {
  const result = await pool.query('SELECT * FROM users');
  res.json(result.rows);
});

app.listen(3000, () => {
  console.log('Backend running on port 3000');
});