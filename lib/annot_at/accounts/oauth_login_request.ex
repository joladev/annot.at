defmodule AnnotAt.Accounts.OAuthLoginRequest do
  use Ecto.Schema

  import Ecto.Changeset

  schema "oauth_login_requests" do
    # OAuth `state`, the single-use lookup key for the callback
    field :state, :string
    field :did, :string
    field :handle, :string
    field :pds_host, :string
    field :auth_server_issuer, :string
    # PKCE verifier, its challenge went out in PAR, the verifier redeems the code
    field :pkce_verifier, AnnotAt.Encrypted.Binary
    # Per-session DPoP key (serialized), tokens get bound to it at exchange
    field :dpop_private_jwk, AnnotAt.Encrypted.Binary
    field :token_endpoint, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :state,
      :did,
      :handle,
      :pds_host,
      :auth_server_issuer,
      :pkce_verifier,
      :dpop_private_jwk,
      :token_endpoint
    ])
    |> validate_required([
      :state,
      :did,
      :handle,
      :pds_host,
      :auth_server_issuer,
      :pkce_verifier,
      :dpop_private_jwk,
      :token_endpoint
    ])
    |> unique_constraint(:state)
  end
end
