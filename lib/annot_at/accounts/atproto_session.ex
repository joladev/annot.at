defmodule AnnotAt.Accounts.AtprotoSession do
  use Ecto.Schema

  import Ecto.Changeset

  schema "atproto_sessions" do
    # e.g. https://bsky.social
    field :auth_server_issuer, :string
    # Space-separated scopes from token response
    field :granted_scopes, :string
    field :access_token, AnnotAt.Encrypted.Binary
    field :refresh_token, AnnotAt.Encrypted.Binary
    # ES256 keypair for this session
    field :dpop_private_jwk, AnnotAt.Encrypted.Binary
    # Access token expiry
    field :expires_at, :utc_datetime

    belongs_to :user, AnnotAt.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :auth_server_issuer,
      :granted_scopes,
      :access_token,
      :refresh_token,
      :dpop_private_jwk,
      :expires_at
    ])
    |> validate_required([
      :user_id,
      :auth_server_issuer,
      :granted_scopes,
      :access_token,
      :refresh_token,
      :dpop_private_jwk,
      :expires_at
    ])
    |> foreign_key_constraint(:user_id)
    |> unique_constraint(:user_id)
  end
end
