Mimic.copy(AnnotAt.Atproto.HTTP)
Mimic.copy(AnnotAt.Atproto.DNS)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(AnnotAt.Repo, :manual)
