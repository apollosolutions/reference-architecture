const express = require("express");

function handleCoprocessorRequest(req, res) {
  if (req.body.stage !== "SubgraphRequest") {
    res.json(req.body);
    return;
  }

  const payload = req.body;

  payload.headers["source"] = ["coprocessor"];

  res.json(payload);
}

const port = process.env.PORT || 8081;
const app = express();
app.use(express.json());
app.post("/", handleCoprocessorRequest);
app.listen(port, () => {
  console.log(`🚀 Coprocessor running on port ${port}`);
});
