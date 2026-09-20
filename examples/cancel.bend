import Base
import ../anthropic.bend as Anthropic
import ./request.bend as Example

def started(result: Result<&1, &1, Anthropic.Error, Anthropic.Stream>, client: Anthropic.Client) -> IO(Unit):
  match result:
    case Fail{Anthropic.Error{code, message, status, request_id, retry_after}}: IO.die(Unit, 1, message)
    case Done{stream}:
      do IO<Unit>:
        IO.sleep(50)
        ack : Result<&1, &1, String, Bool> <- Anthropic.cancel(client, "cancel-example")
        Example.consume(stream)

def main() -> IO(Unit):
  do IO<Unit>:
    +client : Anthropic.Client <- Example.client()
    model : String <- IO.try(String, IO.get_env("ANTHROPIC_MODEL"))
    result : Result<&1, &1, Anthropic.Error, Anthropic.Stream> <- Anthropic.create(client, "cancel-example", Anthropic.text_request(model, "slow", 256))
    started(result, client)
