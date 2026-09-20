import Base
import ../anthropic.bend as Anthropic
import ../json.bend as Json
import ./request.bend as Example

def schema() -> Json.Json:
  Json.Object{[
    Json.Field{"type", Json.Text{"object"}},
    Json.Field{"properties", Json.Object{[Json.Field{"city", Json.Object{[Json.Field{"type", Json.Text{"string"}}]}}]}},
    Json.Field{"required", Json.Array{[Json.Text{"city"}]}},
    Json.Field{"additionalProperties", Json.Boolean{False{}}}
  ]}

# This example requests a function call. It does not execute model-chosen code.
def main() -> IO(Unit):
  do IO<Unit>:
    client : Anthropic.Client <- Example.client()
    model : String <- IO.try(String, IO.get_env("ANTHROPIC_MODEL"))
    result : Result<&1, &1, Anthropic.Error, Anthropic.Stream> <- Anthropic.create(
      client, "tools-example",
      Anthropic.Request{model, 256, Json.Array{[Json.Object{[Json.Field{"role", Json.Text{"user"}}, Json.Field{"content", Json.Text{"What is the weather in Sao Paulo?"}}]}]}, [
        Json.Field{"tools", Json.Array{[Anthropic.tool("weather", "Look up weather for a city", schema())]}},
        Json.Field{"tool_choice", Json.Object{[Json.Field{"type", Json.Text{"any"}}]}}
      ]})
    Example.opened(result)
