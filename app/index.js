const express = require('express');
const { Pool } = require('pg');
const app = express();
const port = process.env.PORT || 3000;

// PostgreSQL connection pool
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'myapp',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres',
  ssl: {
    rejectUnauthorized: false
  }
});

app.use(express.json());
app.use(express.static('public'));

// Home page with HTML
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>My App - User Management</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; background: red; color: #1f2937; }
        h1 { color: #1f2937; }
        .form-group { margin: 15px 0; }
        input { padding: 8px; width: 200px; margin-right: 10px; }
        button { padding: 8px 20px; background: #007bff; color: white; border: none; cursor: pointer; }
        button:hover { background: #0056b3; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f8f9fa; }
        .delete-btn { background: #dc3545; padding: 5px 10px; }
        .delete-btn:hover { background: #c82333; }
        .status { margin: 10px 0; padding: 10px; border-radius: 4px; }
        .success { background: #d4edda; color: #155724; }
        .error { background: #f8d7da; color: #721c24; }
      </style>
    </head>
    <body>
      <h1>User Management System</h1>
      <p>Sample web application with PostgreSQL database</p>
      
      <div id="status"></div>
      
      <div class="form-group">
        <h2>Add New User</h2>
        <input type="text" id="name" placeholder="Name">
        <input type="email" id="email" placeholder="Email">
        <button onclick="addUser()">Add User</button>
      </div>
      
      <h2>Users List</h2>
      <button onclick="loadUsers()">Refresh Users</button>
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Created At</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody id="users-list"></tbody>
      </table>
      
      <script>
        function showStatus(message, isError = false) {
          const status = document.getElementById('status');
          status.className = 'status ' + (isError ? 'error' : 'success');
          status.textContent = message;
          setTimeout(() => status.textContent = '', 3000);
        }
        
        async function loadUsers() {
          try {
            const response = await fetch('/api/users');
            const users = await response.json();
            const tbody = document.getElementById('users-list');
            tbody.innerHTML = users.map(user => \`
              <tr>
                <td>\${user.id}</td>
                <td>\${user.name}</td>
                <td>\${user.email}</td>
                <td>\${new Date(user.created_at).toLocaleString()}</td>
                <td><button class="delete-btn" onclick="deleteUser(\${user.id})">Delete</button></td>
              </tr>
            \`).join('');
          } catch (error) {
            showStatus('Error loading users', true);
          }
        }
        
        async function addUser() {
          const name = document.getElementById('name').value;
          const email = document.getElementById('email').value;
          
          if (!name || !email) {
            showStatus('Please enter both name and email', true);
            return;
          }
          
          try {
            const response = await fetch('/api/users', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ name, email })
            });
            
            if (response.ok) {
              showStatus('User added successfully!');
              document.getElementById('name').value = '';
              document.getElementById('email').value = '';
              loadUsers();
            } else {
              showStatus('Error adding user', true);
            }
          } catch (error) {
            showStatus('Error adding user', true);
          }
        }
        
        async function deleteUser(id) {
          if (!confirm('Are you sure you want to delete this user?')) return;
          
          try {
            const response = await fetch('/api/users/' + id, { method: 'DELETE' });
            if (response.ok) {
              showStatus('User deleted successfully!');
              loadUsers();
            } else {
              showStatus('Error deleting user', true);
            }
          } catch (error) {
            showStatus('Error deleting user', true);
          }
        }
        
        // Load users on page load
        loadUsers();
      </script>
    </body>
    </html>
  `);
});

// API endpoint to get all users
app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM users ORDER BY id DESC');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// API endpoint to create a new user
app.post('/api/users', async (req, res) => {
  const { name, email } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// API endpoint to delete a user
app.delete('/api/users/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query('DELETE FROM users WHERE id = $1', [id]);
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: 'Database error' });
  }
});

// Initialize database table
async function initDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('Database initialized successfully');
  } catch (error) {
    console.error('Error initializing database:', error);
  }
}

initDatabase();

app.listen(port, () => console.log(`listening on ${port}`));
