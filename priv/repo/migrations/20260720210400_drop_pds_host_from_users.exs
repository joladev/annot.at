defmodule AnnotAt.Repo.Migrations.DropPdsHostFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :pds_host
    end
  end
end
