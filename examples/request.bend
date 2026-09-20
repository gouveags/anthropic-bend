import Base
import ../anthropic.bend as Anthropic
import ../json.bend as Json

def stopped(+reason: String) -> Bool:
  String.eq(reason, "max_tokens") || String.eq(reason, "refusal")

def provider_failed(+kind: String, +data: Json.Json) -> Bool:
  String.eq(kind, "error") ||
    (String.eq(kind, "result") && stopped(Anthropic.field(data, "stop_reason"))) ||
    (String.eq(kind, "message_delta") && stopped(Anthropic.field(Anthropic.json_field(data, "delta"), "stop_reason")))

def print_event(failed: Bool, stream: Anthropic.Stream, kind: String, data: Json.Json,
                next: Anthropic.Stream -> IO(Unit)) -> IO(Unit):
  match failed:
    case True{}:
      do IO<Unit>:
        Anthropic.close(stream)
        IO.die(Unit, 1, "provider_error: " ++ Json.stringify(data))
    case False{}:
      do IO<Unit>:
        IO.print(kind ++ " " ++ Json.stringify(data))
        next(stream)

def print_step(step: Anthropic.Step, next: Anthropic.Stream -> IO(Unit)) -> IO(Unit):
  match step:
    case Anthropic.Finished{}: IO.print("finished")
    case Anthropic.Failed{Anthropic.Error{code, message, status, request_id, retry_after}}:
      IO.die(Unit, 1, code ++ ": " ++ message)
    case Anthropic.Event{stream, +kind, +data, request_id}:
      print_event(provider_failed(kind, data), stream, kind, data, next)

@unsafe
def consume(stream: Anthropic.Stream) -> IO(Unit):
  do IO<Unit>:
    step : Anthropic.Step <- Anthropic.next(stream)
    print_step(step, s => consume(s))

def opened(result: Result<&1, &1, Anthropic.Error, Anthropic.Stream>) -> IO(Unit):
  match result:
    case Fail{Anthropic.Error{code, message, status, request_id, retry_after}}: IO.die(Unit, 1, message)
    case Done{stream}: consume(stream)

def run(port: U32, token: String, id: String, stream: Bool, body: Json.Json) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1, &1, Anthropic.Error, Anthropic.Stream> <- Anthropic.open_raw(Anthropic.Client{port, token}, id, stream, body)
    opened(result)

def body_read(result: Result<&1, &1, String, Json.Json>, port: U32, token: String, id: String, stream: Bool) -> IO(Unit):
  match result:
    case Fail{message}: IO.die(Unit, 1, message)
    case Done{body}: run(port, token, id, stream, body)

def port_read(port: Maybe<&2, U32>, token: String, args: List<&1, String>) -> IO(Unit):
  match port args:
    case Some{port} Con{id, Con{stream, Con{json, Nil{}}}}:
      body_read(Json.read(json), port, token, id, String.eq(stream, "stream"))
    case _ _: IO.die(Unit, 1, "Usage: request REQUEST_ID stream|once JSON (set ANTHROPIC_BEND_PORT and ANTHROPIC_BEND_TOKEN)")

def main() -> IO(Unit):
  do IO<Unit>:
    port : String <- IO.try(String, IO.get_env("ANTHROPIC_BEND_PORT"))
    token : String <- IO.try(String, IO.get_env("ANTHROPIC_BEND_TOKEN"))
    args : List<&1, String> <- IO.args()
    port_read(U32.read(port), token, args)

def client_port(port: Maybe<&2, U32>, token: String) -> IO(Anthropic.Client):
  match port:
    case Some{port}: IO.pure(Anthropic.Client, Anthropic.Client{port, token})
    case None{}: IO.die(Anthropic.Client, 1, "Invalid ANTHROPIC_BEND_PORT")

def client() -> IO(Anthropic.Client):
  do IO<Anthropic.Client>:
    port : String <- IO.try(String, IO.get_env("ANTHROPIC_BEND_PORT"))
    token : String <- IO.try(String, IO.get_env("ANTHROPIC_BEND_TOKEN"))
    client_port(U32.read(port), token)
