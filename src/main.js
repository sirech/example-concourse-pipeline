const express = require('express')
const app = express()
const port = 3000

app.get('/', (req, res) => res.send('Hello World!'))
app.get('/secret', (req, res) => res.send(`The super secret value is ${process.env.SECRET}`))

app.listen(port, () => console.log(`Example app listening on port ${port}!`))
