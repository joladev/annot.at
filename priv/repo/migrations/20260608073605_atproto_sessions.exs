defmodule AnnotAt.Repo.Migrations.AtprotoSessions do
  use Ecto.Migration

  def change do
    create table(:atproto_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :auth_server_issuer, :text, null: false
      add :granted_scopes, :text, null: false
      add :access_token, :text, null: false
      add :refresh_token, :text, null: false
      add :dpop_private_jwk, :text, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:atproto_sessions, [:user_id])
  end
end
