defmodule AnnotAt.Repo.Migrations.AddPostsRkeyUniqueIndex do
  use Ecto.Migration

  def change do
    create unique_index(:posts, [:site_id, :rkey])
  end
end
