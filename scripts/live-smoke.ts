import Anthropic from "@anthropic-ai/sdk";
import { randomBytes } from "node:crypto";
import { startBridge } from "../bridge/server";

if (process.env.SDK_LIVE_TEST !== "1")
  throw new Error(
    "Set SDK_LIVE_TEST=1 to authorize two billed inference requests.",
  );
const apiKey = process.env.ANTHROPIC_API_KEY;
if (!apiKey) throw new Error("Set ANTHROPIC_API_KEY securely before running.");
const model = process.env.ANTHROPIC_MODEL ?? "claude-haiku-4-5-20251001";
const token = randomBytes(32).toString("hex");
const bridge = await startBridge({
  token,
  port: 0,
  deadlineMs: 30000,
  client: new Anthropic({
    apiKey,
    baseURL: "https://api.anthropic.com",
    maxRetries: 0,
    logLevel: "off",
  }),
});
try {
  for (const [mode, command] of [
    ["once", ["bun", "build/request.js"]],
    ["stream", ["./build/request"]],
  ] as const) {
    const child = Bun.spawn(
      [
        ...command,
        "live-" + mode,
        mode,
        JSON.stringify({
          model,
          max_tokens: 64,
          messages: [{ role: "user", content: "Reply with exactly SDK_OK." }],
        }),
      ],
      {
        env: {
          PATH: process.env.PATH ?? "",
          ANTHROPIC_BEND_TOKEN: token,
          ANTHROPIC_BEND_PORT: String(bridge.port),
        },
        stdout: "pipe",
        stderr: "pipe",
      },
    );
    const timer = setTimeout(() => child.kill("SIGKILL"), 40000);
    let stdout: string;
    let code: number;
    try {
      const result = await Promise.all([
        new Response(child.stdout).text(),
        child.exited,
        new Response(child.stderr).text(),
      ]);
      [stdout, code] = result;
    } finally {
      clearTimeout(timer);
    }
    if (code !== 0)
      throw new Error(
        `Live ${mode} client failed (exit ${code}); provider payload omitted.`,
      );
    const lines = stdout.trim().split("\n");
    if (lines.at(-1) !== "finished")
      throw new Error("Transport did not finish");
    const events = lines.slice(0, -1).map((line) => {
      const at = line.indexOf(" ");
      return { kind: line.slice(0, at), data: JSON.parse(line.slice(at + 1)) };
    });
    const response = events.find((e) => e.kind === "result")?.data;
    const terminal =
      mode === "once"
        ? response?.stop_reason
        : events.find((e) => e.kind === "message_delta")?.data.delta
            ?.stop_reason;
    if (terminal !== "end_turn") throw new Error("Missing completed message");
    const text =
      mode === "once"
        ? response.content
            .filter((item: any) => item.type === "text")
            .map((item: any) => item.text)
            .join("")
        : events
            .filter(
              (e) =>
                e.kind === "content_block_delta" &&
                e.data.delta?.type === "text_delta",
            )
            .map((e) => e.data.delta.text)
            .join("");
    if (text.trim() !== "SDK_OK")
      throw new Error("Unexpected live reply; payload omitted.");
    console.log(
      JSON.stringify({
        provider: "anthropic",
        model,
        mode,
        client: mode === "once" ? "JavaScript" : "native",
        reply: text.trim(),
        passed: true,
      }),
    );
  }
} finally {
  await bridge.close();
}
