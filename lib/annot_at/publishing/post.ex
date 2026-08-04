defmodule AnnotAt.Publishing.Post do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          site_id: integer(),
          rkey: String.t(),
          content_hash: String.t()
        }

  schema "posts" do
    field :rkey, :string
    # We store the hash of the content to detect changes in the future
    field :content_hash, :string

    belongs_to :site, AnnotAt.Publishing.Site

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:rkey, :content_hash])
    |> validate_required([:rkey, :content_hash])
    |> validate_length(:rkey, max: 512)
    |> validate_length(:content_hash, max: 64)
    |> unique_constraint(:rkey, name: :posts_site_id_rkey_index)
    |> foreign_key_constraint(:site_id)
  end
end
