defmodule AnnotAt.Publishing.Site do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          user_id: integer(),
          name: String.t(),
          url: String.t(),
          description: String.t() | nil,
          feed_url: String.t(),
          rkey: String.t(),
          verified_at: DateTime.t()
        }

  schema "sites" do
    # Display name of the publication
    field :name, :string
    # The website the publication represents
    field :url, :string
    # Tagline
    field :description, :string
    # The url of the feed
    field :feed_url, :string
    # rkey of the site.standard.publication record
    # deterministically generated from did and url
    field :rkey, :string
    # when the site was verified
    field :verified_at, :utc_datetime

    belongs_to :user, AnnotAt.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(site, attrs) do
    site
    |> cast(attrs, [:name, :url, :description, :feed_url])
    |> validate_required([:name, :url, :feed_url, :rkey])
    |> validate_length(:name, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_length(:url, max: 2048)
    |> validate_length(:feed_url, max: 2048)
    |> validate_length(:rkey, max: 512)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:rkey, name: :sites_user_id_rkey_index)
  end
end
