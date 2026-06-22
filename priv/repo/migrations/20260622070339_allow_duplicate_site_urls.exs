defmodule AnnotAt.Repo.Migrations.AllowDuplicateSiteUrls do
  use Ecto.Migration

  def change do
    drop unique_index(:sites, [:user_id, :url])
    create index(:sites, [:user_id])
  end
end
