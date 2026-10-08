use smartmove_db

db.createUser({
  user: "smartmove_app",
  pwd: passwordPrompt(),
  roles: [{ role: "readWrite", db: "smartmove_db" }]
})
