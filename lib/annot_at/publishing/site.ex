defmodule AnnotAt.Publishing.Site do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          user_id: integer(),
          name: String.t() | nil,
          url: String.t(),
          description: String.t() | nil,
          feed_url: String.t() | nil,
          rkey: String.t() | nil,
          verified_at: DateTime.t() | nil,
          published_at: DateTime.t() | nil
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
    field :rkey, :string
    # when the site was verified
    field :verified_at, :utc_datetime
    # when the user clicked publish
    field :published_at, :utc_datetime

    belongs_to :user, AnnotAt.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(site, attrs) do
    site
    |> cast(attrs, [:url, :name, :description, :feed_url])
    |> validate_required([:url])
    |> validate_length(:url, max: 2048)
    |> validate_length(:name, max: 255)
    |> validate_length(:description, max: 1000)
    |> validate_length(:feed_url, max: 2048)
    |> unique_constraint(:url, name: :sites_user_id_url_index)
    |> foreign_key_constraint(:user_id)
  end

  def status(%__MODULE__{published_at: %DateTime{}}), do: :published
  def status(%__MODULE__{verified_at: %DateTime{}}), do: :verified
  def status(%__MODULE__{}), do: :draft
end
