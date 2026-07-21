defmodule AnnotAt.Accounts.AtprotoSession do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: map()

  schema "atproto_sessions" do
    # The decentralized ID of the user
    field :did, :string
    # PDS host, where user's data lives
    field :pds_host, :string
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

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :did,
      :pds_host,
      :auth_server_issuer,
      :granted_scopes,
      :access_token,
      :refresh_token,
      :dpop_private_jwk,
      :expires_at
    ])
    |> validate_required([
      :did,
      :pds_host,
      :auth_server_issuer,
      :granted_scopes,
      :access_token,
      :refresh_token,
      :dpop_private_jwk,
      :expires_at
    ])
    |> unique_constraint(:did)
  end
end
