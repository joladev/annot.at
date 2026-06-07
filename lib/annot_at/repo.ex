defmodule AnnotAt.Repo do
  use Ecto.Repo,
    otp_app: :annot_at,
    adapter: Ecto.Adapters.Postgres
end
