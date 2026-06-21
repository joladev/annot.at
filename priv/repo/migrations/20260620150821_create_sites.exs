defmodule AnnotAt.Repo.Migrations.CreateSites do
  use Ecto.Migration

  def change do
    create table(:sites) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :url, :text, null: false
      add :description, :text
      add :feed_url, :text, null: false
      add :rkey, :text, null: false
      add :verified_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sites, [:user_id, :rkey])
  end
end
