defmodule AnnotAt.Accounts.User do
  use Ecto.Schema

  import Ecto.Changeset

  schema "users" do
    # Stable atproto identity from OAuth sub
    field :did, :string
    # Cached display handle
    field :handle, :string
    # Cached from profile
    field :display_name, :string
    # Same
    field :avatar_url, :string
    # Cached PDS URL from DID resolution
    field :pds_host, :string
    # Last bidirectional handle↔DID check
    field :handle_verified_at, :utc_datetime

    has_one :atproto_session, AnnotAt.Accounts.AtprotoSession

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :did,
      :handle,
      :display_name,
      :avatar_url,
      :pds_host,
      :handle_verified_at
    ])
    |> validate_required([:did])
    |> validate_length(:did, max: 2048)
    |> validate_length(:handle, max: 255)
    |> validate_length(:display_name, max: 255)
    |> validate_length(:avatar_url, max: 2048)
    |> validate_length(:pds_host, max: 255)
    |> unique_constraint(:did)
  end
end
