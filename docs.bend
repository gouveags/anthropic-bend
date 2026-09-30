# An unofficial Anthropic SDK for Bend, with typed requests, streaming, and tool calling.

import Base

# # anthropic-bend
#
# **An unofficial Anthropic SDK for Bend, with typed requests, streaming, and tool calling.**
#
# Call Claude from Bend through a small authenticated localhost companion using the official Anthropic TypeScript SDK. Native and JavaScript Bend programs use the same interface.
#
# [Examples](https://github.com/gouveags/anthropic-bend/tree/main/examples) · [Source](https://github.com/gouveags/anthropic-bend) · [Issues](https://github.com/gouveags/anthropic-bend/issues) · [OpenAI companion project](https://github.com/gouveags/openai-bend)
#
# > Experimental v0.1.0. A community project, not an official Anthropic or Bend project. This release covers the Messages API, not the entire SDK. Automated tests use a local mock API; a bounded live Claude smoke test is recorded below.
#
# ## Install from Bend Hub
#
# [**bend-anthropic-sdk@0.1.0.1**](https://hub.bend-lang.com/n/bend-anthropic-sdk) · [Packaged documentation](https://github.com/gouveags/anthropic-bend/blob/main/docs.bend) · [Source and examples](https://github.com/gouveags/anthropic-bend)
#
# Use **Bend 2.0.34 or newer** for named imports. Bend fetches the exact release, resolves it to an immutable content hash, and verifies the downloaded files. There is no separate install command for the Bend modules.
#
# ```bend
# import bend-anthropic-sdk@0.1.0.1/anthropic.bend as Anthropic
# import bend-anthropic-sdk@0.1.0.1/json.bend as Json
# ```
#
# Install and start the localhost companion below as well: the Hub package contains the Bend modules, documentation and MIT license, not the Bun companion or its dependencies. Provider API keys stay in the companion process.
#
# Release `0.1.0.1` fixes the JSON parser constructor collision with Bend 2.0.28+ and updates the example CLIs for Bend 2.0.34. The SDK API and bridge protocol are unchanged. Existing imports of the [previous hash](https://hub.bend-lang.com/0x44dbbb9fe7023c9f8cc89550f8343cd3) remain available, but require the older compiler they were published with. Use `0.1.0.1` on current Bend. Published versions are immutable; future updates use a new version.
#
# ## Features
#
# | Capability                                             | Implementation                                                  |
# | ------------------------------------------------------ | --------------------------------------------------------------- |
# | Create messages                                        | Typed model, max_tokens and messages; arbitrary JSON options    |
# | Streaming                                              | Message, content-block, thinking, tool-input and unknown events |
# | Message helpers                                        | Text, tool uses, stop reason, usage and original JSON           |
# | Structured outputs                                     | `output_config.format` JSON Schema helper                       |
# | Tool use                                               | Definitions, typed extraction and tool-result builder           |
# | Images/documents                                       | Content blocks supplied as JSON; no upload helper               |
# | Cancellation                                           | Close a stream or cancel its ID separately                      |
# | Error metadata                                         | HTTP status, request ID and Retry-After                         |
# | Batches, uploads, token-count endpoint, managed agents | Not implemented                                                 |
# | Bedrock, Vertex and beta-header configuration          | Not implemented                                                 |
#
# No automatic tool execution, agent loop, arbitrary schema derivation, or stream-to-final-message accumulator is included. Raw payloads retain details without convenience helpers.
#
# ## Install the companion
#
# Requirements: [Bend 2.0.34+](https://github.com/bendlang/bend), [Bun 1.4.2](https://bun.sh/), and Git. Native builds also need Clang and Make. Linux x86_64 is tested; macOS is not yet validated.
#
# ```sh
# git clone https://github.com/gouveags/anthropic-bend.git
# cd anthropic-bend
# git checkout main
# bun install --frozen-lockfile
# ```
#
# Load your key into `ANTHROPIC_API_KEY` through your secret manager or private shell input. Never commit it or put it in a command saved to shell history.
#
# ```sh
# export ANTHROPIC_BEND_TOKEN="$(openssl rand -hex 32)"
# export ANTHROPIC_BEND_PORT=42102
# export ANTHROPIC_MODEL='your-available-claude-model-id'
# bun run bridge
# ```
#
# Expected startup:
#
# ```text
# anthropic-bend 0.1.0 listening on 127.0.0.1:42102 (protocol 1)
# ```
#
# Give your Bend process the same bridge token and port. It does not need the Anthropic API key. Share the token between terminals through your local secret-management mechanism; the bridge never prints it.
#
# **The Bend Hub package installs only the Bend modules. Install the companion and its Bun dependencies separately using these steps.**
#
# ## Quick start
#
# With the companion running and the same bridge environment available:
#
# ```sh
# make build/request.js
# bun build/request.js example-1 once \
#   "{\"model\":\"$ANTHROPIC_MODEL\",\"max_tokens\":256,\"messages\":[{\"role\":\"user\",\"content\":\"Say hello.\"}]}"
#
# # Change 'once' to 'stream' to print every event.
# # Or use the native client:
# make build/request
# ./build/request example-2 stream \
#   "{\"model\":\"$ANTHROPIC_MODEL\",\"max_tokens\":256,\"messages\":[{\"role\":\"user\",\"content\":\"Explain interaction nets briefly.\"}]}"
# ```
#
# The Makefile emits C and compiles with Clang `-O1`. Builds are sequential; allow roughly 4 GiB of available compiler memory. This integration makes no claim of faster inference or GPU acceleration.
#
# ## Typed Bend API
#
# Within this checkout:
#
# ```bend
# import Base
# import ./anthropic.bend as Anthropic
#
# def start(token: String, model: String) ->
#   IO(Result<&1, &1, Anthropic.Error, Anthropic.Stream>):
#   Anthropic.create(
#     Anthropic.Client{42102, token},
#     "my-unique-request-id",
#     Anthropic.text_request(model, "Say hello.", 256))
# ```
#
# Use `Anthropic.stream` for streaming or `Anthropic.open_raw` for a JSON request body. Typed requests are `Request{model, max_tokens, messages, options}`. Options are JSON fields such as `system`, `thinking`, `tools`, `tool_choice` and `output_config`; model support varies.
#
# Both methods return an owned stream handle. `Anthropic.next` yields:
#
# - `Event{stream, kind, data, request_id}`: process the payload, then read using the returned stream.
# - `Finished{}`: the transport ended correctly and the socket has closed.
# - `Failed{error}`: the socket has closed with an API, protocol or transport failure.
#
# Nonstreaming calls produce a `result`. `Anthropic.message(data)` extracts `Message{id, stop_reason, text, calls, usage, raw}`. Streaming begins with bridge `metadata`, then provider events such as `message_start`, `content_block_delta`, `message_delta` and `message_stop`.
#
# **Transport completion is not a successful model outcome by itself.** Inspect `stop_reason` or the final `message_delta`: `max_tokens` means truncated output; `tool_use` requests tool results. Stream `error` events remain visible. Missing terminal events fail explicitly. Anthropic usage deltas are cumulative, not values to sum blindly.
#
# The companion uses the official SDK's raw SSE decoder to preserve unknown event types and pings. For text, inspect `content_block_delta` with `delta.type` equal to `text_delta`. Thinking and tool JSON deltas remain separate. See [the streaming reference](https://platform.claude.com/docs/en/build-with-claude/streaming).
#
# Call `Anthropic.close(stream)` when abandoning a result. `Anthropic.cancel(client, id)` uses a separate connection, allowing another computation to cancel a blocked read. Cancellation requests an abort; remote processing or billing may already have occurred.
#
# ## Examples
#
# - [hello.bend](https://github.com/gouveags/anthropic-bend/blob/main/examples/hello.bend): basic typed request.
# - [request.bend](https://github.com/gouveags/anthropic-bend/blob/main/examples/request.bend): complete event reader and JSON CLI.
# - [structured.bend](https://github.com/gouveags/anthropic-bend/blob/main/examples/structured.bend): JSON Schema output.
# - [tools.bend](https://github.com/gouveags/anthropic-bend/blob/main/examples/tools.bend): request a tool call without automatic execution.
# - [cancel.bend](https://github.com/gouveags/anthropic-bend/blob/main/examples/cancel.bend): cancellation; cancellation intentionally exits nonzero.
#
# Compile with `bend examples/hello.bend -o build/hello.js`, then run `bun build/hello.js`. Examples read `ANTHROPIC_BEND_PORT`, `ANTHROPIC_BEND_TOKEN` and, where needed, `ANTHROPIC_MODEL`.
#
# ## Structured outputs
#
# Add `Json.Field{"output_config", Anthropic.json_schema(schema)}` to request options. It produces `output_config: {format: {type: "json_schema", schema: ...}}`.
#
# Use [Anthropic's supported schemas](https://platform.claude.com/docs/en/build-with-claude/structured-outputs). Check the stop reason/refusal before parsing output with `Json.read`, then validate your application's fields. Arbitrary schemas are not automatically proven equivalent to Bend types.
#
# ## Tool-use round trip
#
# Define a tool using `Anthropic.tool(name, description, input_schema)`. `Message.calls` contains `ToolUse{id, name, input, raw}` records. Validate names and inputs against an application-owned registry before executing anything.
#
# Create results with `Anthropic.tool_result(tool_use_id, content, is_error)`. Send the conversation again, preserving the assistant content and adding a user message with the tool results:
#
# ```json
# [
#   { "role": "user", "content": "What is the weather?" },
#   {
#     "role": "assistant",
#     "content": [
#       {
#         "type": "tool_use",
#         "id": "toolu_example",
#         "name": "weather",
#         "input": { "city": "Sao Paulo" }
#       }
#     ]
#   },
#   {
#     "role": "user",
#     "content": [
#       {
#         "type": "tool_result",
#         "tool_use_id": "toolu_example",
#         "content": "22 C",
#         "is_error": false
#       }
#     ]
#   }
# ]
# ```
#
# The assistant content is abbreviated here. Real continuations must retain the full content, including thinking/signature blocks, and return results for the relevant tool uses. Anthropic continues through messages, not OpenAI's `previous_response_id`. Read the [official tool guidance](https://platform.claude.com/docs/en/agents-and-tools/tool-use/define-tools).
#
# ## JSON behavior
#
# The JSON module supports null, booleans, decimal number strings, Unicode strings, arrays and objects. `Json.get` distinguishes absent fields (`None`) from explicit null (`Some{Null{}}`). Omit an optional field by leaving it out.
#
# Numbers do not pass through Bend's `F32`. The JavaScript companion and SDK still have IEEE-754 limitations: integers beyond JavaScript's safe range are not guaranteed exact across the whole system. Supply valid decimal strings in `Json.Number`. Unknown fields remain available in raw JSON.
#
# ## Security and architecture
#
# ```text
# Bend → authenticated localhost TCP → companion → official Anthropic SDK → HTTPS API
# ```
#
# - Loopback binding to `127.0.0.1`; never expose or proxy this service publicly.
# - Separate random bridge token, at least 32 characters; constant-time comparison for equal-length tokens.
# - Only `messages.create` and local cancellation are allowed. Request bodies cannot choose SDK methods, URLs, headers or credentials.
# - The CLI fixes the API URL to `https://api.anthropic.com` and disables SDK logging.
# - One request per connection; 32 connections; 1 MiB requests; 4 MiB frames. JSON decoding caps nesting at 64 levels and tokens at 65536.
# - Partial requests expire after 10 seconds. Completed/rejected connections have a bounded close timeout. The upstream deadline defaults to 120 seconds; `ANTHROPIC_BEND_DEADLINE_MS` accepts up to 600000.
# - The SDK owns retries (two configured). The bridge never replays disconnected requests; consider duplicate cost/execution before retrying partial results.
# - Writes respect backpressure. Disconnects/cancellation abort upstream requests. ASCII-escaped JSON avoids UTF-8 fragmentation at socket boundaries.
# - This project implements no telemetry or prompt logging. Provider errors may contain submitted content and go only to authenticated callers. Examples intentionally print outputs.
#
# This is a single-user, trusted-machine design, not a multi-tenant gateway. Local TCP has no TLS. A compromised account, privileged process, stolen token or malicious replacement companion is outside its protection. Bend's checks do not prove the provider, foreign socket runtime or entire SDK secure. Externally driven loops and structurally unrecognized recursion are explicitly marked `@unsafe`.
#
# ## Test and contribute
#
# ```sh
# bun install --frozen-lockfile
# make test
# bun audit
# ```
#
# Tests exercise the actual official SDK against local HTTP mocks, real TCP, native/JavaScript clients, documented examples and fresh content-addressed package imports. They use no real API key or paid inference. Passing mocks proves the integration contract, not model behavior, account access or all provider features.
#
# [compatibility.json](https://github.com/gouveags/anthropic-bend/blob/main/compatibility.json) records pinned versions. CI checks types, formatting, compilation, tests and dependency advisories. Coverage includes Unicode, nesting, malformed input, auth, connection limits, deadlines, cancellation, disconnects and incomplete streams.
#
# For connection failures, check the companion, port and shared token. For API failures, inspect status/request ID and verify credentials/model access in the companion. [Report reproducible issues](https://github.com/gouveags/anthropic-bend/issues) without private prompts or credentials.
#
# ## License
#
# MIT. Anthropic's SDK and Bend are separately licensed. The JSON and transport foundation is shared with [openai-bend](https://github.com/gouveags/openai-bend).
#
# ## Releases and live validation
#
# [Release workflow and credential renewal](https://github.com/gouveags/anthropic-bend/blob/main/docs/releasing.md). New Hub versions publish automatically after their version bump lands on `main` and CI succeeds.
#
# For an explicitly authorized real-provider check, load your API key into the environment securely, build with the compiler in `compatibility.json`, then run:
#
# ```sh
# make build
# SDK_LIVE_TEST=1 bun run test:live
# ```
#
# This makes two billed requests (JavaScript nonstreaming and native streaming), each limited to 64 output tokens with retries disabled. It checks the actual reply and completion status. Regular `make test` uses local mocks and does not call a paid API. Provider keys are never needed by the release workflow.
#
# Live smoke validation on September 30, 2026 passed with `claude-haiku-4-5-20251001`: both the JavaScript nonstreaming and native streaming clients received a completed `SDK_OK` reply. This verifies basic real-provider integration, not every model or API feature.
#

def repository() -> String:
  "https://github.com/gouveags/anthropic-bend"

def version() -> String:
  "0.1.0"
