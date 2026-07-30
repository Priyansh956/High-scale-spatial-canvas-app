const http = require('http');

const newServer = http.createServer((req, res) => {console.log("Server started!")});

newServer.listen(3000, () => console.log("Server started!"));
