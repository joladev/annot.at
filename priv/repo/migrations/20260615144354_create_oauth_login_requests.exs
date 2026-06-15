defmodule AnnotAt.Repo.Migrations.CreateOauthLoginRequests do
  use Ecto.Migration

  def change do
    create table(:oauth_login_requests) do
      add :state, :text, null: false
      add :did, :text, null: false
      add :handle, :text, null: false
      add :pds_host, :text, null: false
      add :auth_server_issuer, :text, null: false
      add :pkce_verifier, :text, null: false
      add :dpop_private_jwk, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:oauth_login_requests, [:state])
  end
end
