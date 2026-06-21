defmodule AnnotAt.Repo.Migrations.AlterSitesForWizard do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      modify :name, :text, null: true, from: {:text, null: false}
      modify :feed_url, :text, null: true, from: {:text, null: false}
      modify :verified_at, :utc_datetime, null: true, from: {:utc_datetime, null: false}
      modify :rkey, :text, null: true, from: {:text, null: false}
      add :published_at, :utc_datetime
    end

    drop unique_index(:sites, [:user_id, :rkey])
    create unique_index(:sites, [:user_id, :url])
  end
end
