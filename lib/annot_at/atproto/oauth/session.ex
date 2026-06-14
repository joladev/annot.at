defmodule AnnotAt.Atproto.OAuth.Session do
  @moduledoc """
  An established atproto OAuth session: the credentials and binding needed to
  make authenticated PDS requests and to refresh the access token.

  The `dpop_key` is the per-session private key every request is signed with.
  The access and refresh tokens are bound to it. `issue` identifies the
  authorization server (for refresh and re-discovery), `pds_endpoint` is where
  authenticated XPRC calls go.
  """

  @enforce_keys [
    :did,
    :access_token,
    :refresh_token,
    :dpop_key,
    :scope,
    :issuer,
    :pds_endpoint,
    :expires_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          did: String.t(),
          access_token: String.t(),
          refresh_token: String.t(),
          dpop_key: JOSE.JWK.t(),
          scope: String.t(),
          issuer: String.t(),
          pds_endpoint: String.t(),
          expires_at: DateTime.t()
        }
end
