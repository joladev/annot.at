defmodule AnnotAt.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :guid, :text, null: false
      add :rkey, :text, null: false
      add :content_hash, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:posts, [:site_id, :guid])
  end
end
