defmodule AnnotAt.Repo.Migrations.AddTokenEndpointToOauthLoginRequests do
  use Ecto.Migration

  def change do
    alter table(:oauth_login_requests) do
      add :token_endpoint, :text
    end
  end
end
