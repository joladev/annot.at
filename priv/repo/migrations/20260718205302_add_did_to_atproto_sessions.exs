defmodule AnnotAt.Repo.Migrations.AddDidToAtprotoSessions do
  use Ecto.Migration

  def change do
    alter table(:atproto_sessions) do
      add :did, :text
      add :pds_host, :text
    end

    create unique_index(:atproto_sessions, [:did])
  end
end
