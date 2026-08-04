defmodule AnnotAt.Repo.Migrations.RemovePostsGuid do
  use Ecto.Migration

  def change do
    drop index(:posts, [:site_id, :guid])

    alter table(:posts) do
      remove :guid
    end
  end
end
