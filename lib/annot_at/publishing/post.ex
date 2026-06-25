defmodule AnnotAt.Publishing.Post do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          site_id: integer(),
          guid: String.t(),
          rkey: String.t(),
          content_hash: String.t()
        }

  schema "posts" do
    # The stable ID of the blog post, or the URL if not available
    field :guid, :string
    field :rkey, :string
    # We store the hash of the content to detect changes in the future
    field :content_hash, :string

    belongs_to :site, AnnotAt.Publishing.Site

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:guid, :rkey, :content_hash])
    |> validate_required([:guid, :rkey, :content_hash])
    |> validate_length(:guid, max: 2048)
    |> validate_length(:rkey, max: 512)
    |> validate_length(:content_hash, max: 64)
    |> unique_constraint(:guid, name: :posts_site_id_guid_index)
    |> foreign_key_constraint(:site_id)
  end
end
