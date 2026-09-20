import Base
import ../anthropic.bend as Anthropic
import ../json.bend as Json
import ./request.bend as Example

def schema() -> Json.Json:
  Json.Object{[
    Json.Field{"type", Json.Text{"object"}},
    Json.Field{"properties", Json.Object{[Json.Field{"name", Json.Object{[Json.Field{"type", Json.Text{"string"}}]}}]}},
    Json.Field{"required", Json.Array{[Json.Text{"name"}]}},
    Json.Field{"additionalProperties", Json.Boolean{False{}}}
  ]}

def main() -> IO(Unit):
  do IO<Unit>:
    client : Anthropic.Client <- Example.client()
    model : String <- IO.try(String, IO.get_env("ANTHROPIC_MODEL"))
    result : Result<&1, &1, Anthropic.Error, Anthropic.Stream> <- Anthropic.create(
      client, "structured-example",
      Anthropic.Request{model, 256, Json.Array{[Json.Object{[Json.Field{"role", Json.Text{"user"}}, Json.Field{"content", Json.Text{"Extract the name: Ada wrote this."}}]}]},
        [Json.Field{"output_config", Anthropic.json_schema(schema())}]})
    Example.opened(result)
