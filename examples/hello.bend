import Base
import ../anthropic.bend as Anthropic
import ./request.bend as Example

def main() -> IO(Unit):
  do IO<Unit>:
    client : Anthropic.Client <- Example.client()
    model : String <- IO.try(String, IO.get_env("ANTHROPIC_MODEL"))
    result : Result<&1, &1, Anthropic.Error, Anthropic.Stream> <- Anthropic.create(
      client, "hello-example", Anthropic.text_request(model, "Say hello in one sentence.", 256))
    Example.opened(result)
