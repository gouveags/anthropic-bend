import Anthropic from "@anthropic-ai/sdk";
import { startBridge } from "./server";

const token = process.env.ANTHROPIC_BEND_TOKEN;
const apiKey = process.env.ANTHROPIC_API_KEY;
if (!token || !apiKey) {
  console.error(
    "Set ANTHROPIC_API_KEY and ANTHROPIC_BEND_TOKEN (at least 32 characters). See README.md.",
  );
  process.exit(1);
}
const port = Number(process.env.ANTHROPIC_BEND_PORT ?? "42102");
if (!Number.isInteger(port) || port < 1 || port > 65535)
  throw new Error("Invalid ANTHROPIC_BEND_PORT");
const bridge = await startBridge({
  token,
  port,
  deadlineMs: Number(process.env.ANTHROPIC_BEND_DEADLINE_MS ?? "120000"),
  client: new Anthropic({
    apiKey,
    baseURL: "https://api.anthropic.com",
    maxRetries: 2,
    logLevel: "off",
  }),
});
console.log(
  `anthropic-bend 0.1.0 listening on 127.0.0.1:${bridge.port} (protocol 1)`,
);
for (const signal of ["SIGINT", "SIGTERM"] as const) {
  process.once(signal, () => {
    void bridge.close().then(() => process.exit(0));
  });
}
