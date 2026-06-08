defmodule AnnotAt.Repo.Migrations.Users do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :did, :text, null: false
      add :handle, :text
      add :display_name, :text
      add :avatar_url, :text
      add :pds_host, :text
      add :handle_verified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:did])
  end
end
