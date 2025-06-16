import express from "express";
import { CoprocessorRequest, CoprocessorStage } from "./types";

/**
 * Handles a coprocessor request
 * Adds a "source" header to the request to all stages besides the SubgraphRequest stage
 *
 * @param req - The request object
 * @param res - The response object
 */
function handleCoprocessorRequest(
  req: CoprocessorRequest,
  res: express.Response
): void {
  if (req.body.stage !== CoprocessorStage.SUBGRAPH_REQUEST) {
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
