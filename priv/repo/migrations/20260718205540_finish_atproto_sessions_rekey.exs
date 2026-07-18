defmodule AnnotAt.Repo.Migrations.FinishAtprotoSessionsRekey do
  use Ecto.Migration

  def up do
    alter table(:atproto_sessions) do
      modify :did, :text, null: false
      modify :pds_host, :text, null: false
      remove :user_id
    end
  end

  def down do
    alter table(:atproto_sessions) do
      add :user_id, references(:users, on_delete: :delete_all)
      remove :did
      remove :pds_host
    end

    create unique_index(:atproto_sessions, [:user_id])
  end
end
