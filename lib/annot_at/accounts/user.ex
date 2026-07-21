defmodule AnnotAt.Accounts.User do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          did: String.t(),
          handle: String.t(),
          display_name: String.t(),
          avatar_url: String.t(),
          handle_verified_at: DateTime.t()
        }

  schema "users" do
    # Stable atproto identity from OAuth sub
    field :did, :string
    # Cached display handle
    field :handle, :string
    # Cached from profile
    field :display_name, :string
    # Same
    field :avatar_url, :string
    # Last bidirectional handle↔DID check
    field :handle_verified_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :did,
      :handle,
      :display_name,
      :avatar_url,
      :handle_verified_at
    ])
    |> validate_required([:did])
    |> validate_length(:did, max: 2048)
    |> validate_length(:handle, max: 255)
    |> validate_length(:display_name, max: 255)
    |> validate_length(:avatar_url, max: 2048)
    |> unique_constraint(:did)
  end
end
