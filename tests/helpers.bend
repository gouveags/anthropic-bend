import Base
import ../anthropic.bend as Anthropic
import ../json.bend as Json

def summary(response: Anthropic.Message) -> String:
  match response:
    case Anthropic.Message{id, status, text, calls, usage, raw}:
      id ++ "|" ++ status ++ "|" ++ text ++ "|" ++ Nat.show(List.length(&2, Anthropic.ToolUse, calls)) ++ "|" ++ Json.stringify(raw)

def parsed(result: Result<&1, &1, String, Json.Json>) -> IO(Unit):
  match result:
    case Fail{e}: IO.die(Unit, 1, e)
    case Done{value}: IO.print(summary(Anthropic.message(value)))

def argument(args: List<&1, String>) -> IO(Unit):
  match args:
    case Con{s, Nil{}}: parsed(Json.read(s))
    case _: IO.die(Unit, 1, "expected response JSON")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    argument(args)
